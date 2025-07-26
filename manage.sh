#!/bin/bash

# Industrial IoT Lakehouse Management Script
# This script provides management commands for the running lakehouse system
# Usage: ./manage.sh [command] [options]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
VENV_NAME="lakehouse-env"
PRODUCER_PID_FILE="producer.pid"
STREAMING_PID_FILE="streaming.pid"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_header() {
    echo -e "\n${CYAN}=== $1 ===${NC}\n"
}

# Function to show help
show_help() {
    echo "Industrial IoT Lakehouse Management Script"
    echo ""
    echo "Usage: $0 COMMAND [OPTIONS]"
    echo ""
    echo "COMMANDS:"
    echo "  status              Show system status"
    echo "  start               Start all services"
    echo "  stop                Stop all services"
    echo "  restart             Restart all services"
    echo "  logs [service]      Show logs for service (or all if no service specified)"
    echo "  producer            Manage data producer"
    echo "    start             Start the producer"
    echo "    stop              Stop the producer"
    echo "    restart           Restart the producer"
    echo "    status            Show producer status"
    echo "  streaming           Manage streaming processor"
    echo "    start             Start the streaming processor"
    echo "    stop              Stop the streaming processor"
    echo "    restart           Restart the streaming processor"
    echo "    status            Show streaming status"
    echo "  monitor             Real-time system monitoring"
    echo "  health              Run health checks"
    echo "  cleanup             Clean up temporary files and logs"
    echo "  backup              Backup important data"
    echo "  reset               Reset the entire system (DESTRUCTIVE)"
    echo ""
    echo "EXAMPLES:"
    echo "  $0 status                    # Show overall system status"
    echo "  $0 logs kafka               # Show Kafka logs"
    echo "  $0 producer start           # Start data producer"
    echo "  $0 streaming restart        # Restart streaming processor"
    echo "  $0 monitor                  # Start real-time monitoring"
    echo ""
}

# Function to check if process is running
is_process_running() {
    local pid_file="$1"
    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        if ps -p "$pid" > /dev/null 2>&1; then
            return 0
        else
            rm -f "$pid_file"
            return 1
        fi
    fi
    return 1
}

# Function to show system status
show_status() {
    log_header "SYSTEM STATUS"
    
    # Docker services status
    echo -e "${CYAN}Docker Services:${NC}"
    if command -v docker-compose >/dev/null 2>&1; then
        docker-compose ps --format "table {{.Service}}\t{{.State}}\t{{.Status}}"
    else
        log_warning "Docker Compose not found"
    fi
    
    echo ""
    
    # Application processes status
    echo -e "${CYAN}Application Processes:${NC}"
    if is_process_running "$PRODUCER_PID_FILE"; then
        echo -e "  Producer:     ${GREEN}RUNNING${NC} (PID: $(cat $PRODUCER_PID_FILE))"
    else
        echo -e "  Producer:     ${RED}STOPPED${NC}"
    fi
    
    if is_process_running "$STREAMING_PID_FILE"; then
        echo -e "  Streaming:    ${GREEN}RUNNING${NC} (PID: $(cat $STREAMING_PID_FILE))"
    else
        echo -e "  Streaming:    ${RED}STOPPED${NC}"
    fi
    
    echo ""
    
    # Service endpoints
    echo -e "${CYAN}Service Endpoints:${NC}"
    endpoints=(
        "MinIO Console:http://localhost:9001"
        "Nessie API:http://localhost:19120"
        "Dremio Console:http://localhost:9047"
        "Superset:http://localhost:8088"
        "Spark Master UI:http://localhost:8080"
    )
    
    for endpoint in "${endpoints[@]}"; do
        IFS=':' read -r name url <<< "$endpoint"
        if curl -f -s "$url" >/dev/null 2>&1; then
            echo -e "  $name: ${GREEN}ACCESSIBLE${NC}"
        else
            echo -e "  $name: ${RED}NOT ACCESSIBLE${NC}"
        fi
    done
    
    # System resources
    echo ""
    echo -e "${CYAN}System Resources:${NC}"
    if command -v docker >/dev/null 2>&1; then
        echo "  Docker containers:"
        docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}"
    fi
}

# Function to start all services
start_services() {
    log_header "STARTING ALL SERVICES"
    
    # Start Docker services
    log_info "Starting Docker services..."
    docker-compose up -d
    
    # Wait for services to be ready
    log_info "Waiting for services to be ready..."
    sleep 30
    
    # Start producer
    start_producer
    
    # Start streaming
    sleep 10
    start_streaming
    
    log_success "All services started"
}

# Function to stop all services
stop_services() {
    log_header "STOPPING ALL SERVICES"
    
    # Stop application processes
    stop_producer
    stop_streaming
    
    # Stop Docker services
    log_info "Stopping Docker services..."
    docker-compose down
    
    log_success "All services stopped"
}

# Function to restart all services
restart_services() {
    log_header "RESTARTING ALL SERVICES"
    stop_services
    sleep 5
    start_services
}

# Function to start producer
start_producer() {
    if is_process_running "$PRODUCER_PID_FILE"; then
        log_warning "Producer is already running"
        return 0
    fi
    
    log_info "Starting data producer..."
    
    # Activate virtual environment
    source "$VENV_NAME/bin/activate" 2>/dev/null || {
        log_warning "Virtual environment not found, using system Python"
    }
    
    # Ensure log directory exists
    mkdir -p logs/application
    
    # Start producer
    cd src/producer
    nohup python kafka_producer.py \
        --csv-file "../../data/raw/industrial-iot-dataset.csv" \
        --batch-size 20 \
        --delay 2.0 \
        --kafka-servers localhost:9092 > ../../logs/application/producer.log 2>&1 &
    
    echo $! > "../../$PRODUCER_PID_FILE"
    cd ../..
    
    log_success "Producer started (PID: $(cat $PRODUCER_PID_FILE))"
}

# Function to stop producer
stop_producer() {
    if is_process_running "$PRODUCER_PID_FILE"; then
        local pid=$(cat "$PRODUCER_PID_FILE")
        log_info "Stopping producer (PID: $pid)..."
        kill "$pid"
        rm -f "$PRODUCER_PID_FILE"
        log_success "Producer stopped"
    else
        log_info "Producer is not running"
    fi
}

# Function to start streaming
start_streaming() {
    if is_process_running "$STREAMING_PID_FILE"; then
        log_warning "Streaming processor is already running"
        return 0
    fi
    
    log_info "Starting Spark streaming processor..."
    
    # Activate virtual environment
    source "$VENV_NAME/bin/activate" 2>/dev/null || {
        log_warning "Virtual environment not found, using system Python"
    }
    
    # Set Spark environment
    if [ -f "set_spark_env.sh" ]; then
        source set_spark_env.sh
    fi
    
    # Ensure log directory exists
    mkdir -p logs/application
    
    # Start streaming
    cd src/streaming
    nohup python spark_streaming.py \
        --mode streaming \
        --kafka-servers localhost:9092 \
        --topic industrial-iot-data > ../../logs/application/streaming.log 2>&1 &
    
    echo $! > "../../$STREAMING_PID_FILE"
    cd ../..
    
    log_success "Streaming processor started (PID: $(cat $STREAMING_PID_FILE))"
}

# Function to stop streaming
stop_streaming() {
    if is_process_running "$STREAMING_PID_FILE"; then
        local pid=$(cat "$STREAMING_PID_FILE")
        log_info "Stopping streaming processor (PID: $pid)..."
        kill "$pid"
        rm -f "$STREAMING_PID_FILE"
        log_success "Streaming processor stopped"
    else
        log_info "Streaming processor is not running"
    fi
}

# Function to show logs
show_logs() {
    local service="$1"
    
    if [ -z "$service" ]; then
        log_header "ALL SERVICE LOGS"
        echo -e "${CYAN}Docker services logs:${NC}"
        docker-compose logs --tail=50
        
        echo -e "\n${CYAN}Producer logs:${NC}"
        if [ -f "logs/application/producer.log" ]; then
            tail -50 logs/application/producer.log
        else
            log_warning "Producer log file not found"
        fi
        
        echo -e "\n${CYAN}Streaming logs:${NC}"
        if [ -f "logs/application/streaming.log" ]; then
            tail -50 logs/application/streaming.log
        else
            log_warning "Streaming log file not found"
        fi
    elif [ "$service" = "producer" ]; then
        log_header "PRODUCER LOGS"
        if [ -f "logs/application/producer.log" ]; then
            tail -f logs/application/producer.log
        else
            log_error "Producer log file not found"
        fi
    elif [ "$service" = "streaming" ]; then
        log_header "STREAMING LOGS"
        if [ -f "logs/application/streaming.log" ]; then
            tail -f logs/application/streaming.log
        else
            log_error "Streaming log file not found"
        fi
    else
        log_header "${service^^} LOGS"
        docker-compose logs -f "$service"
    fi
}

# Function to monitor system
monitor_system() {
    log_header "REAL-TIME SYSTEM MONITORING"
    
    echo "Press Ctrl+C to stop monitoring"
    echo ""
    
    while true; do
        clear
        echo -e "${CYAN}=== LAKEHOUSE SYSTEM MONITOR ===${NC}"
        echo "Last updated: $(date)"
        echo ""
        
        # Service status
        echo -e "${CYAN}Service Status:${NC}"
        docker-compose ps --format "table {{.Service}}\t{{.State}}"
        
        echo ""
        
        # Application processes
        echo -e "${CYAN}Application Processes:${NC}"
        if is_process_running "$PRODUCER_PID_FILE"; then
            echo -e "  Producer:  ${GREEN}RUNNING${NC}"
        else
            echo -e "  Producer:  ${RED}STOPPED${NC}"
        fi
        
        if is_process_running "$STREAMING_PID_FILE"; then
            echo -e "  Streaming: ${GREEN}RUNNING${NC}"
        else
            echo -e "  Streaming: ${RED}STOPPED${NC}"
        fi
        
        echo ""
        
        # Resource usage
        echo -e "${CYAN}Resource Usage:${NC}"
        docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}"
        
        sleep 5
    done
}

# Function to run health checks
run_health_checks() {
    log_header "HEALTH CHECKS"
    
    # Check Docker services
    services=("kafka" "minio" "nessie" "dremio" "superset" "spark-master")
    
    for service in "${services[@]}"; do
        if docker-compose ps "$service" | grep -q "Up"; then
            log_success "$service is running"
        else
            log_error "$service is not running"
        fi
    done
    
    # Check service endpoints
    endpoints=(
        "Kafka:localhost:9092"
        "MinIO:localhost:9000/minio/health/live"
        "Nessie:localhost:19120/api/v1/config"
        "Dremio:localhost:9047"
        "Superset:localhost:8088/health"
    )
    
    for endpoint in "${endpoints[@]}"; do
        IFS=':' read -r name url <<< "$endpoint"
        if curl -f -s "http://$url" >/dev/null 2>&1; then
            log_success "$name endpoint is accessible"
        else
            log_warning "$name endpoint is not accessible"
        fi
    done
    
    # Check application processes
    if is_process_running "$PRODUCER_PID_FILE"; then
        log_success "Producer process is running"
    else
        log_warning "Producer process is not running"
    fi
    
    if is_process_running "$STREAMING_PID_FILE"; then
        log_success "Streaming process is running"
    else
        log_warning "Streaming process is not running"
    fi
}

# Function to cleanup system
cleanup_system() {
    log_header "SYSTEM CLEANUP"
    
    log_info "Cleaning up temporary files..."
    
    # Clean log files older than 7 days
    find logs/ -name "*.log" -mtime +7 -delete 2>/dev/null || true
    
    # Clean Spark checkpoints
    rm -rf /tmp/spark-checkpoints/* 2>/dev/null || true
    
    # Clean Docker unused volumes
    docker volume prune -f 2>/dev/null || true
    
    # Clean Docker unused images
    docker image prune -f 2>/dev/null || true
    
    log_success "Cleanup completed"
}

# Function to backup data
backup_data() {
    log_header "DATA BACKUP"
    
    backup_dir="backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    log_info "Creating backup in $backup_dir..."
    
    # Backup configuration files
    cp docker-compose.yml "$backup_dir/"
    cp .env "$backup_dir/" 2>/dev/null || true
    cp requirements.txt "$backup_dir/"
    
    # Backup logs
    cp -r logs "$backup_dir/" 2>/dev/null || true
    
    # Backup MinIO data
    if command -v mc >/dev/null 2>&1; then
        mc mirror local/lakehouse "$backup_dir/minio_data" 2>/dev/null || log_warning "MinIO backup failed"
    fi
    
    # Create archive
    tar -czf "${backup_dir}.tar.gz" "$backup_dir"
    rm -rf "$backup_dir"
    
    log_success "Backup created: ${backup_dir}.tar.gz"
}

# Function to reset system
reset_system() {
    log_header "SYSTEM RESET"
    
    echo -e "${RED}WARNING: This will destroy all data and reset the system!${NC}"
    echo -n "Are you sure? (yes/no): "
    read -r confirmation
    
    if [ "$confirmation" = "yes" ]; then
        log_info "Resetting system..."
        
        # Stop all services
        stop_services
        
        # Remove Docker volumes
        docker-compose down -v --remove-orphans
        
        # Clean directories
        rm -rf logs/*
        rm -rf /tmp/spark-checkpoints/*
        rm -f producer.pid streaming.pid
        
        # Remove virtual environment
        rm -rf "$VENV_NAME"
        
        log_success "System reset completed"
        log_info "Run setup.sh to reinstall"
    else
        log_info "Reset cancelled"
    fi
}

# Main command handling
case "${1:-}" in
    "status")
        show_status
        ;;
    "start")
        start_services
        ;;
    "stop")
        stop_services
        ;;
    "restart")
        restart_services
        ;;
    "logs")
        show_logs "$2"
        ;;
    "producer")
        case "${2:-}" in
            "start") start_producer ;;
            "stop") stop_producer ;;
            "restart") stop_producer; sleep 2; start_producer ;;
            "status") 
                if is_process_running "$PRODUCER_PID_FILE"; then
                    echo -e "Producer: ${GREEN}RUNNING${NC} (PID: $(cat $PRODUCER_PID_FILE))"
                else
                    echo -e "Producer: ${RED}STOPPED${NC}"
                fi
                ;;
            *) echo "Usage: $0 producer {start|stop|restart|status}" ;;
        esac
        ;;
    "streaming")
        case "${2:-}" in
            "start") start_streaming ;;
            "stop") stop_streaming ;;
            "restart") stop_streaming; sleep 2; start_streaming ;;
            "status")
                if is_process_running "$STREAMING_PID_FILE"; then
                    echo -e "Streaming: ${GREEN}RUNNING${NC} (PID: $(cat $STREAMING_PID_FILE))"
                else
                    echo -e "Streaming: ${RED}STOPPED${NC}"
                fi
                ;;
            *) echo "Usage: $0 streaming {start|stop|restart|status}" ;;
        esac
        ;;
    "monitor")
        monitor_system
        ;;
    "health")
        run_health_checks
        ;;
    "cleanup")
        cleanup_system
        ;;
    "backup")
        backup_data
        ;;
    "reset")
        reset_system
        ;;
    "help"|"-h"|"--help")
        show_help
        ;;
    "")
        show_help
        ;;
    *)
        log_error "Unknown command: $1"
        echo ""
        show_help
        exit 1
        ;;
esac