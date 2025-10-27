/**
 * Core library exports
 */

// Types
export * from './formats/types.js';

// Formats
export { ManifestManager } from './formats/manifest.js';
export { SegmentReader, SegmentWriter } from './formats/segment.js';
export { WAL } from './formats/wal.js';
export { LedgerManager } from './formats/ledger.js';

// Engine
export { IndexWriter } from './engine/index-writer.js';
export { TextChunker, type Chunk, type ChunkOptions } from './engine/chunker.js';

// Search
export { BM25Index, type BM25Document, type BM25Options, type BM25SearchResult } from './search/bm25.js';
export { VectorSearchEngine, type VectorSearchResult } from './search/vector-search.js';
export { HybridSearchEngine, type HybridSearchOptions, type HybridSearchResult } from './search/hybrid-search.js';

// Scheduler
export { TimeSliceScheduler, ReconcileScheduler, type TaskFn, type TaskPriority, type SchedulerOptions } from './scheduler/time-slice.js';

// Utils
export { crc32 } from './utils/crc32.js';
export { createHash, createHashSync } from './utils/hash.js';

// Health check
export { verifyIntegrity } from './engine/health.js';