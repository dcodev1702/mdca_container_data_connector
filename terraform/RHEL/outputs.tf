# Terraform Outputs for MDCA Demo Infrastructure - RHEL 9.6

output "resource_group_name" {
  description = "Name of the created resource group"
  value       = azurerm_resource_group.mdca_demo.name
}

output "vm_name" {
  description = "Name of the created virtual machine"
  value       = azurerm_linux_virtual_machine.mdca_demo.name
}

output "vm_public_ip" {
  description = "Public IP address of the VM"
  value       = azurerm_public_ip.mdca_demo.ip_address
}

output "vm_private_ip" {
  description = "Private IP address of the VM"
  value       = azurerm_network_interface.mdca_demo.private_ip_address
}

output "ssh_connection_command" {
  description = "SSH command to connect to the VM"
  value       = "ssh -i C:/Users/User/.ssh/mdca-demo-rhel96-${local.suffix}_key.pem lorenzoadm@${azurerm_public_ip.mdca_demo.ip_address}"
}

output "ssh_config_file" {
  description = "Location of generated SSH config file"
  value       = "C:/Users/User/.ssh/mdca-demo-rhel96-config-${local.suffix}"
}

output "ssh_private_key_file" {
  description = "Location of SSH private key file"
  value       = "C:/Users/User/.ssh/mdca-demo-rhel96-${local.suffix}_key.pem"
}

output "nsg_name" {
  description = "Name of the Network Security Group"
  value       = azurerm_network_security_group.mdca_demo.name
}

output "mdca_demo_private_ip" {
  description = "Private IP address of the MDCA demo VM"
  value       = azurerm_network_interface.mdca_demo.private_ip_address
}

output "allowed_source_ip" {
  description = "Your current IP address allowed for SSH access"
  value       = local.home_wan_ip
}

output "mdca_docker_command" {
  description = "Docker command template for MDCA log collector deployment"
  value = <<-EOT
    docker run -d \
      --name cisco_asa_fp_logcollector \
      --privileged \
      -p 514:514/udp \
      -e "PUBLICIP='${azurerm_network_interface.mdca_demo.ip_configuration[0].private_ip_address}'" \
      -e "PROXY=" \
      -e "SYSLOG=true" \
      -e "CONSOLE=<YOUR_TENANT>.portal.cloudappsecurity.com" \
      -e "COLLECTOR=cisco_asa_fp_logcollector" \
      --cap-add=SYS_ADMIN \
      --cap-add=SYSLOG \
      --restart unless-stopped \
      mcr.microsoft.com/mcas/logcollector \
      /bin/bash -c 'echo "<YOUR_AUTH_TOKEN>" | /etc/adallom/scripts/starter'
  EOT
}

output "deployment_summary" {
  description = "Summary of deployed resources"
  value = {
    os_type               = "RHEL 9.6"
    location              = azurerm_resource_group.mdca_demo.location
    resource_group        = azurerm_resource_group.mdca_demo.name
    virtual_network       = azurerm_virtual_network.mdca_demo.name
    subnet               = azurerm_subnet.mdca_demo.name
    network_security_group = azurerm_network_security_group.mdca_demo.name
    virtual_machine      = azurerm_linux_virtual_machine.mdca_demo.name
    vm_size              = azurerm_linux_virtual_machine.mdca_demo.size
    admin_username       = azurerm_linux_virtual_machine.mdca_demo.admin_username
    public_ip            = azurerm_public_ip.mdca_demo.ip_address
    private_ip           = azurerm_network_interface.mdca_demo.ip_configuration[0].private_ip_address
    os_disk_size_gb      = azurerm_linux_virtual_machine.mdca_demo.os_disk[0].disk_size_gb
    random_suffix        = local.suffix
  }
}

output "next_steps" {
  description = "Next steps after deployment"
  value = <<-EOT
    1. SSH to VM: ssh -i C:/Users/User/.ssh/mdca-demo-rhel96-${local.suffix}_key.pem lorenzoadm@${azurerm_public_ip.mdca_demo.ip_address}
    2. Check initialization: cat /var/log/init_script.log
    3. Verify Docker: docker --version && docker images
    4. Run system info: /home/$USER/mdca/system_info.sh
    5. Deploy MDCA collector using the docker command above with your auth token
    6. Test syslog: echo '<14>Test message' | timeout 0.2 nc -u ${azurerm_network_interface.mdca_demo.ip_configuration[0].private_ip_address} 514
    7. VS Code: Use SSH config at C:/Users/User/.ssh/mdca-demo-rhel96-config-${local.suffix}
    
    RHEL 9.6 Specific Notes:
    - Package management uses 'dnf' instead of 'apt'
    - Firewall management uses 'firewalld' instead of 'ufw'
    - SELinux is enabled by default (Docker containers run with --privileged)
  EOT
}
