#!/usr/bin/env bash
echo "🔧 Setting up Iceberg + Nessie + AWS dependencies..."

# — MinIO (same as before) —

# Step 2: download jars via curl
echo "📚 Downloading required JARs into Spark master container..."
docker exec spark-master bash -c "
  cd /opt/bitnami/spark/jars/ &&
  echo '⬇️ Iceberg Spark Runtime 3.5' &&
  curl -sSL -o iceberg-spark-runtime-3.5_2.12-1.4.3.jar \
    https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-spark-runtime-3.5_2.12/1.4.3/iceberg-spark-runtime-3.5_2.12-1.4.3.jar &&
  echo '⬇️ Iceberg AWS Bundle' &&
  curl -sSL -o iceberg-aws-bundle-1.4.3.jar \
    https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-aws-bundle/1.4.3/iceberg-aws-bundle-1.4.3.jar &&
  echo '⬇️ Hadoop AWS Connector' &&
  curl -sSL -o hadoop-aws-3.3.4.jar \
    https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/3.3.4/hadoop-aws-3.3.4.jar &&
  echo '✅ All required JARs downloaded!'
"

# Step 3: Python libs
echo "🐍 Installing Python libraries..."
docker exec spark-master pip3 install pyiceberg boto3

echo "🎉 Setup complete!"
