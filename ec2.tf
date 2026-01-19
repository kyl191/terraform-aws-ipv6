# Pick the most recent build matching filters.
data "aws_ami" "selected" {
  for_each    = var.instance_config
  owners      = [each.value.ami_owner]
  most_recent = true

  filter {
    name   = "name"
    values = [each.value.ami_base_string]
  }

  filter {
    name   = "architecture"
    values = [each.value.architecture]
  }
}

data "aws_availability_zones" "azs" {}

data "aws_ebs_default_kms_key" "current" {}

# Workaround the AWS API returning the KMS alias instead of the ARN
# Reported in https://github.com/hashicorp/terraform-provider-aws/issues/13860
# Workaround in https://github.com/hashicorp/terraform-provider-aws/issues/15137#issuecomment-691730866
data "aws_kms_key" "current" {
  key_id = data.aws_ebs_default_kms_key.current.key_arn
}

# Arguably not needed since I enable encryption explicitly, but just as backup
resource "aws_ebs_encryption_by_default" "example" {
  enabled = true
}

# Randomly choose an AZ to launch in instead of hard coding
resource "random_shuffle" "az" {
  input        = data.aws_availability_zones.azs.zone_ids
  result_count = 1
}

resource "aws_key_pair" "key" {
  key_name   = "key"
  public_key = file(var.public_key_file)
}

resource "aws_instance" "instance" {
  for_each                = var.instance_config
  key_name                = aws_key_pair.key.key_name
  ami                     = data.aws_ami.selected[each.key].id
  instance_type           = coalesce(each.value.instance_type, each.value.architecture == "arm64" ? "t4g.small" : "t3a.small")
  disable_api_termination = true

  tags = {
    Name = each.key
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    encrypted             = true
    kms_key_id            = data.aws_kms_key.current.arn
    delete_on_termination = false
  }

  credit_specification {
    cpu_credits = "standard"
  }

  vpc_security_group_ids = [aws_security_group.allow_default_ports.id]
  ipv6_address_count     = 1
  subnet_id              = aws_subnet.subnets[random_shuffle.az.result[0]].id

  # Ignore any AMI changes, once it's created we'll just use that version to avoid
  # cycling through instances
  lifecycle {
    ignore_changes = [ami]
  }

  user_data = file(var.user_data_file)
}

resource "aws_security_group" "allow_default_ports" {
  name_prefix = "default_ports"
  description = "Allow http/https/ssh+ping"
  vpc_id      = aws_vpc.default.id
  lifecycle {
    create_before_destroy = true
  }

  dynamic "ingress" {
    for_each = var.ingress_rules
    content {
      description      = ingress.key
      from_port        = ingress.value.port
      to_port          = ingress.value.port
      protocol         = coalesce(ingress.value.protocol, "tcp")
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  }

  dynamic "ingress" {
    for_each = var.enable_rds ? [1] : []
    content {
      description     = "MySQL"
      from_port       = 3306
      to_port         = 3306
      protocol        = "tcp"
      security_groups = [aws_security_group.allow_mysql[0].id]
    }
  }

  # Allow ICMP protocols
  # type/code from http://shouldiblockicmp.com/
  ingress {
    description      = "icmp echo"
    protocol         = "icmp"
    from_port        = 8 # ICMP type
    to_port          = 0 # ICMP code
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "icmp fragmentation required"
    protocol         = "icmp"
    from_port        = 3 # ICMP type
    to_port          = 4 # ICMP code
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "icmp time excceded"
    protocol         = "icmp"
    from_port        = 11 # ICMP type
    to_port          = 0  # ICMP code
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  # https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/security-group-rules-reference.html#sg-rules-ping
  # implies icmpv6 types are supported, but in practice they aren't
  # Have to allow *all* icmpv6 protos
  ingress {
    description      = "icmpv6"
    protocol         = "icmpv6"
    from_port        = -1 # ICMP type
    to_port          = -1 # ICMP code
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  # I would lock this down further, but my instance does reach out to the public internet
  # I'm not confident I'll be able to enumerate everything
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "default_ports"
  }
}

# Another "I probably don't need this", but just in case the instance fails
# over and Auto-Recovery kicks in, but gets a new private IP off the subnet
resource "aws_eip" "ip" {
  for_each = var.instance_config
  domain   = "vpc"
  instance = aws_instance.instance[each.key].id
}
