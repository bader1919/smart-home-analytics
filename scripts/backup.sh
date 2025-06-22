#!/bin/bash

# BY MB Consultancy - Backup Script
# Automated backup for Smart Home Analytics data

set -e

# Configuration
BACKUP_DIR="./backups"
PROJECT_NAME="bymb-smart-analytics"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="${PROJECT_NAME}_${TIMESTAMP}"
RETENTION_DAYS=${BACKUP_RETENTION_DAYS:-30}

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

# Create backup directory
create_backup_dir() {
    local backup_path="$BACKUP_DIR/$BACKUP_NAME"
    mkdir -p "$backup_path"
    echo "$backup_path"
}

# Backup Neo4j database
backup_neo4j() {
    local backup_path=$1
    log "Backing up Neo4j database..."
    
    # Create Neo4j dump
    docker exec neo4j-graphiti neo4j-admin database dump neo4j --to-path=/tmp/
    docker cp neo4j-graphiti:/tmp/neo4j.dump "$backup_path/"
    
    log "Neo4j backup completed ?"
}

# Backup Redis data
backup_redis() {
    local backup_path=$1
    log "Backing up Redis data..."
    
    # Force save and copy
    docker exec redis-cache redis-cli BGSAVE
    sleep 5
    docker cp redis-cache:/data/dump.rdb "$backup_path/"
    
    log "Redis backup completed ?"
}

# Backup configuration files
backup_config() {
    local backup_path=$1
    log "Backing up configuration files..."
    
    # Copy configuration
    cp -r ./config "$backup_path/" 2>/dev/null || true
    cp docker-compose.yml "$backup_path/" 2>/dev/null || true
    cp .env.example "$backup_path/" 2>/dev/null || true
    
    # Create system info
    cat > "$backup_path/backup_info.txt" << EOF
Backup Information
==================
Timestamp: $(date)
Project: $PROJECT_NAME
Version: Smart Home Analytics v1.0.0
Docker Compose Version: $(docker-compose --version)
Docker Version: $(docker --version)

Container Status:
$(docker-compose ps)
EOF
    
    log "Configuration backup completed ?"
}

# Compress backup
compress_backup() {
    local backup_path=$1
    log "Compressing backup..."
    
    cd "$BACKUP_DIR"
    tar -czf "${BACKUP_NAME}.tar.gz" "$BACKUP_NAME"
    rm -rf "$BACKUP_NAME"
    
    local size=$(du -h "${BACKUP_NAME}.tar.gz" | cut -f1)
    log "Backup compressed: ${BACKUP_NAME}.tar.gz ($size) ?"
}

# Clean old backups
cleanup_old_backups() {
    log "Cleaning up old backups (older than $RETENTION_DAYS days)..."
    
    find "$BACKUP_DIR" -name "${PROJECT_NAME}_*.tar.gz" -mtime +$RETENTION_DAYS -delete
    
    local remaining=$(find "$BACKUP_DIR" -name "${PROJECT_NAME}_*.tar.gz" | wc -l)
    log "Cleanup completed. $remaining backup(s) remaining ?"
}

# Main backup function
perform_backup() {
    log "Starting backup process for BY MB Consultancy Smart Home Analytics..."
    
    # Check if containers are running
    if ! docker-compose ps | grep -q "Up"; then
        warn "Some containers may not be running. Backup may be incomplete."
    fi
    
    # Create backup directory
    local backup_path=$(create_backup_dir)
    log "Backup directory: $backup_path"
    
    # Perform backups
    backup_neo4j "$backup_path"
    backup_redis "$backup_path"
    backup_config "$backup_path"
    
    # Compress and cleanup
    compress_backup "$backup_path"
    cleanup_old_backups
    
    log "Backup process completed successfully! ?"
    log "Backup file: $BACKUP_DIR/${BACKUP_NAME}.tar.gz"
}

# Show usage
show_usage() {
    echo "BY MB Consultancy - Backup Management"
    echo "Usage: $0 {backup|list|cleanup}"
    echo ""
    echo "Commands:"
    echo "  backup    Create a new backup"
    echo "  list      List available backups"
    echo "  cleanup   Remove old backups"
}

# List backups
list_backups() {
    log "Available backups:"
    if [ -d "$BACKUP_DIR" ]; then
        find "$BACKUP_DIR" -name "${PROJECT_NAME}_*.tar.gz" -printf "%T@ %Tc %p\n" | sort -n | cut -d' ' -f2-
    else
        warn "No backup directory found"
    fi
}

# Main command handler
case "${1:-backup}" in
    backup)
        perform_backup
        ;;
    list)
        list_backups
        ;;
    cleanup)
        cleanup_old_backups
        ;;
    *)
        show_usage
        exit 1
        ;;
esac