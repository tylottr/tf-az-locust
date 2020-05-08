# Config
terraform {
  required_version = ">= 0.12.24"

  required_providers {
    azurerm = ">= 2.9.0"
    tls     = "~> 2.1.0"
    local   = "~> 1.4.0"
    http    = "~> 1.1.0"
  }
}

# Providers
provider "azurerm" {
  features {}

  tenant_id       = var.tenant_id
  subscription_id = var.subscription_id

  client_id     = var.client_id
  client_secret = var.client_secret
}
