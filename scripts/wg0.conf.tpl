[Interface]
PrivateKey = ${server_private_key}
Address = ${server_address}
ListenPort = ${listen_port}
PostUp = iptables -t nat -A POSTROUTING -o __PRIMARY_IFACE__ -j MASQUERADE; for f in /proc/sys/net/ipv4/conf/*/rp_filter; do echo 0 > "$f"; done; systemctl try-restart dnsmasq 2>/dev/null || true
PostDown = iptables -t nat -D POSTROUTING -o __PRIMARY_IFACE__ -j MASQUERADE
%{ for peer in peers ~}
[Peer]
# ${peer.name}
PublicKey = ${peer.public_key}
AllowedIPs = ${peer.allowed_ip}
%{ endfor ~}
