# Obsidian Semantic Indexer (OSI)

A local, self-contained semantic search plugin for Obsidian with crash-proof indexing, zero-blocking UX, and comprehensive admin observability.

## Features

- 🔍 **Hybrid Search**: Combines semantic (dense vector) and lexical (BM25) search for best results
- 💾 **Crash-Safe**: Atomic commit protocol ensures index integrity even with mid-write crashes
- ⚡ **Non-Blocking**: Time-sliced indexing keeps the UI responsive
- 📱 **Mobile Ready**: Optimized for iOS/iPadOS with memory-aware processing
- 🔒 **Privacy First**: All processing happens locally, no network calls
- 📊 **Admin Dashboard**: Monitor index health, trigger maintenance, export diagnostics

## Installation

### From Obsidian Community Plugins (Coming Soon)

1. Open Settings → Community plugins
2. Search for "Semantic Index"
3. Install and enable

### Manual Installation

1. Download the latest release from GitHub
2. Extract to your vault's `.obsidian/plugins/semantic-index/` folder
3. Reload Obsidian
4. Enable the plugin in Settings → Community plugins

## Usage

### Quick Start

1. After enabling the plugin, it will automatically start indexing your vault
2. Use the ribbon icon or command palette to open Semantic Search
3. Type your query naturally - the plugin understands context and meaning

### Search Modes

- **Hybrid** (default): Combines semantic and keyword matching
- **Semantic Only**: Pure meaning-based search, great for concepts
- **Keyword Only**: Traditional text matching

### Status Chip

The status chip in the search panel shows:
- 🟢 **Fresh**: Index is up to date
- 🟡 **Stale**: Some files pending indexing
- Click the chip to open the Admin panel

## Configuration

### Model Settings

- **Embedding Model**: Choose between BGE-small (recommended) or MiniLM
- **Storage Type**: Float32 (higher quality) or Float16 (lower memory)

### Performance Tuning

- **Concurrent Chunks**: Number of text chunks to process in parallel
- **Reconcile Interval**: How often to check for file changes (minutes)
- **Enable ANN**: Use approximate nearest neighbor for faster searches on large vaults

### Memory Limits

The plugin automatically manages memory usage:
- Mobile: 150MB limit with throttling
- Desktop: 512MB+ based on available memory

## Development

### Project Structure

```
obsidian-semantic-indexer/
├── packages/
│   ├── core/           # Pure TS index engine
│   ├── plugin-obsidian/# Obsidian plugin
│   └── harness/        # Test & chaos harness
```

### Building

```bash
# Install dependencies
pnpm install

# Build all packages
pnpm build

# Run tests
pnpm test

# Run chaos tests
pnpm -F harness test:chaos
```

### Architecture

The plugin uses a crash-safe commit protocol:

1. **Enqueue**: Append task to WAL
2. **Stage**: Write to tmp/
3. **Publish**: Atomic rename to segments/
4. **Commit**: Update manifest atomically
5. **Acknowledge**: Mark complete in WAL

## Troubleshooting

### Index appears corrupted

1. Open Admin panel (click status chip)
2. Run "Verify Integrity"
3. If issues found, use "Rebuild Index"

### Search is slow

- Enable ANN acceleration (desktop only)
- Reduce chunk size in settings
- Check Admin panel for memory pressure

### Missing results

- Check if files match ignore patterns
- Verify files are indexed (Admin panel)
- Try "Force Reconcile" to reindex

## Privacy

- All processing happens locally in your browser/app
- No data is sent to external servers
- Model weights are downloaded once and cached locally
- Debug bundles are sanitized before export

## Contributing

Contributions are welcome! Please read our contributing guidelines and submit PRs to the GitHub repository.

## License

MIT License - see LICENSE file for details