# Optional AWS deployment

AWS is opt-in. Terraform modules define a VPC, EKS cluster seam, and IAM/workload-identity seam; they do not create resources in CI or local tests. Use remote state with locking/encryption, separate accounts per environment, provider credentials from CI OIDC, and run `make terraform-validate` before a reviewed apply. Review region pricing and quotas; do not enable managed databases or GPU node groups by default.
