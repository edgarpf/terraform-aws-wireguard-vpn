# ── Security group ──────────────────────────────────────────────────────────────

resource "aws_security_group" "vpn" {
  name        = "${var.name}-vpn"
  description = "WireGuard VPN server"
  vpc_id      = data.aws_subnet.vpn.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name}-vpn"
  })
}

resource "aws_vpc_security_group_ingress_rule" "wireguard" {
  security_group_id = aws_security_group.vpn.id
  description       = "Allow WireGuard UDP from internet"

  ip_protocol = "udp"
  from_port   = var.listen_port
  to_port     = var.listen_port
  cidr_ipv4   = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  for_each = var.enable_ssh_key ? toset(var.ssh_allowed_cidr_blocks) : toset([])

  security_group_id = aws_security_group.vpn.id
  description       = "Allow SSH from ${each.value}"

  ip_protocol = "tcp"
  from_port   = 22
  to_port     = 22
  cidr_ipv4   = each.value
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.vpn.id
  description       = "Allow all outbound traffic"

  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"
}
