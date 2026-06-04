#!/bin/bash
set -eu

# Idempotent VPN iptables baseline + per-user WG_FORWARD rules.
# Safe to re-run on every apply (iptables_sync).

# ── Sysctl: asymmetric routing for NATed VPN traffic ───────────────────────────
cat > /etc/sysctl.d/99-wireguard.conf << 'EOF'
net.ipv4.ip_forward = 1
net.ipv4.conf.default.rp_filter = 0
net.ipv4.conf.all.rp_filter = 0
EOF
sysctl --system >/dev/null
for f in /proc/sys/net/ipv4/conf/*/rp_filter; do echo 0 > "$f"; done

# ── FORWARD: return path (policy DROP on AL2023) ─────────────────────────────
iptables -C FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || \
  iptables -I FORWARD 1 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# Docker (if installed) inserts chains before WG_FORWARD — bypass for wg0
if iptables -L DOCKER-USER >/dev/null 2>&1; then
  iptables -C DOCKER-USER -i wg0 -j RETURN 2>/dev/null || iptables -I DOCKER-USER 1 -i wg0 -j RETURN
  iptables -C DOCKER-USER -o wg0 -j RETURN 2>/dev/null || iptables -I DOCKER-USER 2 -o wg0 -j RETURN
fi

# ── INPUT: DNS to dnsmasq on tunnel IP, and return traffic ─────────────────────
iptables -C INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || \
  iptables -I INPUT 1 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

%{ if dns_enabled ~}
iptables -C INPUT -i wg0 -p udp --dport 53 -j ACCEPT 2>/dev/null || iptables -A INPUT -i wg0 -p udp --dport 53 -j ACCEPT
iptables -C INPUT -i wg0 -p tcp --dport 53 -j ACCEPT 2>/dev/null || iptables -A INPUT -i wg0 -p tcp --dport 53 -j ACCEPT
%{ endif ~}

# ── WG_FORWARD: per-user egress policy ───────────────────────────────────────
iptables -N WG_FORWARD 2>/dev/null || true
iptables -C FORWARD -i wg0 -j WG_FORWARD 2>/dev/null || iptables -A FORWARD -i wg0 -j WG_FORWARD
iptables -F WG_FORWARD

%{ for user in users ~}
%{ for cidr in user.cidrs ~}
iptables -A WG_FORWARD -s ${user.tunnel_ip} -d ${cidr} -j ACCEPT
%{ endfor ~}
%{ endfor ~}

iptables -A WG_FORWARD -j DROP

iptables-save > /etc/sysconfig/iptables

# Re-apply after Docker reorders FORWARD on boot (DOCKER-* chains insert at top)
SCRIPT_DEST=/usr/local/sbin/vpn-restore-iptables.sh
if [ "$(readlink -f "$0" 2>/dev/null || echo "$0")" != "$(readlink -f "$SCRIPT_DEST" 2>/dev/null || echo "$SCRIPT_DEST")" ]; then
  cp "$0" "$SCRIPT_DEST"
  chmod 755 "$SCRIPT_DEST"
fi

cat > /etc/systemd/system/vpn-restore-iptables.service << 'EOF'
[Unit]
Description=Restore WireGuard VPN iptables after Docker
After=wg-quick@wg0.service docker.service network-online.target
Wants=wg-quick@wg0.service

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/vpn-restore-iptables.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable vpn-restore-iptables.service

echo "iptables rules applied successfully."
