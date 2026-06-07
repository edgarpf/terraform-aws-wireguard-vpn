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
  description = "Primary VPC CIDR for split-tunnel AllowedIPs"
  type        = string
}

variable "peer_vpc_cidr" {
  description = "Second VPC CIDR (e.g. peered network) for bob's AllowedIPs"
  type        = string
  default     = "10.1.0.0/16"
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
  default = {
    Environment = "example"
  }
}
