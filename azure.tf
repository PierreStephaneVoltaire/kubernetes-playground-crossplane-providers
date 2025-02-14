locals {
  azure_sdk_auth_json = jsonencode({
    clientId                        = azuread_application.crossplane.client_id
    clientSecret                    = azuread_service_principal_password.crossplane.value
    subscriptionId                   = data.azurerm_client_config.current.subscription_id
    tenantId                         = data.azurerm_client_config.current.tenant_id
    activeDirectoryEndpointUrl       = "https://login.microsoftonline.com"
    resourceManagerEndpointUrl       = "https://management.azure.com/"
    activeDirectoryGraphResourceId   = "https://graph.windows.net/"
    sqlManagementEndpointUrl         = "https://management.core.windows.net:8443/"
    galleryEndpointUrl               = "https://gallery.azure.com/"
    managementEndpointUrl            = "https://management.core.windows.net/"
  })
}

data "azurerm_client_config" "current" {}

resource "azuread_application" "crossplane" {
  display_name = "crossplane"
}

resource "azuread_service_principal" "crossplane" {
  client_id = azuread_application.crossplane.client_id
}

resource "azuread_service_principal_password" "crossplane" {
  service_principal_id = azuread_service_principal.crossplane.id
}

resource "azurerm_role_assignment" "rbac" {
  principal_id        = azuread_service_principal.crossplane.object_id
  role_definition_name = "Owner"
  scope               = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
}

resource "aws_kms_key" "azure_secrets_kms" {
  description             = "KMS key for encrypting Azure SDK auth secrets"
  deletion_window_in_days = 7
}

resource "aws_kms_alias" "azure_secrets_kms_alias" {
  name          = "alias/azure-secrets-kms"
  target_key_id = aws_kms_key.azure_secrets_kms.id
}

resource "aws_secretsmanager_secret" "azure_sdk_auth" {
  name       = "azure-sdk-auth"
  kms_key_id = aws_kms_key.azure_secrets_kms.id
}

resource "aws_secretsmanager_secret_version" "azure_sdk_auth" {
  secret_id     = aws_secretsmanager_secret.azure_sdk_auth.id
  secret_string = local.azure_sdk_auth_json
}

resource "kubernetes_secret" "azure_creds" {
  metadata {
    name = "azure-secret"
    namespace = kubernetes_namespace.crossplane.metadata[0].name
  }

  data =   {"azure-auth.json" =  local.azure_sdk_auth_json}

  type = "Opaque"
}

resource "argocd_project" "azure" {
  metadata {
    name      = "azure"
    namespace = "argocd"
    labels = {
      acceptance = "true"
    }
  }

  spec {
    description  = "azure project"
    source_repos = ["*"]


    destination {
      server    = "https://kubernetes.default.svc"
      namespace = kubernetes_namespace.crossplane.metadata[0].name
    }



    sync_window {
      kind         = "allow"
      applications = ["*"]
      clusters     = ["*"]
      namespaces   = ["*"]
      duration     = "360s"
      schedule     = "*/5 * * * *"
      manual_sync  = true
    }
    namespace_resource_whitelist {
      group = "*"
      kind  = "*"
    }
    cluster_resource_whitelist {
      group = "*"
      kind  = "*"
    }
  }
}
