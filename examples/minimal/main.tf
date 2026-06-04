terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

module "wireguard_vpn" {
  source = "../.."

  name      = var.name
  vpc_id    = var.vpc_id
  subnet_id = var.subnet_id

  users = [
    {
      name   = "alice@example.com"
      offset = 2
      cidrs  = [var.vpc_cidr]
    },
  ]

  tags = var.tags
}
