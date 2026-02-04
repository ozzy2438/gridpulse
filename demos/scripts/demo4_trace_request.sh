#!/bin/bash
# Demo 4: Correlation ID Trace
# This script demonstrates end-to-end request tracing

set -e

API_KEY="analytics-team-secret-key-2024"
ENDPOINT="http://localhost:8100/v1/market/dispatch"

echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║                 Demo 4: Correlation ID Tracing                        ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""

# Step 1: Make request and capture correlation ID
echo "📤 Step 1: Making API request..."
echo "   Endpoint: $ENDPOINT"
echo ""

RESPONSE_FILE=$(mktemp)
HEADERS_FILE=$(mktemp)

HTTP_CODE=$(curl -s -w "%{http_code}" \
    -H "apikey: $API_KEY" \
    -D "$HEADERS_FILE" \
    -o "$RESPONSE_FILE" \
    "$ENDPOINT")

# Extract correlation ID from headers
CORRELATION_ID=$(grep -i "X-Correlation-ID:" "$HEADERS_FILE" | awk '{print $2}' | tr -d '\r\n' || echo "")

if [ -z "$CORRELATION_ID" ]; then
    echo "❌ No correlation ID found in response"
    echo ""
    echo "Response headers:"
    cat "$HEADERS_FILE"
    rm -f "$RESPONSE_FILE" "$HEADERS_FILE"
    exit 1
fi

echo "✅ Request completed"
echo "   HTTP Status: $HTTP_CODE"
echo "   Correlation ID: $CORRELATION_ID"
echo ""

# Step 2: Trace through Kong logs
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 Step 2: Tracing through Kong Gateway"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

KONG_LOG=$(docker logs gridpulse-kong 2>&1 | grep "$CORRELATION_ID" | tail -5 || echo "")

if [ ! -z "$KONG_LOG" ]; then
    echo "✅ Found in Kong logs:"
    echo "$KONG_LOG" | sed 's/^/   /'
else
    echo "⚠️  Not found in Kong logs (may be filtered)"
fi

echo ""

# Step 3: Trace through API Server logs
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 Step 3: Tracing through API Server"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ -f "api_server.log" ]; then
    API_LOG=$(grep "$CORRELATION_ID" api_server.log | tail -5 || echo "")
    
    if [ ! -z "$API_LOG" ]; then
        echo "✅ Found in API server logs:"
        echo "$API_LOG" | sed 's/^/   /'
    else
        echo "⚠️  Not found in API server logs"
    fi
else
    echo "⚠️  API server log file not found"
fi

echo ""

# Step 4: Parse response
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Step 4: Response Analysis"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if command -v jq &> /dev/null; then
    # Extract metadata
    RECORD_COUNT=$(jq -r '.meta.count // 0' "$RESPONSE_FILE")
    RESPONSE_CORRELATION=$(jq -r '.meta.correlation_id // "N/A"' "$RESPONSE_FILE")
    TIMESTAMP=$(jq -r '.meta.timestamp // "N/A"' "$RESPONSE_FILE")
    
    echo "  Records returned: $RECORD_COUNT"
    echo "  Response correlation ID: $RESPONSE_CORRELATION"
    echo "  Timestamp: $TIMESTAMP"
    echo ""
    
    # Check if correlation IDs match
    if [ "$CORRELATION_ID" == "$RESPONSE_CORRELATION" ]; then
        echo "  ✅ Correlation IDs match (Kong → API Server)"
    else
        echo "  ⚠️  Correlation ID mismatch"
        echo "     Kong header: $CORRELATION_ID"
        echo "     API response: $RESPONSE_CORRELATION"
    fi
else
    echo "  (Install jq for detailed response analysis)"
    cat "$RESPONSE_FILE"
fi

echo ""

# Step 5: Summary
echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║                        Trace Summary                                 ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""
echo "  🔗 Correlation ID: $CORRELATION_ID"
echo ""
echo "  Request Flow:"
echo "    1️⃣  Client → Kong Gateway"
echo "        • Kong generates/injects correlation ID"
echo "        • Authentication check (API key)"
echo "        • Rate limiting check"
echo "        • Header: X-Correlation-ID: $CORRELATION_ID"
echo ""
echo "    2️⃣  Kong → API Server (upstream)"
echo "        • Forwards request with correlation ID"
echo "        • API server logs with same ID"
echo ""
echo "    3️⃣  API Server → Kafka Consumer"
echo "        • Reads from Kafka topics"
echo "        • Processes data"
echo "        • Logs with correlation ID"
echo ""
echo "    4️⃣  API Server → Client (response)"
echo "        • Returns data"
echo "        • Includes correlation ID in response metadata"
echo ""
echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║                        Key Benefits                                  ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""
echo "  ✅ End-to-end traceability"
echo "  ✅ Debugging: grep $CORRELATION_ID across all logs"
echo "  ✅ Performance analysis: track latency at each hop"
echo "  ✅ Customer support: \"Give me your correlation ID\""
echo "  ✅ Compliance: audit trail for data access"
echo ""
echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║                        Production Usage                              ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""
echo "  In production, you can:"
echo ""
echo "  1. Search logs across all services:"
echo "     kubectl logs -l app=gridpulse | grep $CORRELATION_ID"
echo ""
echo "  2. Query distributed tracing (e.g., Jaeger):"
echo "     https://jaeger.example.com/trace/$CORRELATION_ID"
echo ""
echo "  3. Debug customer issues:"
echo "     Customer: \"My request failed\""
echo "     You: \"What's your correlation ID?\""
echo "     Customer: \"$CORRELATION_ID\""
echo "     You: *searches logs* \"Found it! Issue was in step 3...\""
echo ""

# Cleanup
rm -f "$RESPONSE_FILE" "$HEADERS_FILE"

echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║                        Demo Complete                                 ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""
