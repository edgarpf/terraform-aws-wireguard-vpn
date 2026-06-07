# ── General ────────────────────────────────────────────────────────────────────

variable "name" {
  description = "Name prefix for all resources created by this module (e.g. corp-vpn)"
  type        = string
}

variable "tags" {
  description = "Tags applied to all resources created by this module"
  type        = map(string)
  default     = {}
}

# ── Users ───────────────────────────────────────────────────────────────────────

variable "users" {
  description = "List of VPN users. Each user gets a unique WireGuard key pair and a stable tunnel IP from offset within vpn_cidr (server = 1, users start at 2). name accepts any string including email addresses. offset must be unique per user and is never reassigned when other users are added or removed (gaps are allowed). cidrs sets AllowedIPs in the client config; cidrs = [] pre-provisions keys without granting network access — no WireGuard peer and no client config output."
  type = list(object({
    name   = string
    offset = number
    cidrs  = list(string)
  }))

  validation {
    condition     = length(var.users) == length(distinct([for u in var.users : u.offset]))
    error_message = "Each user must have a unique offset."
  }

  validation {
    condition     = alltrue([for u in var.users : u.offset >= 2])
    error_message = "User offsets must be >= 2 (1 is reserved for the server)."
  }
}

# ── Network ─────────────────────────────────────────────────────────────────────

variable "subnet_id" {
  description = "ID of a public subnet where the VPN instance will be launched"
  type        = string
}

variable "vpn_cidr" {
  description = "WireGuard tunnel subnet. Must not overlap with the VPC CIDR. Server uses offset 1; each user's offset maps to cidrhost(vpn_cidr, offset)."
  type        = string
  default     = "10.100.0.0/24"
}

variable "listen_port" {
  description = "WireGuard UDP listen port on the server"
  type        = number
  default     = 51820
}

variable "client_dns" {
  description = "DNS server(s) written to each WireGuard client .conf (DNS = line). Ignored when dns_static_hosts is non-empty — the VPN tunnel IP is used instead."
  type        = string
  default     = "1.1.1.1"
}

variable "dns_static_hosts" {
  description = "Map of private hostname to IP address. When non-empty, dnsmasq is installed on the VPN server, VPN clients use the server's tunnel IP as DNS, and each entry is served as a static answer."
  type        = map(string)
  default     = {}
}

# ── Compute ────────────────────────────────────────────────────────────────────

variable "instance_type" {
  description = "EC2 instance type for the VPN server"
  type        = string
  default     = "t3.small"
}

variable "ami_id" {
  description = "AMI ID for the VPN instance. If null, the latest Amazon Linux 2023 x86_64 AMI is used."
  type        = string
  default     = null
}

variable "root_volume_size" {
  description = "Root EBS volume size in GB"
  type        = number
  default     = 30
}

# ── SSH and config sync ─────────────────────────────────────────────────────────

variable "enable_ssh_key" {
  description = "When true, generates an RSA key pair and registers the public key with AWS. Required when enable_config_sync is true."
  type        = bool
  default     = true
}

variable "ssh_allowed_cidr_blocks" {
  description = "CIDR blocks allowed to SSH into the VPN instance (TCP 22). Must include the machine running terraform apply so wg_config_sync can reach the instance."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enable_config_sync" {
  description = "When true, pushes WireGuard peer list, iptables rules, and dnsmasq config to the instance over SSH after each apply. Requires enable_ssh_key = true."
  type        = bool
  default     = true
}

variable "ssh_user" {
  description = "SSH user for config sync provisioners. ec2-user for Amazon Linux; ubuntu for Ubuntu AMIs."
  type        = string
  default     = "ec2-user"
}
