#!/usr/bin/env python3
"""
AEMO Veri İndirme Script'i
--------------------------
Bu script AEMO'dan dispatch verilerini indirir ve işler.

NEDEN BU SCRIPT?
- AEMO verileri ZIP formatında geliyor
- Her 5 dakikada yeni dosya yayınlanıyor
- Gerçek dünya entegrasyonlarında bu tür "polling" yaygın
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

# Logging ayarla
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class AEMODataFetcher:
    """
    AEMO verilerini çeken sınıf.
    
    Interview'da açıklayabileceğin noktalar:
    - Retry mekanizması
    - Error handling
    - Idempotency (aynı veriyi tekrar çekince sorun olmaz)
    """
    
    # AEMO API endpoint'leri
    # Gerçek üretimde nemweb.com.au kullanılır
    # Demo için OpenNEM API daha pratik (JSON döner)
    OPENNEM_API = "https://api.opennem.org.au"
    
    def __init__(self, output_dir: str = "data/raw"):
        self.output_dir = output_dir
        os.makedirs(output_dir, exist_ok=True)
        
    def fetch_current_dispatch(self, region: str = "NEM") -> dict:
        """
        Güncel dispatch verilerini çeker.
        
        Args:
            region: Bölge kodu (NEM=tüm piyasa)
            
        Returns:
            dict: Normalize edilmiş dispatch verisi
        """
        logger.info(f"Fetching dispatch data for region: {region}")
        
        try:
            # OpenNEM API'den veri çek
            url = f"{self.OPENNEM_API}/stats/power/{region.lower()}"
            response = requests.get(url, timeout=30)
            response.raise_for_status()
            
            data = response.json()
            
            # Ham veriyi kaydet (debugging için)
            self._save_raw(data, f"dispatch_{region}")
            
            # Normalize et
            normalized = self._normalize_dispatch(data)
            
            logger.info(f"Successfully fetched {len(normalized)} dispatch records")
            return normalized
            
        except requests.exceptions.RequestException as e:
            logger.error(f"Failed to fetch dispatch data: {e}")
            # Retry veya DLQ'ya gönder burada olabilir
            raise
    
    def _normalize_dispatch(self, raw_data: dict) -> list:
        """
        Ham AEMO verisini canonical model'e dönüştürür.
        
        NEDEN NORMALIZASYON?
        - Farklı kaynaklar farklı formatlar kullanır
        - Tüm consumer'lar aynı formatta veri bekler
        - Şema değişikliklerini tek noktada yönetirsin
        """
        normalized = []
        
        # OpenNEM response yapısını işle
        if "data" in raw_data:
            for fuel_type in raw_data["data"]:
                for record in fuel_type.get("history", {}).get("data", []):
                    normalized.append({
                        # Canonical model alanları
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
        Idempotent event ID üretir.
        
        NEDEN ÖNEMLİ?
        - Aynı event tekrar gelse bile aynı ID'yi alır
        - Consumer tarafında deduplication yapılabilir
        - "Exactly once" processing için kritik
        """
        components = [
            fuel_type.get("region", "unknown"),
            fuel_type.get("fuel_tech", "unknown"),
            record.get("date", "unknown")
        ]
        return "_".join(str(c) for c in components)
    
    def _generate_correlation_id(self) -> str:
        """
        İzlenebilirlik için correlation ID üretir.
        
        Bu ID tüm sistemde takip edilir:
        AEMO → webMethods → Kafka → Kong → Consumer
        """
        return str(uuid.uuid4())
    
    def _save_raw(self, data: dict, prefix: str):
        """Ham veriyi debug için kaydet"""
        timestamp = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
        filepath = os.path.join(self.output_dir, f"{prefix}_{timestamp}.json")
        with open(filepath, 'w') as f:
            json.dump(data, f, indent=2)
        logger.debug(f"Saved raw data to {filepath}")


class WeatherDataFetcher:
    """
    Hava durumu verilerini çeken sınıf.
    
    NEDEN HAVA DURUMU?
    - Enerji talebi hava durumuna bağlı (sıcakta klima, soğukta ısıtma)
    - Yenilenebilir enerji üretimi hava durumuna bağlı (güneş, rüzgar)
    - Operasyonel kararlar için kritik
    """
    
    # Open-Meteo: Ücretsiz ve API key gerektirmiyor
    OPENMETEO_API = "https://api.open-meteo.com/v1/forecast"
    
    # Avustralya şehirleri (AEMO bölgeleriyle eşleşir)
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
        Belirtilen bölge için hava durumu verisini çeker.
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
            
            # Normalize et
            normalized = self._normalize_weather(data, region_id, location)
            return normalized
            
        except requests.exceptions.RequestException as e:
            logger.error(f"Failed to fetch weather data: {e}")
            raise
    
    def _normalize_weather(self, raw_data: dict, region_id: str, location: dict) -> dict:
        """
        Hava durumu verisini canonical model'e dönüştürür.
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
        """Tüm bölgeler için hava durumu çeker"""
        results = []
        for region_id in self.LOCATIONS:
            try:
                weather = self.fetch_weather(region_id)
                results.append(weather)
            except Exception as e:
                logger.error(f"Failed to fetch weather for {region_id}: {e}")
        return results


# Test için main
if __name__ == "__main__":
    print("=" * 60)
    print("GridPulse - AEMO & Weather Data Fetcher")
    print("=" * 60)
    
    # Dispatch verisi çek
    print("\n📊 Fetching dispatch data...")
    dispatch_fetcher = AEMODataFetcher()
    # Not: OpenNEM API değişmiş olabilir, simüle ediyoruz
    
    # Hava durumu verisi çek
    print("\n🌤️ Fetching weather data...")
    weather_fetcher = WeatherDataFetcher()
    weather_data = weather_fetcher.fetch_all_regions()
    
    print(f"\n✅ Fetched weather for {len(weather_data)} regions")
    for w in weather_data:
        print(f"  - {w['location_name']}: {w['temperature_celsius']}°C, Wind: {w['wind_speed_kmh']} km/h")
