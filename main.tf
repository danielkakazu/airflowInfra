# Infraestrutura Azure (AKS, ACR, Storage, PostgreSQL)

resource "random_string" "suffix" {
  length  = 6
  upper   = false
  numeric = true
  special = false
}

resource "azurerm_resource_group" "rg" {
  name     = "${var.app_name}rg"
  location = var.location
}

# ========================= AKS =========================
resource "azurerm_kubernetes_cluster" "main" {
  name                = "${var.app_name}-aks"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "${var.app_name}-aks"

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_B2s"
  }

  identity {
    type = "SystemAssigned"
  }

  storage_profile {
    blob_driver_enabled = true
  }
}

# ========================= ACR =========================
resource "azurerm_container_registry" "acr" {
  name                = "${var.app_name}-acr-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  sku                 = "Standard"
  admin_enabled       = true
}

resource "azurerm_role_assignment" "main" {
  principal_id         = azurerm_kubernetes_cluster.main.identity[0].principal_id
  role_definition_name = "AcrPull"
  scope                = azurerm_container_registry.acr.id
}

# ========================= Storage =========================
resource "azurerm_storage_account" "airflow" {
  name                     = "${var.app_name}-airflowsa-${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "airflow_logs" {
  name                  = "airflow-logs"
  storage_account_id    = azurerm_storage_account.airflow.id
  container_access_type = "private"
}

resource "azurerm_storage_management_policy" "prune_logs" {
  storage_account_id = azurerm_storage_account.airflow.id

  rule {
    name    = "prune-logs"
    enabled = true
    filters {
      prefix_match = ["airflow-logs"]
      blob_types   = ["blockBlob"]
    }
    actions {
      base_blob {
        delete_after_days_since_modification_greater_than = 7
      }
    }
  }
}

# ========================= VNet/Subnet =========================
resource "azurerm_virtual_network" "aks_vnet" {
  name                = "${var.app_name}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "aks_subnet" {
  name                 = "aks-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.aks_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# ========================= PostgreSQL =========================
resource "random_password" "postgresql_admin" {
  length           = 16
  special          = true
  override_special = "-_"
}

resource "azurerm_private_dns_zone" "postgresql" {
  name                = "privatelink.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgresql" {
  name                  = "postgresql-dns-link"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.postgresql.name
  virtual_network_id    = azurerm_virtual_network.aks_vnet.id
}

resource "azurerm_postgresql_flexible_server" "airflow" {
  name                = "${var.app_name}-postgresql"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  version             = "13"
  delegated_subnet_id = azurerm_subnet.aks_subnet.id
  private_dns_zone_id = azurerm_private_dns_zone.postgresql.id

  sku_name = "Standard_B1ms"

  administrator_login          = "pgadmin"
  administrator_login_password = random_password.postgresql_admin.result

  storage_mb               = 32768
  backup_retention_days    = 7
  auto_grow_enabled        = true
  geo_redundant_backup_enabled = false
  zone                     = "1"

  high_availability {
    mode = "Disabled"
  }

  network {
    public_network_access_enabled = false
  }
}


