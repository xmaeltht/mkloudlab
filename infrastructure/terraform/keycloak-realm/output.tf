# Output realm information
output "realm_id" {
  description = "The ID of the Keycloak realm"
  value       = local.realm_id
}

output "realm_name" {
  description = "The name of the Keycloak realm"
  value       = var.realm_name
}

# Output all OIDC client IDs
output "oidc_client_ids" {
  description = "Map of OIDC client names to their IDs"
  value = {
    for k, v in keycloak_openid_client.oidc_clients : k => v.id
  }
}

# Output all OIDC client secrets (sensitive)
output "oidc_client_secrets" {
  description = "Map of OIDC client names to their secrets"
  value = {
    for k, v in keycloak_openid_client.oidc_clients : k => v.client_secret
  }
  sensitive = true
}

# Individual OIDC client secrets
output "argocd_oidc_client_secret" {
  description = "The client secret for ArgoCD OIDC client"
  value       = keycloak_openid_client.oidc_clients["argocd"].client_secret
  sensitive   = true
}

output "grafana_oidc_client_secret" {
  description = "The client secret for Grafana OIDC client"
  value       = keycloak_openid_client.oidc_clients["grafana"].client_secret
  sensitive   = true
}

output "prometheus_oidc_client_secret" {
  description = "The client secret for Prometheus OIDC client"
  value       = keycloak_openid_client.oidc_clients["prometheus"].client_secret
  sensitive   = true
}

output "sonarqube_saml_client_id" {
  description = "The client ID for SonarQube SAML client"
  value       = keycloak_saml_client.sonarqube.client_id
}

# Output admin group information
output "admin_group_id" {
  description = "The ID of the admin group"
  value       = keycloak_group.admin_group.id
}

output "admin_group_name" {
  description = "The name of the admin group"
  value       = keycloak_group.admin_group.name
}

# Output all client redirect URIs for reference
output "client_redirect_uris" {
  description = "Map of all client redirect URIs for reference"
  value = merge(
    {
      for k, v in local.oidc_clients : k => v.redirect_uris
    },
    {
      "sonarqube" = keycloak_saml_client.sonarqube.valid_redirect_uris
    }
  )
}

# Output Keycloak endpoints for each client
output "keycloak_endpoints" {
  description = "Keycloak endpoints for OIDC configuration"
  value = {
    auth_url     = "${var.kc_url}/realms/${var.realm_name}/protocol/openid-connect/auth"
    token_url    = "${var.kc_url}/realms/${var.realm_name}/protocol/openid-connect/token"
    userinfo_url = "${var.kc_url}/realms/${var.realm_name}/protocol/openid-connect/userinfo"
    issuer_url   = "${var.kc_url}/realms/${var.realm_name}"
    jwks_url     = "${var.kc_url}/realms/${var.realm_name}/protocol/openid-connect/certs"
  }
}