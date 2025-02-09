terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.8"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "> 1.16.0"

    }
    argocd = {
      source  = "argoproj-labs/argocd"
      version = "7.3.0"
    }
  }
  required_version = ">= 1.3.0"
}

data "aws_region" "current" {}

data "terraform_remote_state" "eks" {
  backend = "s3"
  config = {
    bucket = var.bucket
    key    = var.eks_key
    region = data.aws_region.current.name
  }
}
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = var.bucket
    key    = var.network_key
    region = data.aws_region.current.name
  }
}

resource "argocd_repository" "crossplane_repo" {
  repo = "https://github.com/PierreStephaneVoltaire/kubernetes-playground-crossplane.git"
  type = "git"
}
resource "kubernetes_namespace" "crossplane" {
  metadata {
    name = "crossplane-system"
  }
}
resource "argocd_project" "crossplane" {
  metadata {
    name      = "crossplane"
    namespace = "argocd"
    labels = {
      acceptance = "true"
    }
  }

  spec {
    description  = "crossplane project"
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

resource "argocd_application" "crossplane" {
  metadata {
    name      = "crossplane"
    namespace = "argocd"
    labels = {
      "argocd.argoproj.io/instance"  = "crossplane"
      "app.kubernetes.io/name"       = "crossplane"
      "app.kubernetes.io/part-of"    = "cicd"
      "app.kubernetes.io/managed-by" = "argocd"
      "app.kubernetes.io/version"    = "1.18.2"
      "app.kubernetes.io/component"  = "ci-server"
      "team"                         = "devops"
      "owner"                        = "dev-team"
    }
  }

  spec {
    project = argocd_project.crossplane.metadata[0].name
    source {
      repo_url        = "https://charts.crossplane.io/stable"
      chart           = "crossplane"
      target_revision = "1.18.2"

      helm {
        value_files = ["https://raw.githubusercontent.com/PierreStephaneVoltaire/kubernetes-playground-crossplane/refs/heads/master/crossplane/values.yaml"] # Use your existing values.yaml
      }
    }


    destination {
      server    = "https://kubernetes.default.svc"
      namespace = kubernetes_namespace.crossplane.metadata[0].name
    }

    sync_policy {
      automated {
        prune     = true
        self_heal = true
      }
    }
  }
}
