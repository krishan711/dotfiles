resource "aws_key_pair" "krishan" {
  public_key = file("~/.ssh/aws-kiba.pub")
}

# Appbox

resource "aws_instance" "appbox" {
  # https://eu-west-1.console.aws.amazon.com/ec2/home?region=eu-west-1#AMICatalog:
  ami = "ami-057b6e529186a8233"
  instance_type = "t3a.small"
  subnet_id = aws_subnet.public-1.id
  key_name = aws_key_pair.krishan.key_name
  disable_api_termination = false
  vpc_security_group_ids = [
    aws_security_group.ssh_access.id,
    aws_security_group.all_outgoing.id,
    aws_security_group.webpage.id,
  ]
  # TODO(krishan711): remove sudo yum update -y for future
  user_data = <<EOF
#!/bin/bash
# update ssh port
sudo perl -pi -e 's/^#?Port 22$/Port ${var.SSH_PORT}/' /etc/ssh/sshd_config
sudo service sshd restart || sudo service ssh restart
# install docker
sudo yum update -y
sudo yum install -y docker
sudo service docker start
sudo usermod -a -G docker ec2-user
  EOF

  root_block_device {
    volume_size = 40
    volume_type = "gp3"
  }

  tags = {
    Name = "appbox"
    app = local.project
  }
}

resource "aws_eip" "appbox" {
  instance = aws_instance.appbox.id

  tags = {
    name = "appbox"
    app = local.project
  }
}

resource "aws_eip_association" "appbox" {
  instance_id = aws_instance.appbox.id
  allocation_id = aws_eip.appbox.id
}

output "appbox_ip" {
  value = "${aws_eip.appbox.public_ip}"
}

# vpnbox

resource "aws_instance" "vpnbox" {
  ami = "ami-057b6e529186a8233"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.public-1.id
  key_name = aws_key_pair.krishan.key_name
  disable_api_termination = false
  vpc_security_group_ids = [
    aws_security_group.ssh_access.id,
    aws_security_group.all_outgoing.id,
    aws_security_group.openvpn.id,
    aws_security_group.webpage.id,
  ]
  user_data = <<EOF
#!/bin/bash
# update ssh port
sudo perl -pi -e 's/^#?Port 22$/Port ${var.SSH_PORT}/' /etc/ssh/sshd_config
sudo service sshd restart || sudo service ssh restart
# install docker
sudo yum install -y docker
sudo service docker start
sudo usermod -a -G docker ec2-user
  EOF

  root_block_device {
    volume_size = 10
    volume_type = "gp3"
  }

  tags = {
    Name = "vpnbox"
    app = local.project
  }
}

resource "aws_eip" "vpnbox" {
  instance = aws_instance.vpnbox.id

  tags = {
    name = "vpnbox"
    app = local.project
  }
}

resource "aws_eip_association" "vpnbox" {
  instance_id = aws_instance.vpnbox.id
  allocation_id = aws_eip.vpnbox.id
}

output "vpnbox_ip" {
  value = "${aws_eip.vpnbox.public_ip}"
}
