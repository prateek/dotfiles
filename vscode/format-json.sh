#!/bin/bash
# VSCode JSON Formatter Script
# Provides multiple formatting options for JSON configuration files

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

show_help() {
    cat << EOF
VSCode JSON Formatter

Usage: ./format-json.sh [OPTION]

Options:
    --prettier      Format with Prettier (standard style)
    --compact       Format with jq compact style (Clojure-like)
    --jq            Format with jq (2-space indentation)
    --validate      Validate JSON syntax (strips comments first)
    --help          Show this help message

Examples:
    ./format-json.sh --prettier     # Use Prettier for standard formatting
    ./format-json.sh --compact      # Compact Clojure-style formatting
    ./format-json.sh --jq           # Pretty print with jq

Note: VSCode uses JSONC (JSON with Comments) format for settings and keybindings.
      The --validate option will strip comments before validation.
EOF
}

validate_json() {
    echo -e "${BLUE}Validating JSON files...${NC}"
    
    # Check if jq is available for better validation
    if command -v jq &> /dev/null; then
        echo -e "${GREEN}Using jq for validation${NC}"
        
        for file in extensions.json tasks.json snippets/*.json; do
            if [ -f "$file" ]; then
                if jq empty "$file" 2>/dev/null; then
                    echo -e "${GREEN}✓${NC} $file is valid"
                else
                    echo -e "${YELLOW}✗${NC} $file has errors"
                fi
            fi
        done
        
        echo -e "\n${YELLOW}Note: settings.json and keybindings.json use JSONC (JSON with Comments)${NC}"
        echo -e "${YELLOW}They may not validate with standard JSON parsers but are valid in VSCode${NC}"
    else
        echo -e "${YELLOW}jq not found. Install with: brew install jq${NC}"
    fi
}

format_prettier() {
    echo -e "${BLUE}Formatting with Prettier...${NC}"
    
    if ! command -v npx &> /dev/null; then
        echo -e "${YELLOW}npx not found. Install Node.js first.${NC}"
        exit 1
    fi
    
    npx prettier --write "*.json" "snippets/*.json" --config .prettierrc
    echo -e "${GREEN}✓ Formatted with Prettier${NC}"
}

format_compact() {
    echo -e "${BLUE}Formatting with compact style (Clojure-like)...${NC}"
    
    if ! command -v jq &> /dev/null; then
        echo -e "${YELLOW}jq not found. Install with: brew install jq${NC}"
        exit 1
    fi
    
    for file in extensions.json tasks.json snippets/*.json; do
        if [ -f "$file" ]; then
            echo -e "Processing $file..."
            # Use compact output with some pretty printing
            jq -c . "$file" > "$file.tmp" && mv "$file.tmp" "$file"
            echo -e "${GREEN}✓${NC} $file"
        fi
    done
    
    echo -e "\n${YELLOW}Note: Skipping settings.json and keybindings.json (contain comments)${NC}"
}

format_jq() {
    echo -e "${BLUE}Formatting with jq (2-space indentation)...${NC}"
    
    if ! command -v jq &> /dev/null; then
        echo -e "${YELLOW}jq not found. Install with: brew install jq${NC}"
        exit 1
    fi
    
    for file in extensions.json tasks.json snippets/*.json; do
        if [ -f "$file" ]; then
            echo -e "Processing $file..."
            jq --indent 2 . "$file" > "$file.tmp" && mv "$file.tmp" "$file"
            echo -e "${GREEN}✓${NC} $file"
        fi
    done
    
    echo -e "\n${YELLOW}Note: Skipping settings.json and keybindings.json (contain comments)${NC}"
}

# Main script logic
case "${1:-}" in
    --prettier)
        format_prettier
        ;;
    --compact)
        format_compact
        ;;
    --jq)
        format_jq
        ;;
    --validate)
        validate_json
        ;;
    --help|"")
        show_help
        ;;
    *)
        echo -e "${YELLOW}Unknown option: $1${NC}"
        echo ""
        show_help
        exit 1
        ;;
esac
