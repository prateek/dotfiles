#!/usr/bin/env bash
# Install chezmoi

set -e

# Check if chezmoi is already installed
if command -v chezmoi &> /dev/null; then
    echo "chezmoi is already installed"
    chezmoi --version
else
    echo "Installing chezmoi..."
    
    # Install chezmoi via the official install script
    sh -c "$(curl -fsLS get.chezmoi.io)" -- -b $HOME/.local/bin
    
    # Add to PATH if not already there
    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        echo "Adding $HOME/.local/bin to PATH"
        export PATH="$HOME/.local/bin:$PATH"
    fi
fi

echo "chezmoi installed successfully!"