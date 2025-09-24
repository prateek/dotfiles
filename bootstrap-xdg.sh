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

# XDG Base Directory setup
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

# Create XDG directories
mkdir -p "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_CACHE_HOME" "$XDG_STATE_HOME"

# setup symlinks for backward compatibility
if [ ! -f $HOME/.zshenv ]; then ln -s $CWD/.zshenv $HOME/.zshenv ; fi
if [ ! -f $HOME/.vimrc ]; then ln -s $CWD/.vimrc $HOME/.vimrc ; fi
if [ ! -f $HOME/.inputrc ]; then ln -s $CWD/.inputrc $HOME/.inputrc ; fi

# Copy config files to XDG locations
if [ ! -d "$XDG_CONFIG_HOME/zsh" ]; then
  cp -r "$CWD/.config/zsh" "$XDG_CONFIG_HOME/"
fi

if [ ! -d "$XDG_CONFIG_HOME/vim" ]; then
  cp -r "$CWD/.config/vim" "$XDG_CONFIG_HOME/"
fi

if [ ! -d "$XDG_CONFIG_HOME/less" ]; then
  cp -r "$CWD/.config/less" "$XDG_CONFIG_HOME/"
fi

if [ ! -d "$XDG_CONFIG_HOME/readline" ]; then
  cp -r "$CWD/.config/readline" "$XDG_CONFIG_HOME/"
fi

# .claude directory symlinks
mkdir -p $HOME/.claude
for dir in agents commands docs; do
  if [ -d "$CWD/.claude/$dir" ]; then
    if [ -e "$HOME/.claude/$dir" ]; then
      rm -rf "$HOME/.claude/$dir"
    fi
    ln -sf "$CWD/.claude/$dir" "$HOME/.claude/$dir"
  fi
done

# directories
mkdir -p $HOME/code
mkdir -p $HOME/.sshrc.d

# generate lesskey binary file for older versions of less that might be
# present on remote machines.
# nb: will need to `brew install less` for the following line to work.
lesskey -o $XDG_DATA_HOME/less $XDG_CONFIG_HOME/less/lesskey
cp $XDG_DATA_HOME/less $HOME/.sshrc.d/.less

# zsh setup with XDG compliance
# nb: this setup takes _heavy_ inspiration from the work of https://github.com/htr3n/zsh-config
ZINIT_HOME="${XDG_DATA_HOME}/zinit/zinit.git"
if [ ! -d "$ZINIT_HOME" ]; then
  mkdir -p "$(dirname $ZINIT_HOME)"
  git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi

# vim setup with XDG compliance
mkdir -p "$XDG_DATA_HOME/vim/autoload"
curl -fLo "$XDG_DATA_HOME/vim/autoload/plug.vim" --create-dirs \
     https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
vim -c "PlugInstall"

# Create cache directories for vim
mkdir -p "$XDG_CACHE_HOME/vim/"{backup,swap,undo,view}

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
# - [X] ZDOTDIR and XDG_CONFIG_HOME=~/.config -- https://thevaluable.dev/zsh-install-configure-mouseless/ has ideas
# - [ ] osx settings
#  - VSCodeVim: `defaults write com.microsoft.VSCode ApplePressAndHoldEnabled -bool false` via https://github.com/VSCodeVim/Vim#mac