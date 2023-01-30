#!/usr/bin/env bash
set -e -o pipefail

# From https://docs.aws.amazon.com/AmazonECS/latest/developerguide/docker-basics.html
# works on ARM too
sudo yum update -y
sudo amazon-linux-extras install -y docker
sudo yum install -y docker
sudo service docker start
sudo usermod -a -G docker ec2-user
