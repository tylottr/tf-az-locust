output "server_vm_info" {
  description = "Information for the Locust Server"
  value = {
    resource_group_name = azurerm_resource_group.main.name
    fqdn = azurerm_public_ip.main_server.fqdn
    admin_username = local.vm_admin_username
  }
}

output "server_vm_web_access" {
  description = "Information to log into the Locust Server"
  value       = <<EOF
To access the server follow the below steps:
1. Run the below command
  ssh vmadmin@${azurerm_public_ip.main_server.fqdn} -i ${local_file.main_ssh_private.filename} -L 8080:localhost:8089
2. Open your browser to http://localhost:8080
EOF
}
