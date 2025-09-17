variable "app_name" {
  type        = string
  description = "Nome base da aplicação"
  default     = "airflow"
}

variable "location" {
  type        = string
  description = "Região do Azure para os recursos"
  default     = "centralus"
}
