# Put this in ~/.bash_profile
# export DOTFILES_PATH='/Users/krishan/Projects/dotfiles'  # macOS
# export DOTFILES_PATH='/home/krishan/Projects/dotfiles'   # Linux
# source $DOTFILES_PATH/.bash_profile

# Detect OS
OS="$(uname -s)"

# Add `~/bin` to the `$PATH`
export PATH="$HOME/bin:$PATH";
export PATH="/usr/local/bin:$PATH";
export PATH="/usr/local/sbin:$PATH";
export PATH="/Users/krishan/.local/bin:$PATH";
export PATH="$HOME/.local/bin:$PATH";
export PATH="/usr/local/sbin:$PATH";

# macOS-specific paths
if [[ "$OS" == "Darwin" ]]; then
    export PATH="/opt/homebrew/bin:$PATH";
    export PATH="/opt/homebrew/sbin:$PATH";
    export PATH="/opt/homebrew/opt/libpq/bin:$PATH";
    export PATH="/opt/homebrew/opt/libpq/bin:$PATH";
    export JAVA_HOME=/opt/homebrew/opt/openjdk@17
    export PATH="$JAVA_HOME/bin:$PATH";
fi

# Linux-specific paths
if [[ "$OS" == "Linux" ]]; then
    # Snap packages
    if [ -d "/snap/bin" ]; then
        export PATH="/snap/bin:$PATH";
    fi
    # Flatpak
    if [ -d "/var/lib/flatpak/exports/bin" ]; then
        export PATH="/var/lib/flatpak/exports/bin:$PATH";
    fi
    # User flatpak
    if [ -d "$HOME/.local/share/flatpak/exports/bin" ]; then
        export PATH="$HOME/.local/share/flatpak/exports/bin:$PATH";
    fi
fi

# Load the shell dotfiles, and then some:
# * ~/.path can be used to extend `$PATH`.
# * ~/.extra can be used for other settings you don’t want to commit.
for file in $DOTFILES_PATH/.{path,bash_prompt,exports,aliases,functions,extra}; do
	[ -r "$file" ] && [ -f "$file" ] && source "$file";
done;
unset file;

# Case-insensitive globbing (used in pathname expansion)
shopt -s nocaseglob;

# Append to the Bash history file, rather than overwriting it
shopt -s histappend;

# Autocorrect typos in path names when using `cd`
shopt -s cdspell;

# Enable some Bash 4 features when possible:
# * `autocd`, e.g. `**/qux` will enter `./foo/bar/baz/qux`
# * Recursive globbing, e.g. `echo **/*.txt`
for option in autocd globstar; do
	shopt -s "$option" 2> /dev/null;
done;

# Add tab completion for many Bash commands
if [[ "$OS" == "Darwin" ]]; then
    # macOS with Homebrew
    if which brew &> /dev/null && [ -r "$(brew --prefix)/etc/profile.d/bash_completion.sh" ]; then
        # Ensure existing Homebrew v1 completions continue to work
        export BASH_COMPLETION_COMPAT_DIR="$(brew --prefix)/etc/bash_completion.d";
        source "$(brew --prefix)/etc/profile.d/bash_completion.sh";
    fi
elif [[ "$OS" == "Linux" ]]; then
    # Linux bash completion
    if [ -f /usr/share/bash-completion/bash_completion ]; then
        source /usr/share/bash-completion/bash_completion;
    elif [ -f /etc/bash_completion ]; then
        source /etc/bash_completion;
    fi
fi

# Enable tab completion for `g` by marking it as an alias for `git`
if type _git &> /dev/null; then
	complete -o default -o nospace -F _git g;
fi;

# Add tab completion for SSH hostnames based on ~/.ssh/config, ignoring wildcards
[ -e "$HOME/.ssh/config" ] && complete -o "default" -o "nospace" -W "$(grep "^Host" ~/.ssh/config | grep -v "[?*]" | cut -d " " -f2- | tr ' ' '\n')" scp sftp ssh;

# Add tab completion for `defaults read|write NSGlobalDomain`
# You could just use `-g` instead, but I like being explicit
# (macOS only)
if [[ "$OS" == "Darwin" ]]; then
    complete -W "NSGlobalDomain" defaults;
    # Add `killall` tab completion for common apps
    complete -o "nospace" -W "Contacts Calendar Dock Finder Mail Safari iTunes SystemUIServer Terminal Twitter" killall;
fi

# setup npm to use local "global" packages (https://github.com/sindresorhus/guides/blob/master/npm-global-without-sudo.md)
export NPM_PACKAGES_ROOT=$HOME/.npm-packages
mkdir -p $NPM_PACKAGES_ROOT/lib
npm config set prefix $NPM_PACKAGES_ROOT/
export PATH=$PATH:$NPM_PACKAGES_ROOT/bin
export MANPATH=$NPM_PACKAGES_ROOT/share/man:$(manpath)

# set npm to ignore scripts for security (e.g. ignores post-install on deps)
npm config set ignore-scripts true

# Create symlink between vscode settings in this repo and on local device
if [[ "$OS" == "Darwin" ]]; then
    # macOS VS Code settings location
    if [ -d "$HOME/Library/Application Support/Code" ]; then
        ln -f -s $DOTFILES_PATH/vscode/settings.json "$HOME/Library/Application Support/Code/User/settings.json"
    fi
elif [[ "$OS" == "Linux" ]]; then
    # Linux VS Code settings location
    if [ -d "$HOME/.config/Code/User" ]; then
        ln -f -s $DOTFILES_PATH/vscode/settings.json "$HOME/.config/Code/User/settings.json"
    fi
fi

# Load passwords
if [ -f $HOME/.bash_passwords ]; then
    source $HOME/.bash_passwords
fi
if [ -f $HOME/.bash_secrets ]; then
    source $HOME/.bash_secrets
fi

# direnv
eval "$(direnv hook bash)"

# Go
export GOPATH=~/.go

# Solana
export PATH=$PATH:~/.local/share/solana/install/active_release/bin

# NVM
mkdir -p ~/.nvm
export NVM_DIR="$HOME/.nvm"
[ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"  # This loads nvm
[ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"  # This loads nvm bash_completion

# Aws cli2
alias aws2=''
