data "azurerm_client_config" "current" {}

data "http" "my_ip" {
  url = "https://api.ipify.org"
}
