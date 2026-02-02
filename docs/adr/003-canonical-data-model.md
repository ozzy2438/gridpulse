# ADR-003: Canonical Data Model

## Status
Accepted

## Context

We receive data from multiple sources (AEMO, Weather APIs) in different formats. Consumers need a consistent, predictable data format.

## Decision

We will define canonical data models (XSD schemas) that all data is normalized to before entering the event hub.

## Consequences

### Positive
- **Consistency**: All consumers receive same format
- **Decoupling**: Source format changes don't affect consumers
- **Validation**: Schema enables automatic validation
- **Documentation**: Schema serves as data contract

### Negative
- **Transformation Overhead**: Every message must be transformed
- **Schema Evolution**: Changes require careful versioning
- **Complexity**: Another layer of abstraction

## Canonical Models

### MarketDispatchEvent
```json
{
  "event_id": "NSW1_SOLAR_20240115_1000",
  "event_type": "MarketDispatchEvent",
  "event_time": "2024-01-15T10:00:00Z",
  "region_id": "NSW1",
  "fuel_type": "solar",
  "value_mw": 1250.5,
  "unit": "MW",
  "source": "AEMO",
  "ingestion_time": "2024-01-15T10:00:05Z",
  "correlation_id": "uuid-here"
}
```

### WeatherObservation
```json
{
  "event_id": "weather_NSW1_202401151000",
  "event_type": "WeatherObservation",
  "event_time": "2024-01-15T10:00:00Z",
  "region_id": "NSW1",
  "location_name": "Sydney",
  "temperature_celsius": 28.5,
  "wind_speed_kmh": 15.2,
  "humidity_percent": 65,
  "source": "OPENMETEO",
  "ingestion_time": "2024-01-15T10:00:02Z",
  "correlation_id": "uuid-here"
}
```

## Key Fields

### event_id (Idempotency Key)
- Deterministically generated from source data
- Same source event always produces same event_id
- Enables consumer-side deduplication

### correlation_id (Traceability)
- UUID generated at ingestion time
- Flows through entire system
- Enables end-to-end request tracing

### ingestion_time (Latency Measurement)
- Timestamp when event entered our system
- Compare with event_time to measure latency
- Useful for SLA monitoring

## Schema Evolution Strategy

1. **Additive Changes**: Add new optional fields (backward compatible)
2. **Breaking Changes**: Create new topic version (e.g., `market.dispatch.v2`)
3. **Deprecation**: Run parallel topics during migration period

## References

- [Enterprise Integration Patterns - Canonical Data Model](https://www.enterpriseintegrationpatterns.com/patterns/messaging/CanonicalDataModel.html)
- [Schema Evolution Best Practices](https://docs.confluent.io/platform/current/schema-registry/avro.html)
