# ── WireGuard server key pair ───────────────────────────────────────────────────

resource "wireguard_asymmetric_key" "server" {}

# ── Per-user WireGuard key pairs ────────────────────────────────────────────────
# One key pair per user. Removing a user from var.users destroys their key and
# removes their peer from the server config on the next apply.
# CIDR changes do NOT rotate keys — access is enforced server-side via iptables
# (see wg_sync.tf: null_resource.iptables_sync).

resource "wireguard_asymmetric_key" "user" {
  for_each = toset([for u in var.users : u.name])
}
