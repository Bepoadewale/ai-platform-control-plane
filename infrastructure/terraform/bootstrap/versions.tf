terraform {
  required_version = ">= 1.8.0"

  # The initial apply runs with `-backend=false`, creates this backend's resources, then migrates
  # its local state into the newly created encrypted S3 bucket.
  backend "s3" {}

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.required_tags
  }
}
