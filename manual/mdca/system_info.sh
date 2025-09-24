#!/bin/bash

source /etc/os-release

echo "=== MDCA Demo VM System Information ($NAME $VERSION) ==="
echo "Date: $(date)"

echo "Platform: $PRETTY_NAME"
echo "Hostname: $(hostname)"
echo "Public IP: $(curl -s https://ipv4.icanhazip.com)"
echo "Private IP: $(hostname -I | awk '{print }')"
echo ""
echo "=== System Resources ==="
echo "CPU: $(nproc) cores"
echo "Memory: $(free -h | awk '/^Mem:/ {print }')"
echo "Disk: $(df -h / | awk 'NR==2 {print }')"
echo ""
echo "=== OS Information ==="
echo "OS: $(cat /etc/redhat-release)"
echo "Kernel: $(uname -r)"
echo ""
echo "=== Docker Information ==="
docker --version
echo "Docker status: $(systemctl is-active docker)"
echo "Docker images:"
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"
echo ""
echo "=== Network Information ==="
echo "Listening ports:"
netstat -peauln
echo ""
echo ""
echo "=== MDCA Log Collector Status ==="
if docker ps | grep -q logcollector; then
    echo "MDCA log collector is running"
    docker ps | grep logcollector
else
    echo "MDCA log collector is not running"
fi
