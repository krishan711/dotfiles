resource "aws_vpc" "main" {
  cidr_block = "10.17.0.0/16"
  instance_tenancy = "default"
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = {
    Name = "main"
    app = local.project
  }
}

# Public subnets

resource "aws_subnet" "public-1" {
  vpc_id = aws_vpc.main.id
  cidr_block = "10.17.1.0/24"
  map_public_ip_on_launch = true
  availability_zone = "eu-west-1a"

  tags = {
    Name = "public-1"
    app = local.project
  }
}

resource "aws_subnet" "public-2" {
  vpc_id = aws_vpc.main.id
  cidr_block = "10.17.2.0/24"
  map_public_ip_on_launch = "true"
  availability_zone = "eu-west-1b"

  tags = {
    Name = "public-2"
    app = local.project
  }
}

resource "aws_subnet" "public-3" {
  vpc_id = aws_vpc.main.id
  cidr_block = "10.17.3.0/24"
  map_public_ip_on_launch = "true"
  availability_zone = "eu-west-1c"

  tags = {
    Name = "public-3"
    app = local.project
  }
}

# Private subnets

resource "aws_subnet" "private-1" {
  vpc_id = aws_vpc.main.id
  cidr_block = "10.17.4.0/24"
  map_public_ip_on_launch = "false"
  availability_zone = "eu-west-1a"

  tags = {
    Name = "private-1"
    app = local.project
  }
}

resource "aws_subnet" "private-2" {
  vpc_id = aws_vpc.main.id
  cidr_block = "10.17.5.0/24"
  map_public_ip_on_launch = "false"
  availability_zone = "eu-west-1b"

  tags = {
    Name = "private-2"
    app = local.project
  }
}

resource "aws_subnet" "private-3" {
  vpc_id = aws_vpc.main.id
  cidr_block = "10.17.6.0/24"
  map_public_ip_on_launch = "false"
  availability_zone = "eu-west-1c"

  tags = {
    Name = "private-3"
    app = local.project
  }
}

# Internet Gateway

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main"
    app = local.project
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "public"
    app = local.project
  }
}

resource "aws_route_table_association" "public-1-a" {
  route_table_id = aws_route_table.public.id
  subnet_id = aws_subnet.public-1.id
}

resource "aws_route_table_association" "public-2-a" {
  route_table_id = aws_route_table.public.id
  subnet_id = aws_subnet.public-2.id
}

resource "aws_route_table_association" "public-3-a" {
  route_table_id = aws_route_table.public.id
  subnet_id = aws_subnet.public-3.id
}

# NAT Gateway

resource "aws_eip" "nat" {
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id = aws_subnet.public-1.id
  depends_on = [aws_internet_gateway.main]
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "private"
    app = local.project
  }
}

resource "aws_route_table_association" "private-1-a" {
  route_table_id = aws_route_table.private.id
  subnet_id = aws_subnet.private-1.id
}

resource "aws_route_table_association" "private-2-a" {
  route_table_id = aws_route_table.private.id
  subnet_id = aws_subnet.private-2.id
}

resource "aws_route_table_association" "private-3-a" {
  route_table_id = aws_route_table.private.id
  subnet_id = aws_subnet.private-3.id
}
