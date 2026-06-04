output "public_ip" {
  description = "WireGuard endpoint Elastic IP"
  value       = module.wireguard_vpn.public_ip
}

output "server_vpn_ip" {
  description = "Server WireGuard tunnel IP"
  value       = module.wireguard_vpn.server_vpn_ip
}

output "user_vpn_ips" {
  description = "Assigned tunnel IPs per user"
  value       = module.wireguard_vpn.user_vpn_ips
}

output "ssh_retrieve_key_hint" {
  description = "Command to save the SSH private key from state"
  value       = module.wireguard_vpn.ssh_retrieve_key_hint
}

output "retrieve_config_hint" {
  description = "Command to export a client WireGuard config from state"
  value       = module.wireguard_vpn.retrieve_config_hint
}
