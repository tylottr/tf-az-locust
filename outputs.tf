####################
# Locust VM Details
####################
output "resource_group_name" {
  description = "Resource group of the VMs"
  value       = data.azurerm_resource_group.main.name
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
  description = "Information to log into the Locust Server"
  value       = <<EOF
To access the server follow the below steps for an encrypted connection:
1. Run the below command
  ssh vmadmin@${azurerm_public_ip.main_server.fqdn} -i ${local_file.main_ssh_private.filename} -L 8080:localhost:8089
2. Open your browser to http://localhost:8080

OR

1. Visit the following link (This will not be encrypted): http://${azurerm_public_ip.main_server.fqdn}:8089
EOF
}
