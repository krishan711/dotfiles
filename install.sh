#!/usr/bin/env bash

# Ensure up to date
cd "$(dirname "${BASH_SOURCE}")"
git pull origin master
direnv allow .

# Profile setup
touch ~/.bash_profile
echo "source $(pwd)/.bash_profile" > ~/.bash_profile
source ~/.bash_profile

# Copy files
cp $(pwd)/.gitconfig ~
cp $(pwd)/.inputrc ~
cp $(pwd)/.screenrc ~
cp $(pwd)/.bashrc ~

# Download brew
./brew.sh

# Configure mac
./.macos

# Install vscode extensions
./vscode/install-extensions.sh
