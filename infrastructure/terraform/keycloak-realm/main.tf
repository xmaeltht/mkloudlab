terraform {
  # ⚠️ SECURITY WARNING: Local state is used by default.
  # For production usage, please configure a remote backend (e.g., S3, GCS, Azure Storage)
  # to properly secure your state file and enable locking.
  #
  # backend "s3" {
  #   bucket = "mkloudlab"
  #   key    = "keycloak/terraform.tfstate"
  #   region = "us-east-1"
  # }

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
  count        = var.create_realm ? 1 : 0
  realm        = var.realm_name
  enabled      = true
  display_name = "MaelKloud Realm"

  login_with_email_allowed = true
  duplicate_emails_allowed = false
  reset_password_allowed   = true
  remember_me              = true
  verify_email             = true

  password_policy = "length(8) and digits(1) and lowerCase(1) and upperCase(1)"

  access_token_lifespan    = "15m"
  sso_session_idle_timeout = "30m"
  sso_session_max_lifespan = "10h"
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
    grafana = {
      name          = "Grafana"
      redirect_uris = ["https://grafana.maelkloud.com/login/generic_oauth"]
      web_origins   = ["https://grafana.maelkloud.com"]
    },
    prometheus = {
      name          = "Prometheus"
      redirect_uris = ["https://prometheus.maelkloud.com/oauth/callback"]
      web_origins   = ["https://prometheus.maelkloud.com"]
    }
  }
}

resource "keycloak_openid_client" "oidc_clients" {
  for_each  = local.oidc_clients
  realm_id  = local.realm_id
  client_id = each.key
  name      = each.value.name
  enabled   = true

  standard_flow_enabled        = true
  implicit_flow_enabled        = false
  direct_access_grants_enabled = true
  service_accounts_enabled     = false

  access_type = "CONFIDENTIAL"

  valid_redirect_uris = each.value.redirect_uris
  base_url            = "https://${each.key}.maelkloud.com"
  web_origins         = each.value.web_origins
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
  for_each  = local.oidc_clients
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
  for_each  = local.oidc_clients
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
  for_each        = local.oidc_clients
  realm_id        = local.realm_id
  client_id       = keycloak_openid_client.oidc_clients[each.key].id
  name            = "groups"
  protocol        = "openid-connect"
  protocol_mapper = "oidc-group-membership-mapper"

  config = {
    "claim.name"           = "groups"
    "jsonType.label"       = "String"
    "id.token.claim"       = "true"
    "access.token.claim"   = "true"
    "userinfo.token.claim" = "true"
    "full.path"            = "false"
  }
}
