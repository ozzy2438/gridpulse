#!/usr/bin/env python3
"""
Kafka Producer Script
---------------------
Bu script normalize edilmiş verileri Kafka'ya gönderir.

INTERVIEW'DA AÇIKLAYACAĞIN NOKTALAR:
1. Batch vs Single message gönderimi
2. Acknowledgment levels (acks)
3. Idempotent producer
4. Error handling ve retry
"""

import json
import time
from datetime import datetime
from kafka import KafkaProducer
from kafka.errors import KafkaError
import logging
import uuid

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class GridPulseProducer:
    """
    Kafka producer wrapper sınıfı.
    
    Production-ready özellikler:
    - Retry mekanizması
    - Error handling
    - Metrics
    """
    
    def __init__(self, bootstrap_servers: str = "localhost:9092"):
        """
        Producer'ı başlat.
        
        YAPILANDIRMA AÇIKLAMALARI:
        - bootstrap_servers: Kafka broker adresleri
        - acks='all': Tüm replica'ların onayını bekle (en güvenli)
        - retries=3: Başarısız gönderimde 3 kez dene
        - enable_idempotence=True: Duplicate mesajları önle
        """
        self.producer = KafkaProducer(
            bootstrap_servers=bootstrap_servers,
            # Mesajları JSON olarak serialize et
            value_serializer=lambda v: json.dumps(v).encode('utf-8'),
            key_serializer=lambda k: k.encode('utf-8') if k else None,
            # Güvenilirlik ayarları
            acks='all',  # Tüm in-sync replica'lar onaylamalı
            retries=3,
            retry_backoff_ms=1000,
            # Idempotent producer - duplicate'ları önler
            enable_idempotence=True,
            # Batch ayarları - performans için
            batch_size=16384,  # 16KB batch
            linger_ms=100,  # 100ms bekle, batch'i doldur
        )
        logger.info(f"Producer connected to {bootstrap_servers}")
    
    def send_dispatch_event(self, event: dict) -> bool:
        """
        Dispatch event'i Kafka'ya gönderir.
        
        PARTITION STRATEGY:
        - Key olarak region_id kullanıyoruz
        - Aynı bölgenin tüm event'leri aynı partition'a gider
        - Bu ordering garantisi sağlar (önemli!)
        """
        topic = "market.dispatch"
        
        # Event key = region_id (partition'a yönlendirme için)
        key = event.get("region_id", "unknown")
        
        # Correlation ID ekle/kontrol et
        if "correlation_id" not in event:
            event["correlation_id"] = str(uuid.uuid4())
        
        try:
            # Asenkron gönderim
            future = self.producer.send(
                topic=topic,
                key=key,
                value=event,
                # Header'lar - izlenebilirlik için
                headers=[
                    ("correlation_id", event["correlation_id"].encode()),
                    ("event_type", event["event_type"].encode()),
                    ("source", "gridpulse-producer".encode()),
                    ("timestamp", datetime.utcnow().isoformat().encode())
                ]
            )
            
            # Gönderimin başarılı olduğunu doğrula
            record_metadata = future.get(timeout=10)
            
            logger.info(
                f"✅ Sent dispatch event to {topic}[{record_metadata.partition}] "
                f"offset={record_metadata.offset} key={key}"
            )
            return True
            
        except KafkaError as e:
            logger.error(f"❌ Failed to send dispatch event: {e}")
            # Burada DLQ'ya gönderme mantığı olabilir
            self._send_to_dlq(topic, event, str(e))
            return False
    
    def send_weather_event(self, event: dict) -> bool:
        """
        Weather event'i Kafka'ya gönderir.
        """
        topic = "weather.observations"
        key = event.get("region_id", "unknown")
        
        if "correlation_id" not in event:
            event["correlation_id"] = str(uuid.uuid4())
        
        try:
            future = self.producer.send(
                topic=topic,
                key=key,
                value=event,
                headers=[
                    ("correlation_id", event["correlation_id"].encode()),
                    ("event_type", event["event_type"].encode()),
                    ("source", "gridpulse-producer".encode()),
                    ("timestamp", datetime.utcnow().isoformat().encode())
                ]
            )
            
            record_metadata = future.get(timeout=10)
            
            logger.info(
                f"✅ Sent weather event to {topic}[{record_metadata.partition}] "
                f"offset={record_metadata.offset} key={key}"
            )
            return True
            
        except KafkaError as e:
            logger.error(f"❌ Failed to send weather event: {e}")
            self._send_to_dlq(topic, event, str(e))
            return False
    
    def _send_to_dlq(self, original_topic: str, event: dict, error: str):
        """
        Başarısız mesajları Dead Letter Queue'ya gönderir.
        
        DLQ NEDEN ÖNEMLİ?
        - Mesaj kaybolmuyor
        - Sonradan analiz edilebilir
        - Manuel müdahale ile tekrar gönderilebilir
        """
        dlq_topic = f"dlq.{original_topic}"
        
        dlq_event = {
            "original_event": event,
            "error": error,
            "original_topic": original_topic,
            "failed_at": datetime.utcnow().isoformat(),
            "retry_count": event.get("_retry_count", 0) + 1
        }
        
        try:
            self.producer.send(
                topic=dlq_topic,
                value=dlq_event
            ).get(timeout=10)
            logger.warning(f"⚠️ Event sent to DLQ: {dlq_topic}")
        except Exception as e:
            logger.error(f"❌ Failed to send to DLQ: {e}")
    
    def send_batch(self, events: list, event_type: str) -> dict:
        """
        Birden fazla event'i batch olarak gönderir.
        
        Returns:
            dict: {"success": count, "failed": count}
        """
        results = {"success": 0, "failed": 0}
        
        for event in events:
            if event_type == "dispatch":
                success = self.send_dispatch_event(event)
            elif event_type == "weather":
                success = self.send_weather_event(event)
            else:
                logger.error(f"Unknown event type: {event_type}")
                continue
            
            if success:
                results["success"] += 1
            else:
                results["failed"] += 1
        
        # Tüm mesajların gönderildiğinden emin ol
        self.producer.flush()
        
        return results
    
    def close(self):
        """Producer'ı kapat"""
        self.producer.flush()
        self.producer.close()
        logger.info("Producer closed")


# Demo ve test
if __name__ == "__main__":
    print("=" * 60)
    print("GridPulse - Kafka Producer Demo")
    print("=" * 60)
    
    # Producer oluştur
    producer = GridPulseProducer()
    
    # Örnek dispatch event'leri
    sample_dispatch_events = [
        {
            "event_id": "NSW1_SOLAR_20240115_1000",
            "event_type": "MarketDispatchEvent",
            "event_time": "2024-01-15T10:00:00Z",
            "region_id": "NSW1",
            "fuel_type": "solar",
            "value_mw": 1250.5,
            "unit": "MW",
            "source": "DEMO"
        },
        {
            "event_id": "VIC1_WIND_20240115_1000",
            "event_type": "MarketDispatchEvent",
            "event_time": "2024-01-15T10:00:00Z",
            "region_id": "VIC1",
            "fuel_type": "wind",
            "value_mw": 890.3,
            "unit": "MW",
            "source": "DEMO"
        },
        {
            "event_id": "QLD1_COAL_20240115_1000",
            "event_type": "MarketDispatchEvent",
            "event_time": "2024-01-15T10:00:00Z",
            "region_id": "QLD1",
            "fuel_type": "coal",
            "value_mw": 3200.0,
            "unit": "MW",
            "source": "DEMO"
        }
    ]
    
    # Örnek weather event'leri
    sample_weather_events = [
        {
            "event_id": "weather_NSW1_202401151000",
            "event_type": "WeatherObservation",
            "event_time": "2024-01-15T10:00:00Z",
            "region_id": "NSW1",
            "location_name": "Sydney",
            "temperature_celsius": 28.5,
            "wind_speed_kmh": 15.2,
            "humidity_percent": 65,
            "source": "DEMO"
        },
        {
            "event_id": "weather_VIC1_202401151000",
            "event_type": "WeatherObservation",
            "event_time": "2024-01-15T10:00:00Z",
            "region_id": "VIC1",
            "location_name": "Melbourne",
            "temperature_celsius": 22.3,
            "wind_speed_kmh": 25.8,
            "humidity_percent": 55,
            "source": "DEMO"
        }
    ]
    
    print("\n📊 Sending dispatch events...")
    dispatch_results = producer.send_batch(sample_dispatch_events, "dispatch")
    print(f"  Results: {dispatch_results}")
    
    print("\n🌤️ Sending weather events...")
    weather_results = producer.send_batch(sample_weather_events, "weather")
    print(f"  Results: {weather_results}")
    
    # Temizlik
    producer.close()
    
    print("\n✅ Demo completed! Check Kafka UI at http://localhost:8080")
