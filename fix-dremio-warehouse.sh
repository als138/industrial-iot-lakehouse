#!/bin/bash

echo "🔧 Fixing Dremio warehouse folder issue..."
echo "=========================================="

# Check if Docker containers are running
echo "📋 Checking container status..."
if ! docker ps | grep -q "minio"; then
    echo "❌ MinIO container is not running. Starting containers..."
    docker-compose up -d
    sleep 10
fi

# Install MinIO client if not available
if ! command -v mc &> /dev/null; then
    echo "📦 Installing MinIO Client..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        brew install minio/stable/mc
    else
        # Linux
        wget https://dl.min.io/client/mc/release/linux-amd64/mc
        chmod +x mc
        sudo mv mc /usr/local/bin/
    fi
fi

# Configure MinIO client
echo "🔗 Configuring MinIO client..."
mc alias set myminio http://localhost:9000 minioadmin minioadmin

# Create the warehouse folder structure
echo "📁 Creating warehouse folder structure..."
mc mb myminio/warehouse 2>/dev/null || echo "warehouse bucket already exists"
mc mb myminio/warehouse/folder 2>/dev/null || echo "folder already exists"
mc mb myminio/warehouse/folder/iot_data 2>/dev/null || echo "iot_data folder already exists"

# Set proper permissions
echo "🔐 Setting permissions..."
mc policy set public myminio/warehouse
mc policy set public myminio/warehouse/folder
mc policy set public myminio/warehouse/folder/iot_data

# List the created structure
echo "📋 Current MinIO structure:"
mc ls myminio/warehouse/folder/

echo ""
echo "✅ MinIO folder structure created successfully!"
echo ""

# Restart Dremio to pick up the new folder structure
echo "🔄 Restarting Dremio container..."
docker-compose restart dremio

echo ""
echo "🎯 Setup complete! Here's what to do next:"
echo ""
echo "1. Wait for Dremio to start (check with: docker-compose logs dremio)"
echo "2. Access Dremio UI at: http://localhost:9047"
echo "3. Add MinIO as a source in Dremio with these settings:"
echo "   - Source Type: S3"
echo "   - Access Key: minioadmin"
echo "   - Secret Key: minioadmin"
echo "   - Endpoint: http://minio:9000"
echo "   - Path: /warehouse/folder"
echo ""
echo "4. The data should now be accessible at: /warehouse/folder/iot_data"
echo ""
echo "🔍 To verify the setup, run: mc ls myminio/warehouse/folder/iot_data" 