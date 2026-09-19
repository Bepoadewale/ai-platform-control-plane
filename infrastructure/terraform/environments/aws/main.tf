# Deliberately no resources at the root. Compose reviewed modules only after remote state,
# account boundaries, budgets, and OIDC CI roles are configured.
module "vpc_contract" {
  source  = "../../modules/vpc"
  enabled = var.enable_apply
}
