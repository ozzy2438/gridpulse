#!/usr/bin/env python3
"""
AEMO Data Download Script
--------------------------
This script downloads and processes dispatch data from AEMO.

WHY THIS SCRIPT?
- AEMO data comes in ZIP format
- New file is published every 5 minutes
- This type of "polling" is common in real-world integrations
"""

import os
import requests
import zipfile
import io
import csv
from datetime import datetime, timedelta
import json
import logging
import uuid

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class AEMODataFetcher:
    """
    Class for fetching AEMO data.

    Points you can explain in interview:
    - Retry mechanism
    - Error handling
    - Idempotency (no problem if fetching same data again)
    """

    # AEMO API endpoints
    # In real production, nemweb.com.au is used
    # For demo, OpenNEM API is more practical (returns JSON)
    OPENNEM_API = "https://api.opennem.org.au"
    
    def __init__(self, output_dir: str = "data/raw"):
        self.output_dir = output_dir
        os.makedirs(output_dir, exist_ok=True)
        
    def fetch_current_dispatch(self, region: str = "NEM") -> dict:
        """
        Fetches current dispatch data.

        Args:
            region: Region code (NEM=entire market)

        Returns:
            dict: Normalized dispatch data
        """
        logger.info(f"Fetching dispatch data for region: {region}")
        
        try:
            # Fetch data from OpenNEM API
            url = f"{self.OPENNEM_API}/stats/power/{region.lower()}"
            response = requests.get(url, timeout=30)
            response.raise_for_status()
            
            data = response.json()
            
            # Save raw data (for debugging)
            self._save_raw(data, f"dispatch_{region}")

            # Normalize
            normalized = self._normalize_dispatch(data)
            
            logger.info(f"Successfully fetched {len(normalized)} dispatch records")
            return normalized
            
        except requests.exceptions.RequestException as e:
            logger.error(f"Failed to fetch dispatch data: {e}")
            # Retry or send to DLQ could be here
            raise
    
    def _normalize_dispatch(self, raw_data: dict) -> list:
        """
        Converts raw AEMO data to canonical model.

        WHY NORMALIZATION?
        - Different sources use different formats
        - All consumers expect data in the same format
        - You manage schema changes in one place
        """
        normalized = []

        # Process OpenNEM response structure
        if "data" in raw_data:
            for fuel_type in raw_data["data"]:
                for record in fuel_type.get("history", {}).get("data", []):
                    normalized.append({
                        # Canonical model fields
                        "event_id": self._generate_event_id(fuel_type, record),
                        "event_type": "MarketDispatchEvent",
                        "event_time": record.get("date"),
                        "region_id": fuel_type.get("region"),
                        "fuel_type": fuel_type.get("fuel_tech"),
                        "value_mw": record.get("value", 0),
                        "unit": "MW",
                        # Metadata
                        "source": "OPENNEM",
                        "ingestion_time": datetime.utcnow().isoformat(),
                        "correlation_id": self._generate_correlation_id()
                    })
        
        return normalized
    
    def _generate_event_id(self, fuel_type: dict, record: dict) -> str:
        """
        Generates idempotent event ID.

        WHY IMPORTANT?
        - Even if same event comes again, it gets the same ID
        - Deduplication can be done on consumer side
        - Critical for "exactly once" processing
        """
        components = [
            fuel_type.get("region", "unknown"),
            fuel_type.get("fuel_tech", "unknown"),
            record.get("date", "unknown")
        ]
        return "_".join(str(c) for c in components)
    
    def _generate_correlation_id(self) -> str:
        """
        Generates correlation ID for traceability.

        This ID is tracked throughout the system:
        AEMO → webMethods → Kafka → Kong → Consumer
        """
        return str(uuid.uuid4())
    
    def _save_raw(self, data: dict, prefix: str):
        """Save raw data for debugging"""
        timestamp = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
        filepath = os.path.join(self.output_dir, f"{prefix}_{timestamp}.json")
        with open(filepath, 'w') as f:
            json.dump(data, f, indent=2)
        logger.debug(f"Saved raw data to {filepath}")


class WeatherDataFetcher:
    """
    Class for fetching weather data.

    WHY WEATHER?
    - Energy demand depends on weather (AC in heat, heating in cold)
    - Renewable energy production depends on weather (solar, wind)
    - Critical for operational decisions
    """

    # Open-Meteo: Free and doesn't require API key
    OPENMETEO_API = "https://api.open-meteo.com/v1/forecast"

    # Australian cities (matches AEMO regions)
    LOCATIONS = {
        "NSW1": {"lat": -33.87, "lon": 151.21, "name": "Sydney"},
        "VIC1": {"lat": -37.81, "lon": 144.96, "name": "Melbourne"},
        "QLD1": {"lat": -27.47, "lon": 153.03, "name": "Brisbane"},
        "SA1": {"lat": -34.93, "lon": 138.60, "name": "Adelaide"},
        "TAS1": {"lat": -42.88, "lon": 147.33, "name": "Hobart"},
    }
    
    def __init__(self, output_dir: str = "data/raw"):
        self.output_dir = output_dir
        os.makedirs(output_dir, exist_ok=True)
    
    def fetch_weather(self, region_id: str) -> dict:
        """
        Fetches weather data for specified region.
        """
        if region_id not in self.LOCATIONS:
            raise ValueError(f"Unknown region: {region_id}")
        
        location = self.LOCATIONS[region_id]
        logger.info(f"Fetching weather for {location['name']} ({region_id})")
        
        params = {
            "latitude": location["lat"],
            "longitude": location["lon"],
            "current": "temperature_2m,wind_speed_10m,relative_humidity_2m",
            "hourly": "temperature_2m,wind_speed_10m",
            "timezone": "Australia/Sydney"
        }
        
        try:
            response = requests.get(self.OPENMETEO_API, params=params, timeout=30)
            response.raise_for_status()
            data = response.json()
            
            # Normalize
            normalized = self._normalize_weather(data, region_id, location)
            return normalized
            
        except requests.exceptions.RequestException as e:
            logger.error(f"Failed to fetch weather data: {e}")
            raise
    
    def _normalize_weather(self, raw_data: dict, region_id: str, location: dict) -> dict:
        """
        Converts weather data to canonical model.
        """
        current = raw_data.get("current", {})
        
        return {
            "event_id": f"weather_{region_id}_{datetime.utcnow().strftime('%Y%m%d%H%M')}",
            "event_type": "WeatherObservation",
            "event_time": datetime.utcnow().isoformat(),
            "region_id": region_id,
            "location_name": location["name"],
            "temperature_celsius": current.get("temperature_2m"),
            "wind_speed_kmh": current.get("wind_speed_10m"),
            "humidity_percent": current.get("relative_humidity_2m"),
            # Metadata
            "source": "OPENMETEO",
            "ingestion_time": datetime.utcnow().isoformat(),
            "correlation_id": str(uuid.uuid4())
        }
    
    def fetch_all_regions(self) -> list:
        """Fetches weather for all regions"""
        results = []
        for region_id in self.LOCATIONS:
            try:
                weather = self.fetch_weather(region_id)
                results.append(weather)
            except Exception as e:
                logger.error(f"Failed to fetch weather for {region_id}: {e}")
        return results


# Main for testing
if __name__ == "__main__":
    print("=" * 60)
    print("GridPulse - AEMO & Weather Data Fetcher")
    print("=" * 60)

    # Fetch dispatch data
    print("\n📊 Fetching dispatch data...")
    dispatch_fetcher = AEMODataFetcher()
    # Note: OpenNEM API may have changed, simulating

    # Fetch weather data
    print("\n🌤️ Fetching weather data...")
    weather_fetcher = WeatherDataFetcher()
    weather_data = weather_fetcher.fetch_all_regions()
    
    print(f"\n✅ Fetched weather for {len(weather_data)} regions")
    for w in weather_data:
        print(f"  - {w['location_name']}: {w['temperature_celsius']}°C, Wind: {w['wind_speed_kmh']} km/h")
