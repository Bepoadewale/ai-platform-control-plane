# Roadmap

## Delivered

- [x] Governed API: signed identity, tenant/RBAC, OPA, immutable plans, independent approval,
  idempotency, audit, TTL, destruction, and restart recovery.
- [x] Cloud-first delivery: durable worker → scoped GitHub App PR → Argo ApplicationSet → private
  EKS workload → observed ready/failure/prune.
- [x] AWS reference environment: Terraform VPC/EKS/RDS/ECR/Secrets/IAM, GitHub OIDC apply, IRSA,
  External Secrets, observability, HA pod-loss, bounded load, alert, health rollback, and teardown.

## Next

The remaining cloud improvements are deliberately scoped in
[Production Evolution](docs/production-evolution.md). They are not implied by the completed pilot.
