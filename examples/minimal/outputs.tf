output "public_ip" {
  description = "WireGuard endpoint Elastic IP"
  value       = module.wireguard_vpn.public_ip
}

output "user_vpn_ips" {
  description = "Assigned tunnel IPs per user"
  value       = module.wireguard_vpn.user_vpn_ips
}

output "retrieve_config_hint" {
  description = "How to export a client config from Terraform state"
  value       = module.wireguard_vpn.retrieve_config_hint
}
