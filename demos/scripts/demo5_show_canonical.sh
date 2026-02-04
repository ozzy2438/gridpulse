#!/bin/bash
# Demo 5: Show Canonical Model
# Demonstrates centralized canonical data model

set -e

echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║            Demo 5: NEW Approach - Canonical Data Model               ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""

# Fetch real data from our pipeline
echo "📊 Fetching data from GridPulse centralized pipeline..."
echo ""

RESPONSE=$(curl -s http://localhost:5001/api/v1/stats)

if [ $? -ne 0 ]; then
    echo "❌ Failed to fetch data. Is API server running?"
    exit 1
fi

echo "✅ Data retrieved from canonical source"
echo ""
echo "Canonical Model (from Kafka):"
echo "$RESPONSE" | python3 -m json.tool

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Canonical Model Characteristics:"
echo "  ✅ Single schema (XSD defined in webmethods/models/)"
echo "  ✅ Consistent field naming (snake_case)"
echo "  ✅ Standard units (Celsius, km/h, MW)"
echo "  ✅ ISO8601 timestamps"
echo "  ✅ Event ID (idempotency)"
echo "  ✅ Correlation ID (traceability)"
echo "  ✅ Source field (data lineage)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Show schema
echo "📋 Schema Definition:"
if [ -f "webmethods/models/WeatherObservation.xsd" ]; then
    echo ""
    cat webmethods/models/WeatherObservation.xsd | head -30
    echo ""
    echo "   ... (full schema in webmethods/models/WeatherObservation.xsd)"
else
    echo "   (Schema file: webmethods/models/WeatherObservation.xsd)"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
