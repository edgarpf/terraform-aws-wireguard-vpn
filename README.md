# terraform-aws-wireguard-vpn

Terraform module that deploys a **WireGuard VPN server** on AWS EC2, manages per-user key pairs and client configs entirely in Terraform, and supports **zero-downtime** peer updates when users are added or removed.

## Why this module

Most WireGuard-on-AWS modules embed the full peer list in `user_data`. Adding a user changes `user_data` and **replaces the EC2 instance**, which breaks existing client configs and drops active tunnels.

This module avoids that by:

- First-boot `user_data` contains only the WireGuard `[Interface]` block (no peers)
- Peers are pushed after boot via `wg syncconf` over SSH
- Each user has a **stable tunnel IP** via an explicit `offset`
- Changing `users` or `cidrs` does **not** recreate the instance

## Features

| Feature | How it works |
|---------|--------------|
| **Per-user WireGuard keys** | `wireguard_asymmetric_key` resource per user; keys live in Terraform state |
| **Declarative user management** | Add/remove entries in `var.users`; next `apply` adds/revokes peers automatically |
| **Per-user CIDRs** | Each user's `cidrs` list becomes `AllowedIPs` in their `.conf`. Set `cidrs = []` to pre-provision keys without network access |
| **Server-side CIDR enforcement** | `cidrs` changes enforced via iptables (`WG_FORWARD` chain) — no key rotation or re-download required |
| **Zero-downtime peer sync** | `wg syncconf` over SSH — existing tunnels stay up when peers change |
| **Stable endpoint** | Elastic IP associated with the instance |
| **Client configs in state** | Sensitive output `user_client_configs` — no AWS Secrets Manager required |
| **Private DNS static hosts** | Optional dnsmasq for private hostname → IP mappings |
| **Split-tunnel / full-tunnel** | Controlled per user via `cidrs` |

## Usage

```hcl
module "wireguard_vpn" {
  source = "github.com/<your-org>/terraform-aws-wireguard-vpn?ref=v1.0.0"

  name      = "corp-vpn"
  subnet_id = module.vpc.public_subnets[0]

  users = [
    {
      name   = "alice@example.com"
      offset = 2
      cidrs  = ["10.0.0.0/16"]
    },
    {
      name   = "bob@example.com"
      offset = 3
      cidrs  = ["10.0.0.0/16", "10.1.0.0/16"]
    },
  ]
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| aws | >= 5.0 |
| wireguard (OJFord/wireguard) | >= 0.3.1 |
| tls | >= 4.0 |
| null | >= 3.2 |

**Operational requirements:**

- The machine running `terraform apply` must reach the instance on **TCP 22** (config sync provisioners) unless `enable_config_sync = false`
- `vpn_cidr` must not overlap your VPC CIDR
- Use **encrypted remote state** (e.g. S3 + KMS) — WireGuard private keys and SSH keys are stored in state

## Resources

This module creates the following resources.

### AWS

| Resource | Description |
|----------|-------------|
| [`aws_network_interface`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_interface) | ENI in your subnet (`source_dest_check = false` for forwarding) |
| [`aws_instance`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance) | VPN server (Amazon Linux 2023 by default) |
| [`aws_eip`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip) | Elastic IP for the WireGuard endpoint |
| [`aws_eip_association`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip_association) | Associates the EIP with the instance |
| [`aws_security_group`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | VPN security group |
| [`aws_vpc_security_group_ingress_rule`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | UDP WireGuard (`listen_port`) and TCP 22 (SSH) |
| [`aws_vpc_security_group_egress_rule`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | Allow all egress |
| [`aws_key_pair`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/key_pair) | SSH public key (when `enable_ssh_key = true`) |

### WireGuard, TLS, and config sync

| Resource | Description |
|----------|-------------|
| [`wireguard_asymmetric_key`](https://registry.terraform.io/providers/OJFord/wireguard/latest/docs/resources/asymmetric_key) (server) | Server WireGuard key pair |
| [`wireguard_asymmetric_key`](https://registry.terraform.io/providers/OJFord/wireguard/latest/docs/resources/asymmetric_key) (per user) | One key pair per `var.users` entry |
| [`tls_private_key`](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | RSA 4096 SSH key for provisioners (when `enable_ssh_key = true`) |
| [`null_resource`](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) `wg_config_sync` | Pushes peer list via `wg syncconf` over SSH (when `enable_config_sync = true`) |
| [`null_resource`](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) `iptables_sync` | Applies per-user `WG_FORWARD` iptables rules |
| [`null_resource`](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) `dns_sync` | Configures dnsmasq for `dns_static_hosts` (runs when config sync is enabled; no-op when map is empty) |

### Data sources

| Data source | Description |
|-------------|-------------|
| [`aws_subnet`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnet) | Looks up VPC ID from `subnet_id` |
| [`aws_ami`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | Latest Amazon Linux 2023 AMI (when `ami_id` is `null`) |

No other AWS services (VPC, subnets, Secrets Manager, etc.) are created — you supply a public `subnet_id` (VPC is derived automatically).

## Adding and removing users

Edit `users` and run `terraform apply`:

```hcl
# Add a user — pick the next unused offset
users = [
  { name = "alice@example.com", offset = 2, cidrs = ["10.0.0.0/16"] },
  { name = "bob@example.com",   offset = 3, cidrs = ["10.0.0.0/16"] },
]

# Remove a user — other users' offsets and keys unchanged
users = [
  { name = "bob@example.com", offset = 3, cidrs = ["10.0.0.0/16"] },
]

# Suspend without removing — keys kept, no peer, no config output
users = [
  { name = "alice@example.com", offset = 2, cidrs = [] },
  { name = "bob@example.com",   offset = 3, cidrs = ["10.0.0.0/16"] },
]
```

After each apply:

- **Added/activated users**: new key (if needed), peer added via `wg syncconf`, iptables rules added — existing tunnels unaffected
- **Removed users**: peer dropped, keys destroyed — their `.conf` stops working immediately
- **Suspended users** (`cidrs = []`): peer removed, keys kept for reactivation
- **`cidrs` changed**: iptables updated only — no key rotation

> Renaming a user destroys and recreates their keys. Changing `offset` changes their tunnel IP — they need a new `.conf`.

## Retrieving a user's WireGuard config

Client configs are exposed as a sensitive Terraform output (not Secrets Manager):

```bash
terraform output -json user_client_configs | jq -r '."alice@example.com"' > alice.conf
```

Import `alice.conf` into the [WireGuard client](https://www.wireguard.com/install/) and enable the tunnel.

## SSH access

The module generates an RSA 4096 key pair. The private key is in Terraform state:

```bash
terraform output -raw ssh_private_key_pem > vpn.pem && chmod 600 vpn.pem
ssh -i vpn.pem ec2-user@$(terraform output -raw public_ip)
```

Port 22 defaults to `0.0.0.0/0` so `terraform apply` can reach the instance from your laptop or CI. Restrict `ssh_allowed_cidr_blocks` in production.

Set `enable_ssh_key = false` only if `enable_config_sync = false` (provisioners require SSH).

## Split-tunnel vs full-tunnel

Each user's `cidrs` becomes `AllowedIPs` in their client config:

```hcl
# Split-tunnel — only VPC traffic through VPN
{ name = "alice@example.com", offset = 2, cidrs = ["10.0.0.0/16"] }

# Full-tunnel — all IPv4 through VPN
{ name = "alice@example.com", offset = 2, cidrs = ["0.0.0.0/0"] }
```

## IP assignment

| Offset | Role |
|--------|------|
| `1` | Server (e.g. `10.100.0.1`) — reserved, not assignable to users |
| `2`, `3`, … | Users — pick explicitly when adding someone |

Gaps are allowed. Do not reuse a removed user's offset for a different person unless intentional.

## Private DNS (`dns_static_hosts`)

When set, dnsmasq on the VPN server serves static answers and clients use the server's tunnel IP as DNS:

```hcl
dns_static_hosts = {
  "db.internal.example.com" = "10.0.4.71"
}
```

## Security notes

- WireGuard UDP port is open to `0.0.0.0/0` by default (required for remote clients)
- **All private keys** (WireGuard + SSH) are in Terraform state — treat state as highly sensitive
- Restrict `ssh_allowed_cidr_blocks` when possible
- VPN traffic is NATted to the server's **private IP** inside the VPC

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `name` | Name prefix for resources | `string` | — | yes |
| `subnet_id` | Public subnet ID (VPC is derived from this) | `string` | — | yes |
| `users` | List of `{ name, offset, cidrs }` | `list(object)` | — | yes |
| `vpn_cidr` | WireGuard tunnel subnet | `string` | `10.100.0.0/24` | no |
| `listen_port` | WireGuard UDP port | `number` | `51820` | no |
| `client_dns` | DNS in client `.conf` | `string` | `1.1.1.1` | no |
| `dns_static_hosts` | Static hostname → IP map for dnsmasq | `map(string)` | `{}` | no |
| `instance_type` | EC2 instance type | `string` | `t3.small` | no |
| `ami_id` | AMI ID (null = latest AL2023) | `string` | `null` | no |
| `root_volume_size` | Root volume GB | `number` | `30` | no |
| `enable_ssh_key` | Generate SSH key for instance and provisioners | `bool` | `true` | no |
| `ssh_allowed_cidr_blocks` | CIDRs allowed to SSH (TCP 22) | `list(string)` | `["0.0.0.0/0"]` | no |
| `enable_config_sync` | Push peer/iptables/dns changes over SSH | `bool` | `true` | no |
| `ssh_user` | SSH user for provisioners | `string` | `ec2-user` | no |
| `tags` | Tags for all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| `instance_id` | EC2 instance ID |
| `public_ip` | Elastic IP (WireGuard endpoint) |
| `private_ip` | Instance private IP in VPC |
| `security_group_id` | VPN security group ID |
| `vpc_id` | VPC ID (derived from `subnet_id`) |
| `vpn_cidr` | WireGuard tunnel subnet |
| `server_vpn_ip` | Server tunnel IP |
| `user_vpn_ips` | Map of user → tunnel IP |
| `user_client_configs` | Sensitive map of user → `.conf` content |
| `retrieve_config_hint` | Example output command |
| `ssh_private_key_pem` | Sensitive SSH private key |
| `ssh_connection_hint` | Example SSH command |
| `ssh_retrieve_key_hint` | Example key retrieval command |

## Examples

- [`examples/minimal`](examples/minimal) — single user, basic VPC inputs
- [`examples/complete`](examples/complete) — multiple users with `dns_static_hosts`

## License

MIT — see [LICENSE](LICENSE).
