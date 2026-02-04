# GridPulse Demo Runbook

## Field-Proven Demo Scenarios

This runbook is designed to **prove GridPulse's enterprise value in 5 minutes**.

---

## Pre-Preparation (2 minutes)

### System Check

```bash
# 1. Are all services up?
docker compose ps

# 2. Is API server running?
curl -s http://localhost:5001/health | jq .status

# 3. Are Kafka topics ready?
docker exec gridpulse-kafka kafka-topics --bootstrap-server localhost:9092 --list

# 4. Is Kong running?
curl -s http://localhost:8101/status | jq .database.reachable
```

### Quick Start

If the system is down:

```bash
./start.sh
# Wait 2-3 minutes
```

---

## Demo 1: Rate Limiting (1 minute)

### What Are We Showing?

> "Kong API Gateway performs consumer-based rate limiting. It protects the system when excessive traffic arrives."

### Steps

```bash
# 1. Normal request (200 OK)
curl -i -H "apikey: analytics-team-secret-key-2024" \
  http://localhost:8100/v1/market/dispatch

# 2. Automated test - send 110 requests
./demos/scripts/demo1_rate_limiting.sh

# 3. See results
# First 100 requests: 200 OK
# Next 10 requests: 429 Too Many Requests
```

### Metrics

```bash
# Query in Prometheus
open "http://localhost:9090/graph?g0.expr=kong_http_status%7Bcode%3D%22429%22%7D"

# Open Grafana dashboard
open "http://localhost:3001/d/gridpulse-rate-limiting"
```

### Talking Points

- Consumer-level 100 req/min limit (configurable in production)
- When 429 is returned, downstream gets a warning
- System is protected from overload
- Different limits can be set for different consumers

**Preparation for Questions:**

- Q: "How flexible is the limit?" → A: Can be changed in real-time via Kong Admin API
- Q: "Is there burst handling?" → A: Yes, sliding window or token bucket algorithm can be used

---

## Demo 2: Producer/Consumer Decoupling (2 minutes)

### What Are We Showing?

> "Adding a new consumer doesn't touch upstream at all. Full decoupling thanks to Kafka."

### Steps

```bash
# 1. Show current state
echo "Currently only API server is consuming"
docker exec gridpulse-kafka kafka-consumer-groups \
  --bootstrap-server localhost:9092 --list

# 2. Add new consumer (Analytics Team)
./demos/scripts/demo2_add_consumer.sh analytics

# 3. Add another consumer (Operations Team)
./demos/scripts/demo2_add_consumer.sh operations

# 4. Add third consumer (Risk Team)
./demos/scripts/demo2_add_consumer.sh risk

# 5. Show all reading the same data
echo "3 consumers reading same messages independently:"
docker exec gridpulse-kafka kafka-consumer-groups \
  --bootstrap-server localhost:9092 \
  --all-groups --describe
```

### Result

```
3 consumers added in 3 minutes
Producer unchanged
Each consumer reads at its own pace
They don't affect each other
```

### Talking Points

- "Add new consumer" = just adding Kafka consumer group (0 deployment risk)
- Consumer manages its own offset (replay capability)
- Producer decoupled - doesn't know consumers or care about their speed
- In traditional point-to-point this would take 3 weeks (coordination, testing, deployment)

**Preparation for Questions:**

- Q: "Can it read historical data?" → A: Yes, consumer offset can be reset (within retention window)
- Q: "Does a slow consumer slow down the system?" → A: No, each consumer is independent. No problem until Kafka retention fills up.

---

## Demo 3: Buffering & Resilience (2 minutes)

### What Are We Showing?

> "Even if a consumer crashes, we don't lose data. Kafka acts as a buffer. Also, when source API fails, DLQ and fallback kick in."

### Part A: Consumer Lag & Recovery

```bash
# 1. Show normal state (lag = 0)
./demos/scripts/demo3_check_lag.sh

# 2. Stop consumer
./demos/scripts/demo3_stop_consumer.sh

# 3. Send data from producer (will accumulate in Kafka)
source venv/bin/activate
python scripts/data_pipeline.py

# 4. Show lag (should be increased)
./demos/scripts/demo3_check_lag.sh

# 5. Restart consumer
./demos/scripts/demo3_start_consumer.sh

# 6. Show lag decreasing (backlog being consumed)
watch -n 1 './demos/scripts/demo3_check_lag.sh'
```

### Part B: Source API Failure & DLQ

```bash
# 1. Normal state - data will come
python scripts/data_pipeline.py

# 2. Simulate API failure
export SIMULATE_API_FAILURE=true
python scripts/data_pipeline.py

# 3. Show messages dropped to DLQ
docker exec gridpulse-kafka kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic dlq.market.dispatch \
  --from-beginning --max-messages 5

# 4. Show fallback mechanism working
# (Simulated data used, system stayed up)
curl -s http://localhost:5001/api/v1/stats | jq .total_dispatch_events
```

### Metrics

```bash
# Consumer lag in Grafana
open "http://localhost:3001/d/gridpulse-consumer-lag"

# DLQ count in Grafana
open "http://localhost:3001/d/gridpulse-dlq-metrics"
```

### Talking Points

- Within Kafka retention (7 days), consumer can open anytime and continue
- Downstream failure doesn't affect upstream (decoupling)
- Failed messages aren't lost thanks to DLQ, can be analyzed later
- System stays up with fallback mechanism (graceful degradation)

**Preparation for Questions:**

- Q: "Retention is 7 days, then what?" → A: Can be archived (S3, data lake) or alerting for prevention
- Q: "How is replay done from DLQ?" → A: Manual review + re-publish or automated retry (exponential backoff)

---

## Demo 4: Correlation ID Trace (1 minute)

### What Are We Showing?

> "We can trace a single request across the entire system. Same correlation ID from Kong through producer, Kafka, to consumer."

### Steps

```bash
# 1. Make request through Kong and get correlation ID
RESPONSE=$(curl -si -H "apikey: analytics-team-secret-key-2024" \
  http://localhost:8100/v1/market/dispatch)

# Extract Correlation ID
CORRELATION_ID=$(echo "$RESPONSE" | grep -i "X-Correlation-ID" | awk '{print $2}' | tr -d '\r')

echo "Correlation ID: $CORRELATION_ID"

# 2. Find this ID in Kong log
docker logs gridpulse-kong 2>&1 | grep "$CORRELATION_ID"

# 3. Find this ID in API server log
cat api_server.log | grep "$CORRELATION_ID"

# 4. Show automatically with trace script
./demos/scripts/demo4_trace_request.sh
```

### Script Output

```
Tracing Correlation ID: abc-123-def-456

Kong Gateway (Entry Point)
   Time: 2026-02-04 13:30:00
   Method: GET /v1/market/dispatch
   Consumer: analytics-team
   Status: 200

API Server (Application)
   Time: 2026-02-04 13:30:00.123
   Handler: get_dispatch_events
   Duration: 2.5ms

Response
   Records returned: 17
   Status: 200 OK

End-to-end latency: 3.8ms
```

### Talking Points

- Single point of debugging - entire system can be traversed with one ID
- Critical in production incidents: "Where did this customer's request get stuck?"
- Kong injects automatically (X-Correlation-ID header)
- Every service writes this ID to its log (structured logging)

**Preparation for Questions:**

- Q: "Distributed tracing tools?" → A: Yes, OpenTelemetry/Jaeger can be integrated
- Q: "Performance overhead?" → A: Minimal - just UUID generation + header injection

---

## Demo 5: Centralized Ingestion Value (3 minutes)

### What Are We Showing?

> "Old approach: 2 teams produce the same data differently → inconsistency. New approach: Single canonical ingestion → everyone gets the same data."

### Scenario: Before & After

#### BEFORE: Decentralized Chaos

```bash
# Team A's pipeline
./demos/scripts/demo5_old_approach_teamA.sh

# Team B's pipeline
./demos/scripts/demo5_old_approach_teamB.sh

# Compare results
echo "=== TEAM A OUTPUT ==="
cat /tmp/teamA_output.json | jq '.region_id, .temperature_celsius'

echo "=== TEAM B OUTPUT ==="
cat /tmp/teamB_output.json | jq '.region, .temp_c'

# PROBLEM:
# - Different field names (region_id vs region)
# - Different units (celsius vs fahrenheit)
# - Different timestamp formats
# - 2x API call for same data (cost)
```

#### AFTER: Centralized Canonical

```bash
# Single centralized ingestion
python scripts/data_pipeline.py

# All consumers get the same canonical model
./demos/scripts/demo5_show_canonical.sh

# SOLUTION:
# - Single XSD schema (webmethods/models/*.xsd)
# - Standardized field names
# - Single API call (cost reduction)
# - Schema evolution controlled
```

### Schema Contract

```bash
# Show schema validation
./demos/scripts/demo5_validate_schema.sh

# Simulate schema change
echo "Backward compatibility test when Schema v2 is added:"
./demos/scripts/demo5_schema_evolution.sh
```

### Comparison Table

| Aspect | Before (Decentralized) | After (Centralized) |
|--------|------------------------|---------------------|
| **Data consistency** | Each team different | Canonical model |
| **API calls** | N teams = N calls | 1 call |
| **Schema control** | None | XSD + validation |
| **Onboarding** | 3 weeks | <5 minutes |
| **Debugging** | Which pipeline? | Single source |
| **Cost** | N × API cost | 1 × API cost |

### Talking Points

- "Single source of truth" - entire organization uses the same data
- Breaking changes controlled with schema contract
- Cost reduction: API calls go from N to 1
- Faster onboarding: Schema is known, writing a consumer takes 5 minutes
- Governance: Who, what, why using which data? → Visible from Kafka metrics

**Preparation for Questions:**

- Q: "What if schema changes?" → A: Backward compatibility test + versioning (topic-v2 or Avro schema registry)
- Q: "How do old pipelines migrate?" → A: Dual-write period + gradual cutover

---

## Grafana Dashboards

### Dashboard 1: Rate Limiting

**URL**: http://localhost:3001/d/gridpulse-rate-limiting

**Panels:**

- HTTP Status Codes (200 vs 429)
- Requests per Consumer
- Rate Limit Hits (time series)
- Consumer Activity Heatmap

### Dashboard 2: Consumer Lag

**URL**: http://localhost:3001/d/gridpulse-consumer-lag

**Panels:**

- Consumer Group Lag (per partition)
- Lag Trend (last 1 hour)
- Messages per Second (consumed)
- Consumer Offset Position

### Dashboard 3: DLQ & Resilience

**URL**: http://localhost:3001/d/gridpulse-dlq-metrics

**Panels:**

- DLQ Message Count
- Failed Message Rate
- Source API Health
- Fallback Activation Count

### Dashboard 4: End-to-End Latency

**URL**: http://localhost:3001/d/gridpulse-e2e-latency

**Panels:**

- P50/P95/P99 Latency
- Kong Gateway Latency
- API Server Processing Time
- Kafka Publish Time

---

## 5-Minute Demo Timeline

| Time | Demo | Key Point |
|------|------|-----------|
| 0:00-1:00 | Rate Limiting | "System protects itself" |
| 1:00-3:00 | Producer/Consumer Decoupling | "New consumer <5 min" |
| 3:00-4:00 | Resilience | "No data loss" |
| 4:00-5:00 | Correlation ID | "End-to-end trace" |
| 5:00-8:00 | Centralized Ingestion | "Single source of truth" |

**Backup:** If there's time, show Grafana dashboards (extra 2 minutes)

---

## Pre-Demo Checklist

- [ ] Docker compose up
- [ ] API server running (port 5001)
- [ ] Kafka healthy
- [ ] Kong configured
- [ ] Grafana dashboards imported
- [ ] Demo scripts executable (`chmod +x demos/scripts/*.sh`)
- [ ] Test data in Kafka (run `python scripts/data_pipeline.py`)

---

## Troubleshooting

### "Consumer lag not showing"

```bash
# Check consumer groups
docker exec gridpulse-kafka kafka-consumer-groups \
  --bootstrap-server localhost:9092 --list

# Manual lag check
docker exec gridpulse-kafka kafka-consumer-groups \
  --bootstrap-server localhost:9092 \
  --group gridpulse-api-consumer --describe
```

### "Rate limiting not working"

```bash
# Check Kong rate-limit plugin
curl -s http://localhost:8101/plugins | jq '.data[] | select(.name=="rate-limiting")'

# Check Kong routes
curl -s http://localhost:8101/routes | jq .
```

### "Grafana dashboards missing"

```bash
# Import them
./demos/scripts/setup_grafana_dashboards.sh
```

---

## Post-Demo Questions

### Technical

1. **How is Kafka partition count determined?**
   → Based on throughput × parallelism needs. We have 3 partitions = 3 parallel consumers.

2. **How is schema evolution handled?**
   → Avro Schema Registry (Confluent) or versioned topics (v1, v2).

3. **Multi-datacenter scenario?**
   → Cross-DC replication with Kafka MirrorMaker or Confluent Replicator.

### Business Value

1. **What's the ROI?**
   → API call reduction (60% cost save), faster onboarding (3 weeks → 5 min), data consistency (priceless).

2. **How does it scale?**
   → Kafka cluster grows, partitions increase, consumers parallelize. Linear scaling.

3. **Integration with existing systems?**
   → Any API/service can be added as Kong upstream. 100+ connectors with Kafka Connect.

---

**Final Note**: This demo addresses both technical and business teams in the field. Technical part = architecture depth, business part = value proposition.
