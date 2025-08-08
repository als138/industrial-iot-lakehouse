#!/bin/bash

echo "🔧 Setting up Nessie with proper version compatibility..."

# Step 1: Update Nessie container version
echo "📦 Updating Nessie container..."
docker stop nessie 2>/dev/null  true
docker rm nessie 2>/dev/null  true

# Update docker-compose.yml
sed -i '' 's/projectnessie\/nessie:0.67.0/projectnessie\/nessie:0.74.0/' docker-compose.yml

# Restart Nessie
docker-compose up -d nessie
sleep 30

# Step 2: Setup MinIO
echo "📦 Setting up MinIO..."
docker exec minio sh -c "
  curl -s -o /usr/local/bin/mc https://dl.min.io/client/mc/release/linux-amd64/mc && 
  chmod +x /usr/local/bin/mc &&
  mc alias set local http://localhost:9000 minioadmin minioadmin &&
  mc mb local/warehouse --ignore-existing &&
  mc policy set public local/warehouse
" 2>/dev/null

# Step 3: Remove old incompatible JARs
echo "🧹 Cleaning old JARs..."
docker exec spark-master rm -f /opt/bitnami/spark/jars/nessie-* 2>/dev/null || true

# Step 4: Test Nessie connectivity
echo "🔍 Testing Nessie connectivity..."
until curl -f http://localhost:19120/api/v1/trees > /dev/null 2>&1; do
    echo "Waiting for Nessie..."
    sleep 5
done

echo "✅ Nessie is ready!"

# Step 5: Verify setup
echo "🔍 Verifying setup..."
echo "Nessie API: $(curl -s http://localhost:19120/api/v1/trees | head -1)"
echo "MinIO: $(curl -s http://localhost:9000/minio/health/ready)"

echo "�� Nessie setup complete!"
echo ""
echo "🚀 Now run the streaming processor with packages:"
echo "docker exec -it spark-master spark-submit \\"
echo "  --packages org.apache.spark:spark-sql-kafka-0-10_2.12:3.4.1,org.apache.iceberg:iceberg-spark-runtime-3.4_2.12:1.4.2,org.projectnessie.nessie-integrations:nessie-spark-extensions-3.4_2.12:0.74.0 \\"
echo "  --conf spark.sql.extensions=org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions,org.projectnessie.spark.extensions.NessieSparkSessionExtensions \\"
echo "  --conf spark.sql.catalog.nessie=org.apache.iceberg.spark.SparkCatalog \\"
echo "  --conf spark.sql.catalog.nessie.catalog-impl=org.apache.iceberg.nessie.NessieCatalog \\"
echo "  --conf spark.sql.catalog.nessie.uri=http://nessie:19120/api/v1 \\"
echo "  --conf spark.sql.catalog.nessie.ref=main \\"
echo "  --conf spark.sql.catalog.nessie.warehouse=s3a://warehouse/ \\"
echo "  --conf spark.hadoop.fs.s3a.endpoint=http://minio:9000 \\"
echo "  --conf spark.hadoop.fs.s3a.access.key=minioadmin \\"
echo "  --conf spark.hadoop.fs.s3a.secret.key=minioadmin \\"
echo "  --conf spark.hadoop.fs.s3a.path.style.access=true \\"
echo "  --conf spark.hadoop.fs.s3a.impl=org.apache.hadoop.fs.s3a.S3AFileSystem \\"
echo "  /opt/spark/work-dir/iceberg-streaming-processor.py"

