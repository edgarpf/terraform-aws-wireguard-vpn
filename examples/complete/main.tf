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
  subnet_id = var.subnet_id

  dns_static_hosts = {
    "db.internal.example.com" = "10.0.4.71"
  }

  users = [
    {
      name   = "alice@example.com"
      offset = 2
      cidrs  = [var.vpc_cidr]
    },
    {
      name   = "bob@example.com"
      offset = 3
      cidrs  = [var.vpc_cidr, var.peer_vpc_cidr]
    },
    {
      name   = "charlie@example.com"
      offset = 4
      cidrs  = [] # pre-provisioned, no access yet
    },
  ]

  tags = var.tags
}
