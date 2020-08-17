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
