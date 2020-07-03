# To allow IPv6 communication, we need to
# * Add an IPv6 block to the VPC
# * Add a ::0/0 route to the route table pointing at the internet gateway
# * Add IPv6 blocks to the subnets

# Randomly generate an octet for the VPC instead of hard coding
resource "random_id" "vpc_cidr_block" {
  byte_length = 1
}

# Have to create a new VPC because the AWS terraform provider doesn't support
# adding IPv6 to the default VPC
# https://github.com/terraform-providers/terraform-provider-aws/issues/13859
resource "aws_vpc" "default" {
  enable_dns_support               = true
  enable_dns_hostnames             = true
  assign_generated_ipv6_cidr_block = true
  cidr_block                       = "10.${random_id.vpc_cidr_block.dec}.0.0/16"
}

resource "aws_internet_gateway" "default" {
  vpc_id = aws_vpc.default.id
}

# Add routes for both IPv4 and IPv6
# Not using egress only gateway because I want to be reachable over IPv6
resource "aws_default_route_table" "default" {
  default_route_table_id = aws_vpc.default.default_route_table_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.default.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.default.id
  }
}

# Create a subnet for every AZ in the region
# Use zone IDs since those are stable, instead of the AZ names
resource "aws_subnet" "subnets" {
  for_each = {
    for zid in data.aws_availability_zones.azs.zone_ids :
    zid => index(data.aws_availability_zones.azs.zone_ids, zid)
  }

  vpc_id                  = aws_vpc.default.id
  availability_zone_id    = each.key
  cidr_block              = cidrsubnet(aws_vpc.default.cidr_block, 4, each.value)
  map_public_ip_on_launch = true

  ipv6_cidr_block                 = cidrsubnet(aws_vpc.default.ipv6_cidr_block, 8, each.value)
  assign_ipv6_address_on_creation = true
}

# Might not explicitly need this since it will fall through to the default table
# But I'll leave it since there might be IPv6 weirdness
resource "aws_route_table_association" "default" {
  for_each       = aws_subnet.subnets
  subnet_id      = each.value.id
  route_table_id = aws_default_route_table.default.id
}

# Create endpoints for s3 and dynamodb
resource "aws_vpc_endpoint" "s3" {
  vpc_id          = aws_vpc.default.id
  service_name    = "com.amazonaws.us-west-2.s3"
  auto_accept     = true
  route_table_ids = [aws_default_route_table.default.id]
}

resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id          = aws_vpc.default.id
  service_name    = "com.amazonaws.us-west-2.dynamodb"
  auto_accept     = true
  route_table_ids = [aws_default_route_table.default.id]
}