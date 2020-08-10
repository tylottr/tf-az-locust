##########################
# Workers - Configuration
##########################

locals {
  // Merge location and additional_locations
  worker_locations = var.additional_locations != null ? concat([var.location], var.additional_locations) : [var.location]

  // Generate name => { name, address_space } map of VNets
  worker_vnets = {
    for l in range(length(local.worker_locations)) :
    local.worker_locations[l] => {
      name          = format("%s-%s-worker-vnet", local.resource_prefix, replace(local.worker_locations[l], " ", ""))
      address_space = format("10.%g.0.0/24", l + 1)
    }
  }

  // Generate name => { vnet, location } map of VMs
  worker_vms = {
    for s in setproduct(local.worker_locations, range(var.vm_count)) :
    format("%s-%s-worker-vm%02d", local.resource_prefix, replace(s[0], " ", ""), s[1] + 1) => {
      vnet     = format("%s-%s-worker-vnet", local.resource_prefix, replace(s[0], " ", ""))
      location = s[0]
    }
  }
}

#######################
# Workers - Networking
#######################

resource "azurerm_network_security_group" "main_worker" {
  for_each = toset(local.worker_locations)

  name                = replace("${local.resource_prefix}-${each.value}-worker-nsg", " ", "")
  resource_group_name = azurerm_virtual_network.main_worker[each.value].resource_group_name
  location            = each.value
  tags                = local.worker_tags
}

resource "azurerm_virtual_network" "main_worker" {
  for_each = toset(local.worker_locations)

  name                = local.worker_vnets[each.value].name
  resource_group_name = azurerm_resource_group.main.name
  location            = each.value
  tags                = local.worker_tags

  address_space = [local.worker_vnets[each.value].address_space]
}

resource "azurerm_subnet" "main_worker" {
  for_each = toset(local.worker_locations)

  name                = "default"
  resource_group_name = azurerm_virtual_network.main_worker[each.value].resource_group_name

  virtual_network_name = azurerm_virtual_network.main_worker[each.value].name
  address_prefixes     = [azurerm_virtual_network.main_worker[each.value].address_space[0]]
}

resource "azurerm_subnet_network_security_group_association" "main_worker" {
  for_each = toset(local.worker_locations)

  subnet_id                 = azurerm_subnet.main_worker[each.value].id
  network_security_group_id = azurerm_network_security_group.main_worker[each.value].id
}

resource "azurerm_virtual_network_peering" "main_worker_to_server" {
  for_each = toset(local.worker_locations)

  name                      = "${replace(each.value, " ", "")}-worker-to-server"
  resource_group_name       = azurerm_resource_group.main.name
  virtual_network_name      = azurerm_virtual_network.main_worker[each.value].name
  remote_virtual_network_id = azurerm_virtual_network.main_server.id

  allow_virtual_network_access = true
}

resource "azurerm_virtual_network_peering" "main_worker_from_server" {
  for_each = toset(local.worker_locations)

  name                      = replace("${each.value}-server-to-worker", " ", "")
  resource_group_name       = azurerm_resource_group.main.name
  virtual_network_name      = azurerm_virtual_network.main_server.name
  remote_virtual_network_id = azurerm_virtual_network.main_worker[each.value].id

  allow_virtual_network_access = true
}

####################
# Workers - Compute
####################

resource "azurerm_network_interface" "main_worker" {
  for_each = local.worker_vms

  name                = "${each.key}-nic"
  resource_group_name = azurerm_virtual_network.main_worker[each.value.location].resource_group_name
  location            = each.value.location
  tags                = local.worker_tags

  ip_configuration {
    name                          = "ipconfig"
    subnet_id                     = azurerm_subnet.main_worker[each.value.location].id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "main_worker" {
  for_each = local.worker_vms

  name                = each.key
  resource_group_name = azurerm_virtual_network.main_worker[each.value.location].resource_group_name
  location            = each.value.location
  tags                = local.worker_tags

  size                  = local.vm_size
  network_interface_ids = [azurerm_network_interface.main_worker[each.key].id]

  admin_username = local.vm_admin_username
  admin_ssh_key {
    username   = local.vm_admin_username
    public_key = tls_private_key.main_ssh.public_key_openssh
  }

  custom_data = base64encode(templatefile(
    "${path.module}/templates/cloud-init/locust-worker.tpl.yml",
    {
      "admin_user"     = local.vm_admin_username
      "ssh_public_key" = tls_private_key.main_ssh.public_key_openssh

      "locustfile" = local.locustfile

      "server_address" = azurerm_network_interface.main_server.private_ip_address
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
