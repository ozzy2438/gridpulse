# GridPulse - Data Sources Documentation

## Overview

GridPulse integrates **real-world data** from multiple sources to demonstrate enterprise-grade data integration patterns.

## Data Sources

### 1. 🌤️ Weather Data - Open-Meteo API

**Source**: https://api.open-meteo.com/v1/forecast

**Status**: ✅ **REAL DATA - Working**

**What we fetch**:
- Current temperature (°C)
- Wind speed (km/h)
- Relative humidity (%)
- Hourly forecasts

**Coverage**:
- Sydney (NSW1): -33.87°, 151.21°
- Melbourne (VIC1): -37.81°, 144.96°
- Brisbane (QLD1): -27.47°, 153.03°
- Adelaide (SA1): -34.93°, 138.60°
- Hobart (TAS1): -42.88°, 147.33°

**API Features**:
- ✅ No API key required
- ✅ Free for non-commercial use
- ✅ High availability
- ✅ Real-time data
- ✅ Global coverage

**Example Response**:
```json
{
  "event_id": "weather_NSW1_202602032132",
  "event_type": "WeatherObservation",
  "event_time": "2026-02-03T21:32:15.407300",
  "region_id": "NSW1",
  "location_name": "Sydney",
  "temperature_celsius": 19.9,
  "wind_speed_kmh": 4.1,
  "humidity_percent": 75,
  "source": "OPENMETEO",
  "ingestion_time": "2026-02-03T21:32:15.407309"
}
```

**Why this matters for interviews**:
- Demonstrates real API integration
- Shows data normalization patterns
- Weather impacts energy demand and renewable generation
- Real-world use case that interviewers can relate to

---

### 2. ⚡ Energy Dispatch Data - AEMO/OpenNEM API

**Primary Source**: https://api.opennem.org.au (Currently returning 404)

**Fallback**: **SIMULATED DATA** (realistic values)

**What we fetch**:
- Power generation by fuel type (MW)
- Solar, Wind, Coal, Gas, Hydro
- Regional breakdown (NSW, VIC, QLD, SA, TAS)
- 5-minute dispatch intervals

**Data Model**:
```json
{
  "event_id": "dispatch_NSW1_solar_202602032132",
  "event_type": "MarketDispatchEvent",
  "event_time": "2026-02-03T21:32:22.061200",
  "region_id": "NSW1",
  "fuel_type": "solar",
  "value_mw": 1022.43,
  "unit": "MW",
  "source": "SIMULATED",
  "ingestion_time": "2026-02-03T21:32:22.061219"
}
```

**Alternative Real Sources** (for future enhancement):
1. **AEMO NEM Web** (nemweb.com.au)
   - Official source
   - Requires parsing CSV from ZIP files
   - 5-minute dispatch data
   - Free but complex format

2. **OpenNEM Dashboard API**
   - Alternative endpoint to try
   - Real-time Australian grid data
   - May require different URL structure

3. **EIA API** (US Energy Information Administration)
   - US-based alternative
   - Requires free API key
   - Good for US-centric demos

**Why we simulate when API unavailable**:
- System keeps working (resilience)
- Demonstrates fallback patterns
- Values are realistic (100-2000 MW per fuel type)
- Interview focus remains on architecture, not API availability

---

## Data Pipeline Flow

```
┌─────────────────────────────────────────────────────────────┐
│  External APIs                                               │
│  - Open-Meteo (Weather)      ✅ REAL                        │
│  - OpenNEM (Dispatch)         ⚠️ Simulated (API issue)      │
└─────────────┬───────────────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────────────────────┐
│  Data Pipeline (scripts/data_pipeline.py)                   │
│  - Fetch from APIs                                           │
│  - Normalize to canonical model                              │
│  - Add event IDs (idempotency)                              │
│  - Add correlation IDs (traceability)                       │
└─────────────┬───────────────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────────────────────┐
│  Apache Kafka                                                │
│  Topics:                                                     │
│  - weather.observations                                      │
│  - market.dispatch                                           │
│  - dlq.* (Dead Letter Queues)                               │
└─────────────┬───────────────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────────────────────┐
│  Kong API Gateway                                            │
│  - API Key authentication                                    │
│  - Rate limiting (100 req/min)                              │
│  - Correlation ID tracking                                   │
└─────────────┬───────────────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────────────────────┐
│  API Server (scripts/api_server.py)                         │
│  - Consumes from Kafka                                       │
│  - Exposes REST API                                          │
│  - In-memory cache                                           │
└─────────────────────────────────────────────────────────────┘
```

---

## Running the Data Pipeline

### Test Data Sources Only (No Kafka)

```bash
source venv/bin/activate
python scripts/test_data_fetch.py
```

This will:
- ✅ Fetch real weather data from 5 Australian cities
- ✅ Attempt to fetch dispatch data (falls back to simulation)
- ✅ Show sample events
- ✅ Verify API connectivity

### Full Pipeline (With Kafka)

```bash
# One-time run
source venv/bin/activate
python scripts/data_pipeline.py

# Continuous mode (every 5 minutes)
python scripts/data_pipeline.py --continuous --interval 300
```

This will:
- ✅ Fetch data from all sources
- ✅ Send to Kafka topics
- ✅ Handle errors with DLQ pattern
- ✅ Log all operations

---

## Canonical Data Model

All data is normalized to a standard format before entering Kafka.

### Common Fields (All Events)

| Field | Type | Description |
|-------|------|-------------|
| `event_id` | string | Deterministic ID (enables deduplication) |
| `event_type` | string | Event classification |
| `event_time` | ISO8601 | When event occurred |
| `source` | string | Data source identifier |
| `ingestion_time` | ISO8601 | When data was ingested |
| `correlation_id` | UUID | Request tracking ID |

### Weather Event Schema

```typescript
interface WeatherObservation {
  event_id: string;           // "weather_NSW1_202602032132"
  event_type: "WeatherObservation";
  event_time: string;         // ISO8601
  region_id: string;          // "NSW1", "VIC1", etc.
  location_name: string;      // "Sydney", "Melbourne", etc.
  temperature_celsius: number;
  wind_speed_kmh: number;
  humidity_percent: number;
  source: "OPENMETEO";
  ingestion_time: string;     // ISO8601
}
```

### Dispatch Event Schema

```typescript
interface MarketDispatchEvent {
  event_id: string;           // "dispatch_NSW1_solar_202602032132"
  event_type: "MarketDispatchEvent";
  event_time: string;         // ISO8601
  region_id: string;          // "NSW1", "VIC1", etc.
  fuel_type: string;          // "solar", "wind", "coal", etc.
  value_mw: number;           // Power generation in MW
  unit: "MW";
  source: "OPENNEM" | "SIMULATED";
  ingestion_time: string;     // ISO8601
}
```

---

## Key Interview Points

### 1. **Real Data Integration**
> "We're using real weather data from Open-Meteo API covering 5 Australian cities. The data updates in real-time and includes temperature, wind speed, and humidity - all critical for energy demand forecasting."

### 2. **Resilience & Fallback**
> "The dispatch API is currently unavailable, but the system continues operating with simulated data. This demonstrates resilience - in production, you'd have circuit breakers, cached data, or alternative sources."

### 3. **Data Normalization**
> "Each source has its own format. We normalize everything to a canonical model before entering Kafka. This means consumers don't need to know about upstream API changes."

### 4. **Idempotency**
> "Event IDs are deterministic - based on region, fuel type, and timestamp. If we fetch the same data twice, it gets the same ID, enabling deduplication downstream."

### 5. **Observability**
> "Every event gets a correlation ID. You can trace a single request from the external API, through Kafka, through Kong, all the way to the consumer."

### 6. **Scalability**
> "Weather data is fetched concurrently for all regions. Kafka topics are partitioned. Kong handles rate limiting. This scales to hundreds of data sources and thousands of consumers."

---

## Monitoring Data Flow

### Via Kafka UI
```
http://localhost:8180
```
- Browse topics
- View messages
- Check consumer lag
- Monitor partition distribution

### Via Grafana
```
http://localhost:3001 (admin/admin)
```
- Message throughput
- API latency
- Error rates
- System health

### Via Logs
```bash
# Data pipeline logs
python scripts/data_pipeline.py

# API server logs
python scripts/api_server.py

# Kafka consumer logs
docker compose logs -f kafka
```

---

## Next Steps

### Enhancements for Real AEMO Data

1. **Use NEM Web Portal**:
   ```python
   # Download and parse real AEMO dispatch files
   url = "https://nemweb.com.au/Reports/Current/Dispatch_SCADA/"
   # Parse CSV from ZIP
   # Extract 5-minute dispatch intervals
   ```

2. **Alternative: EIA API** (US-based):
   ```bash
   # Sign up: https://www.eia.gov/opendata/
   export EIA_API_KEY=your_key_here
   # Fetch US grid data
   ```

3. **Cache & Replay**:
   ```python
   # Cache raw responses
   # Replay historical data
   # Useful for testing and demos
   ```

### Additional Data Sources to Consider

- **Pricing Data**: AEMO spot prices ($/MWh)
- **Forecast Data**: Demand and generation forecasts
- **Outage Data**: Planned and unplanned outages
- **Emissions Data**: CO2 intensity by fuel type

---

## Summary

✅ **Weather Data**: Real, working, covers 5 cities
⚠️ **Dispatch Data**: Simulated due to API availability (easily replaceable)
🎯 **Architecture Focus**: Patterns demonstrated are production-ready
🚀 **Interview Ready**: Real APIs show practical integration experience

The system is designed to be **impressive in interviews** while remaining **honest about limitations**. The architecture and patterns are real, battle-tested, and scalable.
