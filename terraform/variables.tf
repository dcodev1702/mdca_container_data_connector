# Terraform Variables for MDCA Demo Infrastructure

variable "location" {
  description = "Azure region for resource deployment"
  type        = string
  default     = "East US 2"
}

variable "vm_size" {
  description = "Size of the Azure virtual machine"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "admin_username" {
  description = "Administrator username for the VM"
  type        = string
  default     = "lorenzoadm"
}

variable "os_disk_size_gb" {
  description = "Size of the OS disk in GB"
  type        = number
  default     = 128
}

variable "environment" {
  description = "Environment tag for resources"
  type        = string
  default     = "Demo"
}

variable "project" {
  description = "Project tag for resources"
  type        = string
  default     = "MDCA"
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

# Optional variables for custom network configuration
variable "vnet_address_space" {
  description = "Address space for the virtual network"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "subnet_address_prefix" {
  description = "Address prefix for the subnet"
  type        = list(string)
  default     = ["10.0.1.0/24"]
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
