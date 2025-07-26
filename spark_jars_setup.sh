#!/bin/bash

# Spark JAR Dependencies Setup Script
# This script downloads all necessary JAR files for Spark integration
# with Kafka, Iceberg, S3, and Nessie

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
SPARK_VERSION="3.5.0"
SCALA_VERSION="2.12"
ICEBERG_VERSION="1.4.2"
KAFKA_VERSION="3.5.1"
HADOOP_VERSION="3.3.4"
NESSIE_VERSION="0.74.0"

# Create jars directory
JARS_DIR="./spark-jars"
mkdir -p "$JARS_DIR"

echo -e "${BLUE}Downloading Spark JAR dependencies...${NC}"
echo "Target directory: $JARS_DIR"

# Function to download JAR if it doesn't exist
download_jar() {
    local url="$1"
    local filename="$2"
    local filepath="$JARS_DIR/$filename"
    
    if [ -f "$filepath" ]; then
        echo -e "${GREEN}✓ $filename already exists${NC}"
    else
        echo -e "${BLUE}Downloading $filename...${NC}"
        curl -L -o "$filepath" "$url"
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ Downloaded $filename${NC}"
        else
            echo -e "${RED}✗ Failed to download $filename${NC}"
            exit 1
        fi
    fi
}

echo -e "\n${BLUE}=== ICEBERG DEPENDENCIES ===${NC}"

# Iceberg Spark Runtime
download_jar \
    "https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-spark-runtime-${SPARK_VERSION}_${SCALA_VERSION}/${ICEBERG_VERSION}/iceberg-spark-runtime-${SPARK_VERSION}_${SCALA_VERSION}-${ICEBERG_VERSION}.jar" \
    "iceberg-spark-runtime-${SPARK_VERSION}_${SCALA_VERSION}-${ICEBERG_VERSION}.jar"

# Iceberg AWS Bundle
download_jar \
    "https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-aws-bundle/${ICEBERG_VERSION}/iceberg-aws-bundle-${ICEBERG_VERSION}.jar" \
    "iceberg-aws-bundle-${ICEBERG_VERSION}.jar"

echo -e "\n${BLUE}=== KAFKA DEPENDENCIES ===${NC}"

# Kafka Spark Connector
download_jar \
    "https://repo1.maven.org/maven2/org/apache/spark/spark-sql-kafka-0-10_${SCALA_VERSION}/${SPARK_VERSION}/spark-sql-kafka-0-10_${SCALA_VERSION}-${SPARK_VERSION}.jar" \
    "spark-sql-kafka-0-10_${SCALA_VERSION}-${SPARK_VERSION}.jar"

# Kafka Clients
download_jar \
    "https://repo1.maven.org/maven2/org/apache/kafka/kafka-clients/${KAFKA_VERSION}/kafka-clients-${KAFKA_VERSION}.jar" \
    "kafka-clients-${KAFKA_VERSION}.jar"

echo -e "\n${BLUE}=== AWS S3 DEPENDENCIES ===${NC}"

# Hadoop AWS
download_jar \
    "https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/${HADOOP_VERSION}/hadoop-aws-${HADOOP_VERSION}.jar" \
    "hadoop-aws-${HADOOP_VERSION}.jar"

# AWS SDK Bundle
download_jar \
    "https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/1.12.565/aws-java-sdk-bundle-1.12.565.jar" \
    "aws-java-sdk-bundle-1.12.565.jar"

echo -e "\n${BLUE}=== NESSIE DEPENDENCIES ===${NC}"

# Nessie Spark Extensions
download_jar \
    "https://repo1.maven.org/maven2/org/projectnessie/nessie/nessie-spark-extensions-${SPARK_VERSION}_${SCALA_VERSION}/${NESSIE_VERSION}/nessie-spark-extensions-${SPARK_VERSION}_${SCALA_VERSION}-${NESSIE_VERSION}.jar" \
    "nessie-spark-extensions-${SPARK_VERSION}_${SCALA_VERSION}-${NESSIE_VERSION}.jar"

# Nessie Iceberg
download_jar \
    "https://repo1.maven.org/maven2/org/projectnessie/nessie/nessie-iceberg/${NESSIE_VERSION}/nessie-iceberg-${NESSIE_VERSION}.jar" \
    "nessie-iceberg-${NESSIE_VERSION}.jar"

echo -e "\n${BLUE}=== ADDITIONAL UTILITIES ===${NC}"

# Delta Lake (optional, for Delta format support)
download_jar \
    "https://repo1.maven.org/maven2/io/delta/delta-core_${SCALA_VERSION}/2.4.0/delta-core_${SCALA_VERSION}-2.4.0.jar" \
    "delta-core_${SCALA_VERSION}-2.4.0.jar"

# JSON processing
download_jar \
    "https://repo1.maven.org/maven2/com/fasterxml/jackson/core/jackson-databind/2.15.2/jackson-databind-2.15.2.jar" \
    "jackson-databind-2.15.2.jar"

# HTTP client for REST APIs
download_jar \
    "https://repo1.maven.org/maven2/org/apache/httpcomponents/httpclient/4.5.14/httpclient-4.5.14.jar" \
    "httpclient-4.5.14.jar"

echo -e "\n${GREEN}=== DOWNLOAD COMPLETE ===${NC}"
echo "All JAR files downloaded to: $JARS_DIR"

# Create environment script to set SPARK_JARS
cat > set_spark_env.sh << EOF
#!/bin/bash
# Set Spark environment variables for JAR dependencies

export SPARK_JARS_DIR="\$(pwd)/$JARS_DIR"

# Build SPARK_JARS classpath
SPARK_JARS=""
for jar in \$SPARK_JARS_DIR/*.jar; do
    if [ -f "\$jar" ]; then
        if [ -z "\$SPARK_JARS" ]; then
            SPARK_JARS="\$jar"
        else
            SPARK_JARS="\$SPARK_JARS,\$jar"
        fi
    fi
done

export SPARK_JARS

# Alternative: Set individual environment variables
export ICEBERG_JAR="\$SPARK_JARS_DIR/iceberg-spark-runtime-${SPARK_VERSION}_${SCALA_VERSION}-${ICEBERG_VERSION}.jar"
export KAFKA_JAR="\$SPARK_JARS_DIR/spark-sql-kafka-0-10_${SCALA_VERSION}-${SPARK_VERSION}.jar"
export HADOOP_AWS_JAR="\$SPARK_JARS_DIR/hadoop-aws-${HADOOP_VERSION}.jar"
export NESSIE_JAR="\$SPARK_JARS_DIR/nessie-spark-extensions-${SPARK_VERSION}_${SCALA_VERSION}-${NESSIE_VERSION}.jar"

echo "Spark environment configured with JARs from: \$SPARK_JARS_DIR"
echo "Use: source ./set_spark_env.sh"
EOF

chmod +x set_spark_env.sh

echo -e "\n${BLUE}=== ENVIRONMENT SETUP ===${NC}"
echo "Environment script created: set_spark_env.sh"
echo "To use these JARs with Spark, run:"
echo "  source ./set_spark_env.sh"
echo ""
echo "Or add to your Spark submit command:"
echo "  spark-submit --jars \$SPARK_JARS your_application.py"

# Create requirements file for JARs (for documentation)
cat > jar-requirements.txt << EOF
# Spark JAR Dependencies for Industrial IoT Lakehouse
# These JAR files are required for proper Spark integration

## Core Iceberg Support
iceberg-spark-runtime-${SPARK_VERSION}_${SCALA_VERSION}-${ICEBERG_VERSION}.jar
iceberg-aws-bundle-${ICEBERG_VERSION}.jar

## Kafka Streaming Support
spark-sql-kafka-0-10_${SCALA_VERSION}-${SPARK_VERSION}.jar
kafka-clients-${KAFKA_VERSION}.jar

## S3/MinIO Storage Support
hadoop-aws-${HADOOP_VERSION}.jar
aws-java-sdk-bundle-1.12.565.jar

## Nessie Catalog Support
nessie-spark-extensions-${SPARK_VERSION}_${SCALA_VERSION}-${NESSIE_VERSION}.jar
nessie-iceberg-${NESSIE_VERSION}.jar

## Optional: Delta Lake Support
delta-core_${SCALA_VERSION}-2.4.0.jar

## Utility Libraries
jackson-databind-2.15.2.jar
httpclient-4.5.14.jar

# Total JAR files: $(ls $JARS_DIR/*.jar 2>/dev/null | wc -l)
# Total size: $(du -sh $JARS_DIR 2>/dev/null | cut -f1 || echo "Unknown")
EOF

echo -e "${GREEN}JAR requirements documented in: jar-requirements.txt${NC}"
echo -e "${GREEN}Setup complete!${NC}"

# Display summary
echo -e "\n${BLUE}=== SUMMARY ===${NC}"
echo "Downloaded $(ls $JARS_DIR/*.jar 2>/dev/null | wc -l) JAR files"
echo "Total size: $(du -sh $JARS_DIR 2>/dev/null | cut -f1 || echo "Unknown")"
echo ""
echo "Next steps:"
echo "1. Source the environment: source ./set_spark_env.sh"
echo "2. Run your Spark applications with proper classpath"
echo "3. Verify integration by running the streaming application"