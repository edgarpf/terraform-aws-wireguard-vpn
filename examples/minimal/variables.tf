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

variable "vpc_id" {
  description = "VPC ID where the VPN will be deployed"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR used for the user's AllowedIPs (split-tunnel)"
  type        = string
}

variable "subnet_id" {
  description = "Public subnet ID for the VPN instance"
  type        = string
}

variable "tags" {
  description = "Tags applied to VPN resources"
  type        = map(string)
  default     = {}
}
