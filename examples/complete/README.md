# Complete example

Multi-user VPN with per-user CIDRs, a suspended user (`cidrs = []`), and static DNS via dnsmasq.

```bash
terraform init
terraform apply \
  -var="vpc_cidr=10.0.0.0/16" \
  -var="subnet_id=subnet-0123456789abcdef0" \
  -var='ssh_allowed_cidr_blocks=["203.0.113.10/32"]'  # /32 per apply host; avoid 0.0.0.0/0

terraform output -raw ssh_retrieve_key_hint | bash
terraform output retrieve_config_hint
```

Client configs (sensitive) are on the module — access via the root module's state after apply.
