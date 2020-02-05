# Data
data "azurerm_client_config" "current" {}

data "http" "my_ip" {
  url = "https://api.ipify.org"
}

resource "random_integer" "entropy" {
  min = 0
  max = 99
}

resource "tls_private_key" "main_ssh" {
  algorithm = "RSA"
}

resource "local_file" "main_ssh_public" {
  filename          = ".terraform/.ssh/id_rsa.pub"
  sensitive_content = tls_private_key.main_ssh.public_key_openssh
}

resource "local_file" "main_ssh_private" {
  filename          = ".terraform/.ssh/id_rsa"
  sensitive_content = tls_private_key.main_ssh.private_key_pem
  file_permission   = "0600"
}

# Resources
## Resource Group
resource "azurerm_resource_group" "main" {
  name     = "${var.resource_prefix}-rg"
  location = var.location
  tags     = local.tags
}
