# ── VPN EC2 instance (WireGuard server) ───────────────────────────────────────────

resource "aws_network_interface" "vpn" {
  subnet_id       = var.subnet_id
  security_groups = [aws_security_group.vpn.id]

  # Required for NAT: allows the instance to forward packets not addressed to its own IP.
  source_dest_check = false

  tags = merge(var.tags, {
    Name = "${var.name}-vpn"
  })
}

resource "aws_instance" "vpn" {
  ami           = local.ami_id
  instance_type = var.instance_type
  key_name      = var.enable_ssh_key ? aws_key_pair.vpn[0].key_name : null

  primary_network_interface {
    network_interface_id = aws_network_interface.vpn.id
  }

  user_data_base64            = base64encode(local.setup_script)
  user_data_replace_on_change = false

  root_block_device {
    volume_size = var.root_volume_size
  }

  tags = merge(var.tags, {
    Name = "${var.name}-vpn"
  })

  # AWS provider 6.x toggles source_dest_check on the instance when using
  # primary_network_interface, even though it is correctly false on the ENI.
  # See https://github.com/hashicorp/terraform-provider-aws/issues/44768
  lifecycle {
    ignore_changes = [source_dest_check]
  }
}

resource "aws_eip" "vpn" {
  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${var.name}-vpn-eip"
  })
}

resource "aws_eip_association" "vpn" {
  instance_id   = aws_instance.vpn.id
  allocation_id = aws_eip.vpn.id
}
