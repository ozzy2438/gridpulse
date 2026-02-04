#!/bin/bash

# GridPulse - Quick Start Script
# This script starts the entire system

set -e  # Exit on error

echo "========================================================================"
echo "🚀 GridPulse - Starting Energy Integration Platform"
echo "========================================================================"
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if Docker is running
echo "🐳 Checking Docker..."
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}❌ Docker is not running${NC}"
    echo ""
    echo "Please start Docker first:"
    echo "  - macOS: open -a Docker"
    echo "  - Or start Docker Desktop manually"
    echo ""
    exit 1
fi
echo -e "${GREEN}✅ Docker is running${NC}"
echo ""

# Check if services are already running
echo "🔍 Checking existing services..."
if docker compose ps | grep -q "Up"; then
    echo -e "${YELLOW}⚠️  Services are already running${NC}"
    echo ""
    docker compose ps
    echo ""
    read -p "Do you want to restart? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "🔄 Restarting services..."
        docker compose down
    else
        echo "Continuing with existing services..."
    fi
fi

# Start services
echo ""
echo "🚀 Starting services (Kafka, Zookeeper, Kong, Monitoring)..."
docker compose up -d

# Wait for services to be ready
echo ""
echo "⏳ Waiting for services to be healthy (60 seconds)..."
sleep 60

# Check service health
echo ""
echo "🏥 Service health check:"
docker compose ps

# Create Kafka topics
echo ""
echo "📋 Creating Kafka topics..."
if [ -f scripts/create_kafka_topics.sh ]; then
    chmod +x scripts/create_kafka_topics.sh
    ./scripts/create_kafka_topics.sh
else
    echo -e "${YELLOW}⚠️  Topic creation script not found - will be created on first use${NC}"
fi

# Setup Kong
echo ""
echo "🦍 Configuring Kong API Gateway..."
if [ -f scripts/setup_kong.sh ]; then
    chmod +x scripts/setup_kong.sh
    ./scripts/setup_kong.sh
else
    echo -e "${YELLOW}⚠️  Kong setup script not found - manual configuration needed${NC}"
fi

# Check if virtual environment exists
echo ""
echo "🐍 Checking Python environment..."
if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv venv
    echo -e "${GREEN}✅ Virtual environment created${NC}"
fi

# Install dependencies
echo ""
echo "📦 Installing Python dependencies..."
source venv/bin/activate
pip install -q -r requirements.txt
echo -e "${GREEN}✅ Dependencies installed${NC}"

# Test data sources
echo ""
echo "🧪 Testing data sources..."
python scripts/test_data_fetch.py

# Summary
echo ""
echo "========================================================================"
echo "✅ GridPulse is ready!"
echo "========================================================================"
echo ""
echo "📍 Access Points:"
echo "   • Kafka UI:        http://localhost:8180"
echo "   • Kong Admin:      http://localhost:8101"
echo "   • Kong Proxy:      http://localhost:8100"
echo "   • Grafana:         http://localhost:3001 (admin/admin)"
echo "   • Prometheus:      http://localhost:9090"
echo ""
echo "🔑 API Keys:"
echo "   • Analytics Team:  analytics-team-secret-key-2024"
echo "   • Operations Team: ops-team-secret-key-2024"
echo "   • Risk Team:       risk-team-secret-key-2024"
echo ""
echo "🚀 Next Steps:"
echo ""
echo "1. Start API Server:"
echo "   source venv/bin/activate"
echo "   python scripts/api_server.py"
echo ""
echo "2. Run Data Pipeline (in another terminal):"
echo "   source venv/bin/activate"
echo "   python scripts/data_pipeline.py"
echo ""
echo "3. Test API:"
echo "   curl -H \"apikey: analytics-team-secret-key-2024\" \\"
echo "        http://localhost:8100/v1/market/dispatch"
echo ""
echo "4. View Kafka messages:"
echo "   Open http://localhost:8180 and browse topics"
echo ""
echo "========================================================================"
