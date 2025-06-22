# Deployment Guide - BY MB Consultancy Smart Home Analytics

This guide provides step-by-step instructions for deploying the Smart Home Analytics platform in production environments.

## Prerequisites

### System Requirements
- **Operating System**: Ubuntu 20.04+ / CentOS 8+ / Docker-compatible Linux
- **Memory**: Minimum 8GB RAM (16GB recommended)
- **Storage**: 50GB+ free space
- **Network**: Access to Home Assistant instance (192.168.11.198)
- **Docker**: Version 20.10+
- **Docker Compose**: Version 2.0+

### Required Credentials
- OpenAI API key for Graphiti processing
- Home Assistant long-lived access token
- Network access to your Home Assistant instance

## Quick Deployment

### 1. Clone Repository
```bash
git clone https://github.com/bader1919/smart-home-analytics.git
cd smart-home-analytics
```

### 2. Configure Environment
```bash
# Copy environment template
cp .env.example .env

# Edit configuration (required)
nano .env
```

**Required Environment Variables:**
```bash
# OpenAI Configuration
OPENAI_API_KEY=your_openai_api_key_here

# Home Assistant Configuration  
HOME_ASSISTANT_URL=http://192.168.11.198:8123
HOME_ASSISTANT_TOKEN=your_home_assistant_token_here
```

### 3. Deploy Services
```bash
# Make management script executable
chmod +x scripts/manage-analytics.sh

# Start all services
./scripts/manage-analytics.sh start
```

### 4. Verify Deployment
```bash
# Check service status
./scripts/manage-analytics.sh status

# Run health checks
./scripts/manage-analytics.sh health

# Test Home Assistant integration
./scripts/manage-analytics.sh test
```

## Service Endpoints

After successful deployment, access these services:

| Service | URL | Purpose |
|---------|-----|---------|
| Analytics Dashboard | http://localhost:3000 | Main client interface |
| Graphiti MCP API | http://localhost:8000 | Memory graph operations |
| Neo4j Browser | http://localhost:7474 | Database management |

**Default Credentials:**
- Neo4j: `neo4j` / `bader123`

## Network Configuration

### VLAN Setup
The platform uses your existing VLAN configuration:
- **Network**: `vlan-static-eth0.11-cce8d8`
- **IP Range**: 192.168.11.x

### Service IP Addresses
- **Neo4j**: 192.168.11.23
- **Graphiti MCP**: 192.168.11.29
- **Redis**: 192.168.11.30
- **Data Collector**: 192.168.11.31
- **Dashboard**: 192.168.11.32

## Advanced Configuration

### Custom Network Settings
If you need to modify IP addresses:

```bash
# Edit docker-compose.yml
nano docker-compose.yml

# Update network configuration
networks:
  your-network-name:
    external: true
```

### Data Collection Settings
Modify collection frequency in `.env`:
```bash
COLLECTION_INTERVAL=900  # 15 minutes (in seconds)
```

### Security Configuration
For production deployments:

1. **Change default passwords**:
   ```bash
   # In docker-compose.yml
   NEO4J_AUTH=neo4j/your_secure_password
   ```

2. **Enable HTTPS** (recommended):
   ```bash
   # Add SSL certificates to config/ssl/
   # Update nginx.conf for HTTPS
   ```

3. **Firewall configuration**:
   ```bash
   # Allow only necessary ports
   ufw allow 3000/tcp  # Dashboard
   ufw allow 7474/tcp  # Neo4j (internal only)
   ufw allow 8000/tcp  # Graphiti API
   ```

## Backup Configuration

### Automated Backups
```bash
# Run backup manually
./scripts/backup.sh

# Schedule automated backups (crontab)
0 2 * * * /path/to/smart-home-analytics/scripts/backup.sh
```

### Backup Storage
Backups are stored in `./backups/` with:
- Neo4j database dumps
- Redis data snapshots
- Configuration files
- Application logs

## Monitoring

### Service Health Monitoring
```bash
# Real-time service monitoring
watch ./scripts/manage-analytics.sh status

# View service logs
./scripts/manage-analytics.sh logs [service-name]
```

### Key Metrics to Monitor
- **Neo4j**: Memory usage, query performance
- **Redis**: Memory usage, cache hit rate
- **Data Collector**: Collection success rate
- **Dashboard**: Response times

## Troubleshooting

### Common Issues

#### 1. Neo4j Connection Issues
```bash
# Check Neo4j status
docker logs neo4j-graphiti

# Restart Neo4j
docker-compose restart neo4j

# Check network connectivity
docker exec graphiti-mcp ping neo4j-graphiti
```

#### 2. Home Assistant Connection Failures
```bash
# Test HA connectivity
curl -H "Authorization: Bearer YOUR_TOKEN" \
     http://192.168.11.198:8123/api/

# Check collector logs
docker logs ha-data-collector
```

#### 3. Graphiti MCP Issues
```bash
# Check Graphiti logs
docker logs graphiti-mcp

# Verify OpenAI API key
echo $OPENAI_API_KEY

# Test API endpoint
curl http://localhost:8000/sse
```

### Log Locations
- **Container logs**: `docker logs [container-name]`
- **Application logs**: `./logs/`
- **Backup logs**: `./backups/`

## Performance Optimization

### Resource Allocation
For production deployments, adjust resource limits:

```yaml
# In docker-compose.yml
services:
  neo4j:
    deploy:
      resources:
        limits:
          memory: 4G
        reservations:
          memory: 2G
```

### Database Tuning
Neo4j performance optimization:
```bash
# Edit Neo4j configuration
NEO4J_server_memory_heap_maxsize=4g
NEO4J_server_memory_pagecache_size=2g
```

## Scaling Considerations

### Horizontal Scaling
For multiple Home Assistant instances:
1. Deploy additional collector services
2. Use separate Graphiti group IDs
3. Configure load balancing

### High Availability
For production environments:
1. Deploy Neo4j cluster
2. Implement Redis clustering
3. Use external load balancer

## Maintenance

### Regular Maintenance Tasks
```bash
# Weekly: Update containers
./scripts/manage-analytics.sh update

# Daily: Check service health
./scripts/manage-analytics.sh health

# Monthly: Clean old data
./scripts/backup.sh cleanup
```

### Version Updates
```bash
# Pull latest changes
git pull origin main

# Rebuild and restart
./scripts/manage-analytics.sh update
```

## Support

For deployment assistance or technical support:
- **GitHub Issues**: Report bugs and feature requests
- **Documentation**: Refer to additional docs in `/docs/`
- **BY MB Consultancy**: Professional implementation services available

---

*This deployment guide ensures your BY MB Consultancy Smart Home Analytics platform runs optimally in production environments.*