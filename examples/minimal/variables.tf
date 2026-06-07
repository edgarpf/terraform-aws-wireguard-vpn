variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Name prefix for VPN resources"
  type        = string
  default     = "example-vpn"
}

variable "vpc_cidr" {
  description = "VPC CIDR used for the user's AllowedIPs (split-tunnel)"
  type        = string
}

variable "subnet_id" {
  description = "Public subnet ID for the VPN instance"
  type        = string
}

variable "ssh_allowed_cidr_blocks" {
  description = "CIDRs allowed to SSH (must include terraform apply source IP). Prefer /32 per host; avoid 0.0.0.0/0."
  type        = list(string)
}

variable "tags" {
  description = "Tags applied to VPN resources"
  type        = map(string)
  default     = {}
}
