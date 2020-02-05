// Clients
locals {
  // Merge location and additional_locations
  client_locations = var.additional_locations != null ? concat([var.location], var.additional_locations) : [var.location]

  // Generate name => { name, address_space } map of VNets
  client_vnets = {
    for l in range(length(local.client_locations)):
    local.client_locations[l] => {
      name = format("%s-%s-client-vnet", var.resource_prefix, replace(local.client_locations[l], " ", ""))
      address_space = format("10.%g.0.0/24", l + 1)
    }
  }

  // Generate name => { vnet, location } map of VMs
  client_vms = {
    for s in setproduct(local.client_locations, range(var.vm_count)) :
    format("%s-%s-client-vm%g", var.resource_prefix, replace(s[0], " ", ""), s[1] + 1) => {
      vnet = format("%s-%s-client-vnet", var.resource_prefix, replace(s[0], " ", ""))
      location = s[0]
    }
  }
}

## Network
resource "azurerm_network_security_group" "main_client" {
  for_each = toset(local.client_locations)

  name                = "${var.resource_prefix}-${replace(each.value, " ", "")}-client-nsg"
  resource_group_name = azurerm_virtual_network.main_client[each.value].resource_group_name
  location            = azurerm_virtual_network.main_client[each.value].location
  tags                = merge(local.tags, { locustRole = "Client" })
}

resource "azurerm_virtual_network" "main_client" {
  for_each = toset(local.client_locations)

  name                = local.client_vnets[each.value].name
  resource_group_name = azurerm_resource_group.main.name
  location            = each.value
  tags                = merge(local.tags, { locustRole = "Client" })

  address_space = [local.client_vnets[each.value].address_space]
}

resource "azurerm_subnet" "main_client" {
  for_each = toset(local.client_locations)

  name                = "default"
  resource_group_name = azurerm_virtual_network.main_client[each.value].resource_group_name

  virtual_network_name = azurerm_virtual_network.main_client[each.value].name
  address_prefix       = azurerm_virtual_network.main_client[each.value].address_space[0]

  lifecycle {
    ignore_changes = [network_security_group_id]
  }
}

resource "azurerm_subnet_network_security_group_association" "main_client" {
  for_each = toset(local.client_locations)

  subnet_id                 = azurerm_subnet.main_client[each.value].id
  network_security_group_id = azurerm_network_security_group.main_client[each.value].id
}

resource "azurerm_virtual_network_peering" "main_client_to_server" {
  for_each = toset(local.client_locations)

  name                      = "${replace(each.value, " ", "")}-client-to-server"
  resource_group_name       = azurerm_resource_group.main.name
  virtual_network_name      = azurerm_virtual_network.main_client[each.value].name
  remote_virtual_network_id = azurerm_virtual_network.main_server.id

  allow_virtual_network_access = true
}

resource "azurerm_virtual_network_peering" "main_client_from_server" {
  for_each = toset(local.client_locations)

  name                      = "${replace(each.value, " ", "")}-server-to-client"
  resource_group_name       = azurerm_resource_group.main.name
  virtual_network_name      = azurerm_virtual_network.main_server.name
  remote_virtual_network_id = azurerm_virtual_network.main_client[each.value].id

  allow_virtual_network_access = true
}

## Compute
resource "azurerm_public_ip" "main_client" {
  for_each = local.client_vms

  name                = "${each.key}-pip"
  resource_group_name = azurerm_virtual_network.main_client[each.value.location].resource_group_name
  location            = azurerm_virtual_network.main_client[each.value.location].location
  tags                = merge(local.tags, { locustRole = "Client" })

  allocation_method = "Dynamic"
  domain_name_label = lower(each.key)
}

resource "azurerm_network_interface" "main_client" {
  for_each = local.client_vms

  name                = "${each.key}-nic"
  resource_group_name = azurerm_virtual_network.main_client[each.value.location].resource_group_name
  location            = azurerm_virtual_network.main_client[each.value.location].location
  tags                = merge(local.tags, { locustRole = "Client" })

  ip_configuration {
    name                          = "ipconfig"
    subnet_id                     = azurerm_subnet.main_client[each.value.location].id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.main_client[each.key].id
  }
}

resource "azurerm_virtual_machine" "main_client" {
  for_each = local.client_vms

  name                = each.key
  resource_group_name = azurerm_virtual_network.main_client[each.value.location].resource_group_name
  location            = azurerm_virtual_network.main_client[each.value.location].location
  tags                = merge(local.tags, { locustRole = "Client" })

  vm_size                          = var.vm_size
  network_interface_ids            = [azurerm_network_interface.main_client[each.key].id]
  delete_os_disk_on_termination    = true
  delete_data_disks_on_termination = true

  os_profile {
    computer_name  = each.key
    admin_username = var.vm_username
    custom_data = templatefile(
      "${path.module}/templates/cloud-init/locust-client.tpl.yml",
      {
        admin_user     = var.vm_username
        ssh_public_key = tls_private_key.main_ssh.public_key_openssh

        locustfile = file(var.locustfile)

        server_address = azurerm_network_interface.main_server.private_ip_address
      }
    )
  }

  storage_image_reference {
    publisher = local.vm_os.publisher
    offer     = local.vm_os.offer
    sku       = local.vm_os.sku
    version   = "latest"
  }

  storage_os_disk {
    name              = "${each.key}-osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    disk_size_gb      = local.vm_disk_size
    managed_disk_type = local.vm_disk_type
  }

  os_profile_linux_config {
    disable_password_authentication = true

    ssh_keys {
      path     = "/home/${var.vm_username}/.ssh/authorized_keys"
      key_data = tls_private_key.main_ssh.public_key_openssh
    }
  }
}