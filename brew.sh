#!/usr/bin/env bash

# On Apple Silicon, re-exec natively if running under Rosetta 2 (e.g. from an Intel shell).
# ARM brew refuses to install packages from a Rosetta process.
if [ "$(uname -m)" = "x86_64" ] && [ -d /opt/homebrew ]; then
    exec arch -arm64 /bin/bash "$0" "$@"
fi

# Suppress post-install cleanup hints.
export HOMEBREW_NO_ENV_HINTS=1
export HOMEBREW_NO_INSTALL_CLEANUP=1

# Install Homebrew if not already present.
if ! command -v brew &> /dev/null; then
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Remove defunct taps that cause git auth failures on brew update.
brew untap homebrew/homebrew-versions 2>/dev/null || true
brew untap karan/homebrew-karan 2>/dev/null || true

# Make sure we’re using the latest Homebrew.
brew update

# Upgrade any already-installed formulae.
brew upgrade

# Install all packages via Brewfile (skips already-installed ones quietly).
brew bundle install --file="$(dirname "${BASH_SOURCE[0]}")/brew/Brewfile"

# Add sha256sum alias (coreutils installs it as gsha256sum).
BREW_PREFIX=$(brew --prefix)
ln -sf "${BREW_PREFIX}/bin/gsha256sum" "${BREW_PREFIX}/bin/sha256sum"

# Switch to using brew-installed bash as default shell.
if ! fgrep -q "${BREW_PREFIX}/bin/bash" /etc/shells; then
  echo "${BREW_PREFIX}/bin/bash" | sudo tee -a /etc/shells;
  chsh -s "${BREW_PREFIX}/bin/bash";
fi;

# Remove outdated versions from the cellar.
brew cleanup
