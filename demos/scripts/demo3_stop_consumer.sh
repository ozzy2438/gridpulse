#!/bin/bash
# Demo 3: Stop Consumer (to simulate lag)

set -e

echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║                  Demo 3: Stop Consumer (Simulate Lag)                ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""

# Find API server process
API_PID=$(lsof -ti:5001 2>/dev/null || echo "")

if [ -z "$API_PID" ]; then
    echo "⚠️  API server not running on port 5001"
    echo ""
    exit 0
fi

echo "Found API server (PID: $API_PID)"
echo ""
echo "⏸️  Stopping API server to simulate consumer lag..."
kill -TERM "$API_PID" 2>/dev/null || true

# Wait a moment
sleep 2

# Verify it's stopped
if lsof -ti:5001 >/dev/null 2>&1; then
    echo "⚠️  Process still running, forcing kill..."
    kill -9 "$API_PID" 2>/dev/null || true
    sleep 1
fi

if ! lsof -ti:5001 >/dev/null 2>&1; then
    echo "✅ API server stopped"
else
    echo "❌ Failed to stop API server"
    exit 1
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║                        Next Steps                                    ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""
echo "  1. Send more data to Kafka:"
echo "     source venv/bin/activate && python scripts/data_pipeline.py"
echo ""
echo "  2. Check consumer lag (should be increasing):"
echo "     ./demos/scripts/demo3_check_lag.sh"
echo ""
echo "  3. Restart consumer:"
echo "     ./demos/scripts/demo3_start_consumer.sh"
echo ""
echo "  4. Watch lag decrease (backlog being consumed):"
echo "     watch -n 2 './demos/scripts/demo3_check_lag.sh'"
echo ""
