####################
# Locust VM Details
####################

output "resource_group_name" {
  description = "Resource group of the VMs"
  value       = azurerm_resource_group.main.name
}

output "server_vm_ip" {
  description = "IP of the server VM"
  value       = azurerm_linux_virtual_machine.main_server.public_ip_address
}

output "server_vm_fqdn" {
  description = "FQDN of the server VM"
  value       = azurerm_public_ip.main_server.fqdn
}

output "admin_username" {
  description = "Username of the VM Admin"
  value       = local.vm_admin_username
}

output "admin_private_key" {
  description = "Private key data for the vm admin"
  value       = tls_private_key.main_ssh.private_key_pem
  sensitive   = true
}

output "server_vm_web_access" {
  description = "Web access URL to the Locust server"
  value       = "https://${azurerm_linux_virtual_machine.main_server.public_ip_address}"
}
