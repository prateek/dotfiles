#!/bin/bash
CWD=$(dirname "$0")

# install homebrew
/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"

# install homebrew-bundle
brew tap Homebrew/bundle

# setup symlinks
ln -s $CWD/vimrc $HOME/.vimrc
ln -s $CWD/zshrc $HOME/.zshrc

# directories
mkdir -p $HOME/code


# vim setup
$CWD/install-vim-plug.sh
vim -c "PlugInstall" #TODO:
