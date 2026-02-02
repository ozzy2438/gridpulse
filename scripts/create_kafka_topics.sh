#!/bin/bash
# Kafka Topic Creation Script
# This script creates required topics in Kafka

echo "=========================================="
echo "GridPulse - Kafka Topic Setup"
echo "=========================================="

KAFKA_CONTAINER="gridpulse-kafka"

# Wait for Kafka to be ready
echo "Waiting for Kafka to be ready..."
until docker exec $KAFKA_CONTAINER kafka-broker-api-versions --bootstrap-server localhost:9092 > /dev/null 2>&1; do
    sleep 2
done
echo "Kafka is ready!"

# ========================================
# MAIN TOPICS
# ========================================
echo ""
echo "Creating main topics..."

# Market Dispatch Topic
docker exec $KAFKA_CONTAINER kafka-topics --create \
  --bootstrap-server localhost:9092 \
  --topic market.dispatch \
  --partitions 3 \
  --replication-factor 1 \
  --if-not-exists

echo "  ✅ market.dispatch created (3 partitions)"

# Weather Observations Topic
docker exec $KAFKA_CONTAINER kafka-topics --create \
  --bootstrap-server localhost:9092 \
  --topic weather.observations \
  --partitions 3 \
  --replication-factor 1 \
  --if-not-exists

echo "  ✅ weather.observations created (3 partitions)"

# ========================================
# DEAD LETTER QUEUE TOPICS
# ========================================
echo ""
echo "Creating DLQ topics..."

# Market Dispatch DLQ
docker exec $KAFKA_CONTAINER kafka-topics --create \
  --bootstrap-server localhost:9092 \
  --topic dlq.market.dispatch \
  --partitions 1 \
  --replication-factor 1 \
  --if-not-exists

echo "  ✅ dlq.market.dispatch created"

# Weather Observations DLQ
docker exec $KAFKA_CONTAINER kafka-topics --create \
  --bootstrap-server localhost:9092 \
  --topic dlq.weather.observations \
  --partitions 1 \
  --replication-factor 1 \
  --if-not-exists

echo "  ✅ dlq.weather.observations created"

# ========================================
# TOPIC LIST
# ========================================
echo ""
echo "=========================================="
echo "Topic List:"
echo "=========================================="
docker exec $KAFKA_CONTAINER kafka-topics --list --bootstrap-server localhost:9092

echo ""
echo "=========================================="
echo "Topic Details:"
echo "=========================================="
for topic in market.dispatch weather.observations dlq.market.dispatch dlq.weather.observations; do
    echo ""
    echo "--- $topic ---"
    docker exec $KAFKA_CONTAINER kafka-topics --describe \
      --bootstrap-server localhost:9092 \
      --topic $topic 2>/dev/null | head -3
done

echo ""
echo "✅ Kafka topic setup completed!"
echo ""
echo "You can view topics at: http://localhost:8080 (Kafka UI)"
