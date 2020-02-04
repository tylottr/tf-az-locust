output "server_vm_fqdn" {
  value = azurerm_public_ip.main_server.fqdn
}

# output "client_vm_public_ips" {
#   value = [for e in azurerm_public_ip.main_client : e.ip]
# }