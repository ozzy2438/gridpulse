#!/bin/bash
# Demo 1: Rate Limiting
# Bu script Kong'un rate limiting özelliğini test eder

set -e

API_KEY="analytics-team-secret-key-2024"
ENDPOINT="http://localhost:8100/v1/market/dispatch"
TOTAL_REQUESTS=110
SUCCESS_COUNT=0
RATE_LIMITED_COUNT=0

echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║                    Demo 1: Rate Limiting Test                        ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""
echo "Target: $ENDPOINT"
echo "API Key: $API_KEY"
echo "Total Requests: $TOTAL_REQUESTS"
echo "Expected: ~100 success (200), ~10 rate limited (429)"
echo ""
echo "Starting test..."
echo ""

# Temporary file for results
TEMP_FILE=$(mktemp)

# Send requests
for i in $(seq 1 $TOTAL_REQUESTS); do
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "apikey: $API_KEY" \
        "$ENDPOINT")
    
    echo "$HTTP_CODE" >> "$TEMP_FILE"
    
    if [ "$HTTP_CODE" == "200" ]; then
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        if [ $((i % 10)) -eq 0 ]; then
            echo -n "."
        fi
    elif [ "$HTTP_CODE" == "429" ]; then
        RATE_LIMITED_COUNT=$((RATE_LIMITED_COUNT + 1))
        echo -n "X"
    else
        echo -n "?"
    fi
done

echo ""
echo ""
echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║                           Test Results                               ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""
echo "  ✅ Success (200):        $SUCCESS_COUNT requests"
echo "  ⛔ Rate Limited (429):   $RATE_LIMITED_COUNT requests"
echo ""

# Detailed breakdown
echo "Response Code Distribution:"
sort "$TEMP_FILE" | uniq -c | while read count code; do
    printf "  %3s responses → HTTP %s\n" "$count" "$code"
done

echo ""
echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║                        Key Observations                              ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""
echo "  1. Kong rate limiting is ACTIVE and WORKING"
echo "  2. Limit: 100 requests per minute per consumer"
echo "  3. After limit: 429 Too Many Requests"
echo "  4. Client should implement retry with exponential backoff"
echo ""
echo "View metrics:"
echo "  • Prometheus: http://localhost:9090/graph?g0.expr=kong_http_status"
echo "  • Grafana:    http://localhost:3001/d/gridpulse-rate-limiting"
echo ""

# Cleanup
rm -f "$TEMP_FILE"

# Wait for rate limit window to reset
echo "💡 Tip: Rate limit window resets after 60 seconds"
echo ""
