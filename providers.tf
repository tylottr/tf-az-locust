# Config
terraform {
  required_version = ">= 0.12.24"

  required_providers {
    azurerm = "~> 2.13"
    tls     = "~> 2.1"
    local   = "~> 1.4"
    http    = "~> 1.1"
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
