
// Server
## Storage
resource "azurerm_storage_account" "main" {
  name                = lower(replace("${var.resource_prefix}${random_integer.entropy.result}sa", "/[-_]/", ""))
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = local.tags

  account_kind             = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "main" {
  name                 = "locust"
  storage_account_name = azurerm_storage_account.main.name

  container_access_type = "private"
}

resource "azurerm_storage_share" "main" {
  name                 = "locust"
  storage_account_name = azurerm_storage_account.main.name

  quota = 5
}

resource "azurerm_role_assignment" "main" {
  for_each = toset([
    "Reader",
    "Storage Blob Data Contributor",
    "Storage File Data SMB Share Contributor"
  ])

  scope                = azurerm_storage_account.main.id
  role_definition_name = each.value
  principal_id         = azurerm_virtual_machine.main_server.identity[0].principal_id
}

## Network
resource "azurerm_network_security_group" "main_server" {
  name                = "${var.resource_prefix}-server-nsg"
  resource_group_name = azurerm_virtual_network.main_server.resource_group_name
  location            = azurerm_virtual_network.main_server.location
  tags                = local.tags

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
  name                = "${var.resource_prefix}-server-vnet"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = local.tags

  address_space = ["10.0.0.0/24"]
}

resource "azurerm_subnet" "main_server" {
  name                = "default"
  resource_group_name = azurerm_virtual_network.main_server.resource_group_name

  virtual_network_name = azurerm_virtual_network.main_server.name
  address_prefix       = azurerm_virtual_network.main_server.address_space[0]

  lifecycle {
    ignore_changes = [network_security_group_id]
  }
}

resource "azurerm_subnet_network_security_group_association" "main_server" {
  subnet_id                 = azurerm_subnet.main_server.id
  network_security_group_id = azurerm_network_security_group.main_server.id
}

## Compute
resource "azurerm_public_ip" "main_server" {
  name                = "${var.resource_prefix}-server-pip"
  resource_group_name = azurerm_virtual_network.main_server.resource_group_name
  location            = azurerm_virtual_network.main_server.location
  tags                = local.tags

  allocation_method = "Dynamic"
  domain_name_label = lower("${var.resource_prefix}-server")
}

resource "azurerm_network_interface" "main_server" {
  name                = "${var.resource_prefix}-server-nic"
  resource_group_name = azurerm_virtual_network.main_server.resource_group_name
  location            = azurerm_virtual_network.main_server.location
  tags                = local.tags

  ip_configuration {
    name                          = "ipconfig"
    subnet_id                     = azurerm_subnet.main_server.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.main_server.id
  }
}

resource "azurerm_virtual_machine" "main_server" {
  name                = "${var.resource_prefix}-server-vm"
  resource_group_name = azurerm_virtual_network.main_server.resource_group_name
  location            = azurerm_virtual_network.main_server.location
  tags                = local.tags

  vm_size                          = var.vm_size
  network_interface_ids            = [azurerm_network_interface.main_server.id]
  delete_os_disk_on_termination    = true
  delete_data_disks_on_termination = true

  os_profile {
    computer_name  = "${var.resource_prefix}-server-vm"
    admin_username = var.vm_username
    custom_data = templatefile(
      "${path.module}/templates/cloud-init/locust-server.tpl.yml",
      {
        admin_user     = var.vm_username
        ssh_public_key = tls_private_key.main_ssh.public_key_openssh

        locustfile = file(var.locustfile)

        storage_account_name   = azurerm_storage_account.main.name
        storage_share_endpoint = azurerm_storage_account.main.primary_file_host
        storage_share_key      = azurerm_storage_account.main.primary_access_key
        storage_share_name     = azurerm_storage_share.main.name
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
    name              = "${var.resource_prefix}-server-osdisk"
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

  identity {
    type = "SystemAssigned"
  }
}