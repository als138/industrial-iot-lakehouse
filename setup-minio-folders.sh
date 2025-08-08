#!/bin/bash

# Setup MinIO folders for Dremio
echo "Setting up MinIO folder structure for Dremio..."

# Install mc (MinIO Client) if not available
if ! command -v mc &> /dev/null; then
    echo "Installing MinIO Client..."
    wget https://dl.min.io/client/mc/release/linux-amd64/mc
    chmod +x mc
    sudo mv mc /usr/local/bin/
fi

# Configure MinIO client
mc alias set myminio http://localhost:9000 minioadmin minioadmin

# Create the warehouse folder structure
echo "Creating warehouse folder structure..."
mc mb myminio/warehouse
mc mb myminio/warehouse/folder
mc mb myminio/warehouse/folder/iot_data

# Set proper permissions
mc policy set public myminio/warehouse
mc policy set public myminio/warehouse/folder
mc policy set public myminio/warehouse/folder/iot_data

echo "✅ MinIO folder structure created successfully!"
echo "📁 Created folders:"
echo "   - warehouse"
echo "   - warehouse/folder"
echo "   - warehouse/folder/iot_data"

echo ""
echo "🔧 Next steps:"
echo "1. Restart Dremio container: docker-compose restart dremio"
echo "2. Access Dremio UI at http://localhost:9047"
echo "3. Add MinIO as a source in Dremio with these settings:"
echo "   - Source Type: S3"
echo "   - Access Key: minioadmin"
echo "   - Secret Key: minioadmin"
echo "   - Endpoint: http://minio:9000"
echo "   - Path: /warehouse" 