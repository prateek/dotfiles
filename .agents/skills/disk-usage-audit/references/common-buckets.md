# Common Buckets

Use this file as a search guide when building a storage map. Do not scan every path by default. Start broad, then drill into the largest buckets.

## Cross-Platform Categories

### App bundles

- macOS: `/Applications`, `~/Applications`
- Linux: `/usr`, `/opt`, `~/.local/share/applications` plus package-manager stores

### App state and support data

- macOS: `~/Library/Application Support`, `~/Library/Containers`, `~/Library/Group Containers`
- Linux: `~/.local/share`, `~/.config`, `~/.cache`

### Developer storage

- Xcode and simulators
- Android SDK and emulators
- Container runtimes
- Package-manager caches
- Browser automation downloads

### Hidden user directories

- `~/.cache`
- `~/.local`
- `~/.npm`, `~/.pnpm-store`, `~/.yarn`
- `~/go`, `~/.cargo`, `~/.rustup`
- `~/.platformio`
- `~/.vscode`, `~/.cursor`, `~/.windsurf`
- Agent-specific state under `~/.codex`, `~/.claude`, `~/.config`, `~/.local/share`

## Provider-Specific Search Targets

### Cloud sync

- Dropbox
  - local mirror folders
  - `.dropbox.cache`
  - online-only and selective-sync candidates
- Google Drive
  - `~/Library/CloudStorage/...` on macOS
  - mirrored folders
  - offline-pinned folders
- iCloud
  - `~/Library/Mobile Documents`
- OneDrive
  - local sync root and offline-pinned files

### Containers and VMs

- Docker Desktop
- OrbStack
- Colima
- Podman machine storage
- UTM, Parallels, VMware, VirtualBox

### Browsers and Electron apps

These can be large but stateful. Treat as ambiguous unless the user wants app-state cleanup.

- Chrome, Arc, Chromium, Edge, Firefox
- Service worker storage
- IndexedDB
- WebStorage
- profile caches
- Electron app support folders

### Local AI and media tooling

- local model caches
- Core ML caches
- speech-transcription models
- browser automation bundles
- audio editor temp/session data

## Package and Tool Caches

Common low-risk targets:

- npm, pnpm, yarn, bun
- pip, uv, conda
- go module caches
- cargo registry and target dirs
- Homebrew downloads
- Playwright and Puppeteer browser caches
- CI local caches
- build artifact directories such as `dist`, `build`, `.next`, `target`, `.venv`, `DerivedData`

## Heuristic Prompts

When you have sizes, ask:

- Is this generated?
- Is this mirrored from a cloud provider?
- Is this tied to an installed app?
- Was it touched recently?
- Can it be recreated?
- Would deleting it remove unique user data?

## Output Buckets

A good final report usually has these sections:

- Biggest low-risk cleanup wins
- Cloud-sync policy opportunities
- Dormant apps and leftovers
- Active but large data
- Full storage map by major category
