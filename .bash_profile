# Add `~/bin` to the `$PATH`
export PATH="$HOME/bin:$PATH";
export PATH="/usr/local/sbin:$PATH";

# Load the shell dotfiles, and then some:
# * ~/.path can be used to extend `$PATH`.
# * ~/.extra can be used for other settings you don’t want to commit.
for file in $(dirname ${BASH_SOURCE})/.{path,bash_prompt,exports,aliases,functions,extra}; do
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
if which brew &> /dev/null && [ -r "$(brew --prefix)/etc/profile.d/bash_completion.sh" ]; then
	# Ensure existing Homebrew v1 completions continue to work
	export BASH_COMPLETION_COMPAT_DIR="$(brew --prefix)/etc/bash_completion.d";
	source "$(brew --prefix)/etc/profile.d/bash_completion.sh";
elif [ -f /etc/bash_completion ]; then
	source /etc/bash_completion;
fi;

# Enable tab completion for `g` by marking it as an alias for `git`
if type _git &> /dev/null; then
	complete -o default -o nospace -F _git g;
fi;

# Add tab completion for SSH hostnames based on ~/.ssh/config, ignoring wildcards
[ -e "$HOME/.ssh/config" ] && complete -o "default" -o "nospace" -W "$(grep "^Host" ~/.ssh/config | grep -v "[?*]" | cut -d " " -f2- | tr ' ' '\n')" scp sftp ssh;

# Add tab completion for `defaults read|write NSGlobalDomain`
# You could just use `-g` instead, but I like being explicit
complete -W "NSGlobalDomain" defaults;

# Add `killall` tab completion for common apps
complete -o "nospace" -W "Contacts Calendar Dock Finder Mail Safari iTunes SystemUIServer Terminal Twitter" killall;

# setup npm to use local "global" packages (https://github.com/sindresorhus/guides/blob/master/npm-global-without-sudo.md)
export NPM_PACKAGES_ROOT=$HOME/.npm-packages
npm config set prefix $NPM_PACKAGES_ROOT
export PATH=$PATH:$NPM_PACKAGES_ROOT/bin
export MANPATH=$NPM_PACKAGES_ROOT/share/man:$(manpath)

# Create symlink between vscode settings in this repo and on local device
if [ -x $HOME/Library/Application\ Support ]; then
    ln -f -s $(dirname "${BASH_SOURCE}")/vscode/settings.json $HOME/Library/Application\ Support/Code/User/settings.json
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
