# MDCA Demo Infrastructure - RHEL 9.6 Compatible
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
  location = "${var.location}"

  tags = {
    Environment = "${var.tag_env}"
    Project     = "${var.tag_proj}"
    CreatedBy   = "Terraform.AI"
  }
}

# Create Virtual Network
resource "azurerm_virtual_network" "mdca_demo" {
  name                = "mdca-demo-vnet-${local.suffix}"
  address_space       = "${var.network_vnet_cidr}"
  location            = azurerm_resource_group.mdca_demo.location
  resource_group_name = azurerm_resource_group.mdca_demo.name

  tags = {
    Environment = "${var.tag_env}"
    Project     = "${var.tag_proj}"
  }
}

# Create Subnet
resource "azurerm_subnet" "mdca_demo" {
  name                 = "mdca-demo-subnet-${local.suffix}"
  resource_group_name  = azurerm_resource_group.mdca_demo.name
  virtual_network_name = azurerm_virtual_network.mdca_demo.name
  address_prefixes     = "${var.vm_subnet_cidr}"
}

# Create SSH Key
resource "tls_private_key" "mdca_demo" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Save SSH private key to local file
resource "local_file" "ssh_private_key" {
  content         = tls_private_key.mdca_demo.private_key_pem
  filename        = "C:/Users/User/.ssh/mdca-demo-rhel96-${local.suffix}_key.pem"
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
    destination_address_prefix = "${var.vm_private_ip}"
  }

  tags = {
    Environment = "${var.tag_env}"
    Project     = "${var.tag_proj}"
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
    Environment = "${var.tag_env}"
    Project     = "${var.tag_proj}"
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
    private_ip_address            = "${var.vm_private_ip}"
    public_ip_address_id          = azurerm_public_ip.mdca_demo.id
  }

  tags = {
    Environment = "${var.tag_env}"
    Project     = "${var.tag_proj}"
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
  size                            = "${var.vm_size}"
  admin_username                  = "${var.vm_username}"
  disable_password_authentication = true

  # Disable monitoring
  boot_diagnostics {
    storage_account_uri = null
  }

  network_interface_ids = [
    azurerm_network_interface.mdca_demo.id,
  ]

  admin_ssh_key {
    username   = "${var.vm_username}"
    public_key = tls_private_key.mdca_demo.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 128
  }

  source_image_reference {
    publisher = "RedHat"
    offer     = "RHEL"
    sku       = "9-lvm-gen2"
    version   = "latest"
  }

  # Enable System Managed Identity
  identity {
    type = "SystemAssigned"
  }

  # Custom data script
  custom_data = base64encode(templatefile("${path.module}/init_script.tpl", { 
    admin_username      = "${var.vm_username}"
    mdca_auth_token     = "${var.mdca_auth_token}"
    mdca_console_url    = "${var.mdca_console_url}"
    mdca_collector_name = "${var.mdca_collector_name}"
    mdca_script_content = base64encode(file("${path.module}/vm_files/mdca_send_msgs.sh"))
   }))

  # Add file provisioners for the large files
  provisioner "file" {
    source      = "${path.module}/vm_files/cisco_asa_fp_c.ai2k.log"
    destination = "/home/${var.admin_username}/cisco_asa_fp_c.ai2k.log"
    
    connection {
      type        = "ssh"
      user        = var.admin_username
      private_key = tls_private_key.mdca_demo.private_key_pem
      host        = self.public_ip_address
    }
  }

  provisioner "file" {
    source      = "${path.module}/vm_files/cisco_asa_fp_c.ai.log"
    destination = "/home/${var.admin_username}/cisco_asa_fp_c.ai.log"
    
    connection {
      type        = "ssh"
      user        = var.admin_username
      private_key = tls_private_key.mdca_demo.private_key_pem
      host        = self.public_ip_address
    }
  }

  # Make the script executable and move files to final location
  provisioner "remote-exec" {
    inline = [
      "sudo chown ${var.admin_username}:${var.admin_username} /home/${var.admin_username}/cisco_asa_fp_c.ai2k.log",
      "sudo chown ${var.admin_username}:${var.admin_username} /home/${var.admin_username}/cisco_asa_fp_c.ai.log"
    ]
    
    connection {
      type        = "ssh"
      user        = var.admin_username
      private_key = tls_private_key.mdca_demo.private_key_pem
      host        = self.public_ip_address
    }
  }
   
  tags = {
    Environment = "${var.tag_env}"
    Project     = "${var.tag_proj}"
  }
}

# Generate SSH config file
resource "local_file" "ssh_config" {
  content = templatefile("${path.module}/windows_ssh_vscode.tpl", {
    vm_public_ip = azurerm_public_ip.mdca_demo.ip_address
    admin_user   = "${var.vm_username}"
    private_key  = "mdca-demo-rhel96-${local.suffix}_key.pem"
    suffix       = local.suffix
  })
  filename = "C:/Users/User/.ssh/mdca-demo-rhel96-config-${local.suffix}"
}
