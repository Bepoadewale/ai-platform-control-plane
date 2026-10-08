output "cluster_name" {
  value = aws_eks_cluster.pilot.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.pilot.endpoint
}

output "ecr_repository_url" {
  value = aws_ecr_repository.control_plane.repository_url
}

output "rds_address" {
  value = aws_db_instance.postgres.address
}

output "rds_master_secret_arn" {
  value     = aws_db_instance.postgres.master_user_secret[0].secret_arn
  sensitive = true
}

output "github_oidc_role_arn" {
  value = aws_iam_role.github_readonly.arn
}

output "github_terraform_role_arn" {
  value       = aws_iam_role.github_terraform.arn
  description = "Manual, branch-bound GitHub Actions Terraform role. Configure after reviewing its policy."
}

output "gitops_publisher_secret_arn" {
  value       = aws_secretsmanager_secret.gitops_publisher.arn
  description = "Empty secret container for the GitHub App key; its value is set outside Terraform."
}

output "eks_oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.eks.arn
}

output "external_secrets_role_arn" {
  value       = aws_iam_role.external_secrets.arn
  description = "IRSA role limited to the GitHub App secret used by External Secrets."
}

output "aws_load_balancer_controller_role_arn" {
  value       = aws_iam_role.aws_load_balancer_controller.arn
  description = "IRSA role for the version-pinned AWS Load Balancer Controller used by every cloud pilot."
}
