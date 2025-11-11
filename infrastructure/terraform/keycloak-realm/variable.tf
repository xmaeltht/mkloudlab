variable "kc_admin_user" {
  description = "Keycloak admin username"
  type        = string
  sensitive   = true
}

variable "kc_admin_pass" {
  description = "Keycloak admin password"
  type        = string
  sensitive   = true
}

variable "kc_url" {
  description = "Keycloak URL"
  type        = string
  default     = "https://keycloak.maelkloud.com"
}

variable "realm_name" {
  description = "Name of the Keycloak realm"
  type        = string
  default     = "mkloud"
}

variable "create_realm" {
  description = "Whether to create a new realm or use an existing one"
  type        = bool
  default     = false
}