# VSCode Configuration Guide

## Overview

This directory contains optimized VSCode configuration files for your dotfiles repository. The configuration has been reorganized for better maintainability, performance, and clarity.

## Files

- **settings.json** - Main VSCode settings, organized by category
- **keybindings.json** - Custom keyboard shortcuts, grouped by function
- **extensions.json** - Recommended extensions list
- **tasks.json** - Custom tasks (e.g., markdown to Confluence)
- **snippets/go.json** - Go language code snippets
- **.editorconfig** - Editor formatting rules
- **.prettierrc** - Prettier formatting configuration

## Recent Improvements

### 1. Settings.json Enhancements

**Removed:**
- Duplicate key bindings (duplicate "j" mapping removed)
- Commented-out settings that cluttered the file
- Hard-coded user-specific paths (moved to comments with instructions)
- Deprecated settings (e.g., `python.jediEnabled`)
- Invalid JSON syntax

**Organized:**
Settings are now grouped into logical sections:
- Editor Settings
- Workbench Settings
- Explorer Settings
- Files Settings
- Language-Specific Settings
- Go Language Settings
- Gopls Settings
- Git/GitLens Settings
- Vim Extension Settings
- GitHub Copilot Settings
- Terminal Settings
- Notebook Settings
- Extensions & Security
- Debug Settings

**Performance Benefits:**
- Removed unused/commented settings
- Cleaner file structure for faster parsing
- Better organization helps VSCode load settings more efficiently

### 2. Keybindings.json Improvements

**Removed:**
- Duplicate entries (shift+cmd+[, shift+cmd+], ctrl+h/l/k/j navigation)
- Conflicting keybindings

**Organized:**
Keybindings are now grouped by function:
- System/Global Shortcuts
- Editor Navigation
- Editor Features
- Problem/Error Navigation
- References & Symbols
- Explorer View
- Git/Version Control
- Tasks & Build
- Terminal
- Copilot Chat
- Language-Specific Bindings (Go, Zig)
- Misc Disabled Bindings

### 3. Go Snippets Cleanup

- Removed commented template text
- Improved formatting consistency
- Added proper descriptions

### 4. Added Configuration Files

- **.editorconfig** - Ensures consistent formatting across editors
- **.prettierrc** - Prettier configuration for automatic formatting

## Clojure-Style JSON Formatting

You mentioned wanting "Clojure-like formatting" for JSON configs. Here are several approaches:

### Option 1: Using jq (Compact Style)

For a more compact, Clojure/EDN-inspired format:

```bash
# Install jq if not already installed
brew install jq

# Format with compact output
jq -c . settings.json > settings.compact.json

# Or with specific indentation
jq --indent 2 . settings.json > settings.formatted.json
```

### Option 2: Using Prettier with Custom Config

The included `.prettierrc` file provides sensible defaults. You can customize it further:

```json
{
  "printWidth": 80,           // Shorter lines for more compact style
  "tabWidth": 2,
  "bracketSpacing": false,    // Remove spaces in objects: {key:value}
  "trailingComma": "none"     // No trailing commas
}
```

Run prettier:
```bash
npx prettier --write "*.json"
```

### Option 3: VSCode Settings for Clojure-Style

Add these to your `settings.json` for more compact formatting:

```json
"[json][jsonc]": {
  "editor.formatOnSave": true,
  "editor.defaultFormatter": "esbenp.prettier-vscode",
  "editor.tabSize": 2
}
```

### Option 4: Using json-fmt (Custom Formatter)

For truly Clojure-style formatting with compact arrays/objects:

```bash
# Install json-fmt (if available) or use a custom script
npm install -g json-format-cli

# Format with compact style
json-fmt --compact settings.json
```

### Option 5: Manual EDN-Style Patterns

For arrays and simple objects, you can manually format like this:

```json
// Standard JSON
{
  "array": [
    "item1",
    "item2",
    "item3"
  ]
}

// Clojure/EDN-inspired (compact)
{
  "array": ["item1", "item2", "item3"]
}

// For objects
{
  "config": {"key1": "value1", "key2": "value2"}
}
```

## Recommended Workflow

### 1. Format on Save

The settings are configured to format most files on save, except JSON/JSONC (to preserve your custom formatting).

### 2. Manual Formatting

Use `Ctrl+Shift+F` (or `Cmd+Shift+F` on macOS) to format a document manually.

### 3. Using Prettier

```bash
# Format all JSON files
npx prettier --write "vscode/**/*.json"

# Format with custom config
npx prettier --config vscode/.prettierrc --write "vscode/**/*.json"
```

### 4. Custom Format Script

Create a shell script for your preferred JSON formatting:

```bash
#!/bin/bash
# vscode/format-json.sh

for file in *.json snippets/*.json; do
  if [ -f "$file" ]; then
    jq --indent 2 . "$file" > "$file.tmp" && mv "$file.tmp" "$file"
  fi
done

echo "JSON files formatted!"
```

Make it executable:
```bash
chmod +x vscode/format-json.sh
```

## Performance Tips

1. **Reduce File Watching**: The `files.watcherExclude` setting now excludes bazel and pkg/mod directories to reduce file system watching overhead.

2. **Disable Unused Features**: 
   - Quick suggestions are disabled for better performance
   - Minimap is disabled
   - Preview modes are disabled

3. **Git Performance**: 
   - Submodule detection is disabled
   - Repository detection is scoped to subFolders

4. **Language Server Optimizations**:
   - Gopls has directory filters to exclude build directories
   - Bazel paths are ignored

## User-Specific Settings

Some settings need to be configured per-user. Add these to your User Settings (not workspace):

```json
{
  // Zig paths (if using Zig)
  "zig.zigPath": "/path/to/zig",
  "zig.zls.path": "/path/to/zls",
  
  // Git ignored repositories (your specific paths)
  "git.ignoredRepositories": [
    "/path/to/large/repo"
  ]
}
```

## Extension Management

The `extensions.json` file recommends essential extensions. Install them with:

```bash
# Install all recommended extensions
code --list-extensions | while read ext; do
  code --install-extension $ext
done
```

## Vim Keybindings

The configuration includes extensive vim keybindings. Key highlights:

- `<space>` is the leader key
- `[` and `]` prefixes for navigation (errors, changes, references)
- `:` and `;` are swapped
- `j`/`k` mapped to `gj`/`gk` for wrapped lines
- Custom `g` commands for references, implementations, hover

## Git/GitLens Integration

- GitLens is configured with alternate keymap
- Custom remote for Uber internal repositories (update domain as needed)
- Git autofetch enabled
- Smart commit enabled

## Language-Specific Configurations

### Go
- Format with custom formatter
- Tests run with `-v -count=1` flags
- Coverage decorators configured
- Context menu commands mostly disabled for cleaner UI

### Python
- Pylance language server (Jedi disabled)
- Virtual environment in `.venv`

### Markdown
- Marp support for presentations
- Enhanced markdown preview

## Troubleshooting

### Settings Not Applied
1. Check for JSON syntax errors: `Cmd+Shift+P` → "Preferences: Open User Settings (JSON)"
2. Reload VSCode: `Cmd+Shift+P` → "Developer: Reload Window"

### Keybindings Conflict
1. Open Keyboard Shortcuts: `Shift+Cmd+.`
2. Search for your keybinding to see conflicts
3. Adjust in `keybindings.json`

### Formatting Issues
1. Check your default formatter: `editor.defaultFormatter`
2. Install Prettier extension
3. Run `npx prettier --write file.json` manually

## Further Customization

For more aggressive Clojure-style formatting, consider creating a custom formatter:

1. Use a tool like `jetfmt` (if available for JSON)
2. Create a VSCode extension with custom formatting rules
3. Use a language server that supports EDN-style formatting

## References

- [VSCode Settings Documentation](https://code.visualstudio.com/docs/getstarted/settings)
- [Prettier Options](https://prettier.io/docs/en/options.html)
- [EditorConfig](https://editorconfig.org/)
- [jq Manual](https://stedolan.github.io/jq/manual/)
