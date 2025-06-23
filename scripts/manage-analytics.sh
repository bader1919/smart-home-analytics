#!/bin/bash

# BY MB Consultancy - Smart Home Analytics Management Script
# Professional deployment and management for smart home IoT analytics

set -e

# Configuration
PROJECT_NAME="bymb-smart-analytics"
COMPOSE_FILE="docker-compose.yml"
ENV_FILE=".env"
LOG_DIR="./logs"

# Detect Docker Compose command
if command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
elif docker compose version &> /dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
else
    echo "ERROR: Docker Compose not found. Please install docker-compose or use Docker with Compose plugin."
    exit 1
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

# Create necessary directories
create_directories() {
    log "Creating necessary directories..."
    mkdir -p "$LOG_DIR"
    mkdir -p "./backups"
    mkdir -p "./config"
    mkdir -p "./dashboard/assets"
    chmod 755 "$LOG_DIR" "./backups" "./config"
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    # Check environment file
    if [ ! -f "$ENV_FILE" ]; then
        warn "Environment file not found. Creating from template..."
        if [ -f ".env.example" ]; then
            cp .env.example "$ENV_FILE"
            warn "Please edit $ENV_FILE with your actual credentials before starting"
        else
            error "No .env.example template found. Please create $ENV_FILE manually."
            exit 1
        fi
    fi
    
    log "Prerequisites check completed ✓"
}

# Build services
build_services() {
    log "Building Docker services..."
    $COMPOSE_CMD -f "$COMPOSE_FILE" build --no-cache
    log "Build completed ✓"
}

# Start services
start_services() {
    log "Starting BY MB Consultancy Smart Home Analytics..."
    create_directories
    check_prerequisites
    
    # Pull latest images
    info "Pulling latest Docker images..."
    $COMPOSE_CMD -f "$COMPOSE_FILE" pull
    
    # Start services
    info "Starting services..."
    $COMPOSE_CMD -f "$COMPOSE_FILE" up -d
    
    # Wait for services to be ready
    info "Waiting for services to initialize..."
    sleep 30
    
    # Check service health
    check_health
    
    log "Smart Home Analytics platform started successfully! 🚀"
    echo ""
    show_endpoints
}

# Stop services
stop_services() {
    log "Stopping services..."
    $COMPOSE_CMD -f "$COMPOSE_FILE" down
    log "Services stopped ✓"
}

# Restart services
restart_services() {
    log "Restarting services..."
    stop_services
    sleep 5
    start_services
}

# Show service status
show_status() {
    log "Service Status:"
    $COMPOSE_CMD -f "$COMPOSE_FILE" ps
    echo ""
    
    info "Container Health Status:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "(neo4j|graphiti|redis|collector|dashboard)" || echo "No matching containers found"
}

# Show logs
show_logs() {
    local service=$1
    if [ -z "$service" ]; then
        log "Showing logs for all services..."
        $COMPOSE_CMD -f "$COMPOSE_FILE" logs --tail=50 -f
    else
        log "Showing logs for service: $service"
        $COMPOSE_CMD -f "$COMPOSE_FILE" logs --tail=50 -f "$service"
    fi
}

# Health check
check_health() {
    log "Performing health checks..."
    
    local all_healthy=true
    
    # Check Neo4j
    if curl -s http://localhost:7474 > /dev/null 2>&1; then
        echo -e "  Neo4j Database: ${GREEN}✓ Healthy${NC}"
    else
        echo -e "  Neo4j Database: ${RED}✗ Unhealthy${NC}"
        all_healthy=false
    fi
    
    # Check Graphiti MCP
    if curl -s http://localhost:8000 > /dev/null 2>&1; then
        echo -e "  Graphiti MCP: ${GREEN}✓ Healthy${NC}"
    else
        echo -e "  Graphiti MCP: ${RED}✗ Unhealthy${NC}"
        all_healthy=false
    fi
    
    # Check Redis
    if docker exec redis-cache redis-cli ping > /dev/null 2>&1; then
        echo -e "  Redis Cache: ${GREEN}✓ Healthy${NC}"
    else
        echo -e "  Redis Cache: ${RED}✗ Unhealthy${NC}"
        all_healthy=false
    fi
    
    # Check Dashboard
    if curl -s http://localhost:3000 > /dev/null 2>&1; then
        echo -e "  Analytics Dashboard: ${GREEN}✓ Healthy${NC}"
    else
        echo -e "  Analytics Dashboard: ${RED}✗ Unhealthy${NC}"
        all_healthy=false
    fi
    
    if [ "$all_healthy" = true ]; then
        log "All services are healthy ✓"
    else
        warn "Some services are not responding properly"
    fi
}

# Test integration
test_integration() {
    log "Testing Home Assistant integration..."
    
    # Check if environment variables are set
    source "$ENV_FILE"
    
    if [ -z "$HOME_ASSISTANT_TOKEN" ]; then
        error "HOME_ASSISTANT_TOKEN not set in $ENV_FILE"
        return 1
    fi
    
    # Test HA connectivity
    local ha_url="${HOME_ASSISTANT_URL:-http://192.168.11.198:8123}"
    if curl -s -H "Authorization: Bearer $HOME_ASSISTANT_TOKEN" "$ha_url/api/" > /dev/null 2>&1; then
        echo -e "  Home Assistant: ${GREEN}✓ Connected${NC}"
    else
        echo -e "  Home Assistant: ${RED}✗ Cannot connect${NC}"
        error "Cannot connect to Home Assistant at $ha_url"
        return 1
    fi
    
    log "Integration test completed ✓"
}

# Show service endpoints
show_endpoints() {
    info "Service Endpoints:"
    echo "  🏠 Analytics Dashboard:  http://localhost:3000"
    echo "  🧠 Graphiti MCP API:     http://localhost:8000"
    echo "  📊 Neo4j Browser:       http://localhost:7474"
    echo "  ⚡ Redis Commander:     Available via docker exec"
    echo ""
    info "Credentials:"
    echo "  Neo4j: neo4j / bader123"
    echo "  Dashboard: No authentication required"
    echo ""
    info "Integration:"
    echo "  Home Assistant: 192.168.11.198:8123"
    echo "  Data Collection: Every 15 minutes"
    echo "  Memory Group: bymb-consultancy"
}

# Update services
update_services() {
    log "Updating services..."
    
    # Pull latest images
    $COMPOSE_CMD -f "$COMPOSE_FILE" pull
    
    # Rebuild custom images
    build_services
    
    # Restart with new images
    restart_services
    
    log "Services updated ✓"
}

# Show usage
show_usage() {
    echo -e "${PURPLE}BY MB Consultancy - Smart Home Analytics Management${NC}"
    echo "Professional IoT analytics platform deployment and management"
    echo ""
    echo "Usage: $0 {command}"
    echo ""
    echo "Commands:"
    echo "  start       Start all services"
    echo "  stop        Stop all services" 
    echo "  restart     Restart all services"
    echo "  status      Show service status"
    echo "  logs [svc]  Show logs (optionally for specific service)"
    echo "  health      Check service health"
    echo "  test        Test Home Assistant integration"
    echo "  build       Build Docker services"
    echo "  update      Update services to latest versions"
    echo "  endpoints   Show service endpoints and credentials"
    echo ""
    echo "Examples:"
    echo "  $0 start                    # Start the platform"
    echo "  $0 logs graphiti-mcp       # Show Graphiti logs"
    echo "  $0 health                  # Check all service health"
    echo "  $0 test                    # Test HA connectivity"
}

# Main command handler
case "${1:-}" in
    start)
        start_services
        ;;
    stop)
        stop_services
        ;;
    restart)
        restart_services
        ;;
    status)
        show_status
        ;;
    logs)
        show_logs "$2"
        ;;
    health)
        check_health
        ;;
    test)
        test_integration
        ;;
    build)
        build_services
        ;;
    update)
        update_services
        ;;
    endpoints)
        show_endpoints
        ;;
    *)
        show_usage
        exit 1
        ;;
esac
