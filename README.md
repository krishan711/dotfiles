# Krishan's dotfiles

## New computer setup

```
mkdir -p ~/.ssh
ssh-keygen -t ed25519 -f ~/.ssh/github -N ""
printf "Host github.com\n    IdentityFile ~/.ssh/github\n" >> ~/.ssh/config
cat ~/.ssh/github.pub
# add key to github ssh keys
mkdir -p ~/Projects
git clone git@github.com:krishan711/dotfiles
cd dotfiles
./install.sh
```
