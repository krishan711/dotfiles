#!/usr/bin/env bash
set -e -o pipefail

# From https://linuxize.com/post/create-a-linux-swap-file/
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile swap swap defaults 0 0\n' >> /etc/fstab
sudo swapon --show
