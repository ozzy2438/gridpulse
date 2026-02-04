#!/bin/bash
# Quick Demo - Run all 5 demos in sequence
# This script runs all demos sequentially with explanations

set -e

DEMOS_DIR="demos/scripts"

echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║                                                                      ║"
echo "║            GridPulse - Complete Demo Suite (5 Minutes)              ║"
echo "║                                                                      ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""
echo "This demo will showcase 5 key enterprise integration patterns:"
echo ""
echo "  1️⃣  Rate Limiting         (1 min) - Kong protects the system"
echo "  2️⃣  Producer/Consumer     (2 min) - Add consumer in <5 minutes"
echo "  3️⃣  Buffering & Resilience(2 min) - No data loss + DLQ pattern"
echo "  4️⃣  Correlation ID Trace  (1 min) - End-to-end traceability"
echo "  5️⃣  Centralized Ingestion (3 min) - Single source of truth"
echo ""
echo "Total time: ~9 minutes (with explanations)"
echo ""

# Function to wait for user
wait_for_user() {
    echo ""
    read -p "Press ENTER to continue..." dummy
    echo ""
}

# Function to run demo with timer
run_demo() {
    local demo_num=$1
    local demo_name=$2
    local demo_script=$3
    local expected_time=$4
    shift 4
    local demo_args="$*"

    echo "╔══════════════════════════════════════════════════════════════════════╗"
    echo "║                                                                      ║"
    echo "║                     Demo $demo_num: $demo_name"
    echo "║                      Expected time: $expected_time"
    echo "║                                                                      ║"
    echo "╚══════════════════════════════════════════════════════════════════════╝"
    echo ""

    START_TIME=$(date +%s)

    # Run demo
    if [ -f "$demo_script" ]; then
        "$demo_script" "$demo_args"
    else
        echo "❌ Demo script not found: $demo_script"
        return 1
    fi
    
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✅ Demo $demo_num completed in ${DURATION}s (expected: $expected_time)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    wait_for_user
}

# Pre-flight checks
echo "🔍 Pre-flight checks..."
echo ""

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running"
    echo "   Please start Docker and run ./start.sh"
    exit 1
fi

# Check if services are up
if ! curl -s http://localhost:5001/health > /dev/null 2>&1; then
    echo "⚠️  API server not running"
    echo "   Starting API server..."
    source venv/bin/activate && nohup python scripts/api_server.py > api_server.log 2>&1 &
    sleep 3
fi

# Check Kafka
if ! docker exec gridpulse-kafka kafka-topics --bootstrap-server localhost:9092 --list > /dev/null 2>&1; then
    echo "❌ Kafka is not accessible"
    echo "   Please run ./start.sh first"
    exit 1
fi

echo "✅ All services are ready"
echo ""

wait_for_user

# Demo 1: Rate Limiting
run_demo 1 "Rate Limiting                   " \
    "$DEMOS_DIR/demo1_rate_limiting.sh" \
    "1 minute"

# Demo 2: Producer/Consumer Decoupling
run_demo 2 "Producer/Consumer Decoupling   " \
    "$DEMOS_DIR/demo2_add_consumer.sh" \
    "2 minutes" \
    "analytics"

# Demo 3: Buffering & Resilience
echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║                                                                      ║"
echo "║                Demo 3: Buffering & Resilience                        ║"
echo "║                    Expected time: 2 minutes                          ║"
echo "║                                                                      ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""
echo "This demo has 3 parts:"
echo "  Part A: Check current lag (should be 0)"
echo "  Part B: Stop consumer & add data (lag increases)"
echo "  Part C: Restart consumer (lag decreases)"
echo ""

wait_for_user

START_TIME=$(date +%s)

# Part A: Check lag
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Part A: Current State"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
$DEMOS_DIR/demo3_check_lag.sh

echo ""
wait_for_user

# Part B: Stop consumer & add data
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Part B: Simulating Consumer Failure"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
$DEMOS_DIR/demo3_stop_consumer.sh

echo ""
echo "Adding data to Kafka (consumer is stopped, data will buffer)..."
source venv/bin/activate && python scripts/data_pipeline.py

echo ""
echo "Checking lag (should be increased):"
$DEMOS_DIR/demo3_check_lag.sh

echo ""
wait_for_user

# Part C: Restart consumer
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Part C: Consumer Recovery"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
$DEMOS_DIR/demo3_start_consumer.sh

echo ""
echo "Waiting 3 seconds for consumer to process backlog..."
sleep 3

echo ""
echo "Checking lag (should be decreased):"
$DEMOS_DIR/demo3_check_lag.sh

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Demo 3 completed in ${DURATION}s (expected: 2 minutes)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

wait_for_user

# Demo 4: Correlation ID Trace
run_demo 4 "Correlation ID Trace           " \
    "$DEMOS_DIR/demo4_trace_request.sh" \
    "1 minute"

# Demo 5: Centralized Ingestion
run_demo 5 "Centralized Ingestion Value    " \
    "$DEMOS_DIR/demo5_compare.sh" \
    "3 minutes"

# Final summary
echo ""
echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║                                                                      ║"
echo "║                    Demo Suite Completed! 🎉                          ║"
echo "║                                                                      ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""
echo "✅ All 5 enterprise patterns demonstrated:"
echo ""
echo "  1️⃣  Rate Limiting         - System protection"
echo "  2️⃣  Producer/Consumer     - Fast onboarding (<5 min)"
echo "  3️⃣  Buffering & Resilience- No data loss"
echo "  4️⃣  Correlation ID        - End-to-end traceability"
echo "  5️⃣  Centralized Ingestion - Single source of truth"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 View Grafana Dashboards:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  http://localhost:3001/d/gridpulse-rate-limiting"
echo "  http://localhost:3001/d/gridpulse-consumer-lag"
echo "  http://localhost:3001/d/gridpulse-dlq-metrics"
echo "  http://localhost:3001/d/gridpulse-e2e-latency"
echo ""
echo "  Login: admin / admin"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📚 Documentation:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  • Demo Runbook:         demos/DEMO_RUNBOOK.md"
echo "  • System Status:        SYSTEM_STATUS.md"
echo "  • Data Sources:         DATA_SOURCES.md"
echo "  • Interview Prep:       docs/INTERVIEW_PRESENTATION.md"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Thank you for watching the GridPulse demo!"
echo "Questions? Check the documentation or run individual demos again."
echo ""
