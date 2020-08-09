terraform {
  required_version = ">= 0.13"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 2.13"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 2.1"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 1.4"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 1.1"
    }
  }
}
