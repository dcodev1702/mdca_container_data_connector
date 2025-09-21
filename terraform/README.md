# MDCA Demo Terraform Deployment

This Terraform configuration creates a complete Azure infrastructure for Microsoft Defender for Cloud Apps (MDCA) log collector demonstration.

## What Gets Created

- **Resource Group**: `mdca-demo-rg-<random>`
- **Virtual Network**: `mdca-demo-vnet-<random>` (10.0.0.0/16)
- **Subnet**: `mdca-demo-subnet-<random>` (10.0.1.0/24)
- **Network Security Group**: `mdca-demo-nsg-<random>`
  - SSH (22/tcp) from your current WAN IP
  - Syslog (514/udp) from Linux VM
- **Virtual Machine**: `mdca-demo-vm-<random>`
  - Type: Standard_D2s_v3
  - OS: Ubuntu 24.04 LTS
  - Disk: 128 GB Premium SSD
  - User: lorenzoadm
  - System Managed Identity enabled
- **SSH Key Pair**: RSA 4096-bit saved to `C:\Users\User\.ssh\`
- **Public IP**: Static IP for VM access
- **SSH Config**: VS Code compatible configuration

## Prerequisites

1. **Azure Subscription** and appropriate permissions to deploy resources
2. **Azure CLI** [installed](https://learn.microsoft.com/en-us/cli/azure/?view=azure-cli-latest) and authenticated
3. **Terraform** [installed](https://developer.hashicorp.com/terraform/install) (version >= 1.0)
5. **Windows machine** with `C:\Users\User\.ssh\` directory

## Deployment Steps

### 1. Clone and Prepare

```bash
# Clone your repository or download files
# Ensure all .tf and .tpl files are in the same directory
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
- Resource names include random suffix
- VM specifications match requirements

### 4. Deploy Infrastructure

```bash
terraform apply
```

Type `yes` when prompted. Deployment takes 5-10 minutes.

### 5. Collect Outputs

After successful deployment, note these important outputs:
- **VM Public IP**: For SSH and syslog configuration
- **SSH Command**: Ready-to-use connection command
- **SSH Config File**: Location for VS Code setup
- **Docker Command**: Template for MDCA log collector

## Post-Deployment Setup

### 1. Verify VM Access

```bash
# Use the SSH command from terraform output
ssh -i C:/Users/User/.ssh/mdca-demo-ub24-<suffix>_key.pem lorenzoadm@<PUBLIC_IP>
```

### 2. Check Initialization

```bash
# On the VM, check if initialization completed
cat /var/log/init_script.log
ls -la /opt/mdca/.init_complete
```

### 3. Verify Docker

```bash
# Check Docker installation and MDCA image
docker --version
docker images | grep logcollector
```

### 4. Run System Info

```bash
# Execute the system information script
/opt/mdca/system_info.sh
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

## MDCA Log Collector Deployment

### 1. Get MDCA Credentials

From the MDCA portal:
1. Navigate to **Settings** → **Log collectors**
2. Create or select your log collector
3. Copy the **authentication token**
4. Note your **tenant URL**

### 2. Deploy Container

Use the helper script on the VM:
```bash
/opt/mdca/deploy_collector.sh <YOUR_AUTH_TOKEN>
```

Or use the full Docker command from terraform output.

### 3. Verify Deployment

```bash
# Check container status
docker logs cisco_asa_fp_logcollector

# Enter container
docker exec -it cisco_asa_fp_logcollector bash

# Check message collection
cd /var/adallom/syslog/514
ls -lah messages
```

## Testing Syslog Ingestion

### 1. Send Test Message

```bash
# From any machine that can reach the VM
echo '<14>Test syslog message from Cisco ASA' | timeout 0.2 nc -u $PUBLIC_IP 514
```

### 2. Monitor Collection

```bash
# On the VM, watch the messages file (has to be greater than 40 KB)
watch -n 5 'ls -lah /var/adallom/syslog/514/messages'

# View real-time syslog
tail -f /var/adallom/syslog/514/messages
```

### 3. Use Test Script

Copy your test script to the VM and run:
```bash
# Upload your mdca_send_msgs.sh
scp mdca_send_msgs.sh lorenzoadm@<VM_PUBLIC_IP>:/tmp/
ssh lorenzoadm@<VM_PUBLIC_IP>
chmod +x /tmp/mdca_send_msgs.sh
cd /tmp && ./mdca_send_msgs.sh
```

## Customization

### Variables

Modify `terraform.tfvars` to customize deployment:
```hcl
location = "East US 2"
vm_size = "Standard_B2s"
admin_username = "azureuser"
os_disk_size_gb = 128
```

### Network Security

For production, restrict syslog sources:
```hcl
allow_syslog_from_any = false
# Then manually add specific source IPs to NSG
```

## Troubleshooting

### Common Issues

**SSH Connection Failed:**
```bash
# Check if your IP changed
curl https://ipv4.icanhazip.com
# Update NSG rule if needed
```

**Docker Not Found:**
```bash
# Check initialization status
cat /var/log/init_script.log | grep -i error
```

**Container Won't Start:**
```bash
# Check Docker logs
docker logs cisco_asa_fp_logcollector
# Verify auth token and parameters
```

**No Syslog Data:**
```bash
# Test network connectivity
nc -u -v <VM_PUBLIC_IP> 514
# Check NSG rules in Azure portal
```

### Log Locations

- **Init Script**: `/var/log/init_script.log`
- **MDCA Demo**: `/var/log/mdca-demo.log`
- **Docker**: `docker logs <container>`
- **Syslog Messages**: `/var/adallom/syslog/514/messages`

## Cleanup

To destroy all created resources:
```bash
terraform destroy
```

**Note**: This will permanently delete all resources and data.

## File Structure

```
terraform-mdca-demo/
├── main.tf                    # Main Terraform configuration
├── variables.tf               # Variable definitions
├── outputs.tf                 # Output values
├── init_script.tpl           # VM initialization script
├── windows_ssh_vscode.tpl    # SSH config template
└── README.md                 # This file
```

## Support

For issues:
- **Terraform**: Check official documentation
- **Azure**: Azure support portal
- **MDCA**: Microsoft support
- **Docker**: Docker documentation

---

**Version**: 1.0  
**Compatible with**: Terraform >= 1.0, Azure Provider ~> 3.0
