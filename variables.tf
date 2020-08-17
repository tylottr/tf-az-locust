#########
# Global
#########

variable "tenant_id" {
  description = "The tenant id of this deployment"
  type        = string
  default     = null

  validation {
    condition     = var.tenant_id == null || can(regex("\\w{8}-\\w{4}-\\w{4}-\\w{4}-\\w{12}", var.tenant_id))
    error_message = "The tenant_id must to be a valid UUID."
  }
}

variable "subscription_id" {
  description = "The subscription id of this deployment"
  type        = string
  default     = null

  validation {
    condition     = var.subscription_id == null || can(regex("\\w{8}-\\w{4}-\\w{4}-\\w{4}-\\w{12}", var.subscription_id))
    error_message = "The subscription_id must to be a valid UUID."
  }
}

variable "client_id" {
  description = "The client id of this deployment"
  type        = string
  default     = null

  validation {
    condition     = var.client_id == null || can(regex("\\w{8}-\\w{4}-\\w{4}-\\w{4}-\\w{12}", var.client_id))
    error_message = "The client_id must to be a valid UUID."
  }
}

variable "client_secret" {
  description = "The client secret of this deployment"
  type        = string
  default     = null
}

variable "location" {
  description = "The location of this deployment"
  type        = string
  default     = "Central US"
}

variable "resource_prefix" {
  description = "A prefix for the name of the resource, used to generate the resource names"
  type        = string
  default     = "locust-lt"
}

variable "tags" {
  description = "Tags given to the resources created by this template"
  type        = map(string)
  default     = {}
}

##########
# Compute
##########

variable "additional_locations" {
  description = "List of additional locations to deploy to"
  type        = list(string)
  default     = null
}

variable "locustfile" {
  description = "The location of a Locustfile used for load testing"
  type        = string
  default     = null
}

variable "vm_count" {
  description = "Number of client VMs to deploy per-region"
  type        = number
  default     = 1
}

#########
# Locals
#########

locals {
  resource_prefix = var.resource_prefix

  server_tags = merge(var.tags, { "locustRole" = "Server" })
  worker_tags = merge(var.tags, { "locustRole" = "Worker" })

  vm_os_platforms = {
    "ubuntu" = {
      "publisher" = "Canonical"
      "offer"     = "UbuntuServer"
      "sku"       = "18.04-LTS"
    }
  }

  vm_os = {
    publisher = local.vm_os_platforms.ubuntu.publisher
    offer     = local.vm_os_platforms.ubuntu.offer
    sku       = local.vm_os_platforms.ubuntu.sku
  }

  // VM Parameters
  vm_admin_username = "vmadmin"
  vm_size           = "Standard_B1s"
  vm_disk_type      = "StandardSSD_LRS"
  vm_disk_size      = 32

  // VM Configuration
  locustfile = var.locustfile == null ? file("${path.module}/files/Locustfile.py") : var.locustfile
  nginx_conf = templatefile("${path.module}/templates/nginx.tpl.conf", { "server_name" = azurerm_public_ip.main_server.fqdn })
}
