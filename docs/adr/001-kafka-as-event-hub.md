# ADR-001: Kafka as Event Hub

## Status
Accepted

## Context

We need a central event distribution mechanism that:
- Handles high throughput (thousands of events/second)
- Provides durability (events are not lost)
- Supports multiple consumers without coupling
- Maintains event ordering per partition

## Decision

We will use Apache Kafka (AWS MSK in production, local Kafka for dev) as our event hub.

## Consequences

### Positive
- **Decoupling**: Producers and consumers are independent
- **Durability**: Events persist for configurable retention period (7 days default)
- **Scalability**: Partitioning allows horizontal scaling
- **Replayability**: Consumers can replay from any offset
- **Ordering**: Events within same partition maintain order

### Negative
- **Operational Complexity**: Kafka requires operational expertise
- **Learning Curve**: Team needs Kafka training
- **Cost**: MSK has associated AWS costs

## Alternatives Considered

| Option | Pros | Cons |
|--------|------|------|
| AWS SQS | Simple, fully managed | No replay, limited ordering |
| RabbitMQ | Flexible routing, mature | Less suitable for high throughput |
| AWS EventBridge | Serverless, event-driven | Vendor lock-in, limited replay |
| Redis Streams | Fast, simple | Less durable, smaller ecosystem |

## Implementation Notes

### Topic Design
- `market.dispatch` - Market dispatch events (3 partitions, keyed by region_id)
- `weather.observations` - Weather data (3 partitions, keyed by region_id)
- `dlq.*` - Dead letter queues for failed messages

### Partition Strategy
Using `region_id` as partition key ensures:
- All events for same region go to same partition
- Ordering is maintained per region
- Load is distributed across partitions

### Producer Configuration
```python
KafkaProducer(
    acks='all',           # Wait for all replicas
    retries=3,            # Retry on failure
    enable_idempotence=True,  # Prevent duplicates
)
```

### Consumer Configuration
```python
KafkaConsumer(
    auto_offset_reset='earliest',  # Start from beginning if no offset
    enable_auto_commit=True,       # Commit offsets automatically
)
```

## References

- [Kafka Documentation](https://kafka.apache.org/documentation/)
- [AWS MSK Best Practices](https://docs.aws.amazon.com/msk/latest/developerguide/bestpractices.html)
- [Designing Event-Driven Systems](https://www.confluent.io/designing-event-driven-systems/)
