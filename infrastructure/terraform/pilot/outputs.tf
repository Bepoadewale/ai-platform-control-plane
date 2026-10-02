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
