#!/usr/bin/env bash

if [[ "$(uname -s)" == "Linux" ]]; then
    if command -v apt-get &> /dev/null; then
        sudo apt-get update && sudo apt-get upgrade -y && sudo apt-get autoremove -y
    elif command -v dnf &> /dev/null; then
        sudo dnf update -y && sudo dnf autoremove -y
    elif command -v pacman &> /dev/null; then
        sudo pacman -Syu --noconfirm
    else
        echo "Unsupported package manager." >&2
        exit 1
    fi
    exit 0
fi

# On Apple Silicon, re-exec natively if running under Rosetta 2.
if [ "$(uname -m)" = "x86_64" ] && [ -d /opt/homebrew ]; then
    exec arch -arm64 /bin/bash "$0" "$@"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export HOMEBREW_NO_ENV_HINTS=1
export HOMEBREW_NO_INSTALL_CLEANUP=1
export HOMEBREW_NO_INTERACTIVE=1

# Update Homebrew and upgrade all packages
brew update
echo y | brew upgrade --formula

OUTDATED_CASKS=$(brew outdated --cask --quiet)
if [ "$TERM_PROGRAM" = "vscode" ] && echo "$OUTDATED_CASKS" | grep -q "^visual-studio-code"; then
    echo "⚠️  VS Code update available — skipping because this script is running inside VS Code."
    echo "   Run update.sh from Terminal.app to include it."
    OUTDATED_CASKS=$(echo "$OUTDATED_CASKS" | grep -v "^visual-studio-code")
fi
if [ "$TERM_PROGRAM" = "zed" ] && echo "$OUTDATED_CASKS" | grep -q "^zed$"; then
    echo "⚠️  Zed update available — skipping because this script is running inside Zed."
    echo "   Run update.sh from Terminal.app to include it."
    OUTDATED_CASKS=$(echo "$OUTDATED_CASKS" | grep -v "^zed$")
fi
if [ -n "$OUTDATED_CASKS" ]; then
    echo y | brew upgrade --cask $OUTDATED_CASKS
fi

brew bundle install --no-upgrade --file="$SCRIPT_DIR/brew/Brewfile"
brew cleanup
