#!/bin/bash
# Setup Grafana Dashboards
# This script imports all demo dashboards into Grafana

set -e

GRAFANA_URL="http://localhost:3001"
GRAFANA_USER="admin"
GRAFANA_PASS="admin"
DASHBOARDS_DIR="demos/grafana"

echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║                   GridPulse - Grafana Setup                          ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""

# Check if Grafana is running
echo "🔍 Checking Grafana availability..."
if ! curl -s "$GRAFANA_URL/api/health" > /dev/null; then
    echo "❌ Grafana is not accessible at $GRAFANA_URL"
    echo ""
    echo "Please ensure Grafana is running:"
    echo "  docker compose up -d grafana"
    exit 1
fi

echo "✅ Grafana is accessible"
echo ""

# Function to import dashboard
import_dashboard() {
    local dashboard_file=$1
    local dashboard_name=$(basename "$dashboard_file" .json)

    echo "📊 Importing: $dashboard_name"

    # Read dashboard JSON - it already contains "dashboard" wrapper
    local file_json=$(cat "$dashboard_file")

    # Extract inner dashboard and add import metadata
    # The JSON file format: { "dashboard": { ... } }
    # We need to add overwrite and folderUid to the root level
    local payload
    payload=$(echo "$file_json" | jq '. + {"overwrite": true, "folderUid": "gridpulse"}')
    
    # Import dashboard
    response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -u "$GRAFANA_USER:$GRAFANA_PASS" \
        -d "$payload" \
        "$GRAFANA_URL/api/dashboards/db")
    
    if echo "$response" | grep -q '"status":"success"'; then
        local dashboard_url=$(echo "$response" | grep -o '"url":"[^"]*"' | cut -d'"' -f4)
        echo "   ✅ Imported: $GRAFANA_URL$dashboard_url"
    else
        echo "   ⚠️  Import failed (may already exist)"
        echo "   Response: $response"
    fi
    
    echo ""
}

# Create GridPulse folder
echo "📁 Creating GridPulse folder..."
curl -s -X POST \
    -H "Content-Type: application/json" \
    -u "$GRAFANA_USER:$GRAFANA_PASS" \
    -d '{"uid":"gridpulse","title":"GridPulse"}' \
    "$GRAFANA_URL/api/folders" > /dev/null 2>&1 || true

echo ""

# Import all dashboards
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Importing Dashboards"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ -d "$DASHBOARDS_DIR" ]; then
    for dashboard in "$DASHBOARDS_DIR"/*.json; do
        if [ -f "$dashboard" ]; then
            import_dashboard "$dashboard"
        fi
    done
else
    echo "❌ Dashboards directory not found: $DASHBOARDS_DIR"
    exit 1
fi

echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║                        Setup Complete                                ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""
echo "📊 Dashboards imported:"
echo "  • Rate Limiting:    $GRAFANA_URL/d/gridpulse-rate-limiting"
echo "  • Consumer Lag:     $GRAFANA_URL/d/gridpulse-consumer-lag"
echo "  • DLQ & Resilience: $GRAFANA_URL/d/gridpulse-dlq-metrics"
echo "  • E2E Latency:      $GRAFANA_URL/d/gridpulse-e2e-latency"
echo ""
echo "🔑 Login credentials:"
echo "  Username: $GRAFANA_USER"
echo "  Password: $GRAFANA_PASS"
echo ""
echo "💡 Note: Some metrics may not appear until data is flowing through the system."
echo "   Run the demo scripts to generate traffic and populate the dashboards."
echo ""
