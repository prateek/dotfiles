/**
 * Indexing service for managing the semantic index
 */

import { type Vault, type TFile, Notice } from 'obsidian';
import {
  type VaultAdapter,
  TimeSliceScheduler,
  ReconcileScheduler,
  TextChunker,
  IndexWriter,
  WAL,
  LedgerManager,
  BM25Index,
  verifyIntegrity,
  createHash,
  type WALEntry,
  type Manifest
} from '@osi/core';
import type { SemanticIndexSettings } from '../settings/settings.js';
import { EmbeddingWorkerManager } from '../workers/embedding-worker-manager.js';

export class IndexingService {
  scheduler: TimeSliceScheduler; // Made public for metrics access
  private reconcileScheduler: ReconcileScheduler;
  private chunker: TextChunker;
  private indexWriter: IndexWriter;
  private wal: WAL;
  private ledger: LedgerManager;
  private bm25Index: BM25Index;
  private workerManager: EmbeddingWorkerManager;
  private isRunning = false;
  private manifest: Manifest | null = null;

  constructor(
    private vaultAdapter: VaultAdapter,
    private vault: Vault,
    private settings: SemanticIndexSettings
  ) {
    this.scheduler = new TimeSliceScheduler({
      sliceMs: 12,
      maxMemoryMB: settings.maxMemoryMB,
      onMemoryPressure: () => this.handleMemoryPressure()
    });

    this.reconcileScheduler = new ReconcileScheduler({
      sliceMs: 12,
      reconcileIntervalMinutes: settings.reconcileIntervalMinutes
    });

    this.chunker = new TextChunker({
      minTokens: settings.chunkMinTokens,
      maxTokens: settings.chunkMaxTokens,
      overlapTokens: settings.chunkOverlapTokens
    });

    this.indexWriter = new IndexWriter(vaultAdapter);
    this.wal = new WAL(vaultAdapter);
    this.ledger = new LedgerManager(vaultAdapter);
    this.bm25Index = new BM25Index();
    this.workerManager = new EmbeddingWorkerManager(settings);
  }

  async start(): Promise<void> {
    if (this.isRunning) return;
    
    this.isRunning = true;
    
    // Load existing index
    await this.loadIndex();
    
    // Start worker
    await this.workerManager.start();
    
    // Process pending tasks
    await this.processPendingTasks();
    
    // Schedule reconciliation
    this.reconcileScheduler.scheduleReconcile(() => this.reconcile());
  }

  async stop(): Promise<void> {
    this.isRunning = false;
    this.scheduler.pause();
    this.reconcileScheduler.stop();
    await this.workerManager.stop();
  }

  updateSettings(settings: SemanticIndexSettings): void {
    this.settings = settings;
    this.chunker = new TextChunker({
      minTokens: settings.chunkMinTokens,
      maxTokens: settings.chunkMaxTokens,
      overlapTokens: settings.chunkOverlapTokens
    });
    this.workerManager.updateSettings(settings);
  }

  async enqueueFile(path: string): Promise<void> {
    const file = this.vault.getAbstractFileByPath(path);
    if (!file || file.children !== undefined) return;

    // Check ignore patterns
    if (this.shouldIgnore(path)) return;

    const stats = await this.vaultAdapter.stat(path);
    if (!stats) return;

    const content = await this.vault.read(file as TFile);
    const hash = await createHash(content);

    // Check if needs reindexing
    const needsReindex = await this.ledger.needsReindex(path, stats, hash);
    if (!needsReindex) return;

    // Create WAL entry
    const entry: WALEntry = {
      id: `job-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
      path,
      status: 'pending',
      hash,
      enq_at: Date.now()
    };

    await this.wal.append(entry);
    
    // Schedule processing
    this.scheduler.enqueue(() => this.processFile(entry), 'normal');
  }

  async removeFile(path: string): Promise<void> {
    // Remove from ledger
    await this.ledger.remove(path);
    
    // Remove from BM25 index
    // TODO: Track chunk IDs by path for removal
    
    // Mark for recompaction
    this.scheduler.enqueue(() => this.checkCompaction(), 'low');
  }

  async handleRename(oldPath: string, newPath: string): Promise<void> {
    // Update ledger
    const ledger = await this.ledger.read();
    const entry = ledger[oldPath];
    if (entry) {
      await this.ledger.remove(oldPath);
      await this.ledger.update(newPath, entry);
    }
    
    // Re-index to update metadata
    await this.enqueueFile(newPath);
  }

  async reconcile(): Promise<void> {
    if (!this.isRunning) return;
    
    const markdownFiles = this.vault.getMarkdownFiles();
    const ledger = await this.ledger.read();
    
    for (const file of markdownFiles) {
      if (this.shouldIgnore(file.path)) continue;
      
      const stats = await this.vaultAdapter.stat(file.path);
      if (!stats) continue;
      
      const ledgerEntry = ledger[file.path];
      if (!ledgerEntry || 
          ledgerEntry.mtimeMs !== stats.mtimeMs || 
          ledgerEntry.size !== stats.size) {
        await this.enqueueFile(file.path);
      }
    }
    
    // Find deleted files
    for (const path of Object.keys(ledger)) {
      const exists = await this.vaultAdapter.exists(path);
      if (!exists) {
        await this.removeFile(path);
      }
    }
  }

  async rebuild(): Promise<void> {
    // Stop current operations
    this.scheduler.pause();
    
    try {
      // Clear existing index
      const dirs = ['segments', 'meta', 'wal', 'ann', 'tmp'];
      for (const dir of dirs) {
        try {
          const files = await this.vaultAdapter.listDir(`.obsidian/plugins/semantic-index/${dir}`);
          for (const file of files) {
            await this.vaultAdapter.remove(`.obsidian/plugins/semantic-index/${dir}/${file}`);
          }
        } catch {
          // Directory might not exist
        }
      }
      
      // Clear manifest and ledger
      await this.vaultAdapter.remove('.obsidian/plugins/semantic-index/manifest.json');
      await this.vaultAdapter.remove('.obsidian/plugins/semantic-index/manifest.prev.json');
      await this.ledger.write({});
      
      // Clear BM25 index
      this.bm25Index = new BM25Index();
      
      // Re-index all files
      const markdownFiles = this.vault.getMarkdownFiles();
      let processed = 0;
      
      for (const file of markdownFiles) {
        if (this.shouldIgnore(file.path)) continue;
        await this.enqueueFile(file.path);
        processed++;
        
        if (processed % 10 === 0) {
          new Notice(`Queued ${processed}/${markdownFiles.length} files for indexing`);
        }
      }
      
      new Notice(`Rebuild complete. Indexing ${processed} files in background.`);
      
    } finally {
      this.scheduler.resume();
    }
  }

  async verifyIntegrity() {
    return await verifyIntegrity(this.vaultAdapter);
  }

  getBM25Index(): BM25Index {
    return this.bm25Index;
  }

  getManifest(): Manifest | null {
    return this.manifest;
  }

  private async loadIndex(): Promise<void> {
    // Load manifest
    const manifestManager = new (await import('@osi/core')).ManifestManager(this.vaultAdapter);
    this.manifest = await manifestManager.read();
    
    // Load BM25 index
    try {
      const bm25Data = await this.vaultAdapter.readText('.obsidian/plugins/semantic-index/bm25.json');
      this.bm25Index = BM25Index.deserialize(bm25Data);
    } catch {
      // BM25 index doesn't exist yet
      this.bm25Index = new BM25Index();
    }
  }

  private async processPendingTasks(): Promise<void> {
    const pending = await this.wal.getPending();
    
    for (const [id, entry] of pending) {
      this.scheduler.enqueue(() => this.processFile(entry), 'high');
    }
  }

  private async processFile(walEntry: WALEntry): Promise<void> {
    if (!walEntry.path) return;
    
    try {
      // Update WAL status
      await this.wal.append({ ...walEntry, status: 'started' });
      
      // Read file content
      const content = await this.vaultAdapter.readText(walEntry.path);
      
      // Chunk the content
      const chunks = this.chunker.chunk(content, walEntry.path);
      
      // Update BM25 index
      for (const chunk of chunks) {
        this.bm25Index.addDocument({
          id: chunk.id,
          content: chunk.content,
          path: walEntry.path
        });
      }
      
      // Generate embeddings
      const embeddings = await this.workerManager.embedBatch(
        chunks.map(c => c.content)
      );
      
      // Prepare segment data
      const metaLines: string[] = [];
      for (let i = 0; i < chunks.length; i++) {
        metaLines.push(JSON.stringify({
          path: walEntry.path,
          chunk_id: chunks[i].id,
          off: chunks[i].offset,
          len: chunks[i].length,
          hash: walEntry.hash,
          heading: chunks[i].heading
        }));
      }
      
      // Commit segment
      const segmentId = `${Date.now()}-${walEntry.id}`;
      this.manifest = await this.indexWriter.commitSegment({
        id: segmentId,
        vectors: embeddings.vectors,
        metaJsonl: metaLines.join('\n'),
        modelId: this.settings.modelId,
        dims: embeddings.dims,
        dtype: this.settings.storageDtype,
        prev: this.manifest || undefined
      });
      
      // Update ledger
      const stats = await this.vaultAdapter.stat(walEntry.path);
      if (stats) {
        await this.ledger.update(walEntry.path, {
          mtimeMs: stats.mtimeMs,
          size: stats.size,
          lastHash: walEntry.hash!,
          lastIndexedAt: Date.now()
        });
      }
      
      // Mark as done
      await this.wal.append({ ...walEntry, status: 'done', done_at: Date.now() });
      
      // Persist BM25 index periodically
      if (Math.random() < 0.1) { // 10% chance
        await this.persistBM25Index();
      }
      
    } catch (error) {
      console.error(`Failed to process ${walEntry.path}:`, error);
      await this.wal.append({ 
        ...walEntry, 
        status: 'failed', 
        done_at: Date.now(),
        err: String(error)
      });
    }
  }

  private async persistBM25Index(): Promise<void> {
    const data = this.bm25Index.serialize();
    await this.vaultAdapter.writeTextAtomic('.obsidian/plugins/semantic-index/bm25.json', data);
  }

  private shouldIgnore(path: string): boolean {
    return this.settings.ignoreGlobs.some(glob => {
      // Simple glob matching
      const regex = glob
        .replace(/\*\*/g, '.*')
        .replace(/\*/g, '[^/]*')
        .replace(/\?/g, '.');
      return new RegExp(`^${regex}$`).test(path);
    });
  }

  private handleMemoryPressure(): void {
    console.warn('Memory pressure detected');
    // Could pause indexing, reduce batch sizes, etc.
    this.workerManager.reduceBatchSize();
  }

  private async checkCompaction(): Promise<void> {
    // TODO: Implement segment compaction logic
    // For now, just compact the WAL
    await this.wal.compact();
  }
}