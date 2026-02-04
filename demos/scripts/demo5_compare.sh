#!/bin/bash
# Demo 5: Compare Old vs New Approach
# Side-by-side comparison

set -e

echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║         Demo 5: Comparing Decentralized vs Centralized               ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""

# Run old approach
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔴 OLD APPROACH: Decentralized Pipelines"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

./demos/scripts/demo5_old_approach_teamA.sh
echo ""
./demos/scripts/demo5_old_approach_teamB.sh

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🟢 NEW APPROACH: Centralized Canonical Model"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

./demos/scripts/demo5_show_canonical.sh

echo ""
echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║                        Problem Analysis                              ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""

# Compare outputs
echo "Comparing Team A vs Team B outputs:"
echo ""
echo "┌─────────────────────┬─────────────────────┬─────────────────────┐"
echo "│ Aspect              │ Team A              │ Team B              │"
echo "├─────────────────────┼─────────────────────┼─────────────────────┤"
echo "│ Region field        │ region_id           │ region              │"
echo "│ Temperature field   │ temperature_celsius │ temp_c, temp_f      │"
echo "│ Wind field          │ wind_speed_kmh      │ wind_kmh            │"
echo "│ Humidity format     │ 37 (%)              │ 0.37 (decimal)      │"
echo "│ Timestamp format    │ ISO8601             │ Unix epoch          │"
echo "│ Source field        │ source_api          │ api                 │"
echo "└─────────────────────┴─────────────────────┴─────────────────────┘"
echo ""

echo "❌ Problems with Old Approach:"
echo "  1. Inconsistent field names → Integration hell"
echo "  2. Different units → Conversion bugs"
echo "  3. Different timestamps → Sorting issues"
echo "  4. No schema contract → Breaking changes undetected"
echo "  5. Duplicate API calls → 2x cost"
echo "  6. Different transformations → Different results!"
echo "  7. No single source of truth → \"Which pipeline is correct?\""
echo "  8. Hard to onboard new teams → \"Which format should I use?\""
echo ""

echo "✅ Benefits of New Approach:"
echo "  1. Single canonical schema → One source of truth"
echo "  2. Consistent field names → Easy integration"
echo "  3. Standard units → No conversion needed"
echo "  4. XSD contract → Breaking changes prevented"
echo "  5. Single API call → 50% cost reduction"
echo "  6. Same transformation → Same results always"
echo "  7. Clear data lineage → Auditable"
echo "  8. Fast onboarding → Schema is the documentation"
echo ""

echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║                        Business Impact                               ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""

echo "📊 Quantifiable Benefits:"
echo ""
echo "  Cost Reduction:"
echo "    • API calls: 2 teams × 5 cities × 1440 calls/day = 14,400 calls/day"
echo "    • With centralized: 5 cities × 1440 calls/day = 7,200 calls/day"
echo "    • Savings: 50% = 7,200 fewer API calls daily"
echo ""
echo "  Time Savings:"
echo "    • Old: New consumer needs to understand 2+ different formats"
echo "    • Old: Integration time = 2-3 weeks per consumer"
echo "    • New: Single canonical schema, integration time = <5 minutes"
echo "    • Savings: 99% time reduction"
echo ""
echo "  Quality Improvement:"
echo "    • Old: Data inconsistency bugs = High"
echo "    • New: Schema validation = Zero tolerance for inconsistency"
echo "    • Result: Better data quality, fewer production bugs"
echo ""
echo "  Governance:"
echo "    • Old: No visibility into who uses what"
echo "    • New: Kafka metrics show all consumers"
echo "    • Result: Better compliance and audit trail"
echo ""

echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║                        Demo Complete                                 ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""
echo "Key Takeaway:"
echo "  Centralized ingestion with canonical model isn't just about"
echo "  technology - it's about reducing cost, increasing quality,"
echo "  and enabling faster business outcomes."
echo ""
