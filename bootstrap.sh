#!/usr/bin/env zsh
# vim:syntax=zsh
# vim:filetype=zsh

set -e
set -o pipefail

# Resolve repository root directory in a zsh-portable way
CWD="${0:A:h}"

# install homebrew
if ! command -v brew &> /dev/null
then
  echo "install homebrew please"
  exit 1
fi

# install homebrew files
brew bundle install --file "$CWD/Brewfile"

# setup symlinks
# Neovim (LazyVim) config
NVIM_CONFIG_DIR="$HOME/.config/nvim"
if [ -d "$NVIM_CONFIG_DIR" ] || [ -L "$NVIM_CONFIG_DIR" ]; then
  if [ "$(readlink "$NVIM_CONFIG_DIR" 2>/dev/null)" != "$CWD/nvim" ]; then
    echo "Error: $NVIM_CONFIG_DIR already exists and is not a symlink to $CWD/nvim."
    echo "To back it up, run: mv \"$NVIM_CONFIG_DIR\" \"${NVIM_CONFIG_DIR}.backup-$(date +%s)\""
    echo "Or remove it if you don't need it: rm -rf \"$NVIM_CONFIG_DIR\""
    echo "After fixing, rerun this bootstrap script."
    exit 1
  fi
fi
mkdir -p "$HOME/.config"
ln -snf "$CWD/nvim" "$NVIM_CONFIG_DIR"
# if [ ! -f $HOME/.sshrc ]; then ln -s $CWD/sshrc $HOME/.sshrc ; fi
if [ ! -f "$HOME/.zlogin" ]; then ln -s "$CWD/zlogin" "$HOME/.zlogin"; fi
if [ ! -f "$HOME/.zprofile" ]; then ln -s "$CWD/zprofile" "$HOME/.zprofile"; fi
if [ ! -f "$HOME/.zshrc" ]; then ln -s "$CWD/zshrc" "$HOME/.zshrc"; fi
if [ ! -f $HOME/.zshenv ]; then ln -s "$CWD/zshenv" "$HOME/.zshenv"; fi

# .claude directory symlinks
mkdir -p "$HOME/.claude"
for dir in agents commands docs; do
  if [ -d "$CWD/.claude/$dir" ]; then
    if [ -e "$HOME/.claude/$dir" ]; then
      rm -rf "$HOME/.claude/$dir"
    fi
    ln -sf "$CWD/.claude/$dir" "$HOME/.claude/$dir"
  fi
done

# directories
mkdir -p "$HOME/code"
mkdir -p "$HOME/.sshrc.d"

# generate lesskey binary file for older versions of less that might be
# present on remote machines.
# nb: will need to `brew install less` for the following line to work.
if command -v lesskey >/dev/null 2>&1 && [ -f "$CWD/lesskey" ]; then
  lesskey -o "$HOME/.less" "$CWD/lesskey"
  cp "$HOME/.less" "$HOME/.sshrc.d/.less"
fi

# zsh setup
# nb: this setup takes _heavy_ inspiration from the work of https://github.com/htr3n/zsh-config
if [ ! -d "$HOME/.zinit" ]; then
  mkdir -p "$HOME/.zinit"
  git clone https://github.com/zdharma-continuum/zinit.git "$HOME/.zinit/bin"
fi

# LazyVim bootstrap (plugins install on first nvim run). Optionally sync now.
if command -v nvim &>/dev/null; then
  nvim --headless "+Lazy! sync" +qa || true
fi

# osx install
## dropbox (only if allowed (i.e. not work))
### TODO: ensure files are available offline
## alfred
### TODO: sync preferences to dropbox folder
### TODO: command+space to alfred, not spotlight (disable via Settings -> Keyboard)
## moom
# defaults import com.manytricks.Moom $CWD/osx-apps/Moom.plist
### TODO: open the license file from 1p
## TODO: install setapp applications

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
