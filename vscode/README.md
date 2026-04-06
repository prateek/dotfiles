# VSCode Configuration Improvements

This directory contains optimized VSCode settings and configurations with the following improvements:

## 🚀 Performance Optimizations

- **Reduced file watching overhead**: Optimized `files.watcherExclude` patterns to ignore build artifacts and large directories
- **Minimized extension load**: Removed obsolete extensions and kept only essential ones
- **Disabled unnecessary features**: Turned off minimap, reduced quick suggestions delay, and disabled auto-closing tags

## 📁 File Organization

### settings-improved.json
Reorganized into clear sections:
- **Editor Core Settings**: Basic editor preferences
- **File Handling**: Auto-save, formatting, and line endings
- **Performance Optimizations**: Exclude patterns and watcher settings
- **Workbench Settings**: UI and window preferences
- **Terminal Settings**: Shell configurations
- **VIM Extension Settings**: Comprehensive vim keybindings
- **Git Settings**: Version control preferences
- **Language-Specific Settings**: Go, JSON, JavaScript/TypeScript, Python configurations

### keybindings-improved.json
Organized by functionality:
- **Command Palette & Quick Access**
- **Editor Navigation**
- **Editor Actions**
- **Error/Problem Navigation**
- **Explorer & File Management**
- **Git Integration**
- **Build & Tasks**
- **Terminal**
- **Language-Specific Bindings** (Go, Zig)

### extensions-improved.json
Categorized extensions:
- **AI Assistants**: Claude, GitHub Copilot
- **Git Integration**: GitLens
- **Language Support**: Go, Python, etc.
- **Editor Enhancement**: Vim
- **Markdown**: Preview and export tools
- **Remote Development**: Containers
- **Other Languages**: Bazel, Typst, Protocol Buffers, Thrift

## 🎨 Clojure-style JSON Formatting

### Custom Formatter
A Node.js script (`clojure-json-formatter.js`) that formats JSON files with:
- Compact inline formatting for small objects/arrays
- Aligned key-value pairs for better readability
- Minimal vertical space usage
- Intelligent line breaking based on content size

### Usage
```bash
# Format a single file
node vscode/clojure-json-formatter.js settings.json

# Use via VSCode task
# Run task: "Format JSON (Clojure-style)"
```

### Example
Before:
```json
{"editor": {"fontSize": 13, "tabSize": 2}, "files": {"autoSave": "off"}}
```

After:
```json
{
  "editor": {"fontSize": 13, "tabSize": 2},
  "files" : {"autoSave": "off"}
}
```

## 🔧 Prettier Configuration

A `.prettierrc.json` file is included for standard JSON formatting with:
- 120 character line width
- No semicolons
- No trailing commas
- Bracket same line positioning

## 📋 Key Changes from Original

1. **Removed Duplicates**:
   - `editor.renderWhitespace` (was defined twice)
   - Multiple vim keybindings for "j" and "k"

2. **Fixed Conflicts**:
   - JSON formatting now consistently disabled (was conflicting)
   - Go save actions clarified

3. **Removed Obsolete**:
   - Commented out settings
   - Unused Python Jedi settings
   - Redundant extension entries

4. **Added Organization**:
   - Clear section headers with comments
   - Grouped related settings
   - Consistent formatting

## 🚀 Quick Start

1. Back up your current settings:
   ```bash
   cp settings.json settings.json.backup
   cp keybindings.json keybindings.json.backup
   ```

2. Replace with improved versions:
   ```bash
   cp settings-improved.json settings.json
   cp keybindings-improved.json keybindings.json
   cp extensions-improved.json extensions.json
   cp tasks-improved.json tasks.json
   ```

3. Reload VSCode window: `Cmd+R` (on macOS)

## 📝 Notes

- The Clojure-style formatter requires Node.js
- Some paths in settings are user-specific (e.g., Zig paths) and may need adjustment
- The vim keybindings assume you have the VSCode Vim extension installed