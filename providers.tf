provider "aws" {
  region = "ca-central-1"
  default_tags {
    tags = var.tags
  }
}

data "aws_eks_cluster_auth" "eks_auth" {
  name = data.terraform_remote_state.eks.outputs.cluster_name
}
provider "kubernetes" {
  host  = data.terraform_remote_state.eks.outputs.cluster_endpoint
  token = data.aws_eks_cluster_auth.eks_auth.token

  cluster_ca_certificate = base64decode(data.terraform_remote_state.eks.outputs.cluster_certificate_authority_data)
}

provider "helm" {
  kubernetes {
    host  = data.terraform_remote_state.eks.outputs.cluster_endpoint
    token = data.aws_eks_cluster_auth.eks_auth.token

    cluster_ca_certificate = base64decode(data.terraform_remote_state.eks.outputs.cluster_certificate_authority_data)
  }
}

provider "kubectl" {
  host  = data.terraform_remote_state.eks.outputs.cluster_endpoint
  token = data.aws_eks_cluster_auth.eks_auth.token

  load_config_file       = false
  cluster_ca_certificate = base64decode(data.terraform_remote_state.eks.outputs.cluster_certificate_authority_data)
}
provider "argocd" {
  server_addr = var.argocd_server
  username    = var.argocd_username
  password    = var.argocd_password
}
