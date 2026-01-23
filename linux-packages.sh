#!/usr/bin/env bash

# Linux package installation script
# Equivalent to brew.sh for Linux (Debian/Ubuntu-based systems)

echo "Installing packages for Linux..."

# Detect package manager
if command -v apt-get &> /dev/null; then
    PKG_MANAGER="apt"
    INSTALL_CMD="sudo apt-get install -y"
    UPDATE_CMD="sudo apt-get update && sudo apt-get upgrade -y"
elif command -v dnf &> /dev/null; then
    PKG_MANAGER="dnf"
    INSTALL_CMD="sudo dnf install -y"
    UPDATE_CMD="sudo dnf update -y"
elif command -v pacman &> /dev/null; then
    PKG_MANAGER="pacman"
    INSTALL_CMD="sudo pacman -S --noconfirm"
    UPDATE_CMD="sudo pacman -Syu --noconfirm"
else
    echo "Unsupported package manager. Please install packages manually."
    exit 1
fi

echo "Detected package manager: $PKG_MANAGER"

# Update system
echo "Updating system packages..."
eval $UPDATE_CMD

###############################################################################
# Core Utilities                                                               #
###############################################################################

echo "Installing core utilities..."
$INSTALL_CMD \
    bash \
    bash-completion \
    coreutils \
    findutils \
    moreutils \
    sed \
    gawk \
    grep

###############################################################################
# Development Tools                                                            #
###############################################################################

echo "Installing development tools..."
$INSTALL_CMD \
    git \
    git-lfs \
    vim \
    curl \
    wget \
    openssh-client \
    openssh-server \
    screen \
    tmux \
    build-essential \
    pkg-config

# GnuPG for signing commits
$INSTALL_CMD gnupg

###############################################################################
# Programming Languages & Runtimes                                             #
###############################################################################

echo "Installing programming languages..."

# Python
$INSTALL_CMD python3 python3-pip python3-venv

# Node.js (via NodeSource for latest LTS)
if ! command -v node &> /dev/null; then
    echo "Installing Node.js..."
    if [[ "$PKG_MANAGER" == "apt" ]]; then
        curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
        sudo apt-get install -y nodejs
    elif [[ "$PKG_MANAGER" == "dnf" ]]; then
        curl -fsSL https://rpm.nodesource.com/setup_lts.x | sudo bash -
        sudo dnf install -y nodejs
    else
        $INSTALL_CMD nodejs npm
    fi
fi

# Go
if [[ "$PKG_MANAGER" == "apt" ]]; then
    $INSTALL_CMD golang-go
elif [[ "$PKG_MANAGER" == "dnf" ]]; then
    $INSTALL_CMD golang
else
    $INSTALL_CMD go
fi

###############################################################################
# DevOps Tools                                                                 #
###############################################################################

echo "Installing DevOps tools..."

# direnv
$INSTALL_CMD direnv

# jq for JSON processing
$INSTALL_CMD jq

# Terraform
if ! command -v terraform &> /dev/null; then
    echo "Installing Terraform..."
    if [[ "$PKG_MANAGER" == "apt" ]]; then
        wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
        echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
        sudo apt-get update && sudo apt-get install -y terraform
    elif [[ "$PKG_MANAGER" == "dnf" ]]; then
        sudo dnf install -y dnf-plugins-core
        sudo dnf config-manager --add-repo https://rpm.releases.hashicorp.com/fedora/hashicorp.repo
        sudo dnf -y install terraform
    else
        echo "Please install Terraform manually for your distribution."
    fi
fi

###############################################################################
# Useful CLI Tools                                                             #
###############################################################################

echo "Installing CLI tools..."
$INSTALL_CMD \
    ack \
    tree \
    htop \
    ncdu \
    ripgrep \
    fd-find \
    bat \
    unzip \
    p7zip-full \
    pigz \
    pv \
    rename \
    rlwrap \
    imagemagick \
    ffmpeg

# Install fzf (fuzzy finder)
if ! command -v fzf &> /dev/null; then
    git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
    ~/.fzf/install --all
fi

###############################################################################
# Libraries for Development                                                    #
###############################################################################

echo "Installing development libraries..."
if [[ "$PKG_MANAGER" == "apt" ]]; then
    $INSTALL_CMD \
        libmagic-dev \
        libcairo2-dev \
        libgmp-dev \
        libssl-dev \
        libffi-dev
elif [[ "$PKG_MANAGER" == "dnf" ]]; then
    $INSTALL_CMD \
        file-devel \
        cairo-devel \
        gmp-devel \
        openssl-devel \
        libffi-devel
fi

###############################################################################
# Docker                                                                       #
###############################################################################

if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    if [[ "$PKG_MANAGER" == "apt" ]]; then
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        rm get-docker.sh
    elif [[ "$PKG_MANAGER" == "dnf" ]]; then
        sudo dnf -y install dnf-plugins-core
        sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
        sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    fi
    sudo systemctl enable docker
    sudo systemctl start docker
fi

###############################################################################
# AWS CLI                                                                      #
###############################################################################

if ! command -v aws &> /dev/null; then
    echo "Installing AWS CLI..."
    cd /tmp
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install
    rm -rf aws awscliv2.zip
    cd -
fi

###############################################################################
# VS Code                                                                      #
###############################################################################

if ! command -v code &> /dev/null; then
    echo "Installing VS Code..."
    if [[ "$PKG_MANAGER" == "apt" ]]; then
        wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
        sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
        sudo sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
        rm -f packages.microsoft.gpg
        sudo apt-get update
        sudo apt-get install -y code
    elif [[ "$PKG_MANAGER" == "dnf" ]]; then
        sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
        sudo sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'
        sudo dnf install -y code
    fi
fi

###############################################################################
# Cleanup                                                                      #
###############################################################################

echo "Cleaning up..."
if [[ "$PKG_MANAGER" == "apt" ]]; then
    sudo apt-get autoremove -y
    sudo apt-get autoclean
elif [[ "$PKG_MANAGER" == "dnf" ]]; then
    sudo dnf autoremove -y
    sudo dnf clean all
elif [[ "$PKG_MANAGER" == "pacman" ]]; then
    sudo pacman -Sc --noconfirm
fi

echo ""
echo "Linux package installation complete!"
echo "You may need to log out and back in for some changes to take effect."
