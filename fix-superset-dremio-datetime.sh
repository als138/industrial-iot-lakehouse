#!/bin/bash

echo "🔧 Fixing Superset-Dremio datetime64[ms] error..."
echo "================================================"

# Stop all containers
echo "🛑 Stopping all containers..."
docker-compose down

# Remove the superset volume to ensure clean installation
echo "🧹 Removing Superset volume for clean installation..."
docker volume rm industrial-iot-lakehouse_superset_data 2>/dev/null || true

# Start containers
echo "🚀 Starting containers with updated configuration..."
docker-compose up -d

# Wait for services to be ready
echo "⏳ Waiting for services to initialize..."
sleep 30

# Check if Superset is running
echo "🔍 Checking Superset status..."
if docker-compose ps superset | grep -q "Up"; then
    echo "✅ Superset is running"
else
    echo "❌ Superset is not running. Check logs with: docker-compose logs superset"
    exit 1
fi

# Check if Dremio is running
echo "🔍 Checking Dremio status..."
if docker-compose ps dremio | grep -q "Up"; then
    echo "✅ Dremio is running"
else
    echo "❌ Dremio is not running. Check logs with: docker-compose logs dremio"
    exit 1
fi

echo ""
echo "🎉 Setup complete! The datetime64[ms] error should now be resolved."
echo ""
echo "📋 Next steps:"
echo "1. Access Superset at: http://localhost:8088"
echo "   - Username: admin"
echo "   - Password: admin"
echo ""
echo "2. Access Dremio at: http://localhost:9047"
echo ""
echo "3. In Superset, add a new database connection:"
echo "   - Database: dremio"
echo "   - SQLAlchemy URI: dremio://dremio:32010"
echo ""
echo "4. Test with tables containing timestamp fields"
echo ""
echo "🔍 To check logs:"
echo "   docker-compose logs -f superset"
echo "   docker-compose logs -f dremio" 