# Global
variable "tenant_id" {
  description = "The tenant id of this deployment"
  type        = string
  default     = null
}

variable "subscription_id" {
  description = "The subscription id of this deployment"
  type        = string
  default     = null
}

variable "client_id" {
  description = "The client id used to authenticate to Azure"
  type        = string
  default     = null
}

variable "client_secret" {
  description = "The client secret used to authenticate to Azure"
  type        = string
  default     = null
}

variable "location" {
  description = "The primary location of this deployment"
  type        = string
  default     = "UK South"
}

variable "resource_prefix" {
  description = "A prefix for the name of the resource, used to generate the resource names"
  type        = string
  default     = "locust"
}

variable "tags" {
  description = "Tags given to the resources created by this template"
  type        = map(string)
  default     = {}
}

# Resource-specific
## Compute
variable "vm_username" {
  description = "Username for the VMs"
  type        = string
  default     = "vmadmin"
}

variable "vm_size" {
  description = "VM Size for the VMs"
  type        = string
  default     = "Standard_B1s"
}

variable "vm_count" {
  description = "Number of client VMs to deploy per-region"
  type        = number
  default     = 1
}

variable "additional_locations" {
  description = "List of additional locations to deploy to"
  type        = list(string)
  default     = null
}

variable "locustfile" {
  description = "The location of a Locustfile used for load testing"
  type        = string
  default     = "files/Locustfile.py"
}

# Locals
locals {
  tags = merge(
    var.tags,
    {
      deployedBy = "Terraform"
    }
  )

  vm_os_platforms = {
    ubuntu = {
      publisher = "Canonical"
      offer     = "UbuntuServer"
      sku       = "18.04-LTS"
    }
  }

  vm_os = {
    publisher = local.vm_os_platforms.ubuntu.publisher
    offer     = local.vm_os_platforms.ubuntu.offer
    sku       = local.vm_os_platforms.ubuntu.sku
  }

  // VM Parameters
  vm_disk_type = "StandardSSD_LRS"
  vm_disk_size = 32
}
