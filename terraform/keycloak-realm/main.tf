terraform {
  required_providers {
    keycloak = {
      source  = "keycloak/keycloak"
      version = "5.2.0"
    }
  }
}

provider "keycloak" {
  client_id = "admin-cli"
  username  = var.kc_admin_user
  password  = var.kc_admin_pass
  url       = var.kc_url
  realm     = "master"
}

resource "keycloak_realm" "main" {
  count       = var.create_realm ? 1 : 0
  realm        = var.realm_name
  enabled      = true
  display_name = "MaelKloud Realm"

  login_with_email_allowed = true
  duplicate_emails_allowed = false
  reset_password_allowed   = true
  remember_me              = true
  verify_email             = true

  password_policy = "length(8) and digits(1) and lowerCase(1) and upperCase(1)"

  access_token_lifespan      = "15m"
  sso_session_idle_timeout   = "30m"
  sso_session_max_lifespan   = "10h"
}

data "keycloak_realm" "main" {
  depends_on = [keycloak_realm.main]
  realm      = var.realm_name
}

locals {
  realm_id = var.create_realm ? keycloak_realm.main[0].id : data.keycloak_realm.main.id
}

resource "keycloak_group" "admin_group" {
  realm_id = local.realm_id
  name     = "maelkloud-admins"
}

locals {
  oidc_clients = {
    argocd = {
      name = "ArgoCD"
      redirect_uris = ["https://argocd.maelkloud.com/*", "https://argocd.maelkloud.com"]
    },
    minio = {
      name = "MinIO"
      redirect_uris = ["https://minio.maelkloud.com/oauth_callback"]
      web_origins = ["https://minio.maelkloud.com"]
    },
    grafana = {
      name = "Grafana"
      redirect_uris = ["https://grafana.maelkloud.com/login/generic_oauth"]
      web_origins = ["https://grafana.maelkloud.com"]
    },
    prometheus = {
      name = "Prometheus"
      redirect_uris = ["https://prometheus.maelkloud.com/oauth/callback"]
      web_origins = ["https://prometheus.maelkloud.com"]
    }
  }
}

resource "keycloak_openid_client" "oidc_clients" {
  for_each                     = local.oidc_clients
  realm_id                     = local.realm_id
  client_id                    = each.key
  name                         = each.value.name
  enabled                      = true

  standard_flow_enabled        = true
  implicit_flow_enabled        = false
  direct_access_grants_enabled = true
  service_accounts_enabled     = false

  access_type = "CONFIDENTIAL"

  valid_redirect_uris = each.value.redirect_uris
  base_url           = "https://${each.key}.maelkloud.com"
  web_origins        = each.value.web_origins
}

resource "keycloak_role" "client_roles" {
  for_each  = local.oidc_clients
  realm_id  = local.realm_id
  client_id = keycloak_openid_client.oidc_clients[each.key].id
  name      = "${each.key}-admin"
}

resource "keycloak_group_roles" "client_group_roles" {
  for_each = local.oidc_clients
  realm_id = local.realm_id
  group_id = keycloak_group.admin_group.id
  role_ids = [keycloak_role.client_roles[each.key].id]
}

# Client scope mappings (CONSOLIDATED - no duplicates)
resource "keycloak_openid_client_default_scopes" "oidc_client_default_scopes" {
  for_each = local.oidc_clients
  realm_id  = local.realm_id
  client_id = keycloak_openid_client.oidc_clients[each.key].id
  
  default_scopes = [
    "profile",
    "email", 
    "roles",
    "web-origins"
  ]
}

resource "keycloak_openid_client_optional_scopes" "oidc_client_optional_scopes" {
  for_each = local.oidc_clients
  realm_id  = local.realm_id
  client_id = keycloak_openid_client.oidc_clients[each.key].id
  
  optional_scopes = [
    "address",
    "phone",
    "offline_access",
    "microprofile-jwt"
  ]
}

# Group membership mapper for all OIDC clients
resource "keycloak_generic_protocol_mapper" "oidc_groups_mapper" {
  for_each = local.oidc_clients
  realm_id    = local.realm_id
  client_id   = keycloak_openid_client.oidc_clients[each.key].id
  name        = "groups"
  protocol    = "openid-connect"
  protocol_mapper = "oidc-group-membership-mapper"
  
  config = {
    "claim.name"           = "groups"
    "jsonType.label"       = "String"
    "id.token.claim"       = "true"
    "access.token.claim"   = "true"
    "userinfo.token.claim" = "true"
    "full.path"           = "false"
  }
}

# SAML client for Jenkins
resource "keycloak_saml_client" "jenkins" {
  realm_id                    = local.realm_id
  client_id                   = "https://jenkins.maelkloud.com"
  name                        = "Jenkins"
  enabled                     = true

  sign_documents              = false
  sign_assertions             = false
  encrypt_assertions          = false
  client_signature_required   = false
  force_post_binding          = false
  front_channel_logout        = true

  valid_redirect_uris = [
    "https://jenkins.maelkloud.com/securityRealm/finishLogin"
  ]
  base_url = "https://jenkins.maelkloud.com"

  name_id_format = "username"
}

resource "keycloak_saml_user_property_protocol_mapper" "jenkins_username" {
  realm_id                   = local.realm_id
  client_id                  = keycloak_saml_client.jenkins.id
  name                       = "Username"
  user_property              = "Username"
  friendly_name              = "username"
  saml_attribute_name        = "username"
  saml_attribute_name_format = "Basic"
}

resource "keycloak_saml_user_property_protocol_mapper" "jenkins_email" {
  realm_id                   = local.realm_id
  client_id                  = keycloak_saml_client.jenkins.id
  name                       = "Email"
  user_property              = "Email"
  friendly_name              = "email"
  saml_attribute_name        = "email"
  saml_attribute_name_format = "Basic"
}

resource "keycloak_generic_protocol_mapper" "jenkins_groups" {
  realm_id        = local.realm_id
  client_id       = keycloak_saml_client.jenkins.id
  name            = "Groups"
  protocol        = "saml"
  protocol_mapper = "saml-group-membership-mapper"

  config = {
    "attribute.name"        = "groups"
    "attribute.nameformat" = "Basic"
    "full.path"            = "false"
  }
}

# SAML client for SonarQube
resource "keycloak_saml_client" "sonarqube" {
  realm_id                    = local.realm_id
  client_id                   = "sonarqube"
  name                        = "SonarQube"
  enabled                     = true

  sign_documents              = true
  sign_assertions             = false
  encrypt_assertions          = false
  client_signature_required   = false
  force_post_binding          = true
  front_channel_logout        = true

  valid_redirect_uris = [
    "https://sonarqube.maelkloud.com/oauth2/callback/saml"
  ]
  base_url = "https://sonarqube.maelkloud.com"

  name_id_format = "email"
}

resource "keycloak_saml_user_property_protocol_mapper" "sonarqube_login" {
  realm_id                   = local.realm_id
  client_id                  = keycloak_saml_client.sonarqube.id
  name                       = "Login"
  user_property              = "Username"
  friendly_name              = "Login"
  saml_attribute_name        = "login"
  saml_attribute_name_format = "Basic"
}

resource "keycloak_saml_user_property_protocol_mapper" "sonarqube_email" {
  depends_on = [keycloak_saml_client.sonarqube]
  realm_id                   = local.realm_id
  client_id                  = keycloak_saml_client.sonarqube.id
  name                       = "Email"
  user_property              = "Email"
  friendly_name              = "email"
  saml_attribute_name        = "email"
  saml_attribute_name_format = "Basic"
}

resource "keycloak_saml_user_property_protocol_mapper" "sonarqube_username" {
  depends_on = [keycloak_saml_client.sonarqube]
  realm_id                   = local.realm_id
  client_id                  = keycloak_saml_client.sonarqube.id
  name                       = "Username"
  user_property              = "Username"
  friendly_name              = "username"
  saml_attribute_name        = "username"
  saml_attribute_name_format = "Basic"
}

resource "keycloak_saml_user_property_protocol_mapper" "sonarqube_name" {
  depends_on = [keycloak_saml_client.sonarqube]
  realm_id                   = local.realm_id
  client_id                  = keycloak_saml_client.sonarqube.id
  name                       = "Name"
  user_property              = "Username"
  friendly_name              = "name"
  saml_attribute_name        = "name"
  saml_attribute_name_format = "Basic"
}

resource "keycloak_generic_protocol_mapper" "sonarqube_groups" {
  depends_on = [keycloak_saml_client.sonarqube]
  realm_id        = local.realm_id
  client_id       = keycloak_saml_client.sonarqube.id
  name            = "Groups"
  protocol        = "saml"
  protocol_mapper = "saml-group-membership-mapper"

  config = {
    "attribute.name"        = "groups"
    "attribute.nameformat" = "Basic"
    "full.path"            = "false"
  }
}