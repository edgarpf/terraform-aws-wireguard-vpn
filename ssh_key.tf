# ── SSH key pair for VPN instance access and config sync provisioners ───────────

resource "tls_private_key" "ssh" {
  count = var.enable_ssh_key ? 1 : 0

  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "vpn" {
  count = var.enable_ssh_key ? 1 : 0

  key_name   = "${var.name}-vpn-${tls_private_key.ssh[0].public_key_fingerprint_md5}"
  public_key = tls_private_key.ssh[0].public_key_openssh

  tags = var.tags
}
