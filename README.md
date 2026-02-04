# GridPulse - Energy Integration Platform

## Overview

GridPulse is a reference architecture demonstrating enterprise-grade integration patterns for energy market data using webMethods, Kafka, and Kong.

### Problem Statement

Large energy companies face these challenges:
- **Data Inconsistency**: Multiple teams fetch same data differently
- **Integration Sprawl**: Point-to-point connections grow exponentially
- **No Traceability**: "Why was this data delayed?" has no answer
- **Slow Onboarding**: Adding new consumers takes weeks

### Solution

```
Data Sources → webMethods (normalize) → Kafka (event hub) → Kong (API gateway) → Consumers
```

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           GridPulse Architecture                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌──────────────┐    ┌──────────────┐                                       │
│  │  AEMO API    │    │ Weather API  │    DATA SOURCES                       │
│  │  (Dispatch)  │    │ (Open-Meteo) │                                       │
│  └──────┬───────┘    └──────┬───────┘                                       │
│         │                   │                                                │
│         ▼                   ▼                                                │
│  ┌────────────────────────────────────┐                                     │
│  │     webMethods / Python Scripts     │    INGESTION LAYER                 │
│  │  - Fetch & Poll data sources        │    - Normalize to canonical model  │
│  │  - Transform & Validate             │    - Add correlation IDs           │
│  └──────────────┬─────────────────────┘                                     │
│                 │                                                            │
│                 ▼                                                            │
│  ┌────────────────────────────────────┐                                     │
│  │         Apache Kafka                │    EVENT HUB                       │
│  │  Topics:                            │    - Decouple producers/consumers  │
│  │  - market.dispatch (3 partitions)   │    - Replay capability             │
│  │  - weather.observations             │    - 7-day retention               │
│  │  - dlq.* (Dead Letter Queues)       │                                    │
│  └──────────────┬─────────────────────┘                                     │
│                 │                                                            │
│                 ▼                                                            │
│  ┌────────────────────────────────────┐                                     │
│  │         Kong API Gateway            │    API LAYER                       │
│  │  - Authentication (API Keys)        │    - Rate limiting                 │
│  │  - Correlation ID injection         │    - Logging & metrics             │
│  └──────────────┬─────────────────────┘                                     │
│                 │                                                            │
│         ┌───────┼───────┐                                                    │
│         ▼       ▼       ▼                                                    │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐                                     │
│  │Analytics │ │Operations│ │  Risk    │    CONSUMERS                        │
│  │  Team    │ │  Team    │ │  Team    │                                     │
│  └──────────┘ └──────────┘ └──────────┘                                     │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Quick Start

### Prerequisites

- Docker & Docker Compose
- Python 3.9+
- curl (for API testing)

### Automated Setup (Recommended)

```bash
# Clone the repo
cd gridpulse

# Run the quick start script
./start.sh
```

This script will:
- ✅ Check Docker is running
- ✅ Start all services (Kafka, Kong, Monitoring)
- ✅ Create Kafka topics
- ✅ Configure Kong API Gateway
- ✅ Set up Python virtual environment
- ✅ Test data sources (real weather data!)

### Manual Setup

#### 1. Start Infrastructure

```bash
# Make sure Docker Desktop is running
# macOS: open -a Docker

# Start all services
docker compose up -d

# Wait for services to be healthy (about 60 seconds)
docker compose ps
```

#### 2. Create Kafka Topics

```bash
chmod +x scripts/create_kafka_topics.sh
./scripts/create_kafka_topics.sh
```

#### 3. Configure Kong

```bash
chmod +x scripts/setup_kong.sh
./scripts/setup_kong.sh
```

#### 4. Set Up Python Environment

```bash
# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt
```

#### 5. Start API Server

```bash
# In terminal 1
source venv/bin/activate
python scripts/api_server.py
```

#### 6. Run Data Pipeline

```bash
# In terminal 2 (fetches REAL data from APIs!)
source venv/bin/activate
python scripts/data_pipeline.py

# Or run continuously every 5 minutes
python scripts/data_pipeline.py --continuous --interval 300
```

#### 7. Test the API

```bash
# Without API key (should fail with 401)
curl http://localhost:8100/v1/market/dispatch

# With API key (should succeed)
curl -H "apikey: analytics-team-secret-key-2024" \
  http://localhost:8100/v1/market/dispatch
```

## Access Points

| Service | URL | Credentials |
|---------|-----|-------------|
| Kafka UI | http://localhost:8180 | - |
| Kong Admin | http://localhost:8101 | - |
| Kong Proxy | http://localhost:8100 | API Key required |
| Kong Manager | http://localhost:8102 | - |
| Grafana | http://localhost:3001 | admin/admin |
| Prometheus | http://localhost:9090 | - |
| API Server | http://localhost:5001 | - |

## API Keys

| Team | API Key |
|------|---------|
| Analytics | `analytics-team-secret-key-2024` |
| Operations | `ops-team-secret-key-2024` |
| Risk | `risk-team-secret-key-2024` |

## API Endpoints

### Health Check
```bash
GET /health
```

### Market Dispatch
```bash
# Get dispatch events
GET /api/v1/dispatch?region_id=NSW1&limit=100

# Add dispatch event
POST /api/v1/dispatch
Content-Type: application/json
{
  "region_id": "NSW1",
  "fuel_type": "solar",
  "value_mw": 1250.5
}
```

### Weather Observations
```bash
GET /api/v1/weather?region_id=NSW1&limit=100
```

### Statistics
```bash
GET /api/v1/stats
```

## Project Structure

```
gridpulse/
├── start.sh                    # 🚀 Quick start script (run this!)
├── docker-compose.yml          # All services definition
├── docker/
│   ├── kafka/                  # Kafka configuration
│   └── kong/
│       └── kong.yml            # Kong declarative config
├── webmethods/
│   ├── services/               # webMethods services (conceptual)
│   └── models/
│       ├── MarketDispatchEvent.xsd
│       └── WeatherObservation.xsd
├── scripts/
│   ├── data_pipeline.py        # 🌟 Complete data pipeline (real APIs!)
│   ├── download_aemo.py        # AEMO data fetcher
│   ├── test_data_fetch.py      # Test data sources without Kafka
│   ├── kafka_producer.py       # Kafka producer
│   ├── api_server.py           # Flask API server
│   ├── create_kafka_topics.sh  # Topic creation script
│   └── setup_kong.sh           # Kong configuration script
├── data/
│   ├── raw/                    # Raw data from sources (real weather data!)
│   └── processed/              # Processed data
├── monitoring/
│   └── prometheus.yml          # Prometheus configuration
├── docs/
│   └── adr/                    # Architecture Decision Records
└── tests/                      # Test files
```

## Key Concepts

### Canonical Model
All data is normalized to a standard format before entering the system. This ensures consistency across all consumers.

### Correlation ID
Every request gets a unique correlation ID that flows through the entire system, enabling end-to-end traceability.

### Dead Letter Queue (DLQ)
Failed messages are sent to DLQ topics for later analysis and retry, ensuring zero data loss.

### Idempotency
Event IDs are generated deterministically, allowing consumers to deduplicate messages and achieve exactly-once processing.

## Demo Scenarios

### Scenario 1: Add New Consumer

```bash
# Create new consumer in Kong (takes < 5 minutes)
curl -X POST http://localhost:8001/consumers \
  --data username=new-team

curl -X POST http://localhost:8001/consumers/new-team/key-auth \
  --data key=new-team-secret-key-2024

# Test immediately
curl -H "apikey: new-team-secret-key-2024" \
  http://localhost:8000/v1/market/dispatch
```

### Scenario 2: Trace a Request

```bash
# Make a request and capture correlation ID
curl -i -H "apikey: analytics-team-secret-key-2024" \
  http://localhost:8000/v1/market/dispatch

# Look for: X-Correlation-ID header in response
# Use this ID to search logs across all systems
```

### Scenario 3: Rate Limiting

```bash
# Send many requests quickly
for i in {1..110}; do
  curl -s -o /dev/null -w "%{http_code}\n" \
    -H "apikey: analytics-team-secret-key-2024" \
    http://localhost:8000/v1/market/dispatch
done | sort | uniq -c

# After 100 requests, you'll see 429 (Too Many Requests)
```

## Stopping Services

```bash
# Stop all services
docker-compose down

# Stop and remove volumes (clean slate)
docker-compose down -v
```

## Troubleshooting

### Kafka not starting
```bash
# Check Zookeeper first
docker logs gridpulse-zookeeper

# Then check Kafka
docker logs gridpulse-kafka
```

### Kong returning 502
```bash
# Ensure API server is running
python scripts/api_server.py

# Check Kong upstream health
curl http://localhost:8001/upstreams
```

### API returns empty data
```bash
# Send some test data first
python scripts/kafka_producer.py
```

## License

MIT License
