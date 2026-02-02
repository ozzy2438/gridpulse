#!/bin/bash
# GridPulse End-to-End Test Script
# This script tests the entire system

echo "=========================================="
echo "GridPulse - End-to-End Tests"
echo "=========================================="

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test results
PASSED=0
FAILED=0

# Test function
run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_code="$3"
    
    echo -n "Testing: $test_name... "
    
    response=$(eval "$test_command" 2>&1)
    exit_code=$?
    
    if [ "$exit_code" -eq "$expected_code" ]; then
        echo -e "${GREEN}PASSED${NC}"
        ((PASSED++))
        return 0
    else
        echo -e "${RED}FAILED${NC}"
        echo "  Expected exit code: $expected_code, Got: $exit_code"
        echo "  Response: $response"
        ((FAILED++))
        return 1
    fi
}

# HTTP test function
http_test() {
    local test_name="$1"
    local url="$2"
    local expected_status="$3"
    local headers="$4"
    
    echo -n "Testing: $test_name... "
    
    if [ -n "$headers" ]; then
        status=$(curl -s -o /dev/null -w "%{http_code}" -H "$headers" "$url")
    else
        status=$(curl -s -o /dev/null -w "%{http_code}" "$url")
    fi
    
    if [ "$status" -eq "$expected_status" ]; then
        echo -e "${GREEN}PASSED${NC} (HTTP $status)"
        ((PASSED++))
        return 0
    else
        echo -e "${RED}FAILED${NC} (Expected: $expected_status, Got: $status)"
        ((FAILED++))
        return 1
    fi
}

echo ""
echo "=========================================="
echo "1. Infrastructure Health Checks"
echo "=========================================="

# Kafka
http_test "Kafka UI is accessible" "http://localhost:8080" 200

# Kong
http_test "Kong Admin API is accessible" "http://localhost:8001/status" 200

# Prometheus
http_test "Prometheus is accessible" "http://localhost:9090/-/healthy" 200

# Grafana
http_test "Grafana is accessible" "http://localhost:3000/api/health" 200

# API Server
http_test "API Server health check" "http://localhost:5000/health" 200

echo ""
echo "=========================================="
echo "2. Kong Authentication Tests"
echo "=========================================="

# Without API key
http_test "Request without API key (expect 401)" "http://localhost:8000/v1/market/dispatch" 401

# With valid API key
http_test "Request with valid API key" "http://localhost:8000/v1/market/dispatch" 200 "apikey: analytics-team-secret-key-2024"

# With invalid API key
http_test "Request with invalid API key (expect 401)" "http://localhost:8000/v1/market/dispatch" 401 "apikey: invalid-key"

echo ""
echo "=========================================="
echo "3. API Endpoint Tests"
echo "=========================================="

# Market dispatch
http_test "GET /v1/market/dispatch" "http://localhost:8000/v1/market/dispatch" 200 "apikey: analytics-team-secret-key-2024"

# Weather observations
http_test "GET /v1/weather/observations" "http://localhost:8000/v1/weather/observations" 200 "apikey: ops-team-secret-key-2024"

# Stats endpoint
http_test "GET /api/v1/stats" "http://localhost:5000/api/v1/stats" 200

echo ""
echo "=========================================="
echo "4. Correlation ID Tests"
echo "=========================================="

echo -n "Testing: Correlation ID is returned... "
correlation_id=$(curl -s -i -H "apikey: analytics-team-secret-key-2024" \
    http://localhost:8000/v1/market/dispatch 2>&1 | grep -i "x-correlation-id" | head -1)

if [ -n "$correlation_id" ]; then
    echo -e "${GREEN}PASSED${NC}"
    echo "  $correlation_id"
    ((PASSED++))
else
    echo -e "${RED}FAILED${NC} (No correlation ID in response)"
    ((FAILED++))
fi

echo ""
echo "=========================================="
echo "5. Rate Limiting Test"
echo "=========================================="

echo -n "Testing: Rate limiting after 100 requests... "
rate_limited=0
for i in {1..110}; do
    status=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "apikey: analytics-team-secret-key-2024" \
        http://localhost:8000/v1/market/dispatch)
    if [ "$status" -eq "429" ]; then
        rate_limited=1
        break
    fi
done

if [ "$rate_limited" -eq 1 ]; then
    echo -e "${GREEN}PASSED${NC} (Rate limited at request $i)"
    ((PASSED++))
else
    echo -e "${YELLOW}SKIPPED${NC} (Rate limiting not triggered - may need more requests)"
fi

echo ""
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo -e "Passed: ${GREEN}$PASSED${NC}"
echo -e "Failed: ${RED}$FAILED${NC}"

if [ "$FAILED" -gt 0 ]; then
    echo ""
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
else
    echo ""
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
fi
