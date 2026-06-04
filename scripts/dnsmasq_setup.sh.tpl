#!/bin/bash
set -eu

# Manages dnsmasq for static DNS entries on the WireGuard tunnel IP.
# When static_hosts is non-empty: installs dnsmasq and serves each entry.
# When static_hosts is empty: removes the config and stops dnsmasq.
# This script is idempotent — safe to re-run on every apply.

%{ if length(static_hosts) > 0 ~}
dnf install -y dnsmasq

cat > /etc/dnsmasq.d/vpn-forwarder.conf << 'DNSEOF'
# Do not read upstream servers from /etc/resolv.conf
no-resolv
# Bind only on the WireGuard tunnel IP and loopback — not the public NIC
listen-address=127.0.0.1,${server_vpn_ip}
bind-interfaces
# Public DNS fallback for all other queries
server=1.1.1.1
%{ for hostname, ip in static_hosts ~}
address=/${hostname}/${ip}
%{ endfor ~}
DNSEOF

# Allow DNS queries from WireGuard clients to reach dnsmasq on this host
iptables -C INPUT -i wg0 -p udp --dport 53 -j ACCEPT 2>/dev/null || iptables -A INPUT -i wg0 -p udp --dport 53 -j ACCEPT
iptables -C INPUT -i wg0 -p tcp --dport 53 -j ACCEPT 2>/dev/null || iptables -A INPUT -i wg0 -p tcp --dport 53 -j ACCEPT
iptables-save > /etc/sysconfig/iptables

# Remove a prior drop-in if present (Requires=wg-quick caused a systemd ordering cycle)
rm -rf /etc/systemd/system/dnsmasq.service.d/wireguard.conf
systemctl daemon-reload

# Do not start at boot before wg0 exists; wg-quick PostUp starts dnsmasq when the tunnel is up
systemctl disable dnsmasq
systemctl restart dnsmasq
echo "dnsmasq DNS forwarder configured successfully."
%{ else ~}
# No static hosts — remove dnsmasq config and stop the service
rm -f /etc/dnsmasq.d/vpn-forwarder.conf
systemctl stop dnsmasq 2>/dev/null || true
systemctl disable dnsmasq 2>/dev/null || true
echo "dnsmasq DNS forwarder removed."
%{ endif ~}
