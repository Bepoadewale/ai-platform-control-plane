data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

locals {
  prefix = "ai-platform-control-plane-pilot"
  azs    = slice(data.aws_availability_zones.available.names, 0, 2)
  tags = {
    project     = "ai-platform-control-plane"
    environment = "pilot"
    managed_by  = "terraform"
    owner       = "bepoadewale"
    cost_scope  = "pilot"
  }
}

check "expected_account" {
  assert {
    condition     = data.aws_caller_identity.current.account_id == var.expected_account_id
    error_message = "Refusing to deploy cloud pilot outside the expected AWS account."
  }
}

resource "aws_vpc" "pilot" {
  cidr_block           = "10.42.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
}

data "tls_certificate" "eks_oidc" {
  url = aws_eks_cluster.pilot.identity[0].oidc[0].issuer
}

resource "aws_internet_gateway" "pilot" {
  vpc_id = aws_vpc.pilot.id
}

resource "aws_subnet" "public" {
  for_each = { for index, az in local.azs : az => index }

  vpc_id                  = aws_vpc.pilot.id
  availability_zone       = each.key
  cidr_block              = cidrsubnet("10.42.0.0/16", 4, each.value)
  map_public_ip_on_launch = true

  tags = {
    Name                                        = "${local.prefix}-public-${each.value + 1}"
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

resource "aws_subnet" "private" {
  for_each = { for index, az in local.azs : az => index }

  vpc_id            = aws_vpc.pilot.id
  availability_zone = each.key
  cidr_block        = cidrsubnet("10.42.0.0/16", 4, each.value + 8)

  tags = {
    Name                                        = "${local.prefix}-private-${each.value + 1}"
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.pilot.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.pilot.id
  }
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_eip" "nat" {
  domain = "vpc"
}

resource "aws_nat_gateway" "pilot" {
  allocation_id = aws_eip.nat.id
  subnet_id     = values(aws_subnet.public)[0].id

  depends_on = [aws_internet_gateway.pilot]
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.pilot.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.pilot.id
  }
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}

data "aws_iam_policy_document" "eks_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eks_cluster" {
  name               = "${local.prefix}-cluster"
  assume_role_policy = data.aws_iam_policy_document.eks_assume_role.json
}

resource "aws_iam_role_policy_attachment" "eks_cluster" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

data "aws_iam_policy_document" "node_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eks_node" {
  name               = "${local.prefix}-node"
  assume_role_policy = data.aws_iam_policy_document.node_assume_role.json
}

resource "aws_iam_role_policy_attachment" "node_worker" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "node_cni" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "node_ecr" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
}

resource "aws_eks_cluster" "pilot" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster.arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = values(aws_subnet.private)[*].id
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = true
  }

  depends_on = [aws_iam_role_policy_attachment.eks_cluster]
}

resource "aws_iam_openid_connect_provider" "eks" {
  url             = aws_eks_cluster.pilot.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_oidc.certificates[0].sha1_fingerprint]
}

locals {
  eks_oidc_issuer = trimprefix(aws_eks_cluster.pilot.identity[0].oidc[0].issuer, "https://")
}

data "aws_iam_policy_document" "external_secrets_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.eks_oidc_issuer}:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.eks_oidc_issuer}:sub"
      # The controller is installed separately, but the scoped web-identity token
      # belongs to the namespace-local SecretStore reader. Keeping this subject
      # exact prevents any other service account from reading the GitHub App key.
      values   = ["system:serviceaccount:platform-system:pilot-secrets-reader"]
    }
  }
}

resource "aws_iam_role" "external_secrets" {
  name               = "${local.prefix}-external-secrets"
  assume_role_policy = data.aws_iam_policy_document.external_secrets_assume_role.json
}

data "aws_iam_policy_document" "external_secrets" {
  statement {
    actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = [aws_secretsmanager_secret.gitops_publisher.arn]
  }
}

resource "aws_iam_role_policy" "external_secrets" {
  name   = "read-gitops-publisher-secret"
  role   = aws_iam_role.external_secrets.id
  policy = data.aws_iam_policy_document.external_secrets.json
}

resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.pilot.name
  addon_name   = "vpc-cni"
}

resource "aws_eks_addon" "coredns" {
  cluster_name = aws_eks_cluster.pilot.name
  addon_name   = "coredns"
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name = aws_eks_cluster.pilot.name
  addon_name   = "kube-proxy"
}

resource "aws_eks_node_group" "pilot" {
  cluster_name    = aws_eks_cluster.pilot.name
  node_group_name = "cpu-pilot"
  node_role_arn   = aws_iam_role.eks_node.arn
  subnet_ids      = values(aws_subnet.private)[*].id
  instance_types  = [var.node_instance_type]
  capacity_type   = "ON_DEMAND"

  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  update_config {
    max_unavailable = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_worker,
    aws_iam_role_policy_attachment.node_cni,
    aws_iam_role_policy_attachment.node_ecr,
  ]
}

resource "aws_security_group" "rds" {
  name        = "${local.prefix}-rds"
  description = "PostgreSQL ingress from EKS pilot VPC only"
  vpc_id      = aws_vpc.pilot.id
}

resource "aws_vpc_security_group_ingress_rule" "rds_postgres" {
  security_group_id = aws_security_group.rds.id
  cidr_ipv4         = aws_vpc.pilot.cidr_block
  from_port         = 5432
  to_port           = 5432
  ip_protocol       = "tcp"
}

resource "aws_db_subnet_group" "pilot" {
  name       = "${local.prefix}-db"
  subnet_ids = values(aws_subnet.private)[*].id
}

resource "aws_db_instance" "postgres" {
  identifier                  = "${local.prefix}-postgres"
  engine                      = "postgres"
  engine_version              = "16"
  instance_class              = "db.t3.micro"
  allocated_storage           = 20
  max_allocated_storage       = 20
  db_name                     = "platform"
  username                    = "platform"
  manage_master_user_password = true
  publicly_accessible         = false
  skip_final_snapshot         = true
  deletion_protection         = false
  backup_retention_period     = 0
  multi_az                    = false
  storage_encrypted           = true
  db_subnet_group_name        = aws_db_subnet_group.pilot.name
  vpc_security_group_ids      = [aws_security_group.rds.id]
  auto_minor_version_upgrade  = true
  apply_immediately           = true
}

# This container deliberately has no Terraform-managed secret value. An operator places the
# GitHub App private key in it at pilot runtime; Terraform state must never contain that key.
resource "aws_secretsmanager_secret" "gitops_publisher" {
  name                    = "${local.prefix}/gitops-publisher"
  recovery_window_in_days = 0
}

resource "aws_ecr_repository" "control_plane" {
  name                 = "ai-platform-control-plane"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "control_plane" {
  repository = aws_ecr_repository.control_plane.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep the five newest pilot images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 5
      }
      action = { type = "expire" }
    }]
  })
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

data "aws_iam_policy_document" "github_oidc_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repository}:ref:${var.github_ref}"]
    }
  }
}

resource "aws_iam_role" "github_readonly" {
  name               = "${local.prefix}-github-readonly"
  assume_role_policy = data.aws_iam_policy_document.github_oidc_assume_role.json
}

data "aws_iam_policy_document" "github_readonly" {
  statement {
    actions   = ["sts:GetCallerIdentity", "eks:DescribeCluster", "ecr:DescribeRepositories"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "github_readonly" {
  name   = "pilot-readonly-identity"
  role   = aws_iam_role.github_readonly.id
  policy = data.aws_iam_policy_document.github_readonly.json
}

data "aws_iam_policy_document" "github_terraform_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repository}:ref:${var.github_ref}"]
    }
  }
}

resource "aws_iam_role" "github_terraform" {
  name               = "${local.prefix}-github-terraform"
  assume_role_policy = data.aws_iam_policy_document.github_terraform_assume_role.json
}

# This role is intentionally limited to the named pilot footprint. It is for manually
# dispatched, branch-bound Terraform only; it is not an application workload role.
data "aws_iam_policy_document" "github_terraform" {
  statement {
    actions = [
      "ec2:Describe*", "ec2:CreateVpc", "ec2:DeleteVpc", "ec2:ModifyVpcAttribute",
      "ec2:CreateSubnet", "ec2:DeleteSubnet", "ec2:ModifySubnetAttribute",
      "ec2:CreateRouteTable", "ec2:DeleteRouteTable", "ec2:AssociateRouteTable",
      "ec2:DisassociateRouteTable", "ec2:CreateRoute", "ec2:DeleteRoute",
      "ec2:CreateInternetGateway", "ec2:DeleteInternetGateway", "ec2:AttachInternetGateway",
      "ec2:DetachInternetGateway", "ec2:AllocateAddress", "ec2:ReleaseAddress",
      "ec2:CreateNatGateway", "ec2:DeleteNatGateway", "ec2:CreateTags", "ec2:DeleteTags",
      "ec2:CreateSecurityGroup", "ec2:DeleteSecurityGroup", "ec2:AuthorizeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupIngress",
      "eks:CreateCluster", "eks:DeleteCluster", "eks:Describe*", "eks:List*", "eks:TagResource",
      "eks:UntagResource", "eks:CreateAddon", "eks:DeleteAddon", "eks:UpdateAddon",
      "eks:CreateNodegroup", "eks:DeleteNodegroup", "eks:UpdateNodegroupConfig",
      "rds:CreateDBInstance", "rds:DeleteDBInstance", "rds:Describe*", "rds:ListTagsForResource",
      "rds:AddTagsToResource", "rds:CreateDBSubnetGroup", "rds:DeleteDBSubnetGroup",
      "ecr:CreateRepository", "ecr:DeleteRepository", "ecr:Describe*", "ecr:List*", "ecr:PutLifecyclePolicy",
      "ecr:TagResource", "ecr:UntagResource", "secretsmanager:CreateSecret", "secretsmanager:DeleteSecret",
      "secretsmanager:DescribeSecret", "secretsmanager:TagResource", "secretsmanager:UntagResource",
      "iam:GetRole", "iam:CreateRole", "iam:DeleteRole", "iam:TagRole", "iam:UntagRole",
      "iam:AttachRolePolicy", "iam:DetachRolePolicy", "iam:PutRolePolicy", "iam:DeleteRolePolicy",
      "iam:ListRolePolicies", "iam:ListAttachedRolePolicies", "iam:PassRole",
      "sts:GetCallerIdentity"
    ]
    resources = ["*"]
  }

  # Terraform's remote backend needs only this project's state prefix and lock table.
  statement {
    actions   = ["s3:ListBucket", "s3:GetBucketVersioning"]
    resources = ["arn:aws:s3:::ai-platform-control-plane-tfstate-${var.expected_account_id}"]
  }

  statement {
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["arn:aws:s3:::ai-platform-control-plane-tfstate-${var.expected_account_id}/pilot/*"]
  }

  statement {
    actions   = ["dynamodb:DescribeTable", "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem"]
    resources = ["arn:aws:dynamodb:${var.aws_region}:${var.expected_account_id}:table/ai-platform-control-plane-pilot-terraform-locks"]
  }
}

resource "aws_iam_role_policy" "github_terraform" {
  name   = "pilot-terraform"
  role   = aws_iam_role.github_terraform.id
  policy = data.aws_iam_policy_document.github_terraform.json
}
