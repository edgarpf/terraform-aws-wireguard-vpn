# Minimal example

Deploys a WireGuard VPN with a single user. Supply an existing VPC and public subnet.

```hcl
# terraform.tfvars
vpc_cidr  = "10.0.0.0/16"
subnet_id = "subnet-0123456789abcdef0"
```

```bash
terraform init
terraform apply
terraform output -json user_client_configs | jq -r '."alice@example.com"' > alice.conf
```

The `user_client_configs` output is on the root module — reference it via:

```bash
terraform output -json
# Or from the module output if re-exported in your wrapper stack
```
