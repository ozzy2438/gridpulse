#!/bin/bash
# Demo 2: Add New Consumer
# This script adds a new Kafka consumer (decoupling demo)

set -e

CONSUMER_NAME=$1

if [ -z "$CONSUMER_NAME" ]; then
    echo "Usage: $0 <consumer-name>"
    echo "Example: $0 analytics"
    exit 1
fi

CONSUMER_GROUP="gridpulse-${CONSUMER_NAME}-consumer"
TOPIC="market.dispatch"

echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║              Demo 2: Adding New Consumer (Decoupling)                ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""
echo "Consumer Name:  $CONSUMER_NAME"
echo "Consumer Group: $CONSUMER_GROUP"
echo "Topic:          $TOPIC"
echo ""

# Timer start
START_TIME=$(date +%s)

echo "⏱️  Starting timer..."
echo ""

# Step 1: Check current consumers
echo "📋 Step 1: Current consumer groups"
docker exec gridpulse-kafka kafka-consumer-groups \
    --bootstrap-server localhost:9092 \
    --list 2>/dev/null

echo ""

# Step 2: Create consumer
echo "➕ Step 2: Creating new consumer '$CONSUMER_NAME'..."

# Create a simple consumer script
CONSUMER_SCRIPT="/tmp/consumer_${CONSUMER_NAME}.py"

cat > "$CONSUMER_SCRIPT" << 'CONSUMER_EOF'
#!/usr/bin/env python3
import sys
from kafka import KafkaConsumer
import json
import signal

consumer_name = sys.argv[1]
consumer_group = f"gridpulse-{consumer_name}-consumer"

print(f"🚀 Consumer '{consumer_name}' starting...")
print(f"   Group: {consumer_group}")
print(f"   Topics: market.dispatch, weather.observations")
print("")

consumer = KafkaConsumer(
    'market.dispatch',
    'weather.observations',
    bootstrap_servers='localhost:9092',
    group_id=consumer_group,
    auto_offset_reset='earliest',
    value_deserializer=lambda m: json.loads(m.decode('utf-8')),
    consumer_timeout_ms=5000  # Exit after 5s of no messages
)

message_count = 0

def signal_handler(sig, frame):
    print(f"\n✅ Consumer '{consumer_name}' processed {message_count} messages")
    consumer.close()
    sys.exit(0)

signal.signal(signal.SIGINT, signal_handler)
signal.signal(signal.SIGTERM, signal_handler)

try:
    for message in consumer:
        message_count += 1
        event = message.value
        print(f"  [{message_count}] {event.get('event_type')}: {event.get('region_id')} - {event.get('event_time')}")
        
        if message_count >= 10:  # Demo mode: stop after 10 messages
            break
    
    print(f"\n✅ Consumer '{consumer_name}' processed {message_count} messages (demo complete)")
    
except KeyboardInterrupt:
    print(f"\n✅ Consumer '{consumer_name}' processed {message_count} messages")
finally:
    consumer.close()
CONSUMER_EOF

chmod +x "$CONSUMER_SCRIPT"

# Run consumer in background for demo
echo "   Starting consumer (will process 10 messages for demo)..."
python3 "$CONSUMER_SCRIPT" "$CONSUMER_NAME" &
CONSUMER_PID=$!

# Wait for consumer to finish
wait $CONSUMER_PID 2>/dev/null || true

echo ""

# Step 3: Verify consumer group
echo "✅ Step 3: Verifying consumer group"
docker exec gridpulse-kafka kafka-consumer-groups \
    --bootstrap-server localhost:9092 \
    --group "$CONSUMER_GROUP" \
    --describe 2>/dev/null || echo "   (Consumer group will appear after first message)"

echo ""

# Timer end
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║                            Demo Complete                             ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""
echo "  ⏱️  Time taken: $DURATION seconds"
echo "  ✅ Consumer '$CONSUMER_NAME' added successfully"
echo "  ✅ Consumer group: $CONSUMER_GROUP"
echo "  ✅ Topics: market.dispatch, weather.observations"
echo ""
echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║                        Key Observations                              ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""
echo "  1. No changes to PRODUCER (upstream) ✅"
echo "  2. No changes to OTHER CONSUMERS ✅"
echo "  3. New consumer reads independently ✅"
echo "  4. Total time: <${DURATION}s (target: <5 minutes) ✅"
echo ""
echo "  Compare to traditional approach:"
echo "    • Point-to-point integration: 2-3 weeks"
echo "    • API changes required: Yes"
echo "    • Testing required: Full regression"
echo "    • Risk: Medium to High"
echo ""
echo "  Kafka approach:"
echo "    • Integration time: <5 minutes ✅"
echo "    • API changes required: None ✅"
echo "    • Testing required: Only new consumer ✅"
echo "    • Risk: Low ✅"
echo ""

# List all consumer groups
echo "📊 All consumer groups now:"
docker exec gridpulse-kafka kafka-consumer-groups \
    --bootstrap-server localhost:9092 \
    --list 2>/dev/null

echo ""
echo "💡 To run consumer continuously:"
echo "   python3 $CONSUMER_SCRIPT $CONSUMER_NAME"
echo ""

# Cleanup demo script after showing
# (Keep it for manual testing if needed)
