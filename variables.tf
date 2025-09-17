variable "app_name" {
  type        = string
  description = "Nome base da aplicação"
}

variable "location" {
  type        = string
  description = "Região do Azure para os recursos"
  default     = "eastus"
}
