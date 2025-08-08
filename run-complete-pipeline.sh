
echo "🚀 Starting Complete IoT Lakehouse Pipeline..."

# Step 1: Start all services
echo "📋 Step 1: Starting infrastructure..."
docker-compose down  # Clean restart
docker-compose up -d
sleep 20  # Wait for all services

# Step 2: Setup Iceberg dependencies
echo "📋 Step 2: Setting up Iceberg..."
chmod +x setup-iceberg.sh
./setup-iceberg.sh

# Step 3: Install Python dependencies
echo "📋 Step 3: Installing Python dependencies..."
docker exec spark-master pip install kafka-python pandas pyiceberg boto3

# Step 4: Create Kafka topic
echo "📋 Step 4: Creating Kafka topic..."
docker exec kafka kafka-topics --create \
  --topic iot-sensor-data \
  --bootstrap-server localhost:9092 \
  --partitions 3 \
  --replication-factor 1 || echo "Topic already exists"

# Step 5: Instructions for running the pipeline
echo "📋 Step 5: Pipeline ready!"
echo ""
echo "🎯 Now run in separate terminals:"
echo ""
echo "Terminal 1 - Start Iceberg Streaming:"
echo "docker exec -it spark-master spark-submit \\"
echo " --packages org.apache.spark:spark-sql-kafka-0-10_2.12:3.4.1,org.apache.iceberg:iceberg-spark-runtime-3.4_2.12:1.5.0 \\"
echo " --conf spark.sql.extensions=org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions \\"
echo " --conf spark.sql.catalog.nessie=org.apache.iceberg.spark.SparkCatalog \\"
echo " --conf spark.sql.catalog.nessie.catalog-impl=org.apache.iceberg.nessie.NessieCatalog \\"
echo "  /opt/spark/work-dir/iceberg-streaming-processor.py"
echo ""
echo "Terminal 2 - Start Data Producer:"
echo "docker exec -it spark-master python /opt/spark/work-dir/data-producer.py"
echo ""
echo "🌐 Access Points:"
echo "- Spark UI: http://localhost:8080"
echo "- MinIO Console: http://localhost:9001 (minioadmin/minioadmin)"
echo "- Dremio: http://localhost:9047"
echo "- Superset: http://localhost:8088"
echo "- Nessie API: http://localhost:19120"