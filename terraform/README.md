# MDCA Demo Infrastructure - Terraform Deployments

This repository contains Terraform configurations for deploying Microsoft Defender for Cloud Apps (MDCA) log collector demonstration environments on Azure. Choose between two supported Linux distributions based on your requirements.

## Platform Options

### 🐧 Ubuntu 24.04 LTS
**Recommended for**: General use, development environments, users familiar with Debian-based systems

- **Directory**: `Ubuntu/`
- **OS**: Ubuntu 24.04 LTS (Canonical)
- **Package Manager**: APT (apt-get)
- **Firewall**: UFW (Uncomplicated Firewall)
- **Security**: AppArmor (automatically removed for MDCA compatibility)
- **Best For**: Quick deployment, standard configurations, beginners

### 🎩 Red Hat Enterprise Linux 9.6
**Recommended for**: Enterprise environments, production deployments, RHEL-based infrastructure

- **Directory**: `RHEL/`
- **OS**: Red Hat Enterprise Linux 9.6
- **Package Manager**: DNF (Dandified YUM)
- **Firewall**: firewalld
- **Security**: SELinux (enabled by default)
- **Best For**: Enterprise environments, compliance requirements, RHEL ecosystems

## Quick Start

### 1. Choose Your Platform

Navigate to your preferred platform directory:

```bash
# For Ubuntu deployment
cd Ubuntu/

# For RHEL deployment
cd RHEL/
```

### 2. Configure Variables

Edit `terraform.tfvars` with your MDCA credentials and preferences:

```hcl
# MDCA Configuration (REQUIRED)
mdca_auth_token     = "YOUR_64_CHARACTER_HEX_TOKEN_HERE"
mdca_console_url    = "<YOUR_TENANT>.us3.portal.cloudappsecurity.com"
mdca_collector_name = "CISCO_FP_TFAI"

# Azure Infrastructure
vm_username    = "lorenzoadm"
location       = "East US 2"
vm_size        = "Standard_D2s_v3"
```

### 3. Deploy

```bash
az login
terraform init
terraform plan
terraform apply -auto-approve
```

## What Gets Deployed

Both platforms create identical Azure infrastructure:

- **Resource Group** with randomized suffix
- **Virtual Network** (10.0.0.0/16) with subnet (10.0.1.0/24)
- **Network Security Group** with SSH and Syslog rules
- **Virtual Machine** (Standard_D2s_v3, 128GB Premium SSD)
- **SSH Key Pair** (RSA 4096-bit, saved locally)
- **Public IP** with dynamic allocation
- **Private IP** with static allocation
- **MDCA Log Collector** Docker container (auto-deployed)
- **Test Data Files** (Cisco ASA FirePower logs)

## Key Differences

| Feature | Ubuntu 24.04 | RHEL 9.6 |
|---------|-------------|-----------|
| **Package Management** | `apt-get install package` | `dnf install package` |
| **Firewall** | `ufw allow 514/udp` | `firewall-cmd --add-port=514/udp` |
| **Security Framework** | AppArmor (removed) | SELinux (enabled) |
| **System Updates** | `apt-get update && apt-get upgrade` | `dnf update` |
| **Service Management** | `systemctl` (same) | `systemctl` (same) |
| **Container Runtime** | Docker CE | Docker CE |
| **SSH Key Naming** | `mdca-demo-ub24-*` | `mdca-demo-rhel96-*` |

## Prerequisites

### Required for Both Platforms

1. **Azure Subscription** with appropriate permissions
2. **Azure CLI** [installed](https://learn.microsoft.com/en-us/cli/azure/) and authenticated (`az login`)
3. **Terraform** [installed](https://developer.hashicorp.com/terraform/install) (version >= 1.0)
4. **Windows machine** with `C:\Users\User\.ssh\` directory
5. **MDCA Authentication Token** from Defender XDR Portal
6. **MDCA Console URL** (e.g., `tenant.us3.portal.cloudappsecurity.com`)

### Getting MDCA Credentials

1. Navigate to **Microsoft Defender XDR Portal**
2. Go to **Settings** → **Microsoft Defender for Cloud Apps** → **Automatic log upload**
3. Create or select your log collector
4. Copy the **authentication token** (64-character hex string)
5. Note your **tenant URL** format

## Platform-Specific Considerations

### Ubuntu 24.04 LTS
- **Pros**: Familiar package management, extensive documentation, quick deployment
- **Cons**: AppArmor conflicts require removal for MDCA functionality
- **Use Case**: Development, testing, proof-of-concept environments

### RHEL 9.6
- **Pros**: Enterprise-grade security, SELinux compatibility, corporate support
- **Cons**: Requires RHEL subscription awareness, more complex troubleshooting
- **Use Case**: Production deployments, enterprise environments, compliance requirements

## Post-Deployment Access

### SSH Connection
```bash
# Ubuntu
ssh -i C:/Users/User/.ssh/mdca-demo-ub24-<suffix>_key.pem lorenzoadm@<PUBLIC_IP>

# RHEL
ssh -i C:/Users/User/.ssh/mdca-demo-rhel96-<suffix>_key.pem lorenzoadm@<PUBLIC_IP>
```

### VS Code Remote-SSH
Both platforms generate SSH configuration files for VS Code integration:
- **Ubuntu**: `C:/Users/User/.ssh/mdca-demo-config-<suffix>`
- **RHEL**: `C:/Users/User/.ssh/mdca-demo-rhel96-config-<suffix>`

## Testing Syslog Integration

### Automated Test (Both Platforms)
```bash
# Run the included test script
./mdca_send_msgs.sh
```

### Manual Test
```bash
# Send single test message
echo '<14>Test syslog message' | timeout 0.2 nc -u <VM_PRIVATE_IP> 514
```

### Monitor Collection
```bash
# Access MDCA container
docker exec -it CISCO_FP_TFAI bash

# Monitor message collection (needs >40KB for MDCA processing)
tail -f /var/adallom/syslog/514/messages
watch -n 5 'ls -lah /var/adallom/syslog/514/messages'
```

## Troubleshooting

### Common Issues (Both Platforms)
- **Authentication Failures**: Verify 64-character hex token format
- **Network Connectivity**: Check NSG rules match your current IP
- **Container Issues**: Ensure Docker service is running

### Platform-Specific Issues

#### Ubuntu
```bash
# Check AppArmor status (should be removed)
aa-status  # Should show "apparmor module is not loaded"
```

#### RHEL
```bash
# Check SELinux status
sestatus

# Verify firewalld rules
sudo firewall-cmd --list-all
```

## Cleanup

To destroy all resources:
```bash
terraform destroy -auto-approve
```

⚠️ **Warning**: This permanently deletes all resources and data.

## Support & Documentation

- **Platform-Specific READMEs**: See `Ubuntu/README.md` or `RHEL/README.md` for detailed instructions
- **Terraform**: [Official Documentation](https://developer.hashicorp.com/terraform/docs)
- **Azure**: [Support Portal](https://portal.azure.com/#blade/Microsoft_Azure_Support/HelpAndSupportBlade)
- **MDCA**: [Microsoft Support](https://support.microsoft.com/)

## File Structure

```
terraform/
├── README.md                    # This overview (platform selection)
├── Ubuntu/                      # Ubuntu 24.04 LTS deployment
│   ├── README.md               # Ubuntu-specific documentation
│   ├── main.tf                 # Ubuntu Terraform configuration
│   ├── variables.tf            # Variable definitions
│   ├── outputs.tf              # Output values
│   ├── terraform.tfvars        # Configuration values
│   ├── init_script.tpl         # Ubuntu initialization script
│   ├── windows_ssh_vscode.tpl  # SSH config template
│   └── vm_files/               # Test data and scripts
└── RHEL/                       # RHEL 9.6 deployment
    ├── README.md               # RHEL-specific documentation
    ├── main.tf                 # RHEL Terraform configuration
    ├── variables.tf            # Variable definitions
    ├── outputs.tf              # Output values
    ├── terraform.tfvars        # Configuration values
    ├── init_script.tpl         # RHEL initialization script
    ├── windows_ssh_vscode.tpl  # SSH config template
    └── vm_files/               # Test data and scripts
```

---

**Choose your platform above and follow the platform-specific README for detailed deployment instructions.**

**Version**: 2.0  
**Compatible with**: Terraform >= 1.0, Azure Provider ~> 3.0  
**Last Updated**: Multi-platform support with Ubuntu 24.04 LTS and RHEL 9.6
