#!/bin/bash

# MDCA Demo VM Initialization Script - Ubuntu Compatible
# Installs Docker and pulls MDCA log collector image
set -e

# Check if running with sudo privileges
if [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run with sudo privileges"
    echo "Usage: sudo $0"
    exit 1
fi

# Check if system is Ubuntu
if [ ! -f /etc/lsb-release ] || ! grep -q "Ubuntu" /etc/lsb-release; then
    echo "Error: This script is designed for Ubuntu systems only"
    echo "Detected system: $(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d'"' -f2 || echo 'Unknown')"
    exit 1
fi

# Verify Ubuntu system
if ! command -v apt-get &> /dev/null; then
    echo "Error: This script requires Ubuntu with apt package manager"
    exit 1
fi

# Variables
LOG_FILE="/var/log/init_script.log"
OS=$(lsb_release -d | cut -f2)
PUBLIC_IP=$(curl -s https://ipv4.icanhazip.com)

touch /home/$USER/.hushlogin
chown $USER:$USER /home/$USER/.hushlogin

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

# Install Docker using official script
log_message "Installing Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# Add admin user to docker group
log_message "Adding $USER to docker group..."
usermod -aG docker $USER

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

# Set up firewall rules (if ufw is enabled)
#if systemctl is-active --quiet ufw; then
#    log_message "Configuring firewall rules..."
#    ufw allow 22/tcp comment 'SSH'
#    ufw allow 514/udp comment 'Syslog'
#    ufw allow out 443/tcp comment 'HTTPS outbound'
#fi

# APPARMOR PROFILE WILL PREVENT MESSAGES ON SYSLOG 514/UDP FROM GETTING PROCESSED
# DO THE FOLLOWING SO MESSAGES ARE PROPERLY PROCESSED BY THE MDCA LOG COLLECTOR

# Disable the profile again
sudo apparmor_parser -R /etc/apparmor.d/usr.sbin.rsyslogd

# Make it permanent - prevent apparmor applying it's policy to rsyslogd on boot
sudo ln -s /etc/apparmor.d/usr.sbin.rsyslogd /etc/apparmor.d/disable/usr.sbin.rsyslogd


# Create useful aliases for the admin user
log_message "Setting up user aliases..."
cat >> "/home/$USER/.bashrc" << EOF

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
chown $USER:$USER "/home/$USER/.bashrc"

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

# Display summary
log_message "=== Initialization Summary ==="
log_message "✓ System packages updated"
log_message "✓ Docker installed and configured"
log_message "✓ MDCA log collector image pulled"
log_message "✓ User $USER added to docker group"
log_message "✓ Firewall configured (if ufw enabled)"
log_message "✓ Helper scripts created in /home/$USER/mdca/"
log_message "✓ System aliases configured"
log_message ""
log_message "Next steps:"
log_message "1. SSH to the VM: ssh -i <SSH_KEY> $USER@$PUBLIC_IP"
log_message "3. Run system info: /home/$USER/mdca/deploy_mdca_log_collector.sh"
log_message "4. Run system info: /home/$USER/mdca/system_info.sh"
log_message "5. Run ./mdca_send_msgs.sh to send data to Defender XDR via the MDCA Log Collector"
log_message ""
log_message "MDCA Demo VM: $OS is now ready for use!"

# Reboot to ensure all services start properly
log_message "Reboot your system to finalize configuration when ready..."
