variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "expected_account_id" {
  type = string
}

variable "github_oidc_subject" {
  type        = string
  description = "Exact GitHub Actions OIDC subject for protected main. Owner and repository IDs prevent a renamed repository from inheriting this role."
  default     = "repo:Bepoadewale@99020860/ai-platform-control-plane@1376870793:ref:refs/heads/main"
}

variable "cluster_name" {
  type    = string
  default = "ai-platform-control-plane-pilot"
}

variable "kubernetes_version" {
  type        = string
  default     = "1.35"
  description = "Current EKS standard-support version verified during the pilot build."
}

variable "node_instance_type" {
  type        = string
  default     = "t3.large"
  description = "Small CPU-only pilot node type; no GPU capacity is provisioned."
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "node_min_size" {
  type    = number
  default = 2
}

variable "node_max_size" {
  type    = number
  default = 2
}

variable "github_app_id" {
  type        = string
  description = "GitHub App ID used by the runtime GitOps publisher. The private key is supplied outside Terraform."
  default     = ""
}

variable "github_app_installation_id" {
  type        = string
  description = "GitHub App installation ID used by the runtime GitOps publisher. The private key is supplied outside Terraform."
  default     = ""
}
