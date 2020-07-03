# Seems to require 2+ AZs to support multi AZ RDS, even if we're not using multi AZ RDS
# https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_VPC.WorkingWithRDSInstanceinaVPC.html#USER_VPC.Subnets
# Fine, just give it all our created subnets
resource "aws_db_subnet_group" "main" {
  subnet_ids = [
    for subnet in aws_subnet.subnets :
    subnet.id
  ]
}

# Free tier RDS instance
resource "aws_db_instance" "database" {
  allocated_storage        = 20
  storage_type             = "gp2"
  engine                   = "mariadb"
  engine_version           = "10.4"
  instance_class           = "db.t2.micro"
  username                 = "root"
  password                 = var.db_password
  availability_zone        = aws_instance.instance.availability_zone
  backup_retention_period  = 35
  deletion_protection      = true
  delete_automated_backups = true
  identifier               = "db"
  # encryption isn't supported on t2 machines
  #   storage_encrypted         = true
  #   kms_key_id                = 
  skip_final_snapshot       = false
  final_snapshot_identifier = "final-snapshot"
  vpc_security_group_ids    = [aws_security_group.allow_mysql.id]
  db_subnet_group_name      = aws_db_subnet_group.main.id
}

# Setting up the RDS security rules separately because we're going to
# reference the default port security group id, which includes the
# RDS security group. 
# Separate setup allows us to break the deadlock.
resource "aws_security_group" "allow_mysql" {
  name_prefix = "allow_mysql"
  description = "Allow mysql traffic within the security group"
  vpc_id      = aws_vpc.default.id
  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "allow_mysql"
  }
}

resource "aws_security_group_rule" "to_mysql" {
  type                     = "ingress"
  description              = "MySQL"
  protocol                 = "tcp"
  from_port                = 3306
  to_port                  = 3306
  security_group_id        = aws_security_group.allow_mysql.id
  source_security_group_id = aws_security_group.allow_default_ports.id
}

resource "aws_security_group_rule" "from_mysql" {
  type                     = "egress"
  description              = "MySQL"
  protocol                 = "tcp"
  from_port                = 3306
  to_port                  = 3306
  security_group_id        = aws_security_group.allow_mysql.id
  source_security_group_id = aws_security_group.allow_default_ports.id
}
