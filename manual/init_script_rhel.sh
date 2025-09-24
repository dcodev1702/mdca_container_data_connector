#!/bin/bash

# MDCA Demo VM Initialization Script - RHEL 9.6 Compatible
# Installs Docker and pulls MDCA log collector image
set -e

# Check if running with sudo privileges
if [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run with sudo privileges"
    echo "Usage: sudo $0"
    exit 1
fi

# Check if system is RHEL
if [ ! -f /etc/redhat-release ]; then
    echo "Error: This script is designed for Red Hat Enterprise Linux (RHEL) systems only"
    echo "Current system is not RHEL compatible"
    exit 1
fi

# Verify RHEL version (should be 9.x)
if ! grep -q "Red Hat Enterprise Linux" /etc/redhat-release; then
    echo "Error: This script requires Red Hat Enterprise Linux"
    echo "Detected system: $(cat /etc/redhat-release 2>/dev/null || echo 'Unknown')"
    exit 1
fi

# Variables
LOG_FILE="/var/log/init_script.log"
OS=$(cat /etc/redhat-release)
PUBLIC_IP=$(curl -s https://ipv4.icanhazip.com)

touch /home/$USER/.hushlogin
chown $USER:$USER /home/$USER/.hushlogin

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a $LOG_FILE
}

log_message "Starting MDCA Demo VM initialization: $OS"

# Update system packages
log_message "Updating system packages..."
dnf update -y

# Install required packages
log_message "Installing required packages..."
dnf install -y \
    curl \
    wget \
    unzip \
    dnf-plugins-core \
    python3-devel \
    python3-pip \
    git \
    vim \
    tree \
    net-tools \
    bind-utils \
    nc \
    dos2unix

# Enable EPEL repository for additional packages
log_message "Enabling EPEL repository..."
sudo dnf config-manager --set-enabled "codeready-builder-for-rhel-9-$(arch)-rhui-rpms" || true

# then install EPEL release
sudo dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm

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


# Set up firewall rules (if firewalld is enabled)
if systemctl is-active --quiet firewalld; then
    log_message "Configuring firewall rules..."
    firewall-cmd --permanent --add-port=22/tcp --zone=public
    firewall-cmd --permanent --add-port=514/udp --zone=public
    firewall-cmd --permanent --add-service=https --zone=public
    firewall-cmd --reload
fi

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

# Final system update
log_message "Final system cleanup..."
dnf autoremove -y
dnf clean all

# Create completion marker
log_message "MDCA Demo VM initialization completed successfully!"
touch "/home/$USER/.init_complete"
echo "$(date)" > "/home/$USER/.init_complete"


# Display summary
log_message "=== Initialization Summary ==="
log_message "✓ System packages updated"
log_message "✓ Docker installed and configured"
log_message "✓ MDCA log collector image pulled"
log_message "✓ User $USER added to docker group"
log_message "✓ Firewall configured (if firewalld enabled)"
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
