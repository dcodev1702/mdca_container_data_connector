# Terraform Variables for MDCA Demo Infrastructure

variable "location" {
  description = "Azure region for resource deployment"
  type        = string
}

variable "vm_size" {
  description = "Size of the Azure virtual machine"
  type        = string
}

variable "admin_username" {
  description = "Administrator username for the VM"
  type        = string
}

variable "os_disk_size_gb" {
  description = "Size of the OS disk in GB"
  type        = number
  default     = 128
}

variable "ssh_key_path" {
  description = "Local path to save SSH private key"
  type        = string
  default     = "C:/Users/User/.ssh"
}

variable "enable_boot_diagnostics" {
  description = "Enable boot diagnostics for the VM"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}


# Syslog configuration
variable "syslog_port" {
  description = "Port for syslog ingestion"
  type        = number
  default     = 514
}

variable "allow_syslog_from_any" {
  description = "Allow syslog traffic from any source IP (set to false for production)"
  type        = bool
  default     = true
}


# Auth Token variables
variable "mdca_auth_token" {
  description = "Authentication token for MDCA log collector"
  type        = string
  sensitive   = true
}

variable "mdca_console_url" {
  description = "MDCA console URL"
  type        = string
}

variable "mdca_collector_name" {
  description = "MDCA collector name"
  type        = string
}

# Azure Core variables
variable "vm_username" {
  description = "VM admin username"
  type        = string
}

variable "tag_env" {
  description = "Environment tag"
  type        = string
}

variable "tag_proj" {
  description = "Project tag"
  type        = string
}

# Network variables
variable "network_vnet_cidr" {
  description = "Virtual Network CIDR"
  type        = list(string)
}

variable "vm_subnet_cidr" {
  description = "VM Subnet CIDR"
  type        = list(string)
}

variable "vm_private_ip" {
  description = "VM private IP address"
  type        = string
}
