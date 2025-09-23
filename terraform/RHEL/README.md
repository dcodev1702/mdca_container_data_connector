# MDCA Demo via Terraform Deployment - RHEL 9.6

This Terraform configuration creates a complete Azure infrastructure for Microsoft Defender for Cloud Apps (MDCA) log collector demonstration using **Red Hat Enterprise Linux 9.6**.

## What Gets Provisioned in Azure

- **Resource Group**: `mdca-demo-rg-<random>`
- **Virtual Network**: `mdca-demo-vnet-<random>` (10.0.0.0/16)
- **Subnet**: `mdca-demo-subnet-<random>` (10.0.1.0/24)
- **Network Security Group**: `mdca-demo-nsg-<random>`
  - SSH (22/tcp) from your current WAN IP
  - Syslog (514/udp) from your current WAN IP to VM private IP (10.0.1.4)
- **Virtual Machine**: `mdca-demo-vm-<random>`
  - Type: Standard_D2s_v3 (configurable via variables)
  - OS: **Red Hat Enterprise Linux 9.6** (9-lvm-gen2)
  - Disk: 128 GB Premium SSD
  - User: lorenzoadm (configurable via variables)
  - System Managed Identity enabled
  - Static Private IP: 10.0.1.4
- **SSH Key Pair**: RSA 4096-bit saved to `C:\Users\User\.ssh\`
- **Public IP**: Static IP for VM access
- **SSH Config**: VS Code compatible configuration
- **Test Data Files**: Cisco ASA FirePower log files automatically uploaded to VM
- **MDCA Log Collector**: Automatically deployed and configured Docker container (SYSLOG 514:UDP)

## RHEL 9.6 Specific Features

This version is specifically designed for Red Hat Enterprise Linux 9.6 with the following differences from the Ubuntu version:

### Package Management
- Uses **DNF** instead of APT for package management
- Enables **EPEL repository** for additional packages
- Installs RHEL-compatible package names

### Firewall Management
- Uses **firewalld** instead of ufw for firewall configuration
- Automatically configures firewall rules for SSH and Syslog if firewalld is active

### System Configuration
- **SELinux** is enabled by default (Docker containers run with --privileged)
- No AppArmor removal needed (not present on RHEL)
- Optimized for Red Hat package ecosystem

### Docker Installation
- Uses official Docker repository for RHEL
- Installs docker-ce, docker-ce-cli, containerd.io, docker-buildx-plugin, docker-compose-plugin

## Prerequisites

1. **Azure Subscription** and appropriate permissions to deploy resources
2. **Azure CLI** [installed](https://learn.microsoft.com/en-us/cli/azure/?view=azure-cli-latest) and authenticated
3. **Terraform** [installed](https://developer.hashicorp.com/terraform/install) (version >= 1.0)
4. **Windows machine** with `C:\Users\User\.ssh\` directory
5. **MDCA Authentication Token** from Microsoft Defender XDR Portal
6. **MDCA Console URL** (e.g., `<tenant>.us3.portal.cloudappsecurity.com`)

## Configuration Setup

### 1. Configure Variables

Edit `terraform.tfvars` with your specific values:

```hcl
# MDCA Configuration (REQUIRED)
mdca_auth_token     = "YOUR_64_CHARACTER_HEX_TOKEN_HERE"
mdca_console_url    = "<YOUR_TENANT>.us3.portal.cloudappsecurity.com"
mdca_collector_name = "CISCO_FP_TFAI"

# Azure Infrastructure
vm_username    = "lorenzoadm"
admin_username = "lorenzoadm"
location       = "East US 2"
vm_size        = "Standard_D2s_v3"
tag_env        = "Demo"
tag_proj       = "MDCA"

# Network Configuration
network_vnet_cidr = ["10.0.0.0/16"]
vm_subnet_cidr    = ["10.0.1.0/24"]
vm_private_ip     = "10.0.1.4"
```

## Deployment Steps

### 1. Initialize Terraform

```bash
terraform init
```

### 2. Plan Deployment

```bash
terraform plan
```

### 3. Deploy Infrastructure

```bash
terraform apply -auto-approve
```

Deployment takes 10-15 minutes including:
- Azure infrastructure provisioning
- RHEL 9.6 VM initialization with Docker
- MDCA log collector deployment
- Test data file upload

## Post-Deployment Verification

### 1. Verify VM Access

```bash
# Use the SSH command from terraform output
ssh -i C:/Users/User/.ssh/mdca-demo-rhel96-<suffix>_key.pem lorenzoadm@<PUBLIC_IP>
```

### 2. Check RHEL Version

```bash
# Verify RHEL version
cat /etc/redhat-release
# Should show: Red Hat Enterprise Linux release 9.6

# Check kernel version
uname -r
```

### 3. Check Initialization Status

```bash
# On the VM, check if initialization completed successfully
cat /var/log/init_script.log | tail -20
ls -la /home/lorenzoadm/mdca/.init_complete
```

### 4. Verify MDCA Log Collector

```bash
# Check if MDCA container is running
docker ps | grep logcollector

# Check container logs
docker logs CISCO_FP_TFAI

# Verify collector is communicating with MDCA
docker exec -it CISCO_FP_TFAI bash
cd /var/adallom/syslog/514
ls -lah messages
```

### 5. Monitor Log Collection (INBOUND 514:UDP / OUTBOUND 443:TCP:TLS1.2)
```
# Watch message file growth (must be > 40KB)
watch -n 5 'ls -lah /var/adallom/syslog/514/messages'

# View real-time logs (INBOUND [514:UDP] TO MDCA LOG COLLECTOR CONTAINER)
tail -f /var/adallom/syslog/514/messages

# View real-time logs (OUTBOUND [443:TCP/TLS1.2] TO DEFENDER XDR -> MDCA)
tail -f /var/log/adallom/columbus/trace.log
```

## RHEL-Specific Commands

### Package Management

```bash
# Update packages
sudo dnf update -y

# Install packages
sudo dnf install -y package-name

# Search for packages
dnf search package-name

# List installed packages
dnf list installed
```

### Firewall Management

```bash
# Check firewall status
sudo systemctl status firewalld

# List active zones and rules
sudo firewall-cmd --list-all

# Add permanent rule
sudo firewall-cmd --permanent --add-port=514/udp --zone=public
sudo firewall-cmd --reload
```

### SELinux Management

```bash
# Check SELinux status
sestatus

# View SELinux context
ls -Z /path/to/file

# Set SELinux to permissive (if needed)
sudo setenforce 0
```

## Troubleshooting RHEL-Specific Issues

### Docker Permission Issues

```bash
# If docker commands fail, ensure user is in docker group
sudo usermod -aG docker $USER
# Logout and login again, or use:
newgrp docker
```

### Firewall Blocking Connections

```bash
# Check if firewalld is blocking connections
sudo firewall-cmd --list-ports
sudo firewall-cmd --list-services

# Temporarily disable firewall for testing
sudo systemctl stop firewalld
```

### SELinux Blocking Docker

```bash
# Check SELinux denials
sudo ausearch -m avc -ts recent

# If needed, set SELinux to permissive for Docker
sudo setsebool -P container_manage_cgroup true
```

### Package Installation Failures

```bash
# Enable additional repositories if needed
sudo dnf install -y epel-release
sudo dnf config-manager --enable rhel-9-server-extras-rpms
```

## File Structure

```
RHEL/
├── main.tf                      # Main Terraform configuration (RHEL 9.6)
├── variables.tf                 # Variable definitions
├── outputs.tf                   # Output values
├── terraform.tfvars             # Configuration values
├── init_script.tpl              # VM initialization script (DNF-based)
├── windows_ssh_vscode.tpl       # SSH config template
├── vm_files/                    # Files uploaded to VM
│   ├── mdca_send_msgs.sh        # Syslog test script
│   ├── cisco_asa_fp_c.ai.log    # Test log file (smaller)
│   └── cisco_asa_fp_c.ai2k.log  # Test log file (larger)
└── README.md                    # This file
```

## Key Differences from Ubuntu Version

| Feature | Ubuntu 24.04 | RHEL 9.6 |
|---------|-------------|-----------|
| Package Manager | apt/apt-get | dnf |
| Firewall | ufw | firewalld |
| Security | AppArmor | SELinux |
| Base Image | ubuntu-24_04-lts | RHEL:9-lvm-gen2 |
| SSH Key Name | mdca-demo-ub24-* | mdca-demo-rhel96-* |
| Publisher | Canonical | RedHat |

## Support

For RHEL-specific issues:
- **Red Hat Documentation**: [Red Hat Enterprise Linux 9](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9)
- **RHEL Support**: [Red Hat Customer Portal](https://access.redhat.com/)

For general issues:
- **Terraform**: [Terraform Documentation](https://developer.hashicorp.com/terraform/docs)
- **Azure**: [Azure Support Portal](https://portal.azure.com/#blade/Microsoft_Azure_Support/HelpAndSupportBlade)
- **Microsoft Defender for Cloud Apps**: [Microsoft Support](https://support.microsoft.com/)

---

**Version**: 2.0 RHEL  
**Compatible with**: Terraform >= 1.0, Azure Provider ~> 3.0, RHEL 9.6  
**Last Updated**: RHEL 9.6 compatible version with DNF package management
