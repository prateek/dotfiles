#!/usr/bin/env zsh
# vim:syntax=zsh
# vim:filetype=zsh

CWD=$(dirname "$0")

# install homebrew
/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"

# install homebrew-bundle
# TODO: prune/update Homebrew/bundle
brew tap Homebrew/bundle

# setup symlinks
ln -s $CWD/vimrc $HOME/.vimrc
ln -s $CWD/sshrc $HOME/.sshrc
ln -s $CWD/zlogin $HOME/.zlogin
ln -s $CWD/zprofile $HOME/.zprofile
ln -s $CWD/zshrc $HOME/.zshrc

# directories
mkdir -p $HOME/code
mkdir -p $HOME/.sshrc.d

# generate lesskey binary file for older versions of less that might be
# present on remote machines.
# nb: will need to `brew install less` for the following line to work.
lesskey -o $HOME/.less $CWD/lesskey
cp $HOME/.less $HOME/.sshrc.d/.less

# zsh setup
# nb: this setup takes _heavy_ inspiration from the work of https://github.com/htr3n/zsh-config
mkdir ~/.zinit
git clone https://github.com/zdharma-continuum/zinit.git ~/.zinit/bin

# vim setup
$CWD/install-vim-plug.sh
vim -c "PlugInstall" # TODO: quit(?)

# iterm2 session log setup (needed for url-view hackery)
mkdir -p ~/Library/Logs/iterm2-session-logs/

# TODO: pending automation items
# - [ ] need to copy and sync $HOME/.config directory too (incl bootstrap.sh wiring)
# - [ ] need to run `autoload zkbd && zkbd` to setup keycode file (used in zshrc)
# - [ ] create ~/bin folder (both pulling that stuff into `dotfiles`, and hooking up to bootstrap)
# - [ ] wire up boostrap.sh =>> scripts/build.sh
# - [ ] ~/.gitconfig wiring
#  - `git config --global --type=bool checkout.guess false`: https://gist.github.com/mmrko/b3ec6da9bea172cdb6bd83bdf95ee817 for git completions to not suck
# - [ ] osx settings
#  - VSCodeVim: `defaults write com.microsoft.VSCode ApplePressAndHoldEnabled -bool false` via https://github.com/VSCodeVim/Vim#mac