#!/bin/bash
# Demo 5: Old Approach - Team A
# Simulates decentralized data pipeline (Team A's version)

set -e

OUTPUT_FILE="/tmp/teamA_output.json"

echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║              Demo 5: OLD Approach - Team A Pipeline                  ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""
echo "Simulating Team A's custom data pipeline..."
echo ""

# Simulate Team A's approach (different field names, different transformations)
cat > "$OUTPUT_FILE" << 'EOF'
{
  "region_id": "NSW1",
  "temperature_celsius": 28.2,
  "wind_speed_kmh": 10.0,
  "humidity": 37,
  "timestamp": "2026-02-04T13:30:00.000000",
  "source_api": "open-meteo",
  "ingestion_pipeline": "team-a-weather-v1",
  "data_format": "teamA_custom",
  "notes": "Team A uses snake_case and full field names"
}
EOF

echo "✅ Team A pipeline executed"
echo "   Output: $OUTPUT_FILE"
echo ""
echo "Team A's data model:"
cat "$OUTPUT_FILE" | python3 -m json.tool

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Team A Characteristics:"
echo "  • Field naming: snake_case (temperature_celsius)"
echo "  • Timestamp format: ISO8601 with microseconds"
echo "  • Custom metadata: ingestion_pipeline, data_format"
echo "  • Documentation: README in team-a-repo"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
