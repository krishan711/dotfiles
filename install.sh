#!/usr/bin/env bash

# Ensure up to date
# cd "$(dirname "${BASH_SOURCE}")"
# git pull origin main

# Keep sudo alive for the entire script so sub-scripts don't re-prompt.
sudo -v
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

# Detect OS
OS="$(uname -s)"
echo "Detected OS: $OS"

# Configure OS-specific settings
if [[ "$OS" == "Darwin" ]]; then
    # Download and run brew
    ./brew.sh

    echo "Running macOS configuration..."
    ./.macos

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
cp $(pwd)/.tmux.conf ~
cp $(pwd)/.bashrc ~
echo 'source ~/.bashrc' > ~/.bash_profile

source ~/.bash_profile

# direnv setup — create .envrc from template if missing, then allow it
if command -v direnv &> /dev/null; then
    if [ ! -f .envrc ]; then
        cp ./envrc-template.sh .envrc
    fi
    direnv allow .
fi

# Install vscode extensions
./vscode/install-extensions.sh

# Apply Brave settings and policies
./brave/apply.sh

# Run updates (brew upgrade + SwiftBar plugins)
./update.sh
