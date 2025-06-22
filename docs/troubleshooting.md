# Troubleshooting Guide - BY MB Consultancy Smart Home Analytics

This guide helps diagnose and resolve common issues with the Smart Home Analytics platform.

## Quick Diagnostics

### Service Health Check
```bash
# Check all services
./scripts/manage-analytics.sh health

# Check specific service status
docker-compose ps
docker logs [service-name]
```

### Common Service Issues

## 1. Neo4j Database Issues

### Problem: Neo4j fails to start
**Symptoms:**
- Container exits immediately
- "Unable to retrieve routing information" errors
- Connection refused errors

**Solutions:**
```bash
# Check Neo4j logs
docker logs neo4j-graphiti

# Common fixes:
# 1. Memory allocation
export NEO4J_server_memory_heap_maxsize=2g

# 2. Clean corrupted data
docker-compose down
docker volume rm neo4j_data
docker-compose up -d neo4j

# 3. Check disk space
df -h

# 4. Verify network connectivity
docker network ls
docker network inspect vlan-static-eth0.11-cce8d8
```

### Problem: Neo4j browser not accessible
**URL:** http://localhost:7474

**Solutions:**
```bash
# Check if port is bound
netstat -tlnp | grep 7474

# Verify container status
docker exec neo4j-graphiti neo4j status

# Test connectivity
curl -I http://localhost:7474
```

## 2. Graphiti MCP Issues

### Problem: Graphiti MCP connection errors
**Symptoms:**
- Claude cannot connect to MCP server
- "Connection refused" or timeout errors
- Data not being stored in memory graph

**Solutions:**
```bash
# Check Graphiti MCP logs
docker logs graphiti-mcp

# Verify OpenAI API key
echo $OPENAI_API_KEY

# Test Graphiti endpoint
curl http://localhost:8000/sse

# Check Neo4j connectivity from Graphiti
docker exec graphiti-mcp ping neo4j-graphiti

# Restart Graphiti service
docker-compose restart graphiti-mcp
```

### Problem: OpenAI API errors
**Symptoms:**
- "API key invalid" errors
- "Rate limit exceeded" messages
- Processing failures

**Solutions:**
```bash
# Verify API key format
echo $OPENAI_API_KEY | grep "sk-"

# Test API directly
curl -H "Authorization: Bearer $OPENAI_API_KEY" \
     https://api.openai.com/v1/models

# Check rate limits
# Monitor API usage in OpenAI dashboard
```

## 3. Home Assistant Integration Issues

### Problem: Cannot connect to Home Assistant
**Symptoms:**
- Collector shows connection errors
- No data being collected
- Authentication failures

**Solutions:**
```bash
# Test HA connectivity manually
curl -H "Authorization: Bearer $HOME_ASSISTANT_TOKEN" \
     http://192.168.11.198:8123/api/

# Check token validity
# Go to HA ? Profile ? Long-lived access tokens

# Verify network connectivity
ping 192.168.11.198

# Check collector logs
docker logs ha-data-collector

# Restart collector
docker-compose restart ha-collector
```

### Problem: Data collection stops
**Symptoms:**
- No new data in analytics
- Collector container exits
- Timeout errors

**Solutions:**
```bash
# Check collector status
docker-compose ps ha-collector

# Review collector configuration
cat collector/config.json

# Increase timeout values
# Edit docker-compose.yml:
environment:
  - COLLECTION_INTERVAL=1800  # 30 minutes
  - TIMEOUT_SECONDS=60

# Check HA performance
# Monitor HA logs for slow responses
```

## 4. Dashboard Issues

### Problem: Dashboard not loading
**URL:** http://localhost:3000

**Symptoms:**
- Page not found (404)
- Connection refused
- Blank white page

**Solutions:**
```bash
# Check dashboard container
docker logs analytics-dashboard

# Verify nginx configuration
docker exec analytics-dashboard nginx -t

# Check port binding
netstat -tlnp | grep 3000

# Test nginx directly
curl -I http://localhost:3000

# Restart dashboard
docker-compose restart dashboard
```

### Problem: Dashboard shows no data
**Symptoms:**
- Metrics show 0 or default values
- Charts are empty
- Real-time updates not working

**Solutions:**
```bash
# Check API connectivity
curl http://localhost:8000/sse

# Verify Redis cache
docker exec redis-cache redis-cli ping
docker exec redis-cache redis-cli keys "*"

# Check browser console for JavaScript errors
# Open browser dev tools (F12) ? Console

# Verify data collection
docker logs ha-data-collector | grep "Collection completed"
```

## 5. Network and Connectivity Issues

### Problem: Services cannot communicate
**Symptoms:**
- DNS resolution failures
- Connection timeouts between services
- Network unreachable errors

**Solutions:**
```bash
# Check Docker network
docker network inspect vlan-static-eth0.11-cce8d8

# Test inter-service connectivity
docker exec graphiti-mcp ping neo4j-graphiti
docker exec graphiti-mcp ping redis-cache

# Verify IP assignments
docker-compose ps

# Check firewall rules
sudo ufw status
iptables -L

# Restart networking
docker-compose down
docker-compose up -d
```

### Problem: External network access
**Symptoms:**
- Cannot reach Home Assistant
- Internet connectivity issues
- DNS resolution failures

**Solutions:**
```bash
# Test external connectivity
docker exec ha-collector ping 8.8.8.8
docker exec ha-collector nslookup google.com

# Check host network configuration
ip route show
cat /etc/resolv.conf

# Verify Docker daemon configuration
sudo systemctl status docker
```

## 6. Performance Issues

### Problem: Slow response times
**Symptoms:**
- Dashboard loads slowly
- Database queries timeout
- High CPU/memory usage

**Solutions:**
```bash
# Monitor resource usage
docker stats

# Check Neo4j performance
docker exec neo4j-graphiti cypher-shell -u neo4j -p bader123 \
  "CALL dbms.queryJmx('org.neo4j:instance=kernel#0,name=Query') \
   YIELD attributes RETURN attributes.runningQueries"

# Increase memory allocation
# Edit docker-compose.yml:
environment:
  - NEO4J_server_memory_heap_maxsize=4g
  - NEO4J_server_memory_pagecache_size=2g

# Monitor disk I/O
iostat -x 1
```

### Problem: High memory usage
**Solutions:**
```bash
# Check memory usage per container
docker stats --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}"

# Adjust container limits
# In docker-compose.yml:
deploy:
  resources:
    limits:
      memory: 2G
    reservations:
      memory: 1G

# Clear Redis cache if needed
docker exec redis-cache redis-cli FLUSHALL
```

## 7. Data and Storage Issues

### Problem: Data loss or corruption
**Symptoms:**
- Missing historical data
- Corrupted graphs or metrics
- Database integrity errors

**Solutions:**
```bash
# Check disk space
df -h

# Verify volume mounts
docker volume ls
docker volume inspect neo4j_data

# Restore from backup
./scripts/backup.sh list
# Manually restore if needed

# Check file permissions
ls -la /var/lib/docker/volumes/
```

### Problem: Backup failures
**Solutions:**
```bash
# Test backup manually
./scripts/backup.sh

# Check backup directory permissions
ls -la ./backups/

# Verify Neo4j dump capability
docker exec neo4j-graphiti neo4j-admin help dump

# Check available disk space for backups
du -sh ./backups/
```

## 8. Security Issues

### Problem: Unauthorized access
**Solutions:**
```bash
# Change default passwords immediately
# Edit docker-compose.yml:
NEO4J_AUTH=neo4j/your_secure_password

# Enable firewall
sudo ufw enable
sudo ufw allow from 192.168.11.0/24 to any port 7474
sudo ufw allow from 192.168.11.0/24 to any port 8000

# Review access logs
docker logs analytics-dashboard | grep nginx
```

### Problem: SSL/TLS configuration
**Solutions:**
```bash
# Generate SSL certificates
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout config/ssl/private.key \
  -out config/ssl/certificate.crt

# Update nginx configuration for HTTPS
# Edit config/nginx.conf
```

## Diagnostic Commands

### Comprehensive System Check
```bash
#!/bin/bash
echo "=== BY MB Consultancy Analytics Diagnostics ==="
echo "Date: $(date)"
echo ""

echo "=== Docker Status ==="
docker --version
docker-compose --version
echo ""

echo "=== Container Status ==="
docker-compose ps
echo ""

echo "=== Service Health ==="
curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 && echo " Dashboard: OK" || echo " Dashboard: FAIL"
curl -s -o /dev/null -w "%{http_code}" http://localhost:7474 && echo " Neo4j: OK" || echo " Neo4j: FAIL"
curl -s -o /dev/null -w "%{http_code}" http://localhost:8000 && echo " Graphiti: OK" || echo " Graphiti: FAIL"
echo ""

echo "=== Network Connectivity ==="
docker exec ha-collector ping -c 1 192.168.11.198 && echo " HA Connection: OK" || echo " HA Connection: FAIL"
echo ""

echo "=== Resource Usage ==="
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}"
echo ""

echo "=== Disk Space ==="
df -h
echo ""

echo "=== Recent Errors ==="
docker-compose logs --tail=10 | grep -i error
```

## Getting Help

### Log Collection
When reporting issues, include:
```bash
# Collect all relevant logs
mkdir -p /tmp/analytics-logs
docker-compose logs > /tmp/analytics-logs/docker-compose.log
docker logs neo4j-graphiti > /tmp/analytics-logs/neo4j.log
docker logs graphiti-mcp > /tmp/analytics-logs/graphiti.log
docker logs ha-data-collector > /tmp/analytics-logs/collector.log

# System information
docker --version > /tmp/analytics-logs/system-info.txt
docker-compose --version >> /tmp/analytics-logs/system-info.txt
uname -a >> /tmp/analytics-logs/system-info.txt
```

### Support Channels
- **GitHub Issues**: Technical bugs and feature requests
- **Documentation**: Additional guides in `/docs/`
- **BY MB Consultancy**: Professional support services

---

*This troubleshooting guide covers the most common issues encountered with the Smart Home Analytics platform. For complex deployment issues, professional consulting services are available through BY MB Consultancy.*