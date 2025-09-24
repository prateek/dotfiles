#!/usr/bin/env bash
# Test script to verify XDG migration

set -e

echo "=== XDG Migration Test ==="
echo

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test function
test_result() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $2"
    else
        echo -e "${RED}✗${NC} $2"
        EXIT_CODE=1
    fi
}

EXIT_CODE=0

echo "1. Checking XDG directories..."
test_result $([ -d "$HOME/.config" ] && echo 0 || echo 1) "~/.config exists"
test_result $([ -d "$HOME/.local/share" ] && echo 0 || echo 1) "~/.local/share exists"
test_result $([ -d "$HOME/.cache" ] && echo 0 || echo 1) "~/.cache exists"

echo
echo "2. Checking Zsh configuration..."
test_result $([ -f "$HOME/.zshenv" ] && echo 0 || echo 1) "~/.zshenv exists (compatibility)"
test_result $([ -d "$HOME/.config/zsh" ] && echo 0 || echo 1) "~/.config/zsh directory exists"
test_result $([ -f "$HOME/.config/zsh/.zshenv" ] && echo 0 || echo 1) "~/.config/zsh/.zshenv exists"
test_result $([ -f "$HOME/.config/zsh/.zshrc" ] && echo 0 || echo 1) "~/.config/zsh/.zshrc exists"
test_result $([ -f "$HOME/.config/zsh/.zprofile" ] && echo 0 || echo 1) "~/.config/zsh/.zprofile exists"

echo
echo "3. Checking Vim configuration..."
test_result $([ -f "$HOME/.vimrc" ] && echo 0 || echo 1) "~/.vimrc exists (compatibility)"
test_result $([ -d "$HOME/.config/vim" ] && echo 0 || echo 1) "~/.config/vim directory exists"
test_result $([ -f "$HOME/.config/vim/vimrc" ] && echo 0 || echo 1) "~/.config/vim/vimrc exists"

echo
echo "4. Checking other configurations..."
test_result $([ -f "$HOME/.inputrc" ] && echo 0 || echo 1) "~/.inputrc exists (compatibility)"
test_result $([ -f "$HOME/.config/readline/inputrc" ] && echo 0 || echo 1) "~/.config/readline/inputrc exists"
test_result $([ -f "$HOME/.config/less/lesskey" ] && echo 0 || echo 1) "~/.config/less/lesskey exists"

echo
echo "5. Checking environment variables in zsh..."
if command -v zsh &> /dev/null; then
    ZDOTDIR_CHECK=$(zsh -c 'echo $ZDOTDIR' 2>/dev/null)
    test_result $([ "$ZDOTDIR_CHECK" = "$HOME/.config/zsh" ] && echo 0 || echo 1) "ZDOTDIR is set correctly"
    
    XDG_CONFIG_CHECK=$(zsh -c 'echo $XDG_CONFIG_HOME' 2>/dev/null)
    test_result $([ -n "$XDG_CONFIG_CHECK" ] && echo 0 || echo 1) "XDG_CONFIG_HOME is set"
else
    echo -e "${YELLOW}⚠${NC}  zsh not found, skipping environment tests"
fi

echo
echo "6. Checking Chezmoi setup..."
test_result $([ -f "$HOME/.config/chezmoi/chezmoi.toml" ] && echo 0 || echo 1) "Chezmoi config exists"
test_result $([ -f "$HOME/dotfiles/install-chezmoi.sh" ] && echo 0 || echo 1) "Chezmoi install script exists"
test_result $([ -f "$HOME/dotfiles/init-chezmoi.sh" ] && echo 0 || echo 1) "Chezmoi init script exists"

echo
echo "7. File content verification..."
if [ -f "$HOME/.zshenv" ]; then
    if grep -q "ZDOTDIR" "$HOME/.zshenv"; then
        test_result 0 ".zshenv sets ZDOTDIR"
    else
        test_result 1 ".zshenv sets ZDOTDIR"
    fi
fi

if [ -f "$HOME/.vimrc" ]; then
    if grep -q "XDG_CONFIG_HOME" "$HOME/.vimrc"; then
        test_result 0 ".vimrc uses XDG paths"
    else
        test_result 1 ".vimrc uses XDG paths"
    fi
fi

echo
echo "=== Test Summary ==="
if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    echo "Your dotfiles have been successfully migrated to XDG Base Directory specification."
else
    echo -e "${RED}Some tests failed.${NC}"
    echo "Please check the failed items above."
fi

echo
echo "Next steps:"
echo "1. Run './install-chezmoi.sh' to install chezmoi"
echo "2. Run './init-chezmoi.sh' to initialize chezmoi with your dotfiles"
echo "3. Restart your shell or run 'source ~/.zshenv' to apply changes"

exit $EXIT_CODE