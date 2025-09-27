#!/bin/bash

# MDCA Log Collector Deployment Script
# Usage: ./deploy_mdca_log_collector.sh

# Load config values
if [ -f ".mdca_log_collector_config" ]; then
    source .mdca_log_collector_config
else
    echo "Error: .mdca_log_collector_config not found!"
    exit 1
fi

# Check 1: Check the container status (state)
CONTAINER_STATE=$(docker inspect -f '{{.State.Status}}' "$MDCA_COLLECTOR_NAME" 2>/dev/null)

if [ "$CONTAINER_STATE" = "running" ]; then
    echo "Error: Container '$MDCA_COLLECTOR_NAME' is already running"
    echo "Use 'docker stop $MDCA_COLLECTOR_NAME' to stop it first"
    exit 1
elif [ "$CONTAINER_STATE" = "exited" ]; then
    echo "Container '$MDCA_COLLECTOR_NAME' exists but is stopped. Removing it..."
    docker rm -f "$MDCA_COLLECTOR_NAME"
    if [ 0 -eq 0 ]; then
        echo "Exited container '$MDCA_COLLECTOR_NAME' removed successfully. Continuing with deployment..."
    else
        echo "Error: Failed to remove exited container '$MDCA_COLLECTOR_NAME'"
        exit 1
    fi
fi

# Auto-detect public IP from eth0 interface
PUBLIC_IP=$(ip addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n1)

# Check 2: Validate the Private IP of the Azure VM (RHEL)
if [ -z "$PUBLIC_IP" ]; then
    echo "Error: Could not detect IP address from eth0 interface"
    echo "Available network interfaces:"
    ip addr show | grep -E '^[0-9]+:' | awk '{print }' | sed 's/://'
    exit 1
fi

# Mask token value
MASKED_AUTH_TOKEN="${MDCA_AUTH_TOKEN:0:4}****${MDCA_AUTH_TOKEN: -4}"

# Check 3: Validate AUTH_TOKEN format (should be 64 character hex string)
if ! echo "$MDCA_AUTH_TOKEN" | grep -qE '^[a-fA-F0-9]{64}$'; then
    echo "Error: AUTH_TOKEN must be a 64-character hexadecimal string"
    echo "Current token (masked): $MASKED_TOKEN"
    echo "Token length: ${#MDCA_AUTH_TOKEN}"
    exit 1
fi

# Check 4: Validate CONSOLE_URL format (should contain cloudappsecurity.com)
if ! echo "$MDCA_CONSOLE_URL" | grep -qE '\.portal\.cloudappsecurity\.com$'; then
    echo "Error: CONSOLE_URL must end with '.portal.cloudappsecurity.com'"
    echo "Current URL: $MDCA_CONSOLE_URL"
    echo "Example: company.us3.portal.cloudappsecurity.com"
    exit 1
fi

# Check 5: Validate COLLECTOR_NAME (alphanumeric, underscores, hyphens only, 3-50 chars)
if ! echo "$MDCA_COLLECTOR_NAME" | grep -qE '^[a-zA-Z0-9_-]{3,50}$'; then
    echo "Error: COLLECTOR_NAME must be 3-50 characters and contain only letters, numbers, underscores, and hyphens"
    echo "Current name: $MDCA_COLLECTOR_NAME"
    echo "Name length: ${#MDCA_COLLECTOR_NAME}"
    exit 1
fi

echo "Deploying MDCA Log Collector..."
echo "Auth Token: $MASKED_AUTH_TOKEN
echo "Console Url: $MDCA_CONSOLE_URL"
echo "Collector: $MDCA_COLLECTOR_NAME"
echo "Collector IP: $PUBLIC_IP"

# Deploy MDCA container
docker run -d \
  --name $MDCA_COLLECTOR_NAME \
  --privileged \
  -p $PUBLIC_IP:514:514/udp \
  -e "PUBLICIP='$PUBLIC_IP'" \
  -e "PROXY=" \
  -e "SYSLOG=true" \
  -e "CONSOLE=$MDCA_CONSOLE_URL" \
  -e "COLLECTOR=$MDCA_COLLECTOR_NAME" \
  --cap-add=SYS_ADMIN \
  --cap-add=SYSLOG \
  --restart unless-stopped \
  mcr.microsoft.com/mcas/logcollector \
  /bin/bash -c "echo $MDCA_AUTH_TOKEN | /etc/adallom/scripts/starter"

# Detect if running on RHEL/CentOS
if [[ -f /etc/redhat-release ]]; then
    echo "RHEL detected - applying lsof workaround for MDCA log collector container..."
    
    # Wait for container to be fully started
    sleep 5
    
    # Replace broken lsof with dummy script
    docker exec $MDCA_COLLECTOR_NAME mv /usr/bin/lsof /usr/bin/lsof.broken 2>/dev/null || echo "lsof already moved or not found"
    docker exec $MDCA_COLLECTOR_NAME sh -c 'echo "#!/bin/bash" > /usr/bin/lsof'
    docker exec $MDCA_COLLECTOR_NAME sh -c 'echo "exit 0" >> /usr/bin/lsof'
    docker exec $MDCA_COLLECTOR_NAME chmod +x /usr/bin/lsof
    
    echo "RHEL lsof workaround applied successfully"
fi

echo "MDCA log collector deployed successfully!"
echo "Check status with: docker logs $MDCA_COLLECTOR_NAME"
