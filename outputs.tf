output "kube_config" {
  value     = azurerm_kubernetes_cluster.main.kube_config[0]
  sensitive = true
}

output "acr_name" {
  value = azurerm_container_registry.acr.name
}

output "storage_account_name" {
  value = azurerm_storage_account.airflow.name
}

output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "postgresql_host" {
  value = azurerm_postgresql_flexible_server.airflow.fqdn
}

output "postgresql_admin_password" {
  value     = random_password.postgresql_admin.result
  sensitive = true
}
