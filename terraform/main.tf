# MDCA Demo Infrastructure
# Creates Azure VM with Docker and MDCA log collector setup

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.1"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~>4.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "~>3.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~>2.0"
    }
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
}

# Generate random string for unique resource names
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# Get current public IP
data "http" "home_wan_ip" {
  url = "https://ipv4.icanhazip.com"
}

locals {
  home_wan_ip = chomp(data.http.home_wan_ip.response_body)
  suffix      = random_string.suffix.result
}

# Create Resource Group
resource "azurerm_resource_group" "mdca_demo" {
  name     = "mdca-demo-rg-${local.suffix}"
  location = "East US 2"

  tags = {
    Environment = "Demo"
    Project     = "MDCA"
    CreatedBy   = "Terraform.AI"
  }
}

# Create Virtual Network
resource "azurerm_virtual_network" "mdca_demo" {
  name                = "mdca-demo-vnet-${local.suffix}"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.mdca_demo.location
  resource_group_name = azurerm_resource_group.mdca_demo.name

  tags = {
    Environment = "Demo"
    Project     = "MDCA"
  }
}

# Create Subnet
resource "azurerm_subnet" "mdca_demo" {
  name                 = "mdca-demo-subnet-${local.suffix}"
  resource_group_name  = azurerm_resource_group.mdca_demo.name
  virtual_network_name = azurerm_virtual_network.mdca_demo.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Create SSH Key
resource "tls_private_key" "mdca_demo" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Save SSH private key to local file
resource "local_file" "ssh_private_key" {
  content         = tls_private_key.mdca_demo.private_key_pem
  filename        = "C:/Users/User/.ssh/mdca-demo-ub24-${local.suffix}_key.pem"
  file_permission = "0600"
}

# Create Network Security Group
resource "azurerm_network_security_group" "mdca_demo" {
  name                = "mdca-demo-nsg-${local.suffix}"
  location            = azurerm_resource_group.mdca_demo.location
  resource_group_name = azurerm_resource_group.mdca_demo.name

  # SSH Access Rule
  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "${local.home_wan_ip}/32"
    destination_address_prefix = "*"
  }

  # Syslog UDP 514 Rule
  security_rule {
    name                       = "Syslog_514_UDP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = "514"
    source_address_prefix      = "${local.home_wan_ip}/32"
    destination_address_prefix = "10.0.1.4"
  }


  tags = {
    Environment = "Demo"
    Project     = "MDCA"
  }
}

# Create Public IP
resource "azurerm_public_ip" "mdca_demo" {
  name                = "mdca-demo-pip-${local.suffix}"
  location            = azurerm_resource_group.mdca_demo.location
  resource_group_name = azurerm_resource_group.mdca_demo.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    Environment = "Demo"
    Project     = "MDCA"
  }
}

# Create Network Interface
resource "azurerm_network_interface" "mdca_demo" {
  name                = "mdca-demo-nic-${local.suffix}"
  location            = azurerm_resource_group.mdca_demo.location
  resource_group_name = azurerm_resource_group.mdca_demo.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.mdca_demo.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.1.4"
    public_ip_address_id          = azurerm_public_ip.mdca_demo.id
  }

  tags = {
    Environment = "Demo"
    Project     = "MDCA"
  }
}

# Associate Network Security Group to Network Interface
resource "azurerm_network_interface_security_group_association" "mdca_demo" {
  network_interface_id      = azurerm_network_interface.mdca_demo.id
  network_security_group_id = azurerm_network_security_group.mdca_demo.id
}

# Associate Network Security Group to Subnet
resource "azurerm_subnet_network_security_group_association" "mdca_demo" {
  subnet_id                 = azurerm_subnet.mdca_demo.id
  network_security_group_id = azurerm_network_security_group.mdca_demo.id
}

# Create Virtual Machine
resource "azurerm_linux_virtual_machine" "mdca_demo" {
  name                            = "mdca-demo-vm-${local.suffix}"
  location                        = azurerm_resource_group.mdca_demo.location
  resource_group_name             = azurerm_resource_group.mdca_demo.name
  size                            = "Standard_D2s_v3"
  admin_username                  = "lorenzoadm"
  disable_password_authentication = true

  # Disable monitoring
  boot_diagnostics {
    storage_account_uri = null
  }

  network_interface_ids = [
    azurerm_network_interface.mdca_demo.id,
  ]

  admin_ssh_key {
    username   = "lorenzoadm"
    public_key = tls_private_key.mdca_demo.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 128
  }

  source_image_reference {
    publisher    = "Canonical"
    offer        = "ubuntu-24_04-lts"
    sku          = "server"
    version      = "latest"
  }

  # Enable System Managed Identity
  identity {
    type = "SystemAssigned"
  }

  # Custom data script
  custom_data = base64encode(templatefile("${path.module}/init_script.tpl", { 
    admin_username = "lorenzoadm"
    mdca_script_content = base64encode(file("${path.module}/vm_files/mdca_send_msgs.sh"))
   }))

  tags = {
    Environment = "Demo"
    Project     = "MDCA"
  }
}

# Generate SSH config file
resource "local_file" "ssh_config" {
  content = templatefile("${path.module}/windows_ssh_vscode.tpl", {
    vm_public_ip = azurerm_public_ip.mdca_demo.ip_address
    admin_user   = "lorenzoadm"
    private_key  = "mdca-demo-ub24-${local.suffix}_key.pem"
    suffix       = local.suffix
  })
  filename = "C:/Users/User/.ssh/mdca-demo-config-${local.suffix}"
}
