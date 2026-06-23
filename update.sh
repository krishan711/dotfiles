#!/usr/bin/env bash

# On Apple Silicon, re-exec natively if running under Rosetta 2.
if [ "$(uname -m)" = "x86_64" ] && [ -d /opt/homebrew ]; then
    exec arch -arm64 /bin/bash "$0" "$@"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export HOMEBREW_NO_ENV_HINTS=1
export HOMEBREW_NO_INSTALL_CLEANUP=1

# Update Homebrew and upgrade all packages
brew update
brew upgrade
brew bundle install --file="$SCRIPT_DIR/brew/Brewfile"
brew cleanup
