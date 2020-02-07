output "server_vm_info" {
  description = "Information for the Locust Server"
  value = {
    fqdn = azurerm_public_ip.main_server.fqdn
  }
}

output "server_vm_web_access" {
  description = "Information to log into the Locust Server"
  value = <<EOF
To access the server follow the below steps:
1. Run the below command
  ssh ${var.vm_username}@${azurerm_public_ip.main_server.fqdn} -i ${local_file.main_ssh_private.filename} -L 8080:localhost:8089
2. Open your browser to http://localhost:8080
EOF
}
