#!/bin/bash

# Development setup script for OSI

set -e

echo "🚀 Setting up Obsidian Semantic Indexer development environment..."

# Check Node version
NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_VERSION" -lt 18 ]; then
    echo "❌ Node.js 18+ required. Current version: $(node -v)"
    exit 1
fi

# Check pnpm
if ! command -v pnpm &> /dev/null; then
    echo "📦 Installing pnpm..."
    npm install -g pnpm
fi

# Install dependencies
echo "📦 Installing dependencies..."
pnpm install

# Build packages
echo "🔨 Building packages..."
pnpm build

# Create dev vault if it doesn't exist
if [ ! -d "dev-vault" ]; then
    echo "📁 Creating development vault..."
    mkdir -p dev-vault/.obsidian/plugins/semantic-index
    
    # Create sample notes
    mkdir -p dev-vault/notes
    echo "# Welcome to OSI Dev Vault

This is a test vault for developing the Semantic Index plugin.

## Features

- Semantic search
- Crash-safe indexing
- Mobile optimized" > dev-vault/notes/welcome.md
    
    echo "# Machine Learning Basics

Machine learning is a subset of artificial intelligence that enables systems to learn from data.

## Types of ML

- Supervised Learning
- Unsupervised Learning
- Reinforcement Learning" > dev-vault/notes/ml-basics.md
fi

# Link plugin to dev vault
echo "🔗 Linking plugin to dev vault..."
ln -sf "$(pwd)/packages/plugin-obsidian/main.js" dev-vault/.obsidian/plugins/semantic-index/main.js
ln -sf "$(pwd)/packages/plugin-obsidian/manifest.json" dev-vault/.obsidian/plugins/semantic-index/manifest.json
ln -sf "$(pwd)/packages/plugin-obsidian/styles.css" dev-vault/.obsidian/plugins/semantic-index/styles.css

echo "✅ Development environment ready!"
echo ""
echo "Next steps:"
echo "1. Open dev-vault in Obsidian"
echo "2. Enable the Semantic Index plugin"
echo "3. Run 'pnpm -F plugin-obsidian dev' for hot reload"
echo ""
echo "Happy coding! 🎉"