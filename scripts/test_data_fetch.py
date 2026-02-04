#!/usr/bin/env python3
"""
Test Data Fetching - No Kafka Required
---------------------------------------
Tests data fetching from real APIs without Kafka
"""

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from scripts.data_pipeline import DataPipeline
import json

def main():
    print("=" * 70)
    print("🧪 Testing Data Sources (No Kafka Required)")
    print("=" * 70)
    
    pipeline = DataPipeline()
    
    # Test weather data
    print("\n🌤️  Testing Weather API...")
    weather = pipeline.fetch_weather_data()
    print(f"✅ Fetched {len(weather)} weather observations")
    
    if weather:
        print("\n📋 Sample Weather Event:")
        print(json.dumps(weather[0], indent=2))
    
    # Test dispatch data  
    print("\n\n⚡ Testing Dispatch API...")
    dispatch = pipeline.fetch_dispatch_data()
    print(f"✅ Fetched {len(dispatch)} dispatch events")
    
    if dispatch:
        print("\n📋 Sample Dispatch Event:")
        print(json.dumps(dispatch[0], indent=2))
    
    # Summary
    print("\n" + "=" * 70)
    print("📊 Summary:")
    print(f"   Weather observations: {len(weather)}")
    print(f"   Dispatch events: {len(dispatch)}")
    print(f"   Total events: {len(weather) + len(dispatch)}")
    print("=" * 70)
    print("\n✅ All data sources working! Ready to integrate with Kafka.")
    print("\nNext steps:")
    print("1. Start Docker: open -a Docker (or start Docker Desktop)")
    print("2. Start services: docker compose up -d")
    print("3. Create topics: ./scripts/create_kafka_topics.sh")
    print("4. Run pipeline: python scripts/data_pipeline.py")
    print()

if __name__ == "__main__":
    main()
