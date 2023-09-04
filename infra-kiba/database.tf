locals {
  main_db_username = "${local.project}_admin"
  main_db_name = "${local.project}db"
}

resource "random_password" "main_db" {
  length = 64
  special = false
}

resource "aws_db_subnet_group" "main_db" {
  name = local.main_db_name
  subnet_ids = [
    aws_subnet.private-1.id,
    aws_subnet.private-2.id,
    aws_subnet.private-3.id,
  ]
}

resource "aws_db_instance" "main_db" {
  allocated_storage = 20
  max_allocated_storage = 100
  identifier = local.main_db_name
  storage_type = "gp3"
  engine = "postgres"
  engine_version = "15.4"
  instance_class = "db.t4g.micro"
  db_name = local.main_db_name
  username = local.main_db_username
  password = random_password.main_db.result
  storage_encrypted = true
  apply_immediately = true
  multi_az = false
  backup_retention_period = 3
  performance_insights_enabled = true
  performance_insights_retention_period = 7
  publicly_accessible = false
  db_subnet_group_name = aws_db_subnet_group.main_db.id
  vpc_security_group_ids = [
    aws_security_group.psql.id,
  ]
  # NOTE(krishan711): use the below when recreating the db
  deletion_protection = true
  skip_final_snapshot = false
}

output "main_db_url" {
  value = aws_db_instance.main_db.endpoint
}

output "main_db_port" {
  value = aws_db_instance.main_db.port
}

output "main_db_name" {
  value = aws_db_instance.main_db.db_name
}

output "main_db_username" {
  value = local.main_db_username
}

output "main_db_password" {
  value = random_password.main_db.result
  sensitive = true
}
