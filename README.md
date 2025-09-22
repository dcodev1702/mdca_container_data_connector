# Microsoft Defender for Cloud Apps - Cisco ASA FirePOWER Log Collector

This repository provides a complete guide for deploying Microsoft Defender for Cloud Apps (MDCA) log collector to ingest Cisco ASA FirePOWER syslog data on Azure Ubuntu VMs.

## Prerequisites

- Azure subscription with VM deployment permissions
- Microsoft Defender for Cloud Apps license
- Cisco ASA FirePOWER appliance configured for syslog
- SSH access to Ubuntu VM
- Basic knowledge of Docker and syslog

## Architecture Overview

The solution consists of:
- Azure Ubuntu VM running Docker
- MDCA log collector container listening on UDP 514
- Cisco ASA FirePOWER sending syslog to collector
- Automated log processing and upload to MDCA portal

## Quick Start

### 1. Azure VM Setup

Deploy an Ubuntu 24.04+ VM in Azure with the following specifications:
- **Size**: Standard_D2s (minimum)
- **Storage**: 128GB Premium SSD
- **Network**: Allow inbound UDP 514 and SSH 22
- **Public IP**: Required for syslog ingestion
- **Proxy**: If required
- **SSL Certs**: If required

### 2. Network Security Group Configuration

Configure NSG rules:
```bash
# Get your public IP
curl -s https://ipv4.icanhazip.com

# Configure NSG to allow:
# - SSH (22/tcp) from your IP
# - Syslog (514/udp) for log collector network appliance
```

### 3. Docker Installation

Connect to your VM and install Docker:
```bash
# Download Docker installation script
curl -fsSL https://get.docker.com -o get-docker.sh

# Install Docker
sh get-docker.sh

# Add current user to docker group (optional)
sudo usermod -aG docker $USER
```

### 4. MDCA Log Collector Deployment

Deploy the log collector container:
PUBLICIP: The VM'S PRIVATE IP used to configure the data connector in MDCA.
AUTH_TOKEN: The value provided via (echo 918285354a40f0ceda695e162befd26b65bde8d0e8de5b0f80a63a1c254e65ca) from MDCA Setup / Data Connector
```bash
docker run -d \
  --name cisco_asa_fp_logcollector \
  --privileged \
  -p 514:514/udp \
  -e "PUBLIC_IP='10.0.0.4'" \
  -e "PROXY=" \
  -e "SYSLOG=true" \
  -e "CONSOLE=<YOUR_MDCA_TENANT>.portal.cloudappsecurity.com" \
  -e "COLLECTOR=cisco_asa_fp_logcollector" \
  --cap-add=SYS_ADMIN \
  --cap-add=SYSLOG \
  --restart unless-stopped \
  mcr.microsoft.com/mcas/logcollector \
  /bin/bash -c 'echo "<YOUR_AUTH_TOKEN>" | /etc/adallom/scripts/starter'
```

**Required Parameters:**
- `<YOUR_VM_PUBLIC_IP>`: Azure VM's public IP address
- `<YOUR_VM_PRIVATE_IP>`: Azure VM's private IP address
- `<YOUR_MDCA_TENANT>`: Your MDCA tenant identifier
- `<YOUR_AUTH_TOKEN>`: Authentication token from MDCA portal

### 5. Verification

Check deployment status:
```bash
# View container logs
docker logs cisco_asa_fp_logcollector

# Access container shell
docker exec -it cisco_asa_fp_logcollector bash

# Check syslog message collection
cd /var/adallom/syslog/514
ls -lah messages
```

## Configuration Details

### MDCA Portal Setup

1. Navigate to **Settings** → **Log collectors**
2. Click **Add log collector**
3. Configure data source:
   - **Name**: `CISCO-ASA-FP`
   - **Source**: `Cisco ASA FirePOWER`
   - **Receiver type**: `Syslog`
4. Copy the generated authentication token

### Cisco ASA FirePOWER Configuration

Configure syslog forwarding to your Azure VM:
```
logging host <AZURE_VM_PUBLIC_IP> 
logging trap informational
logging facility 16
```

### VS Code Remote Development

For easier management, use VS Code with Remote-SSH extension:

1. **Install Extension**: [Remote - SSH](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-ssh)

2. **SSH Config** (`~/.ssh/config`):
```
Host azure-mdca-vm
    HostName <YOUR_VM_PUBLIC_IP>
    User azureuser
    IdentityFile ~/.ssh/<YOUR_PRIVATE_KEY>.pem
    IdentitiesOnly yes
    StrictHostKeyChecking no
```

3. **Connect**: `Ctrl+Shift+P` → "Remote-SSH: Connect to Host"

## Testing and Validation

### Test Script Usage on your Azure Linux VM (Ubuntu 24.04 LTS)

Use the included test script to simulate syslog traffic:

```bash
# Make script executable
chmod +x mdca_send_msgs.sh

# Run test
./mdca_send_msgs.sh
```

The script sends sample Cisco ASA FirePOWER logs to the collector for testing.

### Monitoring Log Ingestion

Monitor the collection process:
```bash
# Watch message file growth
watch -n 5 'ls -lah /var/adallom/syslog/514/messages'

# View real-time logs
tail -f /var/adallom/syslog/514/messages
```

**Note**: Files rotate and upload to MDCA when they exceed 40KB.

### MDCA Portal Verification

1. Navigate to **Data sources** tab
2. Verify collector shows **Connected** status
   <img width="1104" height="456" alt="image (1)" src="https://github.com/user-attachments/assets/39657554-c60f-4a34-889c-5363f83e54e0" />

4. Check **Last data received** timestamp
5. Monitor **Uploaded logs** count
   <img width="1140" height="431" alt="image" src="https://github.com/user-attachments/assets/cf7898f8-205d-4749-94b6-534bb29a941b" />


## Troubleshooting

### Common Issues

**Container won't start:**
```bash
# Check container status
docker ps -a

# View detailed logs
docker logs cisco_asa_fp_logcollector

# Remove and recreate
docker rm -f cisco_asa_fp_logcollector
```

**No syslog data received:**
```bash
# Test network connectivity
nc -u -l 514

# Check iptables/firewall
sudo iptables -L

# Verify NSG rules in Azure portal
```

**Authentication issues:**
- Verify auth token is current (tokens expire)
- Check MDCA tenant URL format
- Ensure collector name matches portal configuration

### Container Management

**Stop and remove container:**
```bash
docker rm -f cisco_asa_fp_logcollector
```

**Update collector:**
```bash
# Remove old container
docker rm -f cisco_asa_fp_logcollector

# Pull latest image
docker pull mcr.microsoft.com/mcas/logcollector

# Redeploy with same command
```

## File Structure

```
repository/
├── README.md                      # This guide
├── mdca_send_msgs.sh             # Test script for sending sample logs
├── cisco_asa_fp_c_ai2k.log       # Sample Cisco ASA FirePOWER logs
└── deployment/
    ├── docker-compose.yml        # Alternative deployment method
    └── azure-deploy.json         # ARM template for Azure deployment
```

## References

- [MDCA Docker Ubuntu Documentation](https://learn.microsoft.com/en-us/defender-cloud-apps/discovery-docker-ubuntu-azure?tabs=ubuntu)
- [Docker Installation Guide](https://github.com/docker/docker-install)
- [VS Code Remote-SSH Extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-ssh)
- [Cisco ASA Syslog Configuration](https://www.cisco.com/c/en/us/support/docs/security/asa-5500-x-series-next-generation-firewalls/118046-configure-asa-00.html)

## Support

For issues related to:
- **MDCA**: Microsoft Support Portal
- **Azure**: Azure Support
- **Cisco ASA**: Cisco TAC
- **This Repository**: Open an issue on GitHub

---

**Version**: 1.0  
**Last Updated**: September 2025  
**Compatibility**: Ubuntu 20.04+, Docker 20.10+, MDCA Current Version
