#!/bin/bash

# Quick Start Script for Industrial IoT Lakehouse
# Enhanced version with better error handling and Docker timeout management

echo "🚀 Industrial IoT Lakehouse Quick Start (Enhanced)"
echo "================================================="

# Check prerequisites
echo "📋 Checking prerequisites..."

if ! command -v python3 >/dev/null 2>&1; then
    echo "❌ Python 3 is required but not installed"
    exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
    echo "❌ Docker is required but not installed"
    exit 1
fi

if ! command -v docker-compose >/dev/null 2>&1; then
    echo "❌ Docker Compose is required but not installed"
    exit 1
fi

# Check if Docker daemon is running
if ! docker info >/dev/null 2>&1; then
    echo "❌ Docker daemon is not running. Please start Docker first."
    exit 1
fi

echo "✅ Prerequisites OK"

# Create basic structure
echo "📁 Creating directory structure..."
mkdir -p data/raw src/{producer,streaming,visualization} logs/application spark-jars

# Create virtual environment with better error handling
echo "🐍 Setting up Python environment..."
if [ -d "lakehouse-env" ]; then
    echo "   Removing existing virtual environment..."
    rm -rf lakehouse-env
fi

if python3 -m venv lakehouse-env; then
    echo "   ✅ Virtual environment created successfully"
else
    echo "   ❌ Failed to create virtual environment"
    echo "   Please run: sudo apt install python3-venv python3-pip"
    exit 1
fi

source lakehouse-env/bin/activate

if command -v pip >/dev/null 2>&1; then
    echo "   ✅ Pip is available"
    pip install --upgrade pip
else
    echo "   ❌ Pip not found in virtual environment"
    exit 1
fi

# Install minimal dependencies with error handling
echo "📦 Installing Python packages..."
packages=("pandas" "numpy" "kafka-python" "pyspark" "requests" "boto3" "pyarrow")

for package in "${packages[@]}"; do
    echo "   Installing $package..."
    if pip install "$package"; then
        echo "   ✅ $package installed"
    else
        echo "   ⚠️ Failed to install $package, continuing..."
    fi
done

# Test imports
echo "🧪 Testing Python imports..."
python3 -c "
try:
    import pandas, numpy, kafka
    print('   ✅ Core packages working')
except ImportError as e:
    print(f'   ⚠️ Import issue: {e}')
"

# Create .env file if it doesn't exist
if [ ! -f ".env" ]; then
    echo "⚙️ Creating .env file..."
    cat > .env << 'EOF'
# Basic configuration
KAFKA_BOOTSTRAP_SERVERS=localhost:9092
MINIO_ACCESS_KEY=minioadmin
MINIO_SECRET_KEY=minioadmin123
DATASET_PATH=data/raw/industrial-iot-dataset.csv
EOF
    echo "   ✅ .env file created"
fi

# Handle Docker services with better error management
echo "🐳 Managing Docker services..."

# Check if docker-compose.yml exists
if [ ! -f "docker-compose.yml" ]; then
    echo "❌ docker-compose.yml not found!"
    echo "Please make sure you have the docker-compose.yml file in the current directory"
    exit 1
fi

# Stop any existing services first
echo "   Stopping any existing services..."
docker-compose down >/dev/null 2>&1

# Try to start services with timeout handling
echo "   Starting Docker services (this may take a few minutes)..."
echo "   If this times out, we'll use a simpler configuration..."

# Start services with timeout
if timeout 120 docker-compose up -d; then
    echo "   ✅ Docker services started successfully"
    docker_success=true
else
    echo "   ⚠️ Full Docker setup timed out, trying minimal setup..."
    docker_success=false
fi

# If full setup failed, try minimal setup
if [ "$docker_success" = false ]; then
    echo "   📦 Creating minimal Docker setup..."
    
    # Create simplified docker-compose
    cat > docker-compose-minimal.yml << 'EOF'
version: '3.8'
services:
  zookeeper:
    image: confluentinc/cp-zookeeper:7.4.0
    environment:
      ZOOKEEPER_CLIENT_PORT: 2181
      ZOOKEEPER_TICK_TIME: 2000
    ports:
      - "2181:2181"

  kafka:
    image: confluentinc/cp-kafka:7.4.0
    depends_on:
      - zookeeper
    ports:
      - "9092:9092"
    environment:
      KAFKA_BROKER_ID: 1
      KAFKA_ZOOKEEPER_CONNECT: zookeeper:2181
      KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: PLAINTEXT:PLAINTEXT,PLAINTEXT_HOST:PLAINTEXT
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kafka:29092,PLAINTEXT_HOST://localhost:9092
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1
      KAFKA_AUTO_CREATE_TOPICS_ENABLE: 'true'

  minio:
    image: minio/minio:latest
    ports:
      - "9000:9000"
      - "9001:9001"
    environment:
      MINIO_ROOT_USER: minioadmin
      MINIO_ROOT_PASSWORD: minioadmin123
    command: server /data --console-address ":9001"
EOF
    
    echo "   Starting minimal services..."
    if docker-compose -f docker-compose-minimal.yml up -d; then
        echo "   ✅ Minimal Docker services started"
        use_minimal=true
    else
        echo "   ❌ Docker setup failed completely"
        echo "   You can still test the Python code without Docker"
        use_minimal=false
    fi
fi

# Wait for services with proper timing
if [ "${docker_success:-false}" = true ] || [ "${use_minimal:-false}" = true ]; then
    echo "⏳ Waiting for services to initialize..."
    sleep 45
    
    # Check service health
    echo "🔍 Checking service health..."
    
    # Check Kafka
    if nc -z localhost 9092 2>/dev/null; then
        echo "   ✅ Kafka is accessible"
        kafka_ready=true
    else
        echo "   ⚠️ Kafka not ready yet"
        kafka_ready=false
    fi
    
    # Check MinIO
    if curl -s -f http://localhost:9000/minio/health/live >/dev/null 2>&1; then
        echo "   ✅ MinIO is accessible"
        minio_ready=true
    else
        echo "   ⚠️ MinIO not ready yet"
        minio_ready=false
    fi
fi

# Check if dataset exists
echo "📊 Checking for dataset..."
if [ -f "data/raw/industrial-iot-dataset.csv" ]; then
    echo "   ✅ Dataset found"
    dataset_lines=$(wc -l < data/raw/industrial-iot-dataset.csv)
    echo "   📈 Dataset has $dataset_lines lines"
elif [ -f "industrial-iot-dataset.csv" ]; then
    mv industrial-iot-dataset.csv data/raw/
    echo "   ✅ Dataset moved to data/raw/"
else
    echo "   ⚠️ Dataset not found. Please place your CSV file at data/raw/industrial-iot-dataset.csv"
fi

# Create Kafka topic if Kafka is ready
if [ "${kafka_ready:-false}" = true ]; then
    echo "📨 Creating Kafka topic..."
    if [ "${use_minimal:-false}" = true ]; then
        compose_file="docker-compose-minimal.yml"
    else
        compose_file="docker-compose.yml"
    fi
    
    sleep 10  # Give Kafka more time
    if docker-compose -f "$compose_file" exec -T kafka kafka-topics.sh \
        --create --topic industrial-iot-data \
        --bootstrap-server localhost:9092 \
        --partitions 3 --replication-factor 1 \
        --if-not-exists 2>/dev/null; then
        echo "   ✅ Kafka topic created"
    else
        echo "   ⚠️ Kafka topic creation failed (may already exist)"
    fi
fi

# Final status report
echo ""
echo "🎉 Setup completed!"
echo "=================="

# Show what's working
echo "✅ Working components:"
[ -d "lakehouse-env" ] && echo "   • Python virtual environment"
[ -f "data/raw/industrial-iot-dataset.csv" ] && echo "   • Dataset file"
[ "${kafka_ready:-false}" = true ] && echo "   • Kafka service"
[ "${minio_ready:-false}" = true ] && echo "   • MinIO service"

echo ""
echo "📍 Access points (if running):"
echo "   MinIO:     http://localhost:9001 (minioadmin/minioadmin123)"
echo "   Dremio:    http://localhost:9047"
echo "   Superset:  http://localhost:8088 (admin/admin)"
echo ""
echo "🔧 Next steps:"
echo "   1. Activate Python: source lakehouse-env/bin/activate"
echo "   2. Check Docker: docker-compose ps"
echo "   3. Test producer: cd src/producer && python kafka_producer.py --csv-file ../../data/raw/industrial-iot-dataset.csv --test-only"
echo ""

# Provide troubleshooting info if needed
if [ "${docker_success:-false}" = false ] && [ "${use_minimal:-false}" = false ]; then
    echo "🔧 Docker troubleshooting:"
    echo "   • Check Docker daemon: docker info"
    echo "   • Check connectivity: ping google.com"
    echo "   • Manual start: docker-compose up -d"
fi

echo "💡 For detailed help, check the README.md file"