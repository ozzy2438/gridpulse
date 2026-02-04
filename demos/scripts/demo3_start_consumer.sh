#!/bin/bash
# Demo 3: Start Consumer (to recover from lag)

set -e

echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║               Demo 3: Start Consumer (Recover from Lag)              ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""

# Check if already running
if lsof -ti:5001 >/dev/null 2>&1; then
    echo "⚠️  API server already running on port 5001"
    PID=$(lsof -ti:5001)
    echo "   PID: $PID"
    echo ""
    exit 0
fi

# Check if venv exists
if [ ! -d "venv" ]; then
    echo "❌ Virtual environment not found"
    echo "   Run: python3 -m venv venv && pip install -r requirements.txt"
    exit 1
fi

echo "🚀 Starting API server..."
echo ""

# Start in background
nohup bash -c "source venv/bin/activate && python scripts/api_server.py" > api_server.log 2>&1 &
API_PID=$!

echo "   PID: $API_PID"
echo "   Log: api_server.log"
echo ""

# Wait for server to start
echo "⏳ Waiting for server to be ready..."
sleep 3

# Check if it's running
if lsof -ti:5001 >/dev/null 2>&1; then
    echo "✅ API server started successfully"
    
    # Test health
    echo ""
    echo "🏥 Health check:"
    curl -s http://localhost:5001/health | python3 -m json.tool 2>/dev/null || echo "   (Health endpoint not ready yet)"
else
    echo "❌ Failed to start API server"
    echo ""
    echo "Check logs:"
    tail -20 api_server.log
    exit 1
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║                        Consumer Recovery                             ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""
echo "  ✅ Consumer started"
echo "  📊 It will now consume backlog from Kafka"
echo "  ⏱️  Lag should decrease over time"
echo ""
echo "Monitor lag:"
echo "  watch -n 2 './demos/scripts/demo3_check_lag.sh'"
echo ""
echo "View logs:"
echo "  tail -f api_server.log"
echo ""
