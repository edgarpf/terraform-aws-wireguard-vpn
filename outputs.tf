# ── VPN instance ───────────────────────────────────────────────────────────────

output "instance_id" {
  description = "ID of the VPN EC2 instance"
  value       = aws_instance.vpn.id
}

output "public_ip" {
  description = "Elastic IP address of the VPN server (WireGuard endpoint for client configs)"
  value       = aws_eip.vpn.public_ip
}

output "private_ip" {
  description = "Private IP of the VPN instance within the VPC"
  value       = aws_network_interface.vpn.private_ip
}

output "security_group_id" {
  description = "ID of the VPN security group"
  value       = aws_security_group.vpn.id
}

# ── Network ────────────────────────────────────────────────────────────────────

output "vpn_cidr" {
  description = "WireGuard tunnel subnet. Traffic from VPN users is NATted to the VPN server's private IP inside the VPC."
  value       = var.vpn_cidr
}

output "server_vpn_ip" {
  description = "WireGuard tunnel IP of the server (e.g. 10.100.0.1)"
  value       = local.server_vpn_ip
}

output "user_vpn_ips" {
  description = "Map of user name to WireGuard tunnel IP assigned in their client config"
  value       = local.user_vpn_ips
}

# ── Per-user client configs (sensitive — stored in Terraform state) ─────────────

output "user_client_configs" {
  description = "Map of user name to WireGuard client .conf content. Only active users (cidrs non-empty) appear here. Contains private keys — restrict state access."
  value       = local.user_client_configs
  sensitive   = true
}

output "retrieve_config_hint" {
  description = "Example command to save a user's WireGuard .conf from Terraform output"
  value       = "terraform output -json user_client_configs | jq -r '.\"<user@example.com>\"' > <user>.conf"
}

# ── SSH access ──────────────────────────────────────────────────────────────────

output "ssh_private_key_pem" {
  description = "RSA private key for SSH access to the VPN instance. Null when enable_ssh_key is false. Stored in Terraform state — restrict state access."
  value       = var.enable_ssh_key ? tls_private_key.ssh[0].private_key_pem : null
  sensitive   = true
}

output "ssh_connection_hint" {
  description = "Example SSH command to connect to the VPN instance"
  value       = var.enable_ssh_key ? "ssh -i vpn.pem ${var.ssh_user}@${aws_eip.vpn.public_ip}" : null
}

output "ssh_retrieve_key_hint" {
  description = "Example command to save the SSH private key from Terraform output"
  value       = var.enable_ssh_key ? "terraform output -raw ssh_private_key_pem > vpn.pem && chmod 600 vpn.pem" : null
}
