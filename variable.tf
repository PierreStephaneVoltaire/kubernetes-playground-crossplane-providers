variable "app_name" {
  type    = string
  default = "playground"
}
variable "tags" {
  type = map(string)
}

variable "bucket" {
  type = string
}

variable "eks_key" {
  type = string
}
variable "network_key" {
  type = string
}

variable "argocd_server" {
  type = string
}

variable "argocd_username" {
  type = string
}

variable "argocd_password" {
  type = string
}
variable "subscription_id" {
  type      = string
  sensitive = true
}