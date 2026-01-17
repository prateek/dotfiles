#!/usr/bin/env zsh
# vim:syntax=zsh
# vim:filetype=zsh

set -e
set -o pipefail

# Resolve repository root directory in a zsh-portable way
CWD="${0:A:h}"

BREWFILE="$CWD/Brewfile"
PROFILE="full"
DRY_RUN=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --core)
      PROFILE="core"
      shift
      ;;
    --full)
      PROFILE="full"
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --brewfile)
      BREWFILE="$2"
      shift 2
      ;;
    --brewfile=*)
      BREWFILE="${1#*=}"
      shift
      ;;
    -h|--help)
      echo "Usage: ./bootstrap.sh [--core|--full] [--brewfile PATH]"
      exit 0
      ;;
    *)
      echo "Unknown arg: $1"
      echo "Usage: ./bootstrap.sh [--core|--full] [--brewfile PATH]"
      exit 2
      ;;
  esac
done

if [ "$PROFILE" = "core" ]; then
  BREWFILE="$CWD/Brewfile.core"
fi

if [ "$DRY_RUN" = "1" ]; then
  echo "DRY RUN: bootstrap.sh"
  echo "  PROFILE=$PROFILE"
  echo "  BREWFILE=$BREWFILE"
fi

if [ "$DRY_RUN" = "0" ] && [ "$(uname -s)" = "Darwin" ] && [ "${DOTFILES_SUDO_KEEPALIVE_STARTED:-0}" != "1" ]; then
  echo "Requesting sudo (to avoid repeated password prompts)…"
  sudo -v
  SUDO_PID="$$"
  while true; do sudo -n true; sleep 60; kill -0 "$SUDO_PID" || exit; done 2>/dev/null &
  export DOTFILES_SUDO_KEEPALIVE_STARTED=1
fi

# Install Homebrew if needed
if ! command -v brew &> /dev/null; then
  if [ "$DRY_RUN" = "1" ]; then
    echo "Would install Homebrew (missing):"
    echo "  NONINTERACTIVE=1 /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
  else
    echo "Homebrew not found; installing…"
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Ensure `brew` is available in this shell session.
    if [ -x /opt/homebrew/bin/brew ]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -x /usr/local/bin/brew ]; then
      eval "$(/usr/local/bin/brew shellenv)"
    fi
  fi
fi

if [ "$DRY_RUN" = "0" ]; then
  if ! command -v brew &> /dev/null; then
    echo "Error: Homebrew install failed (or brew not on PATH)."
    exit 1
  fi
fi

# Mac App Store apps (mas) require being signed in; skip them if not.
if [ "$DRY_RUN" = "1" ]; then
  echo "Would ensure 'mas' is installed (required for Mac App Store apps), and skip MAS installs if not signed in."
else
  if ! command -v mas &> /dev/null; then
    brew install mas
  fi
  if command -v mas &> /dev/null; then
    if ! mas account &> /dev/null; then
      echo "Not signed into the Mac App Store; skipping MAS installs for now."
      export HOMEBREW_BUNDLE_MAS_SKIP=1
    fi
  fi
fi

if [ -f "$BREWFILE" ]; then
  taps=($(awk -F'"' '/^tap "/ {print $2}' "$BREWFILE" | sort -u))
  brews=($(awk -F'"' '/^brew "/ {print $2}' "$BREWFILE" | sort -u))
  casks=($(awk -F'"' '/^cask "/ {print $2}' "$BREWFILE" | sort -u))
  mas_ids=($(awk '/^mas "/ {for (i=1;i<=NF;i++) if ($i ~ /^id:/) {print $(i+1)}}' "$BREWFILE" | tr -d ',' | sort -u))

  if [ "$DRY_RUN" = "1" ]; then
    echo "Would tap (${#taps[@]}):"
    for tap in "${taps[@]}"; do echo "  - $tap"; done
    echo "Would install via Brewfile:"
    echo "  - formulae: ${#brews[@]}"
    echo "  - casks: ${#casks[@]}"
    echo "  - mas apps: ${#mas_ids[@]} (skipped unless signed into App Store)"
    echo "Would run:"
    echo "  brew bundle install --no-upgrade --file \"$BREWFILE\""
  else
    # Homebrew Bundle currently "fetches" dependencies before processing Brewfile taps,
    # which can break installs for casks/formulae that only exist in third-party taps
    # (e.g. nikitabobko/tap/aerospace, dagger/tap/container-use).
    echo "Ensuring Homebrew taps from $BREWFILE…"
    if [ "${#taps[@]}" -gt 0 ]; then
      existing_taps="$(brew tap 2>/dev/null || true)"
      for tap in "${taps[@]}"; do
        if ! echo "$existing_taps" | grep -qx "$tap"; then
          brew tap "$tap"
        fi
      done
    fi
  fi
fi

if [ "$DRY_RUN" = "0" ]; then
  # install homebrew files
  brew bundle install --no-upgrade --file "$BREWFILE"
fi

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
if [ "$DRY_RUN" = "1" ]; then
  echo "Would ensure directory: $HOME/.config"
else
  mkdir -p "$HOME/.config"
fi
if [ "$DRY_RUN" = "1" ]; then
  echo "Would symlink: $NVIM_CONFIG_DIR -> $CWD/nvim"
else
  ln -snf "$CWD/nvim" "$NVIM_CONFIG_DIR"
fi
# Borders (JankyBorders) config
BORDERS_CONFIG_DIR="$HOME/.config/borders"
if [ -d "$BORDERS_CONFIG_DIR" ] || [ -L "$BORDERS_CONFIG_DIR" ]; then
  if [ "$(readlink "$BORDERS_CONFIG_DIR" 2>/dev/null)" != "$CWD/.config/borders" ]; then
    echo "Error: $BORDERS_CONFIG_DIR already exists and is not a symlink to $CWD/.config/borders."
    echo "To back it up, run: mv \"$BORDERS_CONFIG_DIR\" \"${BORDERS_CONFIG_DIR}.backup-$(date +%s)\""
    echo "Or remove it if you don't need it: rm -rf \"$BORDERS_CONFIG_DIR\""
    echo "After fixing, rerun this bootstrap script."
    exit 1
  fi
fi
if [ "$DRY_RUN" = "1" ]; then
  echo "Would ensure directory: $HOME/.config"
else
  mkdir -p "$HOME/.config"
fi
if [ "$DRY_RUN" = "1" ]; then
  echo "Would symlink: $BORDERS_CONFIG_DIR -> $CWD/.config/borders"
else
  ln -snf "$CWD/.config/borders" "$BORDERS_CONFIG_DIR"
fi

# tmux config
TMUX_CONFIG_DIR="$HOME/.config/tmux"
if [ -d "$TMUX_CONFIG_DIR" ] || [ -L "$TMUX_CONFIG_DIR" ]; then
  if [ "$(readlink "$TMUX_CONFIG_DIR" 2>/dev/null)" != "$CWD/.config/tmux" ]; then
    echo "Error: $TMUX_CONFIG_DIR already exists and is not a symlink to $CWD/.config/tmux."
    echo "To back it up, run: mv \"$TMUX_CONFIG_DIR\" \"${TMUX_CONFIG_DIR}.backup-$(date +%s)\""
    echo "Or remove it if you don't need it: rm -rf \"$TMUX_CONFIG_DIR\""
    echo "After fixing, rerun this bootstrap script."
    exit 1
  fi
fi
if [ "$DRY_RUN" = "1" ]; then
  echo "Would ensure directory: $HOME/.config"
else
  mkdir -p "$HOME/.config"
fi
if [ "$DRY_RUN" = "1" ]; then
  echo "Would symlink: $TMUX_CONFIG_DIR -> $CWD/.config/tmux"
else
  ln -snf "$CWD/.config/tmux" "$TMUX_CONFIG_DIR"
fi

# Start JankyBorders via brew services (uses ~/.config/borders/bordersrc)
if command -v brew >/dev/null 2>&1; then
  if brew list --formula | grep -q "^borders$"; then
    if [ "$DRY_RUN" = "1" ]; then
      echo "Would: brew services restart borders (or start)"
    else
      brew services restart borders || brew services start borders || true
    fi
  fi
fi

# mise (runtime manager) global config
MISE_CONFIG_DIR="$HOME/.config/mise"
MISE_CONFIG_FILE="$MISE_CONFIG_DIR/config.toml"
if [ "$DRY_RUN" = "1" ]; then
  echo "Would ensure directory: $MISE_CONFIG_DIR"
else
  mkdir -p "$MISE_CONFIG_DIR"
fi
if [ -e "$MISE_CONFIG_FILE" ] || [ -L "$MISE_CONFIG_FILE" ]; then
  if [ "$(readlink "$MISE_CONFIG_FILE" 2>/dev/null)" != "$CWD/.config/mise/config.toml" ]; then
    echo "Error: $MISE_CONFIG_FILE already exists and is not a symlink to $CWD/.config/mise/config.toml."
    echo "To back it up, run: mv \"$MISE_CONFIG_FILE\" \"${MISE_CONFIG_FILE}.backup-$(date +%s)\""
    echo "After fixing, rerun this bootstrap script."
    exit 1
  fi
fi
if [ "$DRY_RUN" = "1" ]; then
  echo "Would symlink: $MISE_CONFIG_FILE -> $CWD/.config/mise/config.toml"
else
  ln -snf "$CWD/.config/mise/config.toml" "$MISE_CONFIG_FILE"
fi

# GRM (git-repo-manager) config
GRM_CONFIG_DIR="$HOME/.config/grm"
GRM_CONFIG_FILE="$GRM_CONFIG_DIR/config.toml"
if [ "$DRY_RUN" = "1" ]; then
  echo "Would ensure directory: $GRM_CONFIG_DIR"
else
  mkdir -p "$GRM_CONFIG_DIR"
fi
if [ -e "$GRM_CONFIG_FILE" ] || [ -L "$GRM_CONFIG_FILE" ]; then
  if [ "$(readlink "$GRM_CONFIG_FILE" 2>/dev/null)" != "$CWD/.config/grm/config.toml" ]; then
    echo "Error: $GRM_CONFIG_FILE already exists and is not a symlink to $CWD/.config/grm/config.toml."
    echo "To back it up, run: mv \"$GRM_CONFIG_FILE\" \"${GRM_CONFIG_FILE}.backup-$(date +%s)\""
    echo "After fixing, rerun this bootstrap script."
    exit 1
  fi
fi
if [ "$DRY_RUN" = "1" ]; then
  echo "Would symlink: $GRM_CONFIG_FILE -> $CWD/.config/grm/config.toml"
else
  ln -snf "$CWD/.config/grm/config.toml" "$GRM_CONFIG_FILE"
fi

# Generate an initial GRM config (best-effort) so `grmrepo` works immediately.
if [ "$DRY_RUN" = "1" ]; then
  echo "Would generate: $CWD/.config/grm/config.toml (via bin/grmrepo-refresh) if missing/empty"
else
  if [ ! -s "$CWD/.config/grm/config.toml" ]; then
    if [ -x "$CWD/bin/grmrepo-refresh" ]; then
      GRMREPO_CONFIG="$CWD/.config/grm/config.toml" "$CWD/bin/grmrepo-refresh" >/dev/null 2>&1 || true
    fi
  fi
fi

# Install mise-managed runtimes (node/go/ruby) from global config.
if command -v mise >/dev/null 2>&1; then
  # Avoid interactive trust prompts on a clean machine.
  if [ "$DRY_RUN" = "1" ]; then
    echo "Would run: mise trust --all && mise install -y"
  else
    mise trust --all >/dev/null 2>&1 || true
    if ! mise install -y; then
      echo "Warning: mise install failed (node/go/ruby). You can retry later with: mise install -y"
    fi
  fi
fi

# Codex config
CODEX_DIR="$HOME/.codex"
CODEX_CONFIG_TOML="$CODEX_DIR/config.toml"
CODEX_SKILLS_DIR="$CODEX_DIR/skills"
if [ "$DRY_RUN" = "1" ]; then
  echo "Would ensure directory: $CODEX_DIR"
else
  mkdir -p "$CODEX_DIR"
fi

if [ -e "$CODEX_CONFIG_TOML" ] || [ -L "$CODEX_CONFIG_TOML" ]; then
  if [ "$(readlink "$CODEX_CONFIG_TOML" 2>/dev/null)" != "$CWD/.codex/config.toml" ]; then
    echo "Error: $CODEX_CONFIG_TOML already exists and is not a symlink to $CWD/.codex/config.toml."
    echo "To back it up, run: mv \"$CODEX_CONFIG_TOML\" \"${CODEX_CONFIG_TOML}.backup-$(date +%s)\""
    echo "After fixing, rerun this bootstrap script."
    exit 1
  fi
fi
if [ "$DRY_RUN" = "1" ]; then
  echo "Would symlink: $CODEX_CONFIG_TOML -> $CWD/.codex/config.toml"
else
  ln -snf "$CWD/.codex/config.toml" "$CODEX_CONFIG_TOML"
fi

if [ -e "$CODEX_SKILLS_DIR" ] || [ -L "$CODEX_SKILLS_DIR" ]; then
  if [ "$(readlink "$CODEX_SKILLS_DIR" 2>/dev/null)" != "$CWD/.codex/skills" ]; then
    echo "Error: $CODEX_SKILLS_DIR already exists and is not a symlink to $CWD/.codex/skills."
    echo "To back it up, run: mv \"$CODEX_SKILLS_DIR\" \"${CODEX_SKILLS_DIR}.backup-$(date +%s)\""
    echo "Or remove it if you don't need it: rm -rf \"$CODEX_SKILLS_DIR\""
    echo "After fixing, rerun this bootstrap script."
    exit 1
  fi
fi
if [ "$DRY_RUN" = "1" ]; then
  echo "Would symlink: $CODEX_SKILLS_DIR -> $CWD/.codex/skills"
else
  ln -snf "$CWD/.codex/skills" "$CODEX_SKILLS_DIR"
fi

# Hammerspoon config
HAMMERSPOON_DIR="$HOME/.hammerspoon"
HAMMERSPOON_INIT="$HAMMERSPOON_DIR/init.lua"
if [ "$DRY_RUN" = "1" ]; then
  echo "Would ensure directory: $HAMMERSPOON_DIR"
else
  mkdir -p "$HAMMERSPOON_DIR"
fi
if [ -e "$HAMMERSPOON_INIT" ] || [ -L "$HAMMERSPOON_INIT" ]; then
  if [ "$(readlink "$HAMMERSPOON_INIT" 2>/dev/null)" != "$CWD/.hammerspoon/init.lua" ]; then
    backup="${HAMMERSPOON_INIT}.backup-$(date +%s)"
    if [ "$DRY_RUN" = "1" ]; then
      echo "Would backup: $HAMMERSPOON_INIT -> $backup"
    else
      echo "Backing up existing Hammerspoon init: $HAMMERSPOON_INIT -> $backup"
      mv "$HAMMERSPOON_INIT" "$backup"
    fi
  fi
fi
if [ "$DRY_RUN" = "1" ]; then
  echo "Would symlink: $HAMMERSPOON_INIT -> $CWD/.hammerspoon/init.lua"
else
  ln -snf "$CWD/.hammerspoon/init.lua" "$HAMMERSPOON_INIT"
fi

# Compile Hammerspoon config (Fennel -> Lua) when possible.
if [ "$DRY_RUN" = "1" ]; then
  echo "Would compile Hammerspoon config: (cd $CWD && make hammerspoon) (if fennel is available)"
else
  if command -v fennel >/dev/null 2>&1; then
    (cd "$CWD" && make hammerspoon) || echo "Warning: make hammerspoon failed; run manually."
  else
    echo "Note: fennel not installed; run 'brew bundle' then 'make hammerspoon' to build Hammerspoon config."
  fi
fi

# if [ ! -f $HOME/.sshrc ]; then ln -s $CWD/sshrc $HOME/.sshrc ; fi
for f in zlogin zprofile zshrc zshenv; do
  dest="$HOME/.${f}"
  src="$CWD/${f}"
  if [ "$DRY_RUN" = "1" ]; then
    echo "Would ensure symlink: $dest -> $src (only if $dest does not already exist)"
  else
    if [ ! -f "$dest" ]; then ln -s "$src" "$dest"; fi
  fi
done

# .claude directory symlinks
if [ "$DRY_RUN" = "1" ]; then
  echo "Would ensure directory: $HOME/.claude"
else
  mkdir -p "$HOME/.claude"
fi
for dir in agents commands docs; do
  if [ -d "$CWD/.claude/$dir" ]; then
    if [ "$DRY_RUN" = "1" ]; then
      echo "Would replace symlink: $HOME/.claude/$dir -> $CWD/.claude/$dir"
    else
      if [ -e "$HOME/.claude/$dir" ]; then
        rm -rf "$HOME/.claude/$dir"
      fi
      ln -sf "$CWD/.claude/$dir" "$HOME/.claude/$dir"
    fi
  fi
done

# directories
if [ "$DRY_RUN" = "1" ]; then
  echo "Would ensure directories: $HOME/bin $HOME/code $HOME/.sshrc.d"
else
  mkdir -p "$HOME/bin"
  mkdir -p "$HOME/code"
  mkdir -p "$HOME/.sshrc.d"
fi

# dotfiles bin wrappers
for f in gh grmrepo grmrepo-refresh repo-index; do
  src="$CWD/bin/$f"
  dest="$HOME/bin/$f"
  if [ -f "$src" ]; then
    if [ "$DRY_RUN" = "1" ]; then
      echo "Would symlink: $dest -> $src"
    else
      ln -snf "$src" "$dest"
    fi
  fi
done

# git-repo-manager (grm) install/update (via cargo, when available)
if [ "$DRY_RUN" = "1" ]; then
  echo "Would install/update git-repo-manager via cargo (if cargo is available)"
else
  if command -v cargo >/dev/null 2>&1; then
    cargo install git-repo-manager --locked || echo "Warning: cargo install git-repo-manager failed; retry later."
  fi
fi

# generate lesskey binary file for older versions of less that might be
# present on remote machines.
# nb: will need to `brew install less` for the following line to work.
if command -v lesskey >/dev/null 2>&1 && [ -f "$CWD/lesskey" ]; then
  if [ "$DRY_RUN" = "1" ]; then
    echo "Would generate: $HOME/.less (via lesskey) and copy to $HOME/.sshrc.d/.less"
  else
    lesskey -o "$HOME/.less" "$CWD/lesskey"
    cp "$HOME/.less" "$HOME/.sshrc.d/.less"
  fi
fi

# zsh setup
# nb: this setup takes _heavy_ inspiration from the work of https://github.com/htr3n/zsh-config
if [ ! -d "$HOME/.zinit" ]; then
  if [ "$DRY_RUN" = "1" ]; then
    echo "Would clone zinit to $HOME/.zinit/bin"
  else
    mkdir -p "$HOME/.zinit"
    git clone https://github.com/zdharma-continuum/zinit.git "$HOME/.zinit/bin"
  fi
fi

# LazyVim bootstrap (plugins install on first nvim run).
# Opt-in sync (avoids updating repo lockfile during bootstrap):
if [ "${DOTFILES_NVIM_LAZY_SYNC:-0}" = "1" ] && command -v nvim &>/dev/null; then
  if [ "$DRY_RUN" = "1" ]; then
    echo "Would run: nvim --headless \"+Lazy sync\" +qa"
  else
    nvim --headless "+Lazy sync" +qa || true
  fi
fi

# macOS + app settings
if [ -x "$CWD/scripts/macos/apply.sh" ]; then
  if [ "$DRY_RUN" = "1" ]; then
    echo "Would run: $CWD/scripts/macos/apply.sh"
  else
    "$CWD/scripts/macos/apply.sh"
  fi
fi

echo
if [ "$DRY_RUN" = "1" ]; then
  echo "Dry-run complete (no changes applied)."
else
  echo "Bootstrap complete."
fi
echo
echo "Reminder: set any API keys / secrets in ~/.zshrc.local (this repo's ~/.zshrc sources it if present)."
echo "Common examples:"
echo "  export OPENAI_API_KEY=...        # used by tools like 'llm' (and others)"
echo "  export ANTHROPIC_API_KEY=...     # if you use Anthropic-backed tools"
echo "  export GITHUB_TOKEN=...          # optional; for gh/CI tooling"
echo

# TODO: pending automation items
# - [ ] need to run `autoload zkbd && zkbd` to setup keycode file (used in zshrc)
# - [ ] ~/.gitconfig wiring
#  - `git config --global --type=bool checkout.guess false`: https://gist.github.com/mmrko/b3ec6da9bea172cdb6bd83bdf95ee817 for git completions to not suck
# - [ ] ZDOTDIR and XDG_CONFIG_HOME=~/.config -- https://thevaluable.dev/zsh-install-configure-mouseless/ has ideas
