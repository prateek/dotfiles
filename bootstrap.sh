#!/usr/bin/env zsh
# vim:syntax=zsh
# vim:filetype=zsh

set -eo pipefail

CWD=$(dirname -- "$( readlink -f -- "$0"; )")

# install homebrew
if ! command -v brew &> /dev/null
then
  echo "install homebrew please"
  exit 1
fi

# install homebrew files
# brew bundle install --file $CWD/Brewfile

# setup symlinks
if [ ! -f $HOME/.vimrc ]; then ln -s $CWD/vimrc $HOME/.vimrc ; fi
# if [ ! -f $HOME/.sshrc ]; then ln -s $CWD/sshrc $HOME/.sshrc ; fi
if [ ! -f $HOME/.zlogin ]; then ln -s $CWD/zlogin $HOME/.zlogin ; fi
if [ ! -f $HOME/.zprofile ]; then ln -s $CWD/zprofile $HOME/.zprofile ; fi
if [ ! -f $HOME/.zshrc ]; then ln -s $CWD/zshrc $HOME/.zshrc ; fi
# TODO: .claude

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
if [ ! -d ~/.zinit ]; then
  mkdir ~/.zinit
  git clone https://github.com/zdharma-continuum/zinit.git ~/.zinit/bin
fi

# vim setup
curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
     https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
vim -c "PlugInstall"

# osx install
## dropbox
### TODO: ensure files are available offline
## alfred
### TODO: sync preferences to dropbox folder
### TODO: command+space to alfred, not spotlight (disable via Settings -> Keyboard)
## moom
defaults import com.manytricks.Moom $CWD/osx-apps/Moom.plist
### TODO: open the license file from 1p
## osx
### dock settings (left, hiding)
### add bluetooth/wifi/sounds to menu bar, remove spotlight
### set alert volume to 0 (in Settings -> Sounds)


# TODO: pending automation items
# - [ ] need to run `autoload zkbd && zkbd` to setup keycode file (used in zshrc)
# - [ ] need to copy and sync $HOME/.config directory too (incl bootstrap.sh wiring)
# - [ ] create ~/bin folder (both pulling that stuff into `dotfiles`, and hooking up to bootstrap)
# - [ ] wire up boostrap.sh =>> scripts/build.sh
# - [ ] ~/.gitconfig wiring
#  - `git config --global --type=bool checkout.guess false`: https://gist.github.com/mmrko/b3ec6da9bea172cdb6bd83bdf95ee817 for git completions to not suck
# - [ ] ZDOTDIR and XDG_CONFIG_HOME=~/.config -- https://thevaluable.dev/zsh-install-configure-mouseless/ has ideas
# - [ ] osx settings
#  - VSCodeVim: `defaults write com.microsoft.VSCode ApplePressAndHoldEnabled -bool false` via https://github.com/VSCodeVim/Vim#mac
