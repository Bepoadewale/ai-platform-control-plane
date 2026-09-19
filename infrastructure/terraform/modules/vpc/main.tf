variable "enabled" {
  type = bool
}
# Module contract placeholder: production implementation creates private EKS subnets and NAT cost controls.
output "enabled" {
  value = var.enabled
}
