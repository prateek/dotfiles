# VSCode Quick Reference Card

## 🚀 Quick Start

```bash
# Format JSON files
cd ~/dotfiles/vscode
./format-json.sh --prettier    # Standard formatting
./format-json.sh --compact     # Clojure-style compact
./format-json.sh --validate    # Check syntax

# Install all extensions
code --list-extensions | while read ext; do code --install-extension $ext; done
```

## ⌨️ Essential Keybindings

### Navigation
| Key | Action |
|-----|--------|
| `Ctrl+H` | Navigate left |
| `Ctrl+L` | Navigate right |
| `Ctrl+K` | Navigate up |
| `Ctrl+J` | Navigate down |
| `Shift+Cmd+[` | Previous editor |
| `Shift+Cmd+]` | Next editor |
| `Cmd+N` | Quick open |

### Editor
| Key | Action |
|-----|--------|
| `F1` | Show hover |
| `Ctrl+Shift+F` | Format document |
| `Cmd+2` | Split editor |
| `Cmd+K L` | Close editors to right |

### Problems/Errors
| Key | Action |
|-----|--------|
| `Cmd+P` | Next problem |
| `Shift+Cmd+P` | Previous problem |

### Go Development
| Key | Action |
|-----|--------|
| `Ctrl+E` | Test at cursor |
| `Ctrl+F` | Test file |
| `Ctrl+S` | Run previous test |
| `Ctrl+T` | Test package |
| `F5` | Debug restart |

### Vim Mode Shortcuts
| Key | Action |
|-----|--------|
| `Space` | Leader key |
| `[Q` / `]Q` | Prev/next error |
| `[R` / `]R` | Prev/next reference |
| `[C` / `]C` | Prev/next change |
| `gD` | Go to first declaration |
| `gI` | Find implementations |
| `gU` | Find references |
| `gH` | Show hover |
| `Space+M` | Toggle bookmark |
| `Space+B` | List bookmarks |

### Terminal
| Key | Action |
|-----|--------|
| `Shift+Cmd+Enter` | Toggle maximized panel |
| `Ctrl+A` | Run selected text |

## 📁 File Organization

```
vscode/
├── settings.json          # Main settings (15 sections)
├── keybindings.json       # Custom keybindings (12 sections)
├── extensions.json        # Recommended extensions
├── tasks.json            # Custom tasks
├── snippets/
│   └── go.json          # Go code snippets
├── .editorconfig        # Editor formatting rules
├── .prettierrc          # Prettier config
├── format-json.sh       # Formatting helper script
├── VSCODE_CONFIG.md     # Full documentation
├── IMPROVEMENTS_SUMMARY.md  # Changes summary
└── QUICK_REFERENCE.md   # This file
```

## 🎨 JSON Formatting Options

### Using the Script
```bash
./format-json.sh --prettier    # Prettier (standard)
./format-json.sh --compact     # Compact Clojure-style
./format-json.sh --jq          # jq pretty-print
./format-json.sh --validate    # Validate syntax
```

### Using jq Directly
```bash
jq -c . file.json              # Compact (Clojure-style)
jq --indent 2 . file.json      # Pretty 2-space
jq . file.json                 # Pretty 4-space
```

### Using Prettier
```bash
npx prettier --write "*.json"
npx prettier --write "*.json" --config .prettierrc
```

## 🔧 Common Tasks

### Open Settings
- **GUI**: `Cmd+,` or `Ctrl+,`
- **JSON**: `Space+C+V` (Vim mode) or search "Preferences: Open Settings (JSON)"

### Open Keybindings
- **GUI**: `Shift+Cmd+.`
- **JSON**: Search "Preferences: Open Keyboard Shortcuts (JSON)"

### Reload VSCode
- `Cmd+Shift+P` → "Developer: Reload Window"

### Format Current File
- `Ctrl+Shift+F`

## 🏗️ Settings Structure

```json
{
  // 1. Editor Settings - basic editor config
  // 2. Workbench Settings - UI/UX
  // 3. Explorer Settings - file explorer
  // 4. Files Settings - file handling
  // 5. Language-Specific - per-language config
  // 6. Go Settings - Go development
  // 7. Gopls Settings - Go language server
  // 8. Git Settings - version control
  // 9. GitLens Settings - enhanced git
  // 10. Vim Settings - vim extension
  // 11. Copilot Settings - AI assistance
  // 12. Other Languages - Python, Zig, etc.
  // 13. Terminal Settings - integrated terminal
  // 14. Notebook Settings - Jupyter
  // 15. Extensions & Security
  // 16. Debug Settings
}
```

## 🎯 Performance Tips

### Excluded from Watching
- `**/bazel*/**` - Bazel build directories
- `pkg/mod/**` - Go module cache

### Disabled Features (for speed)
- Quick suggestions
- Minimap
- Preview modes
- Git submodule detection

### Optimized Settings
- `editor.quickSuggestionsDelay: 300` - Delay suggestions
- `files.exclude` - Hide build artifacts
- `gopls.build.directoryFilters` - Exclude bazel dirs

## 📦 Extensions Cheat Sheet

| Extension | Purpose |
|-----------|---------|
| `vscodevim.vim` | Vim keybindings |
| `eamodio.gitlens` | Enhanced Git features |
| `golang.go` | Go language support |
| `GitHub.copilot` | AI pair programming |
| `ms-python.python` | Python support |
| `Anthropic.claude-code` | Claude AI assistant |

Install all:
```bash
cat extensions.json | jq -r '.extensions[]' | while read ext; do
  code --install-extension "$ext"
done
```

## 🐛 Troubleshooting

### Settings Not Applied
1. Check JSON syntax (JSONC supports comments)
2. Reload window: `Cmd+Shift+P` → "Reload Window"
3. Check User vs Workspace settings priority

### Keybinding Conflicts
1. Open shortcuts: `Shift+Cmd+.`
2. Search for your key combo
3. Look for conflicts in the list
4. Disable conflicting defaults in keybindings.json

### Formatting Not Working
1. Install Prettier extension
2. Set default formatter: `editor.defaultFormatter`
3. Check `editor.formatOnSave` setting
4. Run format manually: `Ctrl+Shift+F`

## 🔍 Finding Settings

### By Category
- Search settings UI with keywords
- Jump to section in settings.json using comments

### By Feature
| Feature | Setting |
|---------|---------|
| Font size | `editor.fontSize: 13` |
| Tab size | `editor.tabSize: 2` |
| Format on save | `editor.formatOnSave: true` |
| Minimap | `editor.minimap.enabled: false` |
| Auto save | `files.autoSave: "off"` |
| Theme | `workbench.colorTheme` |

## 📝 Snippet Prefixes

### Go Snippets
| Prefix | Description |
|--------|-------------|
| `psf` | Print formatted string |
| `ctrl` | Test mock controller |
| `leak` | Leaktest check |
| `proptest` | Property-based test |

## 🎨 Clojure-Style JSON Example

**Before (Standard):**
```json
{
  "array": [
    "item1",
    "item2",
    "item3"
  ]
}
```

**After (Clojure-style):**
```json
{"array": ["item1", "item2", "item3"]}
```

**To achieve:**
```bash
jq -c . file.json > file.compact.json
```

## 🚦 Quick Wins

### Speed Up VSCode
1. ✅ Exclude large directories from file watching
2. ✅ Disable unused features (minimap, previews)
3. ✅ Use language server filters
4. ✅ Disable git for large repos

### Improve Workflow
1. ✅ Learn vim keybindings (`:` and `;` are swapped!)
2. ✅ Use `[` and `]` for navigation
3. ✅ Master `Ctrl+H/J/K/L` for window nav
4. ✅ Use `Space` as leader in vim mode

### Better Code Quality
1. ✅ Enable format on save
2. ✅ Use consistent indentation (2 spaces)
3. ✅ Trim trailing whitespace
4. ✅ Insert final newline

## 📚 Documentation Files

| File | Purpose |
|------|---------|
| `VSCODE_CONFIG.md` | Comprehensive guide (300+ lines) |
| `IMPROVEMENTS_SUMMARY.md` | What changed and why |
| `QUICK_REFERENCE.md` | This quick reference card |

## 💡 Pro Tips

1. **Vim Mode**: `:` and `;` are swapped - use `:` for repeat and `;` for commands
2. **Leader Key**: `Space` is your friend - many shortcuts use `Space+<key>`
3. **Navigation**: `[` and `]` prefixes for prev/next everything
4. **Testing**: `Ctrl+E` (cursor), `Ctrl+F` (file), `Ctrl+T` (package) in Go
5. **Formatting**: Disabled for JSON/JSONC to preserve your custom style

## 🎓 Learning Resources

- Press `F1` to see hover information
- `Shift+Cmd+.` to explore all keybindings
- `Cmd+Shift+P` for command palette
- Check VSCode docs: https://code.visualstudio.com/docs

---

**Quick Tip**: Bookmark this file for easy reference!
