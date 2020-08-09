###################
# Server - Storage
###################

resource "azurerm_storage_account" "main" {
  name                = lower(replace("${local.resource_prefix}sa", "/[-_]/", ""))
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  tags                = merge(var.tags, { "locustRole" = "Storage" })

  account_kind             = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = "LRS"

  network_rules {
    default_action             = "Deny"
    ip_rules                   = [data.http.my_ip.body]
    virtual_network_subnet_ids = [azurerm_subnet.main_server.id]
  }
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
  location            = var.location
  tags                = local.server_tags

  security_rule {
    name                       = "AllowSSHInbound"
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
    name                       = "AllowHTTPInbound"
    description                = "Allow HTTP traffic to reach all inbound networks"
    direction                  = "Inbound"
    priority                   = "1010"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_address_prefix      = "${data.http.my_ip.body}/32"
    source_port_range          = "*"
    destination_address_prefix = "*"
    destination_port_range     = "80"
  }

  security_rule {
    name                       = "AllowHTTPSInbound"
    description                = "Allow HTTPS traffic to reach all inbound networks"
    direction                  = "Inbound"
    priority                   = "1020"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_address_prefix      = "${data.http.my_ip.body}/32"
    source_port_range          = "*"
    destination_address_prefix = "*"
    destination_port_range     = "443"
  }

  security_rule {
    name                       = "AllowHTTPLocustinBound"
    description                = "Allow HTTP Locust traffic to reach all inbound networks"
    direction                  = "Inbound"
    priority                   = "1100"
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
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  tags                = local.server_tags

  address_space = ["10.0.0.0/24"]
}

resource "azurerm_subnet" "main_server" {
  name                = "default"
  resource_group_name = azurerm_virtual_network.main_server.resource_group_name

  virtual_network_name = azurerm_virtual_network.main_server.name
  address_prefixes     = [azurerm_virtual_network.main_server.address_space[0]]

  service_endpoints = ["Microsoft.Storage"]
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
  location            = var.location
  tags                = local.server_tags

  allocation_method = "Dynamic"
}

resource "azurerm_network_interface" "main_server" {
  name                = "${local.resource_prefix}-server-nic"
  resource_group_name = azurerm_virtual_network.main_server.resource_group_name
  location            = var.location
  tags                = local.server_tags

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
  location            = var.location
  tags                = local.server_tags

  size                  = local.vm_size
  network_interface_ids = [azurerm_network_interface.main_server.id]

  admin_username = local.vm_admin_username
  admin_ssh_key {
    username   = local.vm_admin_username
    public_key = tls_private_key.main_ssh.public_key_openssh
  }

  custom_data = base64encode(templatefile(
    "${path.module}/templates/cloud-init/locust-server.tpl.yml",
    {
      "admin_user"     = local.vm_admin_username
      "ssh_public_key" = tls_private_key.main_ssh.public_key_openssh

      "locustfile" = local.locustfile

      "server_address" = azurerm_network_interface.main_server.private_ip_address

      "storage_account_name"   = azurerm_storage_account.main.name
      "storage_share_endpoint" = azurerm_storage_account.main.primary_file_host
      "storage_share_key"      = azurerm_storage_account.main.primary_access_key
      "storage_share_name"     = azurerm_storage_share.main.name
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
