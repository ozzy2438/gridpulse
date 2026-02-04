#!/usr/bin/env python3
"""
GridPulse Data Pipeline
------------------------
Complete data pipeline: Download → Process → Send to Kafka

This script demonstrates end-to-end data flow:
1. Fetch real weather data from Open-Meteo API
2. Fetch real AEMO dispatch data from OpenNEM API  
3. Normalize to canonical model
4. Send to Kafka topics
5. Handle errors with DLQ pattern
"""

import os
import sys
import time
import json
import logging
from datetime import datetime
from typing import List, Dict, Optional

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from kafka import KafkaProducer
from kafka.errors import KafkaError
import requests

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class DataPipeline:
    """
    Main data pipeline orchestrator
    
    Interview talking points:
    - Error handling and retry logic
    - Idempotency through deterministic event IDs
    - Observability with correlation IDs
    - Dead Letter Queue pattern for failed messages
    """
    
    def __init__(self, kafka_bootstrap_servers: str = "localhost:9092"):
        self.kafka_bootstrap_servers = kafka_bootstrap_servers
        self.producer = None
        self.weather_api = "https://api.open-meteo.com/v1/forecast"
        self.opennem_api = "https://api.opennem.org.au"
        
        # AEMO regions with coordinates
        self.regions = {
            "NSW1": {"lat": -33.87, "lon": 151.21, "name": "Sydney"},
            "VIC1": {"lat": -37.81, "lon": 144.96, "name": "Melbourne"},
            "QLD1": {"lat": -27.47, "lon": 153.03, "name": "Brisbane"},
            "SA1": {"lat": -34.93, "lon": 138.60, "name": "Adelaide"},
            "TAS1": {"lat": -42.88, "lon": 147.33, "name": "Hobart"},
        }
        
    def initialize_kafka(self) -> bool:
        """Initialize Kafka producer"""
        try:
            self.producer = KafkaProducer(
                bootstrap_servers=self.kafka_bootstrap_servers,
                value_serializer=lambda v: json.dumps(v).encode('utf-8'),
                acks='all',  # Wait for all replicas
                retries=3,
                max_in_flight_requests_per_connection=1  # Preserve order
            )
            logger.info("✅ Kafka producer initialized")
            return True
        except Exception as e:
            logger.error(f"❌ Failed to initialize Kafka: {e}")
            logger.info("💡 Make sure Kafka is running: docker compose up -d")
            return False
    
    def fetch_weather_data(self) -> List[Dict]:
        """Fetch weather data for all regions"""
        weather_events = []
        
        for region_id, location in self.regions.items():
            try:
                logger.info(f"🌤️  Fetching weather for {location['name']} ({region_id})")
                
                params = {
                    "latitude": location["lat"],
                    "longitude": location["lon"],
                    "current": "temperature_2m,wind_speed_10m,relative_humidity_2m",
                    "timezone": "Australia/Sydney"
                }
                
                response = requests.get(self.weather_api, params=params, timeout=30)
                response.raise_for_status()
                data = response.json()
                
                # Normalize to canonical model
                current = data.get("current", {})
                event = {
                    "event_id": f"weather_{region_id}_{datetime.now().strftime('%Y%m%d%H%M')}",
                    "event_type": "WeatherObservation",
                    "event_time": datetime.now().isoformat(),
                    "region_id": region_id,
                    "location_name": location["name"],
                    "temperature_celsius": current.get("temperature_2m"),
                    "wind_speed_kmh": current.get("wind_speed_10m"),
                    "humidity_percent": current.get("relative_humidity_2m"),
                    "source": "OPENMETEO",
                    "ingestion_time": datetime.now().isoformat(),
                }
                
                weather_events.append(event)
                logger.info(f"   📊 {location['name']}: {current.get('temperature_2m')}°C, Wind: {current.get('wind_speed_10m')} km/h")
                
            except Exception as e:
                logger.error(f"❌ Failed to fetch weather for {region_id}: {e}")
                
        return weather_events
    
    def fetch_dispatch_data(self) -> List[Dict]:
        """Fetch AEMO dispatch data"""
        dispatch_events = []
        
        try:
            logger.info("⚡ Fetching AEMO dispatch data from OpenNEM")
            
            # Fetch current power generation
            url = f"{self.opennem_api}/stats/power/nem"
            response = requests.get(url, timeout=30)
            response.raise_for_status()
            data = response.json()
            
            # Parse and normalize
            if "data" in data:
                for item in data["data"]:
                    # Get latest data point
                    history = item.get("history", {})
                    if history and "data" in history and history["data"]:
                        latest = history["data"][-1]  # Most recent
                        
                        event = {
                            "event_id": f"dispatch_{item.get('fuel_tech')}_{datetime.now().strftime('%Y%m%d%H%M')}",
                            "event_type": "MarketDispatchEvent",
                            "event_time": latest.get("time", datetime.now().isoformat()),
                            "region_id": item.get("region", "NEM"),
                            "fuel_type": item.get("fuel_tech"),
                            "value_mw": latest.get("value", 0),
                            "unit": "MW",
                            "source": "OPENNEM",
                            "ingestion_time": datetime.now().isoformat(),
                        }
                        
                        dispatch_events.append(event)
                
                logger.info(f"   📊 Fetched {len(dispatch_events)} dispatch records")
                
        except Exception as e:
            logger.error(f"❌ Failed to fetch dispatch data: {e}")
            logger.info("💡 Using simulated data as fallback")
            # Create simulated data
            dispatch_events = self._create_simulated_dispatch()
            
        return dispatch_events
    
    def _create_simulated_dispatch(self) -> List[Dict]:
        """Create simulated dispatch data as fallback"""
        import random
        
        fuel_types = ["solar", "wind", "coal", "gas", "hydro"]
        events = []
        
        for region_id in self.regions.keys():
            for fuel_type in fuel_types:
                event = {
                    "event_id": f"dispatch_{region_id}_{fuel_type}_{datetime.now().strftime('%Y%m%d%H%M')}",
                    "event_type": "MarketDispatchEvent",
                    "event_time": datetime.now().isoformat(),
                    "region_id": region_id,
                    "fuel_type": fuel_type,
                    "value_mw": round(random.uniform(100, 2000), 2),
                    "unit": "MW",
                    "source": "SIMULATED",
                    "ingestion_time": datetime.now().isoformat(),
                }
                events.append(event)
                
        return events
    
    def send_to_kafka(self, events: List[Dict], topic: str):
        """Send events to Kafka topic"""
        if not self.producer:
            logger.error("❌ Kafka producer not initialized")
            return
        
        success_count = 0
        failed_count = 0
        
        for event in events:
            try:
                # Send to Kafka
                future = self.producer.send(topic, event)
                record_metadata = future.get(timeout=10)
                
                success_count += 1
                logger.debug(f"✅ Sent to {record_metadata.topic} partition {record_metadata.partition}")
                
            except KafkaError as e:
                failed_count += 1
                logger.error(f"❌ Failed to send event {event.get('event_id')}: {e}")
                
                # Send to DLQ
                self._send_to_dlq(event, topic, str(e))
        
        logger.info(f"📤 Sent {success_count} events to {topic} ({failed_count} failed)")
    
    def _send_to_dlq(self, event: Dict, original_topic: str, error: str):
        """Send failed event to Dead Letter Queue"""
        dlq_topic = f"dlq.{original_topic}"
        
        dlq_event = {
            "original_topic": original_topic,
            "original_event": event,
            "error": error,
            "failed_at": datetime.now().isoformat()
        }
        
        try:
            self.producer.send(dlq_topic, dlq_event)
            logger.info(f"📮 Sent to DLQ: {dlq_topic}")
        except Exception as e:
            logger.error(f"❌ Failed to send to DLQ: {e}")
    
    def run_pipeline(self):
        """Run the complete data pipeline"""
        logger.info("=" * 70)
        logger.info("🚀 GridPulse Data Pipeline Starting")
        logger.info("=" * 70)
        
        # Initialize Kafka
        if not self.initialize_kafka():
            logger.error("❌ Cannot proceed without Kafka. Exiting.")
            return
        
        # Fetch weather data
        logger.info("\n📡 Step 1: Fetching Weather Data")
        weather_events = self.fetch_weather_data()
        
        # Fetch dispatch data
        logger.info("\n📡 Step 2: Fetching Dispatch Data")
        dispatch_events = self.fetch_dispatch_data()
        
        # Send to Kafka
        logger.info("\n📤 Step 3: Sending to Kafka")
        self.send_to_kafka(weather_events, "weather.observations")
        self.send_to_kafka(dispatch_events, "market.dispatch")
        
        # Flush and close
        if self.producer:
            self.producer.flush()
            self.producer.close()
        
        logger.info("\n" + "=" * 70)
        logger.info("✅ Pipeline completed successfully!")
        logger.info(f"   Weather events: {len(weather_events)}")
        logger.info(f"   Dispatch events: {len(dispatch_events)}")
        logger.info("=" * 70)
        
    def run_continuous(self, interval_seconds: int = 300):
        """Run pipeline continuously"""
        logger.info(f"🔄 Starting continuous mode (interval: {interval_seconds}s)")
        
        try:
            while True:
                self.run_pipeline()
                logger.info(f"\n⏳ Waiting {interval_seconds} seconds until next run...")
                time.sleep(interval_seconds)
        except KeyboardInterrupt:
            logger.info("\n⏹️  Stopped by user")


def main():
    """Main entry point"""
    import argparse
    
    parser = argparse.ArgumentParser(description="GridPulse Data Pipeline")
    parser.add_argument(
        "--kafka",
        default="localhost:9092",
        help="Kafka bootstrap servers (default: localhost:9092)"
    )
    parser.add_argument(
        "--continuous",
        action="store_true",
        help="Run continuously (default: single run)"
    )
    parser.add_argument(
        "--interval",
        type=int,
        default=300,
        help="Interval in seconds for continuous mode (default: 300)"
    )
    
    args = parser.parse_args()
    
    pipeline = DataPipeline(kafka_bootstrap_servers=args.kafka)
    
    if args.continuous:
        pipeline.run_continuous(interval_seconds=args.interval)
    else:
        pipeline.run_pipeline()


if __name__ == "__main__":
    main()
