variable "region" { type = string, default = "us-east-1" }
variable "cluster_name" { type = string, default = "ai-platform-control-plane" }
variable "enable_apply" { type = bool, default = false, description = "Safety switch: this example is validate-only by default." }
