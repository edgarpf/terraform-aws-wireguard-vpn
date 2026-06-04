# ── Sync WireGuard peer list on user changes ─────────────────────────────────
# Uses `wg syncconf` so existing tunnels are NOT interrupted.

resource "null_resource" "wg_config_sync" {
  count = local.config_sync_enabled ? 1 : 0

  triggers = {
    wg_config_hash = sha256(local.wg_server_config)
    instance_id    = aws_instance.vpn.id
  }

  connection {
    type        = "ssh"
    user        = var.ssh_user
    host        = aws_eip.vpn.public_ip
    private_key = tls_private_key.ssh[0].private_key_pem
    timeout     = "10m"
  }

  provisioner "file" {
    content     = local.wg_server_config
    destination = "/tmp/wg0.conf.new"
  }

  provisioner "remote-exec" {
    inline = [
      "until sudo systemctl is-active --quiet wg-quick@wg0; do echo 'Waiting for WireGuard...'; sleep 10; done",
      "PRIMARY_IFACE=$(ip route show default | awk '{print $5}' | head -1)",
      "sed -i \"s/__PRIMARY_IFACE__/$PRIMARY_IFACE/g\" /tmp/wg0.conf.new",
      "sudo cp /tmp/wg0.conf.new /etc/wireguard/wg0.conf",
      "sudo chmod 600 /etc/wireguard/wg0.conf",
      "rm /tmp/wg0.conf.new",
      "sudo bash -c 'wg syncconf wg0 <(wg-quick strip wg0)'",
      "echo 'WireGuard peer list updated successfully.'",
    ]
  }

  depends_on = [aws_instance.vpn, aws_eip_association.vpn]
}

resource "null_resource" "iptables_sync" {
  count = local.config_sync_enabled ? 1 : 0

  triggers = {
    iptables_rules_hash = sha256(local.iptables_rules_script)
    instance_id         = aws_instance.vpn.id
  }

  connection {
    type        = "ssh"
    user        = var.ssh_user
    host        = aws_eip.vpn.public_ip
    private_key = tls_private_key.ssh[0].private_key_pem
    timeout     = "10m"
  }

  provisioner "file" {
    content     = local.iptables_rules_script
    destination = "/tmp/iptables_rules.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "until sudo systemctl is-active --quiet wg-quick@wg0; do echo 'Waiting for WireGuard...'; sleep 10; done",
      "sudo cp /tmp/iptables_rules.sh /usr/local/sbin/vpn-restore-iptables.sh",
      "sudo chmod 755 /usr/local/sbin/vpn-restore-iptables.sh",
      "sudo bash /usr/local/sbin/vpn-restore-iptables.sh",
      "rm /tmp/iptables_rules.sh",
      "echo 'iptables CIDR rules updated successfully.'",
    ]
  }

  depends_on = [aws_instance.vpn, aws_eip_association.vpn, null_resource.wg_config_sync]
}

resource "null_resource" "dns_sync" {
  count = local.config_sync_enabled ? 1 : 0

  triggers = {
    dnsmasq_script_hash = sha256(local.dnsmasq_script)
    instance_id         = aws_instance.vpn.id
  }

  connection {
    type        = "ssh"
    user        = var.ssh_user
    host        = aws_eip.vpn.public_ip
    private_key = tls_private_key.ssh[0].private_key_pem
    timeout     = "10m"
  }

  provisioner "file" {
    content     = local.dnsmasq_script
    destination = "/tmp/dnsmasq_setup.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "until sudo systemctl is-active --quiet wg-quick@wg0; do echo 'Waiting for WireGuard...'; sleep 10; done",
      "sudo bash /tmp/dnsmasq_setup.sh",
      "rm /tmp/dnsmasq_setup.sh",
      "echo 'dnsmasq DNS forwarder updated successfully.'",
    ]
  }

  depends_on = [aws_instance.vpn, aws_eip_association.vpn, null_resource.wg_config_sync]
}
