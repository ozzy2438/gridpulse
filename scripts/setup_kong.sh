#!/bin/bash
# Kong API Gateway Yapılandırma Script'i
# Bu script Kong'u Admin API üzerinden yapılandırır

echo "=========================================="
echo "GridPulse - Kong API Gateway Setup"
echo "=========================================="

KONG_ADMIN="http://localhost:8101"

# Kong'un hazır olmasını bekle
echo "Waiting for Kong to be ready..."
until curl -s "$KONG_ADMIN/status" > /dev/null 2>&1; do
    sleep 2
done
echo "Kong is ready!"

# ========================================
# 1. MARKET DISPATCH SERVİSİ
# ========================================
echo ""
echo "Creating market-dispatch-service..."

curl -s -X POST "$KONG_ADMIN/services" \
  --data name=market-dispatch-service \
  --data url=http://host.docker.internal:5001/api/v1/dispatch \
  > /dev/null

curl -s -X POST "$KONG_ADMIN/services/market-dispatch-service/routes" \
  --data name=market-dispatch-route \
  --data "paths[]=/v1/market/dispatch" \
  --data "methods[]=GET" \
  --data "methods[]=POST" \
  > /dev/null

echo "  ✅ market-dispatch-service created"

# ========================================
# 2. WEATHER OBSERVATIONS SERVİSİ
# ========================================
echo ""
echo "Creating weather-service..."

curl -s -X POST "$KONG_ADMIN/services" \
  --data name=weather-service \
  --data url=http://host.docker.internal:5001/api/v1/weather \
  > /dev/null

curl -s -X POST "$KONG_ADMIN/services/weather-service/routes" \
  --data name=weather-route \
  --data "paths[]=/v1/weather/observations" \
  --data "methods[]=GET" \
  > /dev/null

echo "  ✅ weather-service created"

# ========================================
# 3. RATE LIMITING PLUGIN
# ========================================
echo ""
echo "Adding rate limiting plugins..."

curl -s -X POST "$KONG_ADMIN/services/market-dispatch-service/plugins" \
  --data name=rate-limiting \
  --data config.minute=100 \
  --data config.policy=local \
  > /dev/null

curl -s -X POST "$KONG_ADMIN/services/weather-service/plugins" \
  --data name=rate-limiting \
  --data config.minute=60 \
  --data config.policy=local \
  > /dev/null

echo "  ✅ Rate limiting configured"

# ========================================
# 4. API KEY AUTHENTICATION
# ========================================
echo ""
echo "Adding API key authentication..."

curl -s -X POST "$KONG_ADMIN/services/market-dispatch-service/plugins" \
  --data name=key-auth \
  --data config.key_names=apikey \
  > /dev/null

curl -s -X POST "$KONG_ADMIN/services/weather-service/plugins" \
  --data name=key-auth \
  --data config.key_names=apikey \
  > /dev/null

echo "  ✅ API key authentication configured"

# ========================================
# 5. CONSUMERS VE API KEYS
# ========================================
echo ""
echo "Creating consumers and API keys..."

# Analytics Team
curl -s -X POST "$KONG_ADMIN/consumers" \
  --data username=market-analytics-team \
  > /dev/null

curl -s -X POST "$KONG_ADMIN/consumers/market-analytics-team/key-auth" \
  --data key=analytics-team-secret-key-2024 \
  > /dev/null

# Operations Team
curl -s -X POST "$KONG_ADMIN/consumers" \
  --data username=operations-team \
  > /dev/null

curl -s -X POST "$KONG_ADMIN/consumers/operations-team/key-auth" \
  --data key=ops-team-secret-key-2024 \
  > /dev/null

# Risk Team
curl -s -X POST "$KONG_ADMIN/consumers" \
  --data username=risk-team \
  > /dev/null

curl -s -X POST "$KONG_ADMIN/consumers/risk-team/key-auth" \
  --data key=risk-team-secret-key-2024 \
  > /dev/null

echo "  ✅ Consumers created"

# ========================================
# 6. CORRELATION ID PLUGIN (Global)
# ========================================
echo ""
echo "Adding correlation ID plugin..."

curl -s -X POST "$KONG_ADMIN/plugins" \
  --data name=correlation-id \
  --data config.header_name=X-Correlation-ID \
  --data config.generator=uuid \
  > /dev/null

echo "  ✅ Correlation ID plugin added"

# ========================================
# SONUÇ
# ========================================
echo ""
echo "=========================================="
echo "Kong Configuration Summary"
echo "=========================================="
echo ""
echo "Services:"
curl -s "$KONG_ADMIN/services" | python3 -c "import sys,json; data=json.load(sys.stdin); print('\n'.join(['  - ' + s['name'] for s in data.get('data', [])]))"
echo ""
echo "Consumers:"
curl -s "$KONG_ADMIN/consumers" | python3 -c "import sys,json; data=json.load(sys.stdin); print('\n'.join(['  - ' + c['username'] for c in data.get('data', [])]))"
echo ""
echo "API Keys:"
echo "  - analytics-team-secret-key-2024 (market-analytics-team)"
echo "  - ops-team-secret-key-2024 (operations-team)"
echo "  - risk-team-secret-key-2024 (risk-team)"
echo ""
echo "=========================================="
echo "Test Commands:"
echo "=========================================="
echo ""
echo "# Without API key (should fail):"
echo "curl http://localhost:8100/v1/market/dispatch"
echo ""
echo "# With API key (should succeed):"
echo 'curl -H "apikey: analytics-team-secret-key-2024" http://localhost:8100/v1/market/dispatch'
echo ""
echo "✅ Kong setup completed!"
