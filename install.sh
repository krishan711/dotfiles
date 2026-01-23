#!/usr/bin/env bash

# Ensure up to date
# cd "$(dirname "${BASH_SOURCE}")"
# git pull origin main

# Detect OS
OS="$(uname -s)"
echo "Detected OS: $OS"

# Configure OS-specific settings
if [[ "$OS" == "Darwin" ]]; then
    echo "Running macOS configuration..."
    ./.macos
    
    # Download and run brew
    ./brew.sh
    
    # Brew dependent commands
    chsh -s /opt/homebrew/bin/bash
    
    # Install xbar stuff
    cp -R ./xbar/*.sh ~/Library/Application\ Support/xbar/plugins
    
elif [[ "$OS" == "Linux" ]]; then
    echo "Running Linux configuration..."
    ./.linux
    
    # Install Linux packages
    ./linux-packages.sh
    
    # Set bash as default shell if not already
    if [[ "$SHELL" != *"bash"* ]]; then
        chsh -s /bin/bash
    fi
fi

# Copy dotfiles (cross-platform)
echo "Copying dotfiles..."
cp $(pwd)/.gitconfig ~
cp $(pwd)/.inputrc ~
cp $(pwd)/.screenrc ~
cp $(pwd)/.bashrc ~
cp $(pwd)/.tmux.conf ~ 2>/dev/null || true
# cp $(pwd)/.bash_profile ~

source ~/.bash_profile

# direnv setup
if command -v direnv &> /dev/null; then
    direnv allow .
fi

# Install vscode extensions
./vscode/install-extensions.sh
