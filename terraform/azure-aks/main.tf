resource "azurerm_resource_group" "rg" {
  name     = "capstone-rg"
  location = var.location
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                = "capstone-aks"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "capstoneaks"
  sku_tier            = "Free"

  default_node_pool {
    name            = "default"
    node_count      = var.node_count
    vm_size         = var.vm_size
    os_disk_size_gb = 32
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
  }
}
