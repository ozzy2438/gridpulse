#!/bin/bash
# Demo 3: Check Consumer Lag
# This script checks Kafka consumer lag

set -e

echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║                    Demo 3: Consumer Lag Check                        ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""

# Get all consumer groups
GROUPS=$(docker exec gridpulse-kafka kafka-consumer-groups \
    --bootstrap-server localhost:9092 \
    --list 2>/dev/null | grep -v "^$")

if [ -z "$GROUPS" ]; then
    echo "⚠️  No consumer groups found"
    exit 0
fi

echo "📊 Consumer Groups:"
echo "$GROUPS" | sed 's/^/  • /'
echo ""

# Check each group
for GROUP in $GROUPS; do
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Consumer Group: $GROUP"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Get lag info
    LAG_OUTPUT=$(docker exec gridpulse-kafka kafka-consumer-groups \
        --bootstrap-server localhost:9092 \
        --group "$GROUP" \
        --describe 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        echo "$LAG_OUTPUT" | head -1  # Header
        echo "$LAG_OUTPUT" | tail -n +2 | while IFS= read -r line; do
            if [ ! -z "$line" ]; then
                # Extract key fields
                TOPIC=$(echo "$line" | awk '{print $1}')
                PARTITION=$(echo "$line" | awk '{print $2}')
                CURRENT_OFFSET=$(echo "$line" | awk '{print $3}')
                LOG_END_OFFSET=$(echo "$line" | awk '{print $4}')
                LAG=$(echo "$line" | awk '{print $5}')
                
                # Color code lag
                if [ "$LAG" = "0" ] || [ "$LAG" = "-" ]; then
                    STATUS="✅"
                    COLOR="\033[0;32m"  # Green
                elif [ ! -z "$LAG" ] && [ "$LAG" -lt 100 ]; then
                    STATUS="⚠️ "
                    COLOR="\033[0;33m"  # Yellow
                else
                    STATUS="🔴"
                    COLOR="\033[0;31m"  # Red
                fi
                
                RESET="\033[0m"
                echo -e "${COLOR}${STATUS} ${line}${RESET}"
            fi
        done
    else
        echo "  No data available (consumer may not be active)"
    fi
    
    echo ""
done

echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║                        Lag Interpretation                            ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""
echo "  LAG = LOG-END-OFFSET - CURRENT-OFFSET"
echo ""
echo "  ✅ LAG = 0        → Consumer is caught up (healthy)"
echo "  ⚠️  LAG < 100     → Consumer is slightly behind (monitor)"
echo "  🔴 LAG >= 100    → Consumer is lagging (action needed)"
echo "  -  LAG = -       → Consumer hasn't started yet"
echo ""
echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║                        Troubleshooting                               ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""
echo "If lag is high:"
echo "  1. Check if consumer is running"
echo "  2. Check consumer logs for errors"
echo "  3. Increase consumer parallelism (more instances)"
echo "  4. Check if consumer processing is slow"
echo ""
echo "View in Grafana:"
echo "  http://localhost:3001/d/gridpulse-consumer-lag"
echo ""
