#!/usr/bin/env python3
"""
GridPulse - Energy Integration Platform
=======================================

Bu dosya projenin ana giriş noktasıdır.
Tüm sistemin hızlı bir özetini sağlar.

Kullanım:
    python main.py          # Proje bilgisini göster
    python main.py demo     # Demo verileri gönder
    python main.py server   # API server'ı başlat
"""

import sys
import os

# Project root'u path'e ekle
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'scripts'))


def print_banner():
    """Proje banner'ını yazdır"""
    print("""
╔══════════════════════════════════════════════════════════════════╗
║                                                                  ║
║   ██████╗ ██████╗ ██╗██████╗ ██████╗ ██╗   ██╗██╗     ███████╗  ║
║  ██╔════╝ ██╔══██╗██║██╔══██╗██╔══██╗██║   ██║██║     ██╔════╝  ║
║  ██║  ███╗██████╔╝██║██║  ██║██████╔╝██║   ██║██║     ███████╗  ║
║  ██║   ██║██╔══██╗██║██║  ██║██╔═══╝ ██║   ██║██║     ╚════██║  ║
║  ╚██████╔╝██║  ██║██║██████╔╝██║     ╚██████╔╝███████╗███████║  ║
║   ╚═════╝ ╚═╝  ╚═╝╚═╝╚═════╝ ╚═╝      ╚═════╝ ╚══════╝╚══════╝  ║
║                                                                  ║
║          Energy Integration Platform                             ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
    """)


def print_info():
    """Proje bilgisini yazdır"""
    print_banner()
    print("""
PROJE YAPISI
============

┌─────────────────────────────────────────────────────────────┐
│  DATA SOURCES                                               │
│  ┌──────────────┐    ┌──────────────┐                      │
│  │  AEMO API    │    │ Weather API  │                      │
│  └──────┬───────┘    └──────┬───────┘                      │
│         │                   │                               │
│         ▼                   ▼                               │
│  ┌────────────────────────────────────┐                    │
│  │     webMethods / Python Scripts     │  INGESTION        │
│  └──────────────┬─────────────────────┘                    │
│                 │                                           │
│                 ▼                                           │
│  ┌────────────────────────────────────┐                    │
│  │         Apache Kafka                │  EVENT HUB        │
│  │  • market.dispatch                  │                   │
│  │  • weather.observations             │                   │
│  └──────────────┬─────────────────────┘                    │
│                 │                                           │
│                 ▼                                           │
│  ┌────────────────────────────────────┐                    │
│  │         Kong API Gateway            │  API LAYER        │
│  │  • Authentication                   │                   │
│  │  • Rate Limiting                    │                   │
│  └──────────────┬─────────────────────┘                    │
│                 │                                           │
│         ┌───────┼───────┐                                   │
│         ▼       ▼       ▼                                   │
│      Analytics  Ops     Risk            CONSUMERS          │
│        Team    Team    Team                                 │
└─────────────────────────────────────────────────────────────┘

HIZLI BAŞLANGIÇ
===============

1. Altyapıyı başlat:
   $ docker-compose up -d

2. Kafka topic'lerini oluştur:
   $ ./scripts/create_kafka_topics.sh

3. Kong'u yapılandır:
   $ ./scripts/setup_kong.sh

4. API server'ı başlat:
   $ python scripts/api_server.py

5. Demo verileri gönder:
   $ python scripts/kafka_producer.py

6. API'yi test et:
   $ curl -H "apikey: analytics-team-secret-key-2024" \\
       http://localhost:8000/v1/market/dispatch

ERİŞİM NOKTALARI
================

  Kafka UI      : http://localhost:8180
  Kong Proxy    : http://localhost:8100
  Kong Admin    : http://localhost:8101
  Kong Manager  : http://localhost:8102
  Grafana       : http://localhost:3001 (admin/admin)
  Prometheus    : http://localhost:9090
  API Server    : http://localhost:5001

API ANAHTARLARI
===============

  analytics-team-secret-key-2024  → market-analytics-team
  ops-team-secret-key-2024        → operations-team
  risk-team-secret-key-2024       → risk-team

KOMUTLAR
========

  python main.py          # Bu bilgiyi göster
  python main.py demo     # Demo verileri Kafka'ya gönder
  python main.py server   # API server'ı başlat
  python main.py fetch    # AEMO ve hava durumu verilerini çek
""")


def run_demo():
    """Demo verileri gönder"""
    print_banner()
    print("Demo verileri Kafka'ya gönderiliyor...")
    print()
    
    try:
        from kafka_producer import GridPulseProducer
        
        producer = GridPulseProducer()
        
        sample_dispatch = [
            {
                "event_id": "NSW1_SOLAR_DEMO",
                "event_type": "MarketDispatchEvent",
                "event_time": "2024-01-15T10:00:00Z",
                "region_id": "NSW1",
                "fuel_type": "solar",
                "value_mw": 1250.5,
                "unit": "MW",
                "source": "DEMO"
            }
        ]
        
        sample_weather = [
            {
                "event_id": "weather_NSW1_DEMO",
                "event_type": "WeatherObservation",
                "event_time": "2024-01-15T10:00:00Z",
                "region_id": "NSW1",
                "location_name": "Sydney",
                "temperature_celsius": 28.5,
                "wind_speed_kmh": 15.2,
                "humidity_percent": 65,
                "source": "DEMO"
            }
        ]
        
        producer.send_batch(sample_dispatch, "dispatch")
        producer.send_batch(sample_weather, "weather")
        producer.close()
        
        print("\n✅ Demo verileri gönderildi!")
        print("   Kafka UI'da kontrol et: http://localhost:8080")
        
    except Exception as e:
        print(f"\n❌ Hata: {e}")
        print("   Kafka'nın çalıştığından emin ol: docker-compose ps")


def run_server():
    """API server'ı başlat"""
    print_banner()
    print("API Server başlatılıyor...")
    print()
    
    try:
        from api_server import app, kafka_consumer_thread
        import threading
        
        consumer_thread = threading.Thread(target=kafka_consumer_thread, daemon=True)
        consumer_thread.start()
        
        app.run(host='0.0.0.0', port=5000, debug=True)
        
    except Exception as e:
        print(f"\n❌ Hata: {e}")


def run_fetch():
    """AEMO ve hava durumu verilerini çek"""
    print_banner()
    print("Veriler çekiliyor...")
    print()
    
    try:
        from download_aemo import WeatherDataFetcher
        
        weather_fetcher = WeatherDataFetcher()
        weather_data = weather_fetcher.fetch_all_regions()
        
        print(f"\n✅ {len(weather_data)} bölge için hava durumu çekildi:")
        for w in weather_data:
            print(f"   • {w['location_name']}: {w['temperature_celsius']}°C")
        
    except Exception as e:
        print(f"\n❌ Hata: {e}")


if __name__ == '__main__':
    if len(sys.argv) > 1:
        command = sys.argv[1].lower()
        
        if command == 'demo':
            run_demo()
        elif command == 'server':
            run_server()
        elif command == 'fetch':
            run_fetch()
        else:
            print(f"Bilinmeyen komut: {command}")
            print("Kullanılabilir komutlar: demo, server, fetch")
    else:
        print_info()
