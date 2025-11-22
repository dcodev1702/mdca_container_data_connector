# Microsoft Defender for Cloud Apps (MDCA) Log Collector Manual Setup

This guide provides step-by-step instructions for manually deploying an MDCA log collector on a Linux VM in Azure for ingesting Cisco ASA Firepower logs.

## Prerequisites

### Azure Requirements
- **Azure Subscription** with appropriate permissions
- Ability to create resources in Azure:
  - Virtual Machines
  - Network Security Groups
  - Virtual Networks
  - Public IP addresses

### System Requirements
- **Linux VM** running one of the following:
  - Red Hat Enterprise Linux (RHEL) 9.x - Gen2
  - Ubuntu 24.04 LTS - Gen2
- **VM Specifications**: Minimum 2 vCPU, 8GB RAM, 128GB storage
- **Network Access**: Internet connectivity for downloading Docker and MDCA images

### Technical Knowledge
- Linux System Administration
- Basic Containerization concepts (Docker)
- Bash scripting
- Networking fundamentals (syslog, UDP/TCP)
- SSH key management

## Step 1: Create Azure Linux VM

1. **Create a new Linux VM** in Azure portal
2. **Select OS Image**:
   - Red Hat Enterprise Linux 9.x, or
   - Ubuntu Server 24.04 LTS
3. **Configure authentication** using SSH public key
4. **Configure networking**:
   - Create or use existing Virtual Network
   - Configure Network Security Group to allow:
     - SSH (port 22/TCP)
     - Syslog (port 514/UDP)
     - HTTPS outbound (port 443/TCP)
5. **Note the public IP address** for SSH access

## Step 2: Connect to VM and Setup Repository

1. **SSH to your VM**:
   ```bash
   ssh -i <your-private-key> <username>@<vm-public-ip>
   ```

2. **Clone this repository** (or manually create the directory structure):
   ```bash
   git clone <repository-url>
   cd <repository-name>
   ```

3. **Set up the required directory structure**:
   ```bash
   # Create directories in user home directory
   mkdir -p ~/mdca
   mkdir -p ~/data
   
   # Copy files to correct locations
   cp manual/mdca/* ~/mdca/
   cp manual/data/* ~/data/
   cp manual/mdca_send_msgs.sh ~/
   
   # Make scripts executable
   chmod +x ~/mdca/*.sh
   chmod +x ~/mdca_send_msgs.sh
   ```

## Step 3: Run System Initialization Script

Choose the appropriate initialization script for your Linux distribution:

### For Ubuntu 24.04 LTS:
```bash
# APPARMOR PROFILE WILL PREVENT MESSAGES ON SYSLOG 514/UDP FROM GETTING PROCESSED
# DO THE FOLLOWING SO MESSAGES ARE PROPERLY PROCESSED BY THE MDCA LOG COLLECTOR

# Disable the profile again
sudo apparmor_parser -R /etc/apparmor.d/usr.sbin.rsyslogd

# Make it permanent - prevent it from loading on boot
sudo ln -s /etc/apparmor.d/usr.sbin.rsyslogd /etc/apparmor.d/disable/usr.sbin.rsyslogd
```

```bash
# OR completely remove the profile
sudo rm /etc/apparmor.d/usr.sbin.rsyslogd
sudo systemctl reload apparmor
```

```bash
# Restart the docker container
docker restart CISCO-ASA-FP
```

### For RHEL 9.x:
```bash
sudo ./manual/init_script_rhel.sh
```

### What the initialization script does:
- Updates system packages
- Installs Docker and required dependencies
- Pulls the MDCA log collector image
- Configures firewall rules
- Sets up useful aliases
- Creates necessary directories

**Important**: After the script completes, **reboot the VM** to ensure all services start properly:
```bash
sudo reboot
```

## Step 4: Configure MDCA Log Collector

1. **SSH back to the VM** after reboot
2. **Edit the deployment script** with your MDCA details:
   ```bash
   nano ~/mdca/deploy_mdca_log_collector.sh
   ```

3. **Update the following variables**:
   ```bash
   MDCA_AUTH_TOKEN="YOUR_64_CHAR_HEX_TOKEN_HERE"
   MDCA_CONSOLE_URL="<TENANT_NAME>.<REGION>.portal.cloudappsecurity.com"
   MDCA_COLLECTOR_NAME="<UNIQUE_COLLECTOR_NAME>"
   ```

   **Example**:
   ```bash
   MDCA_AUTH_TOKEN="1a2b3c4d5e6f7890abcdef1234567890abcdef1234567890abcdef1234567890"
   MDCA_CONSOLE_URL="contoso.us3.portal.cloudappsecurity.com"
   MDCA_COLLECTOR_NAME="CISCO-ASA-FP"
   ```

## Step 5: Deploy MDCA Log Collector

1. **Run the deployment script**:
   ```bash
   cd ~
   ./mdca/deploy_mdca_log_collector.sh
   ```

2. **Verify the container is running**:
   ```bash
   docker ps | grep logcollector
   ```

3. **Check container logs**:
   ```bash
   docker logs -f CISCO-ASA-FP
   ```

   **Expected output should include**:
   - Successful authentication to MDCA console
   - Syslog listener started on port 514
   - Connection established to Microsoft cloud

## Step 6: Send Test Data

1. **Run the message sender script**:
   ```bash
   ./mdca_send_msgs.sh
   ```

   This script will:
   - Read Cisco ASA Firepower logs from `~/data/cisco_asa_fp_c.ai.log`
   - Send each log entry via syslog (UDP/514) to the local MDCA collector
   - Display progress as messages are sent

2. **Monitor the sending process**:
   ```bash
   # In another terminal session, watch container logs
   docker logs -f CISCO_FP_TFAI
   ```

### Verify MDCA Log Collector

```bash
# Check if MDCA container is running
docker ps | grep logcollector

# Check container logs
docker logs -f CISCO-ASA-FP

# Verify collector is communicating with MDCA
docker exec -it CISCO-ASA-FP bash
cd /var/adallom/syslog/514
ls -lah messages

# Get detailed container information
docker inspect CISCO-ASA-FP
```

### Monitor Log Collection (INBOUND 514:UDP / OUTBOUND 443:TCP:TLS1.2)
```
# Validate inbound/outbound inside MDCA Log Collector Container
docker exec -it CISCO-ASA-FP bash

# Watch message file growth (must be > 40KB)
watch -n 5 'ls -lah /var/adallom/syslog/514/messages'

# View real-time logs (INBOUND [514:UDP] TO MDCA LOG COLLECTOR CONTAINER)
tail -f /var/adallom/syslog/514/messages

# View real-time logs (OUTBOUND [443:TCP/TLS1.2] TO DEFENDER XDR -> MDCA)
tail -f /var/log/adallom/columbus/trace.log
```

### Messages Successfully Uploaded to MDCA via the MDCA Log Collector
```bash
docker exec -it CISCO-ASA-FP tail -f /var/log/adallom/columbus/trace.log
```
<img width="2063" height="621" alt="image" src="https://github.com/user-attachments/assets/a8e6fe2f-ada8-4939-8ab8-d27efb965cde" />

### DATA SOURCE
<img width="1806" height="878" alt="image" src="https://github.com/user-attachments/assets/fdddf93f-c00a-4a78-9eb9-2d13abbcf2bd" />

### LOG COLLECTOR (SYSLOG 10.0.0.9:514/UDP)
<img width="1477" height="467" alt="image" src="https://github.com/user-attachments/assets/0fe9785a-afa2-4faa-b92f-dda05bde3535" />


### Network Connectivity
```bash
# Verify syslog port is listening
netstat -tuln | grep 514

# Check outbound HTTPS connections to Microsoft
netstat -peaultn | grep 443

# Test local syslog connectivity
echo "test message" | nc -u localhost 514
```

### System Resource Usage
```bash
# Check system resources
./mdca/system_info.sh

# Monitor Docker container resources
docker stats CISCO-ASA-FP
```

### Log Verification in MDCA Portal
1. **Login to Microsoft Defender for Cloud Apps portal**
2. **Navigate to**: Settings → Security extensions → Automatic log upload
3. **Verify your log collector** shows as "Connected"
4. **Check data sources** under your collector configuration
5. **Review Activity Log** for incoming Cisco ASA data

## Troubleshooting

### Container Won't Start
```bash
# Remove existing container and redeploy
docker rm -f CISCO-ASA-FP
./mdca/deploy_mdca_log_collector.sh

# Check Docker daemon status
sudo systemctl status docker
```

### No Data in MDCA Portal
```bash
# Verify container logs for authentication errors
docker logs CISCO-ASA-FP | grep -i error

# Test local syslog reception
tcpdump -i any port 514 -v

# Check firewall rules
sudo ufw status  # Ubuntu
sudo firewall-cmd --list-all  # RHEL
```

### Network Connectivity Issues
```bash
# Test outbound HTTPS connectivity
curl -v https://portal.cloudappsecurity.com

# Verify DNS resolution
nslookup <your-tenant>.portal.cloudappsecurity.com

# Check routing
ip route show
```

## Useful Commands and Aliases

The initialization script creates helpful aliases:

```bash
# MDCA specific aliases
mdca-logs        # View container logs
mdca-exec        # Execute commands in container
mdca-status      # Check container status
mdca-remove      # Remove container

# Docker aliases
dps              # Docker process status
dpsa             # Docker process status (all)
di               # Docker images
dlog             # Docker logs

# System monitoring
ports            # Show listening ports
diskspace        # Show disk usage
meminfo          # Show memory usage
```

## File Structure

After setup, your directory structure should look like:

```
~/
├── mdca/
│   ├── deploy_mdca_log_collector.sh
│   └── system_info.sh
├── data/
│   ├── cisco_asa_fp_c.ai.log
│   └── cisco_asa_fp_fullLog.log
└── mdca_send_msgs.sh
└── init_script_ubuntu.sh
```

## Security Considerations

- **SSH Keys**: Use strong SSH key pairs and protect private keys
- **Firewall**: Only open necessary ports (22, 514, 443)
- **Updates**: Keep VM and Docker updated regularly
- **Monitoring**: Monitor container logs for security events
- **Access**: Limit VM access to authorized personnel only

## Support and Additional Resources

- **Microsoft Defender for Cloud Apps Documentation**: [Microsoft Learn](https://learn.microsoft.com/en-us/defender-cloud-apps/)
- **Docker Documentation**: [Docker Docs](https://docs.docker.com/)
- **Azure VM Documentation**: [Azure Virtual Machines](https://learn.microsoft.com/en-us/azure/virtual-machines/)

---

**Note**: This manual setup process is ideal for development, testing, or environments where automation tools are not available. For production deployments, consider using Infrastructure as Code tools like Terraform or ARM templates for consistent and repeatable deployments.
