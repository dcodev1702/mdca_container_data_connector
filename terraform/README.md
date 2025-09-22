# MDCA Demo via Terraform Deployment

This Terraform configuration creates a complete Azure infrastructure for Microsoft Defender for Cloud Apps (MDCA) log collector demonstration.

## What Gets Provisioned in Azure

- **Resource Group**: `mdca-demo-rg-<random>`
- **Virtual Network**: `mdca-demo-vnet-<random>` (10.0.0.0/16)
- **Subnet**: `mdca-demo-subnet-<random>` (10.0.1.0/24)
- **Network Security Group**: `mdca-demo-nsg-<random>`
  - SSH (22/tcp) from your current WAN IP
  - Syslog (514/udp) from your current WAN IP to VM private IP (10.0.1.4)
- **Virtual Machine**: `mdca-demo-vm-<random>`
  - Type: Standard_D2s_v3 (configurable via variables)
  - OS: Ubuntu 24.04 LTS
  - Disk: 128 GB Premium SSD
  - User: lorenzoadm (configurable via variables)
  - System Managed Identity enabled
  - Static Private IP: 10.0.1.4
- **SSH Key Pair**: RSA 4096-bit saved to `C:\Users\User\.ssh\`
- **Public IP**: Static IP for VM access
- **SSH Config**: VS Code compatible configuration
- **Test Data Files**: Cisco ASA FirePower log files automatically uploaded to VM
- **MDCA Log Collector**: Automatically deployed and configured Docker container (SYSLOG 514:UDP)

## Prerequisites

1. **Azure Subscription** and appropriate permissions to deploy resources
2. **Azure CLI** [installed](https://learn.microsoft.com/en-us/cli/azure/?view=azure-cli-latest) and authenticated
3. **Terraform** [installed](https://developer.hashicorp.com/terraform/install) (version >= 1.0)
4. **Windows machine** with `C:\Users\User\.ssh\` directory
5. **MDCA Authentication Token** from Microsoft Defender XDR Portal
6. **MDCA Console URL** (e.g., `<tenant>.us3.portal.cloudappsecurity.com`)

<img width="1106" height="435" alt="image" src="https://github.com/user-attachments/assets/56f45ee7-759e-472d-9154-8016a8399ea6" />

<img width="1105" height="412" alt="image" src="https://github.com/user-attachments/assets/777c208a-01b8-4f75-b912-9e7c61f19225" />

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

### 2. Get MDCA Credentials

From the Microsoft Defender XDR Portal:
1. Navigate to **Settings** → **Microsoft Defender for Cloud Apps** → **Automatic log upload**
2. Create or select your log collector
3. Copy the **authentication token** (64-character hex string)
4. Note your **tenant URL** (format: `<tenant>.<region>.portal.cloudappsecurity.com`)

## Deployment Steps

### 1. Clone and Prepare

```bash
# Ensure all .tf, .tpl, and vm_files/* are in the same directory
# Directory structure should be:
# terraform-mdca-demo/
# ├── main.tf
# ├── variables.tf
# ├── outputs.tf
# ├── terraform.tfvars
# ├── init_script.tpl
# ├── windows_ssh_vscode.tpl
# └── vm_files/
#     ├── mdca_send_msgs.sh
#     ├── cisco_asa_fp_c.ai.log
#     └── cisco_asa_fp_c.ai2k.log
```

### 2. Initialize Terraform

```bash
terraform init
```

### 3. Plan Deployment

```bash
terraform plan
```

Review the plan to ensure:
- Your current IP is detected correctly
- MDCA variables are properly configured
- Resource names include random suffix
- VM specifications match requirements

### 4. Deploy Infrastructure

```bash
terraform apply -auto-approve
```

Type `yes` when prompted. Deployment takes 10-15 minutes including:
- Azure infrastructure provisioning
- VM initialization with Docker
- MDCA log collector deployment
- Test data file upload

### 5. Collect Outputs

After successful deployment, note these important outputs:
- **VM Public IP**: For SSH and syslog configuration
- **SSH Command**: Ready-to-use connection command
- **SSH Config File**: Location for VS Code setup
- **MDCA Docker Command**: Template with your collector details

## Post-Deployment Verification

### 1. Verify VM Access

```bash
# Use the SSH command from terraform output
ssh -i C:/Users/User/.ssh/mdca-demo-ub24-<suffix>_key.pem lorenzoadm@<PUBLIC_IP>
```

### 2. Check Initialization Status

```bash
# On the VM, check if initialization completed successfully
cat /var/log/init_script.log | tail -20
ls -la /home/lorenzoadm/mdca/.init_complete
```

### 3. Verify MDCA Log Collector

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

### 4. Test Data Files

```bash
# Verify test data files are uploaded
ls -lah /home/lorenzoadm/data/
# Should show:
# cisco_asa_fp_c.ai.log      (smaller test file)
# cisco_asa_fp_c.ai2k.log    (larger test file)
```

### 5. Run System Information

```bash
# Execute the system information script
/home/lorenzoadm/mdca/system_info.sh
```

### 6. Deployment of MDCA Log Collector via Docker Container 

```bash
# Deploy the MDCA Docker Container (listens on PRIVATE_IP:514:UDP)
/home/lorenzoadm/mdca/deploy_collector.sh
```

## VS Code Remote-SSH Setup

### 1. Install Extension

Install the **Remote - SSH** extension in VS Code:
- Extension ID: `ms-vscode-remote.remote-ssh`

### 2. Use Generated Config

The deployment creates an SSH config file at:
```
C:/Users/User/.ssh/mdca-demo-config-<suffix>
```

Copy this content to your main SSH config file:
```
C:/Users/User/.ssh/config
```

### 3. Connect

1. Press `Ctrl+Shift+P` in VS Code
2. Type "Remote-SSH: Connect to Host"
3. Select `mdca-demo-vm-<suffix>`
4. VS Code will connect to your Azure VM

## Testing Syslog Ingestion

### 1. Automated Test Script

The VM includes a pre-configured test script:

```bash
# Run the automated test script
cd /home/lorenzoadm
./mdca_send_msgs.sh
```

This script will:
- Send log messages from the uploaded Cisco ASA test file
- Use the correct target IP (VM's private IP)
- Send messages with appropriate delays

### 2. Manual Test Message

```bash
# Send a single test message from external machine
echo '<14>Test syslog message from Cisco ASA' | timeout 0.2 nc -u <VM_PUBLIC_IP> 514
```

### 3. Monitor Message Collection

```bash
# From the CLI of the VM, Docker Exec into the MDCA Container:
docker exec -it CISCO_FP_TFAI bash

# Watch the messages file (needs to be >40KB for MDCA processing)
watch -n 5 'ls -lah /var/adallom/syslog/514/messages'

# View real-time syslog ingestion
tail -f /var/adallom/syslog/514/messages

# Check message count
wc -l /var/adallom/syslog/514/messages
```

### 4. Alternative Test Data

```bash
# Use the larger test file for volume testing
INPUT_FILE="./data/cisco_asa_fp_c.ai2k.log" ./mdca_send_msgs.sh
```

## Key Features & Improvements

### Automated MDCA Container Deployment

- Container automatically deployed during VM initialization
- Uses provided authentication token and console URL
- Configured with proper network settings
- AppArmor removed to ensure rsyslog functionality

### Enhanced Security

- Network Security Group restricts syslog to your current IP
- SSH access limited to your current IP
- Static private IP assignment for consistent configuration

### Pre-loaded Test Data

- Cisco ASA FirePOWER log files automatically uploaded
- Ready-to-use test script for immediate validation
- Multiple file sizes for different testing scenarios

### Comprehensive Monitoring

- Detailed initialization logging
- Container health check aliases
- System information script for troubleshooting

## Customization

### Variables

Modify `terraform.tfvars` to customize deployment:
```hcl
# Change Azure region
location = "West US 2"

# Modify VM size
vm_size = "Standard_B2s"

# Change admin username
admin_username = "azureuser"
vm_username = "azureuser"

# Adjust disk size
os_disk_size_gb = 256

# Network customization
network_vnet_cidr = ["172.16.0.0/16"]
vm_subnet_cidr = ["172.16.1.0/24"]
vm_private_ip = "172.16.1.10"
```

### MDCA Collector Customization

The deployment script supports various collector configurations:
```bash
# Deploy with custom name
MDCA_COLLECTOR_NAME="CustomCollector" /home/lorenzoadm/mdca/deploy_collector.sh

# Deploy for different log sources
# (modify init_script.tpl to change container configuration)
```

### Network Security

For production environments, consider:
```hcl
# In variables.tf or terraform.tfvars
allow_syslog_from_any = false

# Then manually add specific source IP ranges to NSG rules
# via Azure Portal or additional Terraform resources
```

## Troubleshooting

### Common Issues

**MDCA Container Fails to Start:**
```bash
# Check authentication token format (should be 64-char hex)
echo $MDCA_AUTH_TOKEN | wc -c  # Should be 65 (including newline)

# Verify console URL format
echo $MDCA_CONSOLE_URL  # Should end with .portal.cloudappsecurity.com

# Check container logs for authentication errors
docker logs CISCO_FP_TFAI
```

**SSH Connection Failed:**
```bash
# Check if your IP changed
curl https://ipv4.icanhazip.com

# Compare with NSG rule in Azure Portal
# Update NSG rule if needed
```

**No Syslog Data Reaching Container:**
```bash
# Test network connectivity from external machine
nc -u -v <VM_PUBLIC_IP> 514

# Check NSG rules allow your current IP
# Verify container is listening on port 514
docker exec -it CISCO_FP_TFAI netstat -ulnp | grep 514
```

**MDCA Not Processing Messages:**
```bash
# Ensure messages file is >40KB
ls -lah /var/adallom/syslog/514/messages

# Check for AppArmor issues (should be removed)
aa-status  # Should show "apparmor module is not loaded"

# Verify rsyslog is running in container
docker exec -it CISCO_FP_TFAI ps aux | grep rsyslog
```

**Test Script Not Working:**
```bash
# Check script permissions
ls -la /home/lorenzoadm/mdca_send_msgs.sh

# Verify data files exist
ls -la /home/lorenzoadm/data/

# Run script with debug output
bash -x /home/lorenzoadm/mdca_send_msgs.sh
```

### Log Locations

- **VM Initialization**: `/var/log/init_script.log`
- **MDCA Container**: `docker logs CISCO_FP_TFAI`
- **Syslog Messages**: `/var/adallom/syslog/514/messages`
- **System Logs**: `/var/log/syslog`

### Validation Commands

```bash
# Complete health check
/home/lorenzoadm/mdca/system_info.sh

# Container status
docker ps -a | grep logcollector

# Deploy container
./mdca/deploy_collector.sh

# Network connectivity
ss -tulpn | grep :514

# Message processing status
find /var/adallom -name "messages" -exec ls -lah {} \; 2>/dev/null
```

## Cleanup

To destroy all created resources:
```bash
terraform destroy -auto-approve
```

**Warning**: This will permanently delete all resources, data, and configuration.

## File Structure

```
terraform-mdca-demo/
├── main.tf                      # Main Terraform configuration
├── variables.tf                 # Variable definitions
├── outputs.tf                   # Output values
├── terraform.tfvars             # Configuration values
├── init_script.tpl              # VM initialization script
├── windows_ssh_vscode.tpl       # SSH config template
├── vm_files/                    # Files uploaded to VM
│   ├── mdca_send_msgs.sh        # Syslog test script
│   ├── cisco_asa_fp_c.ai.log    # Test log file (smaller)
│   └── cisco_asa_fp_c.ai2k.log  # Test log file (larger)
└── README.md                    # This file
```

## Important Notes

### MDCA Authentication Token

- Must be exactly 64 hexadecimal characters
- Obtained from Defender XDR Portal → Settings → MDCA → Automatic log upload
- Token is sensitive and should be kept secure
- Invalid tokens will cause container deployment to fail

### Network Configuration

- VM uses static private IP (10.0.1.4) for consistent syslog targeting
- NSG automatically configured with your current public IP
- Syslog traffic only allowed from your current IP to VM private IP
- SSH access restricted to your current IP

### Container Behavior

- MDCA container requires >40KB of data before processing `/var/adallom/syslog/514/messages` begins
- AppArmor is automatically removed to prevent rsyslog issues
- Container automatically restarts unless stopped manually
- Syslog data is temporarily stored in `/var/adallom/syslog/514/messages` then to `/var/adallom/syslog/rotated/514/messages-DTG` before going to MDCA for analysis.

## Support

For issues related to:
- **Terraform**: [Terraform Documentation](https://developer.hashicorp.com/terraform/docs)
- **Azure**: [Azure Support Portal](https://portal.azure.com/#blade/Microsoft_Azure_Support/HelpAndSupportBlade)
- **Microsoft Defender for Cloud Apps**: [Microsoft Support](https://support.microsoft.com/)
- **Docker**: [Docker Documentation](https://docs.docker.com/)

---

**Version**: 2.0  
**Compatible with**: Terraform >= 1.0, Azure Provider ~> 3.0  
**Last Updated**: Based on enhanced configuration with automated MDCA deployment and test data integration
