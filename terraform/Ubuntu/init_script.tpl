#!/bin/bash

# MDCA Demo VM Initialization Script
# Installs Docker and pulls MDCA log collector image

set -e
set -x

# Variables
ADMIN_USER="${admin_username}"
LOG_FILE="/var/log/init_script.log"

source /etc/os-release
VM_PUBLIC_IP=\$(curl -s https://ipv4.icanhazip.com)

# Create and decode the script file
echo "${mdca_script_content}" | base64 -d > /home/${admin_username}/mdca_send_msgs.sh

mkdir -p /home/${admin_username}/data
chown -R ${admin_username}:${admin_username} /home/${admin_username}/data

touch /home/$ADMIN_USER/.hushlogin
chown $ADMIN_USER:$ADMIN_USER /home/$ADMIN_USER/.hushlogin

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a $LOG_FILE
}

log_message "Starting MDCA Demo VM initialization..."

# Update system packages
log_message "Updating system packages..."
apt-get update -y
apt-get upgrade -y

# Install required packages
log_message "Installing required packages..."
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    software-properties-common \
    unzip \
    gcc \
    g++ \
    python3-dev \
    python3-pip \
    wget \
    neofetch \
    nnn \
    dos2unix \
    net-tools \
    htop \
    tree \
    vim


# Fix script & set proper permissions
log_message "Fix bash script & set proper permissions"
dos2unix /home/${admin_username}/mdca_send_msgs.sh

chmod +x /home/${admin_username}/mdca_send_msgs.sh
chown ${admin_username}:${admin_username} /home/${admin_username}/mdca_send_msgs.sh

# Install Docker using official script
log_message "Installing Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# Add admin user to docker group
log_message "Adding $ADMIN_USER to docker group..."
usermod -aG docker $ADMIN_USER

# Start and enable Docker service
log_message "Starting Docker service..."
systemctl start docker
systemctl enable docker

# Pull MDCA log collector image
log_message "Pulling MDCA log collector image..."
docker pull mcr.microsoft.com/mcas/logcollector

# Verify Docker installation
log_message "Verifying Docker installation..."
docker --version
docker images

# Create directories for MDCA setup
log_message "Creating MDCA directory..."
mkdir -p "/home/$ADMIN_USER/mdca"


# Set up firewall rules (if ufw is enabled)
#if systemctl is-active --quiet ufw; then
#    log_message "Configuring firewall rules..."
#    ufw allow 22/tcp comment 'SSH'
#    ufw allow 514/udp comment 'Syslog'
#    ufw allow out 443/tcp comment 'HTTPS outbound'
#fi


# Create useful aliases for the admin user
log_message "Setting up user aliases..."
cat >> "/home/$ADMIN_USER/.bashrc" << EOF

# MDCA Demo aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias mdca-logs='docker logs cisco_asa_fp_logcollector'
alias mdca-exec='docker exec -it cisco_asa_fp_logcollector bash'
alias mdca-status='docker ps | grep logcollector'
alias mdca-remove='docker rm -f cisco_asa_fp_logcollector'

# Docker aliases
alias dps='docker ps'
alias dpsa='docker ps -a'
alias di='docker images'
alias dlog='docker logs'

# System monitoring
alias ports='netstat -tuln'
alias diskspace='df -h'
alias meminfo='free -m'
EOF

# Set proper ownership
chown $ADMIN_USER:$ADMIN_USER "/home/$ADMIN_USER/.bashrc"

cat > "/home/$ADMIN_USER/mdca/.mdca_log_collector_conf" << EOF
MDCA_AUTH_TOKEN="${mdca_auth_token}"
MASKED_TOKEN="\$${MDCA_AUTH_TOKEN:0:4}****\$${MDCA_AUTH_TOKEN: -4}"
MDCA_CONSOLE_URL="${mdca_console_url}"
MDCA_COLLECTOR_NAME="${mdca_collector_name}"
EOF

# Set proper ownership & permissions
chmod 400 "/home/$ADMIN_USER/mdca/.mdca_log_collector_conf"
chown $ADMIN_USER:$ADMIN_USER "/home/$ADMIN_USER/mdca/.mdca_log_collector_conf"

# Load config values
if [ -f "/home/$ADMIN_USER/mdca/.mdca_log_collector_conf" ]; then
    source /home/$ADMIN_USER/mdca/.mdca_log_collector_conf
else
    echo "Error: /home/$ADMIN_USER/mdca/.mdca_log_collector_conf not found!"
    exit 1
fi

# Create a sample MDCA Log Collector deployment script
log_message "Creating MDCA deployment helper script..."
cat > "/home/$ADMIN_USER/mdca/deploy_mdca_log_collector.sh" << EOF
#!/bin/bash

# MDCA Log Collector Deployment Script
# Usage: ./deploy_mdca_log_collector.sh


# Check 1: Check the container status (state)
CONTAINER_STATE=\$(docker inspect -f '{{.State.Status}}' "\$MDCA_COLLECTOR_NAME" 2>/dev/null)

if [ "\$CONTAINER_STATE" = "running" ]; then
    echo "Error: Container '\$MDCA_COLLECTOR_NAME' is already running"
    echo "Use 'docker stop \$MDCA_COLLECTOR_NAME' to stop it first"
    exit 1
elif [ "\$CONTAINER_STATE" = "exited" ]; then
    echo "Container '\$MDCA_COLLECTOR_NAME' exists but is stopped. Removing it..."
    docker rm -f "\$MDCA_COLLECTOR_NAME"
    if [ $? -eq 0 ]; then
        echo "Exited container '\$MDCA_COLLECTOR_NAME' removed successfully. Continuing with deployment..."
    else
        echo "Error: Failed to remove exited container '\$MDCA_COLLECTOR_NAME'"
        exit 1
    fi
fi

# Auto-detect public IP from eth0 interface
PUBLIC_IP=$(ip addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n1)

# Check 2: Validate the Private IP of the Azure VM (Ubuntu)
if [ -z "\$PUBLIC_IP" ]; then
    echo "Error: Could not detect IP address from eth0 interface"
    echo "Available network interfaces:"
    ip addr show | grep -E '^[0-9]+:' | awk '{print $2}' | sed 's/://'
    exit 1
fi

# Check 3: Validate AUTH_TOKEN format (should be 64 character hex string)
if ! echo "\$MDCA_AUTH_TOKEN" | grep -qE '^[a-fA-F0-9]{64}$'; then
    echo "Error: AUTH_TOKEN must be a 64-character hexadecimal string"
    echo "Current token: \$MDCA_AUTH_TOKEN"
    echo "Token length: \$${#MDCA_AUTH_TOKEN}"
    exit 1
fi

# Check 4: Validate CONSOLE_URL format (should contain cloudappsecurity.com)
if ! echo "\$MDCA_CONSOLE_URL" | grep -qE '\\.portal\\.cloudappsecurity\\.com$'; then
    echo "Error: CONSOLE_URL must end with '.portal.cloudappsecurity.com'"
    echo "Current URL: \$MDCA_CONSOLE_URL"
    echo "Example: company.us3.portal.cloudappsecurity.com"
    exit 1
fi

# Check 5: Validate COLLECTOR_NAME (alphanumeric, underscores, hyphens only, 3-50 chars)
if ! echo "\$MDCA_COLLECTOR_NAME" | grep -qE '^[a-zA-Z0-9_-]{3,50}$'; then
    echo "Error: COLLECTOR_NAME must be 3-50 characters and contain only letters, numbers, underscores, and hyphens"
    echo "Current name: \$MDCA_COLLECTOR_NAME"
    echo "Name length: \$${#MDCA_COLLECTOR_NAME}"
    exit 1
fi

echo "Deploying MDCA Log Collector..."
echo "Auth Token: \$MDCA_AUTH_TOKEN"
echo "Console Url: \$MDCA_CONSOLE_URL"
echo "Collector: \$MDCA_COLLECTOR_NAME"
echo "Collector IP: \$PUBLIC_IP"

# This command works!
# docker run -d --name \$MDCA_COLLECTOR_NAME --privileged -p \$PUBLIC_IP:514:514/udp -e "PUBLICIP='\$PUBLIC_IP'" -e "PROXY=" -e "SYSLOG=true" -e "CONSOLE=\$MDCA_CONSOLE_URL" -e "COLLECTOR=\$MDCA_COLLECTOR_NAME" --cap-add=SYS_ADMIN --cap-add=SYSLOG --restart unless-stopped   mcr.microsoft.com/mcas/logcollector /bin/bash -c "echo \$MDCA_AUTH_TOKEN | /etc/adallom/scripts/starter"

docker run -d \\
  --name \$MDCA_COLLECTOR_NAME \\
  --privileged \\
  -p \$PUBLIC_IP:514:514/udp \\
  -e "PUBLICIP='\$PUBLIC_IP'" \\
  -e "PROXY=" \\
  -e "SYSLOG=true" \\
  -e "CONSOLE=\$MDCA_CONSOLE_URL" \\
  -e "COLLECTOR=\$MDCA_COLLECTOR_NAME" \\
  --cap-add=SYS_ADMIN \\
  --cap-add=SYSLOG \\
  --restart unless-stopped \\
  mcr.microsoft.com/mcas/logcollector \\
  /bin/bash -c "echo \$MDCA_AUTH_TOKEN | /etc/adallom/scripts/starter"

# Detect if running on RHEL/CentOS
if [[ -f /etc/redhat-release ]]; then
    echo "RHEL detected - applying lsof workaround for MDCA log collector container..."
    
    # Wait for container to be fully started
    sleep 5
    
    # Replace broken lsof with dummy script
    docker exec \$MDCA_COLLECTOR_NAME mv /usr/bin/lsof /usr/bin/lsof.broken 2>/dev/null || echo "lsof already moved or not found"
    docker exec \$MDCA_COLLECTOR_NAME sh -c 'echo "#!/bin/bash" > /usr/bin/lsof'
    docker exec \$MDCA_COLLECTOR_NAME sh -c 'echo "exit 0" >> /usr/bin/lsof'
    docker exec \$MDCA_COLLECTOR_NAME chmod +x /usr/bin/lsof
    
    echo "RHEL lsof workaround applied successfully"
fi

echo "MDCA log collector deployed successfully!"
echo "Check status with: docker logs \$MDCA_COLLECTOR_NAME"
EOF

chmod +x "/home/$ADMIN_USER/mdca/deploy_mdca_log_collector.sh"
chown -R $ADMIN_USER:$ADMIN_USER "/home/$ADMIN_USER/mdca/deploy_mdca_log_collector.sh"

# Create system info script
log_message "Creating system info script..."
cat > "/home/$ADMIN_USER/mdca/system_info.sh" << EOF
#!/bin/bash

source /etc/os-release

echo "=== MDCA Demo VM System Information ==="
echo "Date: \$(date)"

echo "Platform: \$PRETTY_NAME"
echo "Hostname: \$(hostname)"
echo "Public IP: \$(curl -s https://ipv4.icanhazip.com)"
echo "Private IP: \$(hostname -I | awk '{print $1}')"
echo ""
echo "=== System Resources ==="
echo "CPU: \$(nproc) cores"
echo "Memory: \$(free -h | awk '/^Mem:/ {print $2}')"
echo "Disk: \$(df -h / | awk 'NR==2 {print $2}')"
echo ""
echo "=== Docker Information ==="
docker --version
echo "Docker status: \$(systemctl is-active docker)"
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
EOF

chmod +x "/home/$ADMIN_USER/mdca/system_info.sh"
chown $ADMIN_USER:$ADMIN_USER "/home/$ADMIN_USER/mdca/system_info.sh"

# Clean up
log_message "Cleaning up installation files..."
rm -f get-docker.sh

# Final system update
log_message "Final system cleanup..."

# Remove App Armor or else the RSYSLOG in the MDCA Container will NOT WORK PROPERLY!
# TODO: Still troubleshooting the issue. 
apt-get remove --purge apparmor apparmor-utils -y

apt-get autoremove -y
apt-get autoclean

# Create completion marker
log_message "MDCA Demo VM initialization completed successfully!"
touch "/home/$ADMIN_USER/mdca/.init_complete"
echo "$(date)" > "/home/$ADMIN_USER/mdca/.init_complete"

chown -R ${admin_username}:${admin_username} /home/${admin_username}/mdca/*

bash /home/${admin_username}/mdca/deploy_mdca_log_collector.sh

# Display summary
log_message "=== Initialization Summary ==="
log_message "✓ System packages updated on ($NAME $VERSION)"
log_message "✓ Docker installed and configured"
log_message "✓ MDCA log collector image pulled"
log_message "✓ User $ADMIN_USER added to docker group"
log_message "✓ Firewall configured (if ufw enabled)"
log_message "✓ Helper scripts created in /opt/mdca/"
log_message "✓ System aliases configured"
log_message "✓ MDCA Log Collector successfully deployed"
log_message ""
log_message "Next steps:"
log_message "1. SSH to the VM: ssh -i <key> $ADMIN_USER@$VM_PUBLIC_IP"
log_message "2. Run system info: /home/$ADMIN_USER/mdca/system_info.sh"
log_message "3. Run ./mdca_send_msgs.sh to send data to Defender XDR via the MDCA Log Collector"
log_message ""
log_message "MDCA Demo VM is ready for use!"

init 6
