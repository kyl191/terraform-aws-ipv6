# Pick the most recent Fedora 32 build.
# Will need to be updated for subsequent Fedora releases
data "aws_ami" "fedora_cloud" {
  owners      = [125523088429] # fedora infra
  most_recent = true

  filter {
    name   = "name"
    values = ["Fedora-Cloud-Base-32*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "block-device-mapping.volume-type"
    values = ["gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
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
  public_key = file("id_rsa.pub")
}

# Free tier eligible in us-west-2
resource "aws_instance" "instance" {
  key_name                = aws_key_pair.key.key_name
  ami                     = data.aws_ami.fedora_cloud.id
  instance_type           = "t3.micro"
  disable_api_termination = true

  tags = {
    Name = "fedora"
  }

  root_block_device {
    volume_type           = "gp2"
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
  # Key name is ignored because I changed the name after creation and I don't want to tear
  # the instance down
  lifecycle {
    ignore_changes = [ami, key_name]
  }

  user_data = file("cloud-init-user-data.yaml")
}

resource "aws_security_group" "allow_default_ports" {
  name_prefix = "default_ports"
  description = "Allow http/https/ssh+ping"
  vpc_id      = aws_vpc.default.id
  lifecycle {
    create_before_destroy = true
  }

  # SSH only on ipv6 - bad form to have it public, but it's key authed
  # ipv6 only reduces the likelihood of scanning
  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description     = "MySQL"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.allow_mysql.id]
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
  vpc      = true
  instance = aws_instance.instance.id
}

# And register the instance with Cloudflare
resource "cloudflare_record" "server_A" {
  zone_id = var.cf_zone
  name    = var.domain
  value   = aws_eip.ip.public_ip
  type    = "A"
}

# And the IPv6 address as well
resource "cloudflare_record" "server_AAAA" {
  zone_id = var.cf_zone
  name    = var.domain
  value   = aws_instance.instance.ipv6_addresses[0]
  type    = "AAAA"
}
