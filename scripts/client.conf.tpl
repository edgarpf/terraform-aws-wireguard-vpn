[Interface]
PrivateKey = ${client_private_key}
Address = ${client_address}/32
DNS = ${client_dns}

[Peer]
PublicKey = ${server_public_key}
Endpoint = ${server_endpoint}
AllowedIPs = ${route_cidrs}
PersistentKeepalive = 25
