locals {
  # Map of name → user object for easy lookup by name.
  users_by_name = { for u in var.users : u.name => u }

  # Sorted names — iteration order for peers and iptables only (not used for IP assignment).
  sorted_users = sort([for u in var.users : u.name])

  # When dns_static_hosts is set, clients point at the VPN server's tunnel IP (which runs dnsmasq).
  effective_client_dns = length(var.dns_static_hosts) > 0 ? local.server_vpn_ip : var.client_dns

  # Server always gets .1 in the VPN subnet (e.g. 10.100.0.1)
  server_vpn_ip = cidrhost(var.vpn_cidr, 1)
  vpn_prefix    = split("/", var.vpn_cidr)[1]

  # Per-user tunnel IPs from explicit offset (stable when other users are added or removed).
  user_vpn_ips = {
    for u in var.users :
    u.name => cidrhost(var.vpn_cidr, u.offset)
  }

  # Users with at least one CIDR, in sorted order.
  active_sorted_users = [
    for name in local.sorted_users :
    local.users_by_name[name]
    if length(local.users_by_name[name].cidrs) > 0
  ]

  # Full server wg0.conf (active peers only) — used by wg_config_sync, not embedded in user_data.
  wg_server_config = templatefile("${path.module}/scripts/wg0.conf.tpl", {
    server_private_key = wireguard_asymmetric_key.server.private_key
    server_address     = "${local.server_vpn_ip}/${local.vpn_prefix}"
    listen_port        = var.listen_port
    peers = [
      for u in local.active_sorted_users : {
        name       = u.name
        public_key = wireguard_asymmetric_key.user[u.name].public_key
        allowed_ip = "${local.user_vpn_ips[u.name]}/32"
      }
    ]
  })

  # Interface-only wg0.conf for first boot (no [Peer] blocks). Embedding this in user_data keeps
  # metadata stable when var.users changes — otherwise EC2 may be replaced and client configs break.
  # Peers are applied immediately after create via wg_config_sync.
  wg_bootstrap_config = templatefile("${path.module}/scripts/wg0.conf.tpl", {
    server_private_key = wireguard_asymmetric_key.server.private_key
    server_address     = "${local.server_vpn_ip}/${local.vpn_prefix}"
    listen_port        = var.listen_port
    peers              = []
  })

  setup_script = templatefile("${path.module}/scripts/setup.sh.tpl", {
    wg_bootstrap_config = local.wg_bootstrap_config
  })

  dnsmasq_script = templatefile("${path.module}/scripts/dnsmasq_setup.sh.tpl", {
    server_vpn_ip = local.server_vpn_ip
    static_hosts  = var.dns_static_hosts
  })

  user_client_configs = {
    for u in local.active_sorted_users :
    u.name => templatefile("${path.module}/scripts/client.conf.tpl", {
      client_private_key = wireguard_asymmetric_key.user[u.name].private_key
      client_address     = local.user_vpn_ips[u.name]
      client_dns         = local.effective_client_dns
      server_public_key  = wireguard_asymmetric_key.server.public_key
      server_endpoint    = "${aws_eip.vpn.public_ip}:${var.listen_port}"
      route_cidrs = join(", ", concat(
        length(var.dns_static_hosts) > 0 ? [var.vpn_cidr] : [],
        u.cidrs
      ))
    })
  }

  iptables_rules_script = templatefile("${path.module}/scripts/iptables_rules.sh.tpl", {
    dns_enabled = length(var.dns_static_hosts) > 0
    users = [
      for name in local.sorted_users : {
        tunnel_ip = local.user_vpn_ips[name]
        cidrs     = local.users_by_name[name].cidrs
      }
      if length(local.users_by_name[name].cidrs) > 0
    ]
  })

  ami_id = var.ami_id != null ? var.ami_id : data.aws_ami.amazon_linux_2023[0].id

  config_sync_enabled = var.enable_config_sync && var.enable_ssh_key
}

check "config_sync_requires_ssh" {
  assert {
    condition     = !var.enable_config_sync || var.enable_ssh_key
    error_message = "enable_config_sync requires enable_ssh_key = true."
  }
}
