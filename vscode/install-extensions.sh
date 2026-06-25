#!/usr/bin/env bash

INSTALLED=$(code --list-extensions 2>/dev/null | tr '[:upper:]' '[:lower:]')

install_if_missing() {
    local ext="$1"
    if echo "$INSTALLED" | grep -qi "^${ext}$"; then
        echo "  Skipping ${ext} (already installed)"
    else
        code --install-extension "${ext}"
    fi
}

install_if_missing "anthropic.claude-code"
install_if_missing "bierner.markdown-mermaid"
install_if_missing "docker.docker"
install_if_missing "github.vscode-pull-request-github"
install_if_missing "graphql.vscode-graphql"
install_if_missing "graphql.vscode-graphql-syntax"
install_if_missing "hashicorp.terraform"
install_if_missing "ms-python.python"
install_if_missing "ms-vsliveshare.vsliveshare"
install_if_missing "ms-vscode-remote.remote-containers"
install_if_missing "ms-vscode-remote.remote-ssh"
install_if_missing "ms-vscode-remote.remote-ssh-edit"
install_if_missing "ms-vscode-remote.vscode-remote-extensionpack"
install_if_missing "nomicfoundation.hardhat-solidity"
install_if_missing "tamasfe.even-better-toml"
install_if_missing "unifiedjs.vscode-mdx"
install_if_missing "vscode-icons-team.vscode-icons"
install_if_missing "wmaurer.change-case"
install_if_missing "zhuangtongfa.material-theme"
