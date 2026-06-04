#!/bin/bash
exec > /var/log/vpn-setup.log 2>&1
set -eux

# ── Install WireGuard and iptables (Amazon Linux 2023) ──────────────────────────
dnf install -y wireguard-tools iptables iptables-services

# ── Disable firewalld (conflicts with iptables rules) ──────────────────────────
systemctl disable --now firewalld || true
iptables -F
iptables -t nat -F

# ── Enable IP forwarding; disable reverse-path filter (NATed VPN traffic) ─────
cat > /etc/sysctl.d/99-wireguard.conf << 'EOF'
net.ipv4.ip_forward = 1
net.ipv4.conf.default.rp_filter = 0
net.ipv4.conf.all.rp_filter = 0
EOF
sysctl --system
for f in /proc/sys/net/ipv4/conf/*/rp_filter; do echo 0 > "$f"; done

# ── Write server config ────────────────────────────────────────────────────────
mkdir -p /etc/wireguard
cat > /etc/wireguard/wg0.conf << 'WGEOF'
${wg_bootstrap_config}
WGEOF
chmod 600 /etc/wireguard/wg0.conf

PRIMARY_IFACE=$(ip route show default | awk '{print $5}' | head -1)
sed -i "s/__PRIMARY_IFACE__/$PRIMARY_IFACE/g" /etc/wireguard/wg0.conf

# ── Enable and start WireGuard ─────────────────────────────────────────────────
systemctl enable wg-quick@wg0
systemctl start wg-quick@wg0

# ── FORWARD baseline (iptables_sync refreshes WG_FORWARD on every apply) ─────
iptables -C FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || \
  iptables -I FORWARD 1 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

if iptables -L DOCKER-USER >/dev/null 2>&1; then
  iptables -C DOCKER-USER -i wg0 -j RETURN 2>/dev/null || iptables -I DOCKER-USER 1 -i wg0 -j RETURN
  iptables -C DOCKER-USER -o wg0 -j RETURN 2>/dev/null || iptables -I DOCKER-USER 2 -o wg0 -j RETURN
fi

iptables -N WG_FORWARD 2>/dev/null || true
iptables -C FORWARD -i wg0 -j WG_FORWARD 2>/dev/null || iptables -A FORWARD -i wg0 -j WG_FORWARD
iptables -A WG_FORWARD -j DROP

# Extra NAT safety if wg-quick PostUp did not run yet
iptables -t nat -C POSTROUTING -o "$PRIMARY_IFACE" -j MASQUERADE 2>/dev/null || \
  iptables -t nat -A POSTROUTING -o "$PRIMARY_IFACE" -j MASQUERADE

systemctl enable iptables
iptables-save > /etc/sysconfig/iptables

echo "=== WireGuard VPN setup complete ==="
