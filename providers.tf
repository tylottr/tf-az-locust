# Config
terraform {
  required_version = ">= 0.12.18"
}

# Providers
provider "azurerm" {
  version = "~> 1.42.0"

  tenant_id       = var.tenant_id
  subscription_id = var.subscription_id

  client_id     = var.client_id
  client_secret = var.client_secret
}

provider "random" {
  version = "~> 2.2.0"
}

provider "null" {
  version = "~> 2.1.0"
}

provider "local" {
  version = "~> 1.4.0"
}

provider "tls" {
  version = "~> 2.1.0"
}

provider "http" {
  version = "~> 1.1.0"
}
