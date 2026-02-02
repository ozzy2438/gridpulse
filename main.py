#!/usr/bin/env python3
"""
GridPulse - Energy Integration Platform
=======================================

This file is the main entry point of the project.
Provides a quick overview of the entire system.

Usage:
    python main.py          # Show project information
    python main.py demo     # Send demo data
    python main.py server   # Start API server
"""

import sys
import os

# Add project root to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'scripts'))


def print_banner():
    """Print project banner"""
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
    """Print project information"""
    print_banner()
    print("""
PROJECT STRUCTURE
=================

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

QUICK START
===========

1. Start infrastructure:
   $ docker-compose up -d

2. Create Kafka topics:
   $ ./scripts/create_kafka_topics.sh

3. Configure Kong:
   $ ./scripts/setup_kong.sh

4. Start API server:
   $ python scripts/api_server.py

5. Send demo data:
   $ python scripts/kafka_producer.py

6. Test the API:
   $ curl -H "apikey: analytics-team-secret-key-2024" \\
       http://localhost:8000/v1/market/dispatch

ACCESS POINTS
=============

  Kafka UI      : http://localhost:8180
  Kong Proxy    : http://localhost:8100
  Kong Admin    : http://localhost:8101
  Kong Manager  : http://localhost:8102
  Grafana       : http://localhost:3001 (admin/admin)
  Prometheus    : http://localhost:9090
  API Server    : http://localhost:5001

API KEYS
========

  analytics-team-secret-key-2024  → market-analytics-team
  ops-team-secret-key-2024        → operations-team
  risk-team-secret-key-2024       → risk-team

COMMANDS
========

  python main.py          # Show this information
  python main.py demo     # Send demo data to Kafka
  python main.py server   # Start API server
  python main.py fetch    # Fetch AEMO and weather data
""")


def run_demo():
    """Send demo data"""
    print_banner()
    print("Sending demo data to Kafka...")
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
        
        print("\n✅ Demo data sent!")
        print("   Check in Kafka UI: http://localhost:8080")

    except Exception as e:
        print(f"\n❌ Error: {e}")
        print("   Make sure Kafka is running: docker-compose ps")


def run_server():
    """Start API server"""
    print_banner()
    print("Starting API Server...")
    print()
    
    try:
        from api_server import app, kafka_consumer_thread
        import threading
        
        consumer_thread = threading.Thread(target=kafka_consumer_thread, daemon=True)
        consumer_thread.start()
        
        app.run(host='0.0.0.0', port=5000, debug=True)
        
    except Exception as e:
        print(f"\n❌ Error: {e}")


def run_fetch():
    """Fetch AEMO and weather data"""
    print_banner()
    print("Fetching data...")
    print()
    
    try:
        from download_aemo import WeatherDataFetcher
        
        weather_fetcher = WeatherDataFetcher()
        weather_data = weather_fetcher.fetch_all_regions()
        
        print(f"\n✅ Weather data fetched for {len(weather_data)} regions:")
        for w in weather_data:
            print(f"   • {w['location_name']}: {w['temperature_celsius']}°C")

    except Exception as e:
        print(f"\n❌ Error: {e}")


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
            print(f"Unknown command: {command}")
            print("Available commands: demo, server, fetch")
    else:
        print_info()
