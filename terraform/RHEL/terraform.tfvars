# MDCA Demo Configuration for RHEL 9.6
# Auth Token from MDCA Data Connector (Defender XDR Portal -> Settings -> MDCA -> Automatic Uploads)
mdca_auth_token     = "YOUR_AUTH_TOKEN_GOES_HERE"
mdca_console_url    = "<YOUR_TENANT>.us3.portal.cloudappsecurity.com"
mdca_collector_name = "CISCO_FP_TFAI"

# Azure Core (Infra)
vm_username    = "lorenzoadm"
admin_username = "lorenzoadm"
location       = "East US 2"
vm_size        = "Standard_D2s_v3"
tag_env        = "Demo"
tag_proj       = "MDCA"

# Network
network_vnet_cidr = ["10.0.0.0/16"]
vm_subnet_cidr    = ["10.0.1.0/24"]
vm_private_ip     = "10.0.1.4"
