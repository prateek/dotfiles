#!/bin/bash
CWD=$(dirname "$0")

# install homebrew
/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"

# install homebrew-bundle
brew tap Homebrew/bundle

# setup symlinks
ln -s $CWD/vimrc $HOME/.vimrc
ln -s $CWD/zshrc $HOME/.zshrc
ln -s $CWD/sshrc $HOME/.sshrc

# directories
mkdir -p $HOME/code
mkdir -p $HOME/.sshrc.d

# vim setup
$CWD/install-vim-plug.sh
vim -c "PlugInstall" #TODO: quit

# generate lesskey binary file for older versions of less that might be
# present on remote machines.
# nb: will need to `brew install less` for the following line to work.
lesskey -o $HOME/.less $CWD/lesskey
cp $HOME/.less $HOME/.sshrc.d/.less

# TODO:
# - need to copy and sync $HOME/.config directory too
# - need to run `autoload zkbd && zkbd` to setup keycode file (used in zshrc)