#!/bin/bash
# Export all Grafana dashboards as PNG images
# Usage: ./demos/scripts/export_dashboards.sh [output_dir]

set -e

OUTPUT_DIR="${1:-demos/exports}"
GRAFANA_URL="http://localhost:3001"
WIDTH="${WIDTH:-1920}"
HEIGHT="${HEIGHT:-1080}"
TIMEOUT="${TIMEOUT:-60}"

mkdir -p "$OUTPUT_DIR"

echo "Exporting GridPulse Dashboards to $OUTPUT_DIR"
echo "Resolution: ${WIDTH}x${HEIGHT}"
echo ""

DASHBOARDS=(
    "gridpulse-consumer-lag:consumer-lag"
    "gridpulse-rate-limiting:rate-limiting"
    "gridpulse-dlq-metrics:dlq-metrics"
    "gridpulse-e2e-latency:e2e-latency"
)

for dashboard in "${DASHBOARDS[@]}"; do
    uid="${dashboard%%:*}"
    name="${dashboard##*:}"
    filename="${name}-dashboard.png"

    echo -n "Exporting $name... "

    curl -s "${GRAFANA_URL}/render/d/${uid}?width=${WIDTH}&height=${HEIGHT}&timeout=${TIMEOUT}" \
        -o "${OUTPUT_DIR}/${filename}"

    if file "${OUTPUT_DIR}/${filename}" | grep -q "PNG image"; then
        size=$(ls -lh "${OUTPUT_DIR}/${filename}" | awk '{print $5}')
        echo "OK ($size)"
    else
        echo "FAILED"
    fi
done

echo ""
echo "Export complete! Files saved to: $OUTPUT_DIR"
ls -la "$OUTPUT_DIR"/*.png 2>/dev/null || echo "No PNG files found"
