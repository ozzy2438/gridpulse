#!/usr/bin/env python3
"""
GridPulse Backend API
---------------------
Kong'un arkasında çalışan API servisi.

Bu servis:
1. Kafka'dan veri okur
2. Consumer'lara JSON formatında sunar
3. Correlation ID'yi takip eder
"""

from flask import Flask, jsonify, request, g
import json
import threading
from datetime import datetime
from collections import deque
import uuid
import logging

# Logging ayarla
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# ========================================
# IN-MEMORY CACHE (Demo amaçlı)
# ========================================
# Gerçek üretimde Redis veya veritabanı kullanılır
class DataCache:
    def __init__(self, max_size=1000):
        self.dispatch_events = deque(maxlen=max_size)
        self.weather_events = deque(maxlen=max_size)
        self.lock = threading.Lock()
    
    def add_dispatch(self, event):
        with self.lock:
            self.dispatch_events.append(event)
    
    def add_weather(self, event):
        with self.lock:
            self.weather_events.append(event)
    
    def get_dispatch(self, region_id=None, limit=100):
        with self.lock:
            events = list(self.dispatch_events)
            if region_id:
                events = [e for e in events if e.get("region_id") == region_id]
            return events[-limit:]
    
    def get_weather(self, region_id=None, limit=100):
        with self.lock:
            events = list(self.weather_events)
            if region_id:
                events = [e for e in events if e.get("region_id") == region_id]
            return events[-limit:]

cache = DataCache()


# ========================================
# KAFKA CONSUMER (Background Thread)
# ========================================
def kafka_consumer_thread():
    """Kafka'dan mesajları oku ve cache'e ekle"""
    try:
        from kafka import KafkaConsumer
        consumer = KafkaConsumer(
            'market.dispatch',
            'weather.observations',
            bootstrap_servers='localhost:9092',
            auto_offset_reset='earliest',
            enable_auto_commit=True,
            group_id='gridpulse-api-consumer',
            value_deserializer=lambda m: json.loads(m.decode('utf-8'))
        )
        
        logger.info("Kafka consumer started")
        
        for message in consumer:
            event = message.value
            topic = message.topic
            
            if topic == 'market.dispatch':
                cache.add_dispatch(event)
                logger.debug(f"Cached dispatch event: {event.get('event_id')}")
            elif topic == 'weather.observations':
                cache.add_weather(event)
                logger.debug(f"Cached weather event: {event.get('event_id')}")
                
    except ImportError:
        logger.warning("kafka-python not installed, running without Kafka consumer")
    except Exception as e:
        logger.error(f"Kafka consumer error: {e}")


# ========================================
# MIDDLEWARE - Correlation ID
# ========================================
@app.before_request
def before_request():
    """Her istekte correlation ID'yi yakala veya oluştur"""
    # Kong'dan gelen correlation ID
    correlation_id = request.headers.get('X-Correlation-ID')
    if not correlation_id:
        correlation_id = str(uuid.uuid4())
    
    g.correlation_id = correlation_id
    g.request_time = datetime.utcnow()
    
    logger.info(f"[{correlation_id}] {request.method} {request.path}")


@app.after_request
def after_request(response):
    """Response'a correlation ID ekle"""
    response.headers['X-Correlation-ID'] = g.correlation_id
    
    # İşlem süresini hesapla
    duration = (datetime.utcnow() - g.request_time).total_seconds() * 1000
    response.headers['X-Response-Time'] = f"{duration:.2f}ms"
    
    logger.info(f"[{g.correlation_id}] Response: {response.status_code} ({duration:.2f}ms)")
    
    return response


# ========================================
# API ENDPOINTS
# ========================================

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        "status": "healthy",
        "service": "gridpulse-api",
        "timestamp": datetime.utcnow().isoformat(),
        "cache_stats": {
            "dispatch_events": len(cache.dispatch_events),
            "weather_events": len(cache.weather_events)
        }
    })


@app.route('/api/v1/dispatch', methods=['GET'])
def get_dispatch():
    """
    Market dispatch verilerini getir.
    
    Query Parameters:
    - region_id: Bölge filtresi (örn: NSW1, VIC1)
    - limit: Maksimum kayıt sayısı (default: 100)
    
    Headers:
    - X-Correlation-ID: İzlenebilirlik için
    """
    region_id = request.args.get('region_id')
    limit = int(request.args.get('limit', 100))
    
    events = cache.get_dispatch(region_id=region_id, limit=limit)
    
    return jsonify({
        "data": events,
        "meta": {
            "count": len(events),
            "region_filter": region_id,
            "correlation_id": g.correlation_id,
            "timestamp": datetime.utcnow().isoformat()
        }
    })


@app.route('/api/v1/dispatch', methods=['POST'])
def post_dispatch():
    """
    Yeni dispatch event'i ekle.
    
    Bu endpoint genelde webMethods tarafından çağrılır.
    """
    try:
        event = request.get_json()
        
        # Validation
        required_fields = ['region_id', 'value_mw']
        for field in required_fields:
            if field not in event:
                return jsonify({
                    "error": f"Missing required field: {field}",
                    "correlation_id": g.correlation_id
                }), 400
        
        # Event ID oluştur
        if 'event_id' not in event:
            event['event_id'] = f"manual_{g.correlation_id}"
        
        event['event_type'] = 'MarketDispatchEvent'
        event['ingestion_time'] = datetime.utcnow().isoformat()
        event['correlation_id'] = g.correlation_id
        
        # Cache'e ekle
        cache.add_dispatch(event)
        
        return jsonify({
            "status": "accepted",
            "event_id": event['event_id'],
            "correlation_id": g.correlation_id
        }), 202
        
    except Exception as e:
        logger.error(f"[{g.correlation_id}] Error: {e}")
        return jsonify({
            "error": str(e),
            "correlation_id": g.correlation_id
        }), 500


@app.route('/api/v1/weather', methods=['GET'])
def get_weather():
    """
    Hava durumu gözlemlerini getir.
    
    Query Parameters:
    - region_id: Bölge filtresi
    - limit: Maksimum kayıt sayısı
    """
    region_id = request.args.get('region_id')
    limit = int(request.args.get('limit', 100))
    
    events = cache.get_weather(region_id=region_id, limit=limit)
    
    return jsonify({
        "data": events,
        "meta": {
            "count": len(events),
            "region_filter": region_id,
            "correlation_id": g.correlation_id,
            "timestamp": datetime.utcnow().isoformat()
        }
    })


@app.route('/api/v1/stats', methods=['GET'])
def get_stats():
    """Dashboard için istatistikler"""
    dispatch_events = list(cache.dispatch_events)
    weather_events = list(cache.weather_events)
    
    # Region bazında aggregation
    dispatch_by_region = {}
    for event in dispatch_events:
        region = event.get('region_id', 'unknown')
        if region not in dispatch_by_region:
            dispatch_by_region[region] = []
        dispatch_by_region[region].append(event.get('value_mw', 0))
    
    # Ortalama değerler
    region_stats = {}
    for region, values in dispatch_by_region.items():
        region_stats[region] = {
            "count": len(values),
            "avg_mw": sum(values) / len(values) if values else 0,
            "max_mw": max(values) if values else 0,
            "min_mw": min(values) if values else 0
        }
    
    return jsonify({
        "total_dispatch_events": len(dispatch_events),
        "total_weather_events": len(weather_events),
        "region_stats": region_stats,
        "correlation_id": g.correlation_id,
        "timestamp": datetime.utcnow().isoformat()
    })


# ========================================
# ERROR HANDLERS
# ========================================
@app.errorhandler(404)
def not_found(error):
    return jsonify({
        "error": "Not Found",
        "message": "The requested resource was not found",
        "correlation_id": getattr(g, 'correlation_id', 'unknown')
    }), 404


@app.errorhandler(500)
def internal_error(error):
    return jsonify({
        "error": "Internal Server Error",
        "message": str(error),
        "correlation_id": getattr(g, 'correlation_id', 'unknown')
    }), 500


# ========================================
# MAIN
# ========================================
if __name__ == '__main__':
    # Kafka consumer'ı background thread'de başlat
    consumer_thread = threading.Thread(target=kafka_consumer_thread, daemon=True)
    consumer_thread.start()
    
    print("=" * 60)
    print("GridPulse API Server")
    print("=" * 60)
    print("\nEndpoints:")
    print("  GET  /health                    - Health check")
    print("  GET  /api/v1/dispatch           - Get dispatch events")
    print("  POST /api/v1/dispatch           - Add dispatch event")
    print("  GET  /api/v1/weather            - Get weather observations")
    print("  GET  /api/v1/stats              - Get statistics")
    print("\nStarting server on http://localhost:5001")
    print("=" * 60)
    
    app.run(host='0.0.0.0', port=5001, debug=True)
