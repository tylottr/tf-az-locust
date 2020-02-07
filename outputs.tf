output "server_vm_info" {
  description = "Information for the Locust Server"
  value = {
    fqdn = azurerm_public_ip.main_server.fqdn
  }
}

output "server_vm_web_access" {
  description = "Information to log into the Locust Server"
  value = "To access the server run `ssh ${var.vm_username}@${azurerm_public_ip.main_server.fqdn} -L 8080:localhost:8089` to and open your browser to http://localhost:8080"
}