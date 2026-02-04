#!/bin/bash
# Demo 5: Old Approach - Team B
# Simulates decentralized data pipeline (Team B's version)

set -e

OUTPUT_FILE="/tmp/teamB_output.json"

echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║              Demo 5: OLD Approach - Team B Pipeline                  ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""
echo "Simulating Team B's custom data pipeline..."
echo ""

# Simulate Team B's approach (different field names, different units)
cat > "$OUTPUT_FILE" << 'EOF'
{
  "region": "NSW1",
  "temp_c": 28.2,
  "temp_f": 82.76,
  "wind_kmh": 10.0,
  "humidity_pct": 0.37,
  "ts": 1706976600,
  "api": "openmeteo",
  "pipeline": "teamb_weather",
  "version": "2.1",
  "notes": "Team B uses camelCase, includes Fahrenheit, and Unix timestamp"
}
EOF

echo "✅ Team B pipeline executed"
echo "   Output: $OUTPUT_FILE"
echo ""
echo "Team B's data model:"
cat "$OUTPUT_FILE" | python3 -m json.tool

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Team B Characteristics:"
echo "  • Field naming: abbreviated (temp_c, temp_f)"
echo "  • Timestamp format: Unix epoch"
echo "  • Multiple units: Both Celsius and Fahrenheit"
echo "  • Humidity as decimal (0.37) not percentage (37%)"
echo "  • Documentation: Confluence page"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
