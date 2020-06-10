##########
# SSH Key
##########
resource "tls_private_key" "main_ssh" {
  algorithm = "RSA"
}

resource "local_file" "main_ssh_private" {
  filename          = ".terraform/.ssh/${local.resource_prefix}-vm.id_rsa"
  sensitive_content = tls_private_key.main_ssh.private_key_pem
  file_permission   = "0600"
}

#################
# Resource Group
#################
resource "azurerm_resource_group" "main" {
  count = var.resource_group_name == "" ? 1 : 0

  name     = "${local.resource_prefix}-rg"
  location = var.location
  tags     = var.tags
}

data "azurerm_resource_group" "main" {
  name = var.resource_group_name == "" ? azurerm_resource_group.main[0].name : var.resource_group_name
}

###################
# Server - Storage
###################
resource "azurerm_storage_account" "main" {
  name                = lower(replace("${local.resource_prefix}sa", "/[-_]/", ""))
  resource_group_name = data.azurerm_resource_group.main.name
  location            = var.location
  tags                = merge(var.tags, { locustRole = "Storage" })

  account_kind             = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_share" "main" {
  name                 = "locust"
  storage_account_name = azurerm_storage_account.main.name

  quota = 5
}

resource "azurerm_role_assignment" "main" {
  for_each = toset([
    "Reader",
    "Storage File Data SMB Share Contributor"
  ])

  scope                = azurerm_storage_account.main.id
  role_definition_name = each.value
  principal_id         = azurerm_linux_virtual_machine.main_server.identity[0].principal_id
}

######################
# Server - Networking
######################
resource "azurerm_network_security_group" "main_server" {
  name                = "${local.resource_prefix}-server-nsg"
  resource_group_name = azurerm_virtual_network.main_server.resource_group_name
  location            = azurerm_virtual_network.main_server.location
  tags                = merge(var.tags, { locustRole = "Server" })

  security_rule {
    name                       = "ssh-allow"
    description                = "Allow SSH traffic to reach all inbound networks"
    direction                  = "Inbound"
    priority                   = "1000"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_address_prefix      = "${data.http.my_ip.body}/32"
    source_port_range          = "*"
    destination_address_prefix = "*"
    destination_port_range     = "22"
  }

  security_rule {
    name                       = "http-locust-allow"
    description                = "Allow HTTP Locust traffic to reach all inbound networks"
    direction                  = "Inbound"
    priority                   = "1010"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_address_prefix      = "${data.http.my_ip.body}/32"
    source_port_range          = "*"
    destination_address_prefix = "*"
    destination_port_range     = "8089"
  }
}

resource "azurerm_virtual_network" "main_server" {
  name                = "${local.resource_prefix}-server-vnet"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = var.location
  tags                = merge(var.tags, { locustRole = "Server" })

  address_space = ["10.0.0.0/24"]
}

resource "azurerm_subnet" "main_server" {
  name                = "default"
  resource_group_name = azurerm_virtual_network.main_server.resource_group_name

  virtual_network_name = azurerm_virtual_network.main_server.name
  address_prefixes     = [azurerm_virtual_network.main_server.address_space[0]]
}

resource "azurerm_subnet_network_security_group_association" "main_server" {
  subnet_id                 = azurerm_subnet.main_server.id
  network_security_group_id = azurerm_network_security_group.main_server.id
}

###################
# Server - Compute
###################
resource "azurerm_public_ip" "main_server" {
  name                = "${local.resource_prefix}-server-pip"
  resource_group_name = azurerm_virtual_network.main_server.resource_group_name
  location            = azurerm_virtual_network.main_server.location
  tags                = merge(var.tags, { locustRole = "Server" })

  allocation_method = "Dynamic"
}

resource "azurerm_network_interface" "main_server" {
  name                = "${local.resource_prefix}-server-nic"
  resource_group_name = azurerm_virtual_network.main_server.resource_group_name
  location            = azurerm_virtual_network.main_server.location
  tags                = merge(var.tags, { locustRole = "Server" })

  ip_configuration {
    name                          = "ipconfig"
    subnet_id                     = azurerm_subnet.main_server.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.main_server.id
  }
}

resource "azurerm_linux_virtual_machine" "main_server" {
  name                = "${local.resource_prefix}-server-vm"
  resource_group_name = azurerm_virtual_network.main_server.resource_group_name
  location            = azurerm_virtual_network.main_server.location
  tags                = merge(var.tags, { locustRole = "Server" })

  size                  = var.vm_size
  network_interface_ids = [azurerm_network_interface.main_server.id]

  admin_username = local.vm_admin_username
  admin_ssh_key {
    username   = local.vm_admin_username
    public_key = tls_private_key.main_ssh.public_key_openssh
  }

  custom_data = base64encode(templatefile(
    "${path.module}/templates/cloud-init/locust-server.tpl.yml",
    {
      admin_user     = local.vm_admin_username
      ssh_public_key = tls_private_key.main_ssh.public_key_openssh

      locustfile = file(var.locustfile)

      storage_account_name   = azurerm_storage_account.main.name
      storage_share_endpoint = azurerm_storage_account.main.primary_file_host
      storage_share_key      = azurerm_storage_account.main.primary_access_key
      storage_share_name     = azurerm_storage_share.main.name
    }
  ))

  os_disk {
    caching              = "None"
    disk_size_gb         = local.vm_disk_size
    storage_account_type = local.vm_disk_type
  }

  source_image_reference {
    publisher = local.vm_os.publisher
    offer     = local.vm_os.offer
    sku       = local.vm_os.sku
    version   = "latest"
  }

  identity {
    type = "SystemAssigned"
  }
}

##########################
# Clients - Configuration
##########################
locals {
  // Merge location and additional_locations
  client_locations = var.additional_locations != null ? concat([var.location], var.additional_locations) : [var.location]

  // Generate name => { name, address_space } map of VNets
  client_vnets = {
    for l in range(length(local.client_locations)) :
    local.client_locations[l] => {
      name          = format("%s-%s-client-vnet", local.resource_prefix, replace(local.client_locations[l], " ", ""))
      address_space = format("10.%g.0.0/24", l + 1)
    }
  }

  // Generate name => { vnet, location } map of VMs
  client_vms = {
    for s in setproduct(local.client_locations, range(var.vm_count)) :
    format("%s-%s-client-vm%g", local.resource_prefix, replace(s[0], " ", ""), s[1] + 1) => {
      vnet     = format("%s-%s-client-vnet", local.resource_prefix, replace(s[0], " ", ""))
      location = s[0]
    }
  }
}


#######################
# Clients - Networking
#######################
resource "azurerm_network_security_group" "main_client" {
  for_each = toset(local.client_locations)

  name                = "${local.resource_prefix}-${replace(each.value, " ", "")}-client-nsg"
  resource_group_name = azurerm_virtual_network.main_client[each.value].resource_group_name
  location            = azurerm_virtual_network.main_client[each.value].location
  tags                = merge(var.tags, { locustRole = "Client" })
}

resource "azurerm_virtual_network" "main_client" {
  for_each = toset(local.client_locations)

  name                = local.client_vnets[each.value].name
  resource_group_name = data.azurerm_resource_group.main.name
  location            = each.value
  tags                = merge(var.tags, { locustRole = "Client" })

  address_space = [local.client_vnets[each.value].address_space]
}

resource "azurerm_subnet" "main_client" {
  for_each = toset(local.client_locations)

  name                = "default"
  resource_group_name = azurerm_virtual_network.main_client[each.value].resource_group_name

  virtual_network_name = azurerm_virtual_network.main_client[each.value].name
  address_prefixes     = [azurerm_virtual_network.main_client[each.value].address_space[0]]
}

resource "azurerm_subnet_network_security_group_association" "main_client" {
  for_each = toset(local.client_locations)

  subnet_id                 = azurerm_subnet.main_client[each.value].id
  network_security_group_id = azurerm_network_security_group.main_client[each.value].id
}

resource "azurerm_virtual_network_peering" "main_client_to_server" {
  for_each = toset(local.client_locations)

  name                      = "${replace(each.value, " ", "")}-client-to-server"
  resource_group_name       = data.azurerm_resource_group.main.name
  virtual_network_name      = azurerm_virtual_network.main_client[each.value].name
  remote_virtual_network_id = azurerm_virtual_network.main_server.id

  allow_virtual_network_access = true
}

resource "azurerm_virtual_network_peering" "main_client_from_server" {
  for_each = toset(local.client_locations)

  name                      = "${replace(each.value, " ", "")}-server-to-client"
  resource_group_name       = data.azurerm_resource_group.main.name
  virtual_network_name      = azurerm_virtual_network.main_server.name
  remote_virtual_network_id = azurerm_virtual_network.main_client[each.value].id

  allow_virtual_network_access = true
}

####################
# Clients - Compute
####################
resource "azurerm_public_ip" "main_client" {
  for_each = local.client_vms

  name                = "${each.key}-pip"
  resource_group_name = azurerm_virtual_network.main_client[each.value.location].resource_group_name
  location            = azurerm_virtual_network.main_client[each.value.location].location
  tags                = merge(var.tags, { locustRole = "Client" })

  allocation_method = "Dynamic"
  domain_name_label = lower(each.key)
}

resource "azurerm_network_interface" "main_client" {
  for_each = local.client_vms

  name                = "${each.key}-nic"
  resource_group_name = azurerm_virtual_network.main_client[each.value.location].resource_group_name
  location            = azurerm_virtual_network.main_client[each.value.location].location
  tags                = merge(var.tags, { locustRole = "Client" })

  ip_configuration {
    name                          = "ipconfig"
    subnet_id                     = azurerm_subnet.main_client[each.value.location].id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.main_client[each.key].id
  }
}

resource "azurerm_linux_virtual_machine" "main_client" {
  for_each = local.client_vms

  name                = each.key
  resource_group_name = azurerm_virtual_network.main_client[each.value.location].resource_group_name
  location            = azurerm_virtual_network.main_client[each.value.location].location
  tags                = merge(var.tags, { locustRole = "Client" })

  size                  = var.vm_size
  network_interface_ids = [azurerm_network_interface.main_client[each.key].id]

  admin_username = local.vm_admin_username
  admin_ssh_key {
    username   = local.vm_admin_username
    public_key = tls_private_key.main_ssh.public_key_openssh
  }

  custom_data = base64encode(templatefile(
    "${path.module}/templates/cloud-init/locust-client.tpl.yml",
    {
      admin_user     = local.vm_admin_username
      ssh_public_key = tls_private_key.main_ssh.public_key_openssh

      locustfile = file(var.locustfile)

      server_address = azurerm_network_interface.main_server.private_ip_address
    }
  ))

  os_disk {
    caching              = "None"
    disk_size_gb         = local.vm_disk_size
    storage_account_type = local.vm_disk_type
  }

  source_image_reference {
    publisher = local.vm_os.publisher
    offer     = local.vm_os.offer
    sku       = local.vm_os.sku
    version   = "latest"
  }
}
