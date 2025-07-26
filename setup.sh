#!/bin/bash

# Industrial IoT Lakehouse Setup Script
# This script sets up the complete Lakehouse architecture for industrial IoT data processing
# Run with: chmod +x setup.sh && ./setup.sh

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0#!/bin/bash

# Industrial IoT Lakehouse Complete Setup Script
# This script sets up the complete Lakehouse architecture for industrial IoT data processing
# Run with: chmod +x setup.sh && ./setup.sh

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration variables
PROJECT_DIR="$(pwd)"
DATASET_FILE="data/raw/industrial-iot-dataset.csv"
VENV_NAME="lakehouse-env"
LOG_FILE="setup.log"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

log_step() {
    echo -e "${PURPLE}[STEP]${NC} $1" | tee -a "$LOG_FILE"
}

log_header() {
    echo -e "\n${CYAN}================================${NC}" | tee -a "$LOG_FILE"
    echo -e "${CYAN} $1${NC}" | tee -a "$LOG_FILE"
    echo -e "${CYAN}================================${NC}\n" | tee -a "$LOG_FILE"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to show help
show_help() {
    echo "Industrial IoT Lakehouse Setup Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo "  -q, --quick             Quick setup (skip optional components)"
    echo "  -d, --dev               Development mode (lighter resource usage)"
    echo "  -p, --production        Production mode (full resource allocation)"
    echo "  -c, --clean             Clean previous installation"
    echo "  -t, --test              Run tests only"
    echo "  --skip-docker           Skip Docker services setup"
    echo "  --skip-jars             Skip JAR downloads"
    echo "  --skip-dataset          Skip dataset creation"
    echo ""
    echo "Examples:"
    echo "  $0                      # Full setup with defaults"
    echo "  $0 --quick              # Quick setup for testing"
    echo "  $0 --dev                # Development environment"
    echo "  $0 --clean              # Clean and fresh install"
}

# Parse command line arguments
QUICK_MODE=false
DEV_MODE=false
PROD_MODE=false
CLEAN_MODE=false
TEST_ONLY=false
SKIP_DOCKER=false
SKIP_JARS=false
SKIP_DATASET=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -q|--quick)
            QUICK_MODE=true
            shift
            ;;
        -d|--dev)
            DEV_MODE=true
            shift
            ;;
        -p|--production)
            PROD_MODE=true
            shift
            ;;
        -c|--clean)
            CLEAN_MODE=true
            shift
            ;;
        -t|--test)
            TEST_ONLY=true
            shift
            ;;
        --skip-docker)
            SKIP_DOCKER=true
            shift
            ;;
        --skip-jars)
            SKIP_JARS=true
            shift
            ;;
        --skip-dataset)
            SKIP_DATASET=true
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Initialize log file
echo "Industrial IoT Lakehouse Setup Started at $(date)" > "$LOG_FILE"

# Welcome message
log_header "INDUSTRIAL IOT LAKEHOUSE SETUP"
log_info "Starting setup process..."
log_info "Project directory: $PROJECT_DIR"
log_info "Log file: $LOG_FILE"

if [ "$QUICK_MODE" = true ]; then
    log_info "Running in QUICK mode"
fi

if [ "$DEV_MODE" = true ]; then
    log_info "Running in DEVELOPMENT mode"
fi

if [ "$PROD_MODE" = true ]; then
    log_info "Running in PRODUCTION mode"
fi

# Function to clean previous installation
clean_installation() {
    log_header "CLEANING PREVIOUS INSTALLATION"
    
    log_info "Stopping Docker services..."
    docker-compose down -v --remove-orphans || true
    
    log_info "Removing virtual environment..."
    rm -rf "$VENV_NAME" || true
    
    log_info "Cleaning temporary files..."
    rm -rf logs/* || true
    rm -rf /tmp/spark-checkpoints/* || true
    
    log_info "Removing JAR files..."
    rm -rf spark-jars/* || true
    
    log_success "Previous installation cleaned"
}

# Function to check system requirements
check_system_requirements() {
    log_header "CHECKING SYSTEM REQUIREMENTS"
    
    # Check Python version
    if ! command_exists python3; then
        log_error "Python 3 is required but not installed"
        log_info "Please install Python 3.8+ and try again"
        exit 1
    fi
    
    python_version=$(python3 -c "import sys; print('.'.join(map(str, sys.version_info[:2])))")
    log_info "Python version: $python_version"
    
    if python3 -c "import sys; exit(0 if sys.version_info >= (3, 8) else 1)"; then
        log_success "Python version is compatible"
    else
        log_error "Python 3.8+ is required, found $python_version"
        exit 1
    fi
    
    # Check Docker
    if [ "$SKIP_DOCKER" = false ]; then
        if ! command_exists docker; then
            log_error "Docker is required but not installed"
            log_info "Install Docker: https://docs.docker.com/get-docker/"
            exit 1
        fi
        
        if ! command_exists docker-compose; then
            log_error "Docker Compose is required but not installed"
            log_info "Install Docker Compose: https://docs.docker.com/compose/install/"
            exit 1
        fi
        
        if ! docker info >/dev/null 2>&1; then
            log_error "Docker daemon is not running"
            log_info "Please start Docker daemon and try again"
            exit 1
        fi
        
        log_success "Docker is ready"
    fi
    
    # Check available disk space
    available_space=$(df . | tail -1 | awk '{print $4}')
    required_space=10485760  # 10GB in KB
    
    if [ "$available_space" -lt "$required_space" ]; then
        log_warning "Low disk space detected (< 10GB free)"
        log_info "Available: $(df -h . | tail -1 | awk '{print $4}')"
        log_info "Consider freeing up space for optimal performance"
    else
        log_success "Sufficient disk space available"
    fi
    
    # Check available memory
    if command_exists free; then
        available_memory=$(free -m | awk 'NR==2{printf "%.0f", $7}')
        if [ "$available_memory" -lt 4096 ]; then
            log_warning "Low memory detected (< 4GB available)"
            log_info "Available: ${available_memory}MB"
            log_info "Performance may be affected"
        else
            log_success "Sufficient memory available"
        fi
    fi
}

# Function to create project structure
create_project_structure() {
    log_header "CREATING PROJECT STRUCTURE"
    
    # Create directories
    directories=(
        "data/raw"
        "data/processed" 
        "data/sample"
        "src/producer"
        "src/streaming"
        "src/visualization"
        "config/spark"
        "config/kafka"
        "config/dremio"
        "config/superset"
        "sql"
        "scripts"
        "docs"
        "notebooks"
        "tests"
        "logs/kafka"
        "logs/spark"
        "logs/application"
        "spark-jars"
    )
    
    for dir in "${directories[@]}"; do
        mkdir -p "$dir"
        log_info "Created directory: $dir"
    done
    
    # Create __init__.py files
    init_files=(
        "src/__init__.py"
        "src/producer/__init__.py"
        "src/streaming/__init__.py"
        "src/visualization/__init__.py"
        "tests/__init__.py"
    )
    
    for init_file in "${init_files[@]}"; do
        touch "$init_file"
    done
    
    # Create .gitignore if it doesn't exist
    if [ ! -f ".gitignore" ]; then
        cat > .gitignore << 'EOF'
# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
wheels/
*.egg-info/
.installed.cfg
*.egg

# Virtual environments
lakehouse-env/
venv/
env/

# Data files
data/raw/*.csv
data/processed/

# Logs
logs/
*.log

# Environment variables
.env

# Jupyter Notebook
.ipynb_checkpoints

# IDEs
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db

# Temporary files
/tmp/
*.tmp
EOF
        log_info "Created .gitignore file"
    fi
    
    log_success "Project structure created"
}

# Function to setup Python environment
setup_python_environment() {
    log_header "SETTING UP PYTHON ENVIRONMENT"
    
    # Create virtual environment
    if [ ! -d "$VENV_NAME" ]; then
        log_info "Creating virtual environment: $VENV_NAME"
        python3 -m venv "$VENV_NAME"
    else
        log_info "Virtual environment $VENV_NAME already exists"
    fi
    
    # Activate virtual environment
    source "$VENV_NAME/bin/activate"
    
    # Upgrade pip
    log_info "Upgrading pip..."
    pip install --upgrade pip setuptools wheel
    
    # Install requirements
    if [ -f "requirements.txt" ]; then
        log_info "Installing Python dependencies from requirements.txt..."
        pip install -r requirements.txt
        log_success "Python dependencies installed"
    else
        log_warning "requirements.txt not found, installing core dependencies"
        pip install pandas numpy kafka-python pyspark requests boto3 pyarrow
        log_success "Core dependencies installed"
    fi
    
    # Verify key installations
    log_info "Verifying installations..."
    python3 -c "import pandas, numpy, kafka, pyspark, requests, boto3, pyarrow; print('All core packages imported successfully')"
    
    log_success "Python environment setup completed"
}

# Function to download Spark JARs
download_spark_jars() {
    if [ "$SKIP_JARS" = true ]; then
        log_info "Skipping JAR downloads as requested"
        return 0
    fi
    
    log_header "DOWNLOADING SPARK JAR DEPENDENCIES"
    
    if [ -f "spark_jars_setup.sh" ]; then
        log_info "Running JAR download script..."
        chmod +x spark_jars_setup.sh
        ./spark_jars_setup.sh
    else
        log_warning "JAR download script not found, downloading essential JARs manually..."
        
        # Create jars directory
        mkdir -p spark-jars
        
        # Download essential JARs
        jars=(
            "https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-spark-runtime-3.5_2.12/1.4.2/iceberg-spark-runtime-3.5_2.12-1.4.2.jar"
            "https://repo1.maven.org/maven2/org/apache/spark/spark-sql-kafka-0-10_2.12/3.5.0/spark-sql-kafka-0-10_2.12-3.5.0.jar"
            "https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/3.3.4/hadoop-aws-3.3.4.jar"
        )
        
        for jar_url in "${jars[@]}"; do
            jar_name=$(basename "$jar_url")
            if [ ! -f "spark-jars/$jar_name" ]; then
                log_info "Downloading $jar_name..."
                curl -L -o "spark-jars/$jar_name" "$jar_url"
            else
                log_info "$jar_name already exists"
            fi
        done
    fi
    
    log_success "Spark JAR dependencies ready"
}

# Function to create sample dataset
create_sample_dataset() {
    if [ "$SKIP_DATASET" = true ]; then
        log_info "Skipping dataset creation as requested"
        return 0
    fi
    
    log_header "CHECKING FOR DATASET"
    
    # Check if dataset already exists
    if [ -f "$DATASET_FILE" ]; then
        log_success "Dataset already exists: $DATASET_FILE"
        return 0
    fi
    
    # Check if dataset is in current directory
    if [ -f "industrial-iot-dataset.csv" ]; then
        log_info "Moving dataset to proper location..."
        mv industrial-iot-dataset.csv "$DATASET_FILE"
        log_success "Dataset moved to: $DATASET_FILE"
        return 0
    fi
    
    log_warning "No dataset found. You have the following options:"
    echo "1. Place your dataset at: $DATASET_FILE"
    echo "2. Continue setup and add dataset later"
    echo "3. Create a sample dataset for testing"
    echo ""
    echo -n "Would you like to create a sample dataset? (y/n): "
    read -r create_sample
    
    if [ "$create_sample" = "y" ] || [ "$create_sample" = "Y" ]; then
        log_info "Creating sample industrial IoT dataset..."
        
        # Activate virtual environment
        source "$VENV_NAME/bin/activate"
        
        # Create dataset with Python
        python3 -c "
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import os

# Ensure directory exists
os.makedirs('data/raw', exist_ok=True)

# Generate sample data
np.random.seed(42)
n_sensors = 10
n_records = 1000

data = []
start_time = datetime.now() - timedelta(days=7)

for i in range(n_records):
    sensor_id = f'sensor_{(i % n_sensors) + 1:03d}'
    timestamp = start_time + timedelta(minutes=i*5)
    
    # Generate realistic readings
    temp = 25 + np.random.normal(0, 5)
    vibration = 0.5 + np.random.exponential(0.3)
    pressure = 1.0 + np.random.normal(0, 0.2)
    
    # Add occasional anomalies
    if np.random.random() < 0.05:
        temp += np.random.choice([-15, 15])
        vibration += np.random.uniform(1, 3)
    
    data.append({
        'sensor_id': sensor_id,
        'timestamp': timestamp.isoformat(),
        'temperature': round(max(0, temp), 2),
        'vibration': round(max(0, vibration), 3),
        'pressure': round(max(0, pressure), 2),
        'machine_status': np.random.choice(['NORMAL', 'WARNING', 'ALARM'], p=[0.8, 0.15, 0.05]),
        'location': f'Plant_A_Unit_{((i % n_sensors) // 2) + 1}',
        'equipment_type': np.random.choice(['Pump', 'Compressor', 'Motor'])
    })

df = pd.DataFrame(data)
df.to_csv('data/raw/industrial-iot-dataset.csv', index=False)
print(f'Sample dataset created with {len(df)} records')
"
        
        log_success "Sample dataset created: $DATASET_FILE"
    else
        log_info "Skipping dataset creation. You can add your dataset later."
    fi
}

# Function to start Docker services
start_docker_services() {
    if [ "$SKIP_DOCKER" = true ]; then
        log_info "Skipping Docker services as requested"
        return 0
    fi
    
    log_header "STARTING DOCKER SERVICES"
    
    # Check if docker-compose.yml exists
    if [ ! -f "docker-compose.yml" ]; then
        log_error "docker-compose.yml not found"
        log_info "Please ensure docker-compose.yml is in the project root"
        exit 1
    fi
    
    # Pull images
    log_info "Pulling Docker images..."
    docker-compose pull
    
    # Start services
    log_info "Starting Docker services..."
    docker-compose up -d
    
    # Wait for services to be ready
    log_info "Waiting for services to initialize (this may take several minutes)..."
    
    # Function to wait for service
    wait_for_service() {
        local service_name="$1"
        local url="$2"
        local max_attempts=60
        local attempt=1
        
        log_info "Waiting for $service_name..."
        
        while [ $attempt -le $max_attempts ]; do
            if curl -f -s "$url" >/dev/null 2>&1; then
                log_success "$service_name is ready!"
                return 0
            fi
            
            if [ $((attempt % 6)) -eq 0 ]; then  # Log every minute
                log_info "$service_name not ready yet (attempt $attempt/$max_attempts)..."
            fi
            
            sleep 10
            attempt=$((attempt + 1))
        done
        
        log_error "$service_name failed to become ready"
        return 1
    }
    
    # Wait for each service
    wait_for_service "Zookeeper" "http://localhost:2181" || true
    wait_for_service "Kafka" "http://localhost:9092" || true
    wait_for_service "MinIO" "http://localhost:9000/minio/health/live"
    wait_for_service "Nessie" "http://localhost:19120/api/v1/config"
    
    # These services take longer to start
    sleep 30
    wait_for_service "Dremio" "http://localhost:9047" || log_warning "Dremio may need more time to start"
    wait_for_service "Superset" "http://localhost:8088/health" || log_warning "Superset may need more time to start"
    
    log_success "Docker services started"
}

# Function to setup MinIO
setup_minio() {
    log_header "SETTING UP MINIO STORAGE"
    
    # Install MinIO client if needed
    if ! command_exists mc; then
        log_info "Installing MinIO client..."