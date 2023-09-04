#!/usr/bin/env bash

# Ensure up to date
# cd "$(dirname "${BASH_SOURCE}")"
# git pull origin main

# Configure mac
./.macos

# Download brew
./brew.sh

# Copy files
cp $(pwd)/.gitconfig ~
cp $(pwd)/.inputrc ~
cp $(pwd)/.screenrc ~
cp $(pwd)/.bashrc ~
# cp $(pwd)/.bash_profile ~

source ~/.bash_profile

# Brew depedent commands
chsh -s /opt/homebrew/bin/bash
direnv allow .

# Install vscode extensions
./vscode/install-extensions.sh

# Install xbar stuff
cp -R ./xbar/*.sh ~/Library/Application\ Support/xbar/plugins
