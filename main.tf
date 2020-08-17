######################
# Resource Management
######################

resource "azurerm_resource_group" "main" {
  name     = "${local.resource_prefix}-rg"
  location = var.location
  tags     = var.tags
}

###################
# Shared Resources
###################

resource "tls_private_key" "main_ssh" {
  algorithm = "RSA"
}

resource "local_file" "main_ssh_private" {
  filename          = ".terraform/.ssh/${local.resource_prefix}-vm.id_rsa"
  sensitive_content = tls_private_key.main_ssh.private_key_pem
  file_permission   = "0600"
}
