/**
 * Core data format types for OSI v1
 */

export interface Manifest {
  version: 1;
  created_at: string;
  model: {
    id: string;
    dims: number;
    dtype: 'f32' | 'f16';
  };
  segments: SegmentRef[];
  stats: {
    rows: number;
    segments: number;
  };
}

export interface SegmentRef {
  id: string;
  rows: number;
  bin: string;
  meta: string;
  crc: number;
}

export interface SegmentMeta {
  path: string;
  chunk_id: string;
  off: number;
  len: number;
  hash: string;
  heading?: string;
}

export interface WALEntry {
  id: string;
  path?: string;
  status: 'pending' | 'started' | 'done' | 'failed';
  hash?: string;
  enq_at?: number;
  done_at?: number;
  err?: string;
}

export interface LedgerEntry {
  mtimeMs: number;
  size: number;
  lastHash: string;
  lastIndexedAt: number;
}

export type Ledger = Record<string, LedgerEntry>;

export interface VaultAdapter {
  readBinary(path: string): Promise<Uint8Array>;
  writeBinaryAtomic(path: string, data: Uint8Array): Promise<void>;
  readText(path: string): Promise<string>;
  writeTextAtomic(path: string, text: string): Promise<void>;
  renameAtomic(from: string, to: string): Promise<void>;
  stat(path: string): Promise<{ mtimeMs: number; size: number } | null>;
  listDir(path: string): Promise<string[]>;
  ensureDir(path: string): Promise<void>;
  exists(path: string): Promise<boolean>;
  remove(path: string): Promise<void>;
}

export const DTYPE_SIZES = {
  f32: 4,
  f16: 2
} as const;

export const INDEX_VERSION = 1;