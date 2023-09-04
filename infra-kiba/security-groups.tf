resource "aws_security_group" "ssh_access_22" {
  vpc_id = aws_vpc.main.id
  name = "ssh-access-22"

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "ssh-access-22"
    app = local.project
  }
}

resource "aws_security_group" "ssh_access" {
  vpc_id = aws_vpc.main.id
  name = "ssh-access"

  ingress {
    from_port = var.SSH_PORT
    to_port = var.SSH_PORT
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "ssh-access"
    app = local.project
  }
}

resource "aws_security_group" "all_outgoing" {
  vpc_id = aws_vpc.main.id
  name = "all-outgoing"

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "all-outgoing"
    app = local.project
  }
}

resource "aws_security_group" "webpage" {
  vpc_id = aws_vpc.main.id
  name = "webpage"

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "webpage"
    app = local.project
  }
}

resource "aws_security_group" "openvpn" {
  vpc_id = aws_vpc.main.id
  name = "openvpn"

  ingress {
    from_port = 1194
    to_port = 1194
    protocol = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "openvpn"
    app = local.project
  }
}

resource "aws_security_group" "selenium" {
  vpc_id = aws_vpc.main.id
  name = "selenium"

  ingress {
    from_port = 4444
    to_port = 4444
    protocol = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "selenium"
    app = local.project
  }
}

resource "aws_security_group" "psql" {
  vpc_id = aws_vpc.main.id
  name = "psql"

  ingress {
    from_port = 5432
    to_port= 5432
    protocol = "TCP"
    cidr_blocks = [aws_vpc.main.cidr_block]
    # ipv6_cidr_blocks = [aws_vpc.main.ipv6_cidr_block]
  }

  tags = {
    Name = "psql"
    app = local.project
  }
}
