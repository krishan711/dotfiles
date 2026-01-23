# ~/.bashrc - Executed for interactive non-login shells
# On Linux, this is the main entry point for interactive terminals

# If not running interactively, don't do anything
[ -z "$PS1" ] && return

# Set DOTFILES_PATH if not already set
if [ -z "$DOTFILES_PATH" ]; then
    # Try to find dotfiles location
    if [ -d "$HOME/Projects/dotfiles" ]; then
        export DOTFILES_PATH="$HOME/Projects/dotfiles"
    elif [ -d "$HOME/dotfiles" ]; then
        export DOTFILES_PATH="$HOME/dotfiles"
    elif [ -d "$HOME/.dotfiles" ]; then
        export DOTFILES_PATH="$HOME/.dotfiles"
    fi
fi

# Source the main bash_profile which loads everything else
if [ -n "$DOTFILES_PATH" ] && [ -f "$DOTFILES_PATH/.bash_profile" ]; then
    source "$DOTFILES_PATH/.bash_profile"
elif [ -f "$HOME/.bash_profile" ]; then
    source "$HOME/.bash_profile"
fi
