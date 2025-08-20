/**
 * Crash-safe index writer implementation
 */

import type { Manifest, SegmentRef, VaultAdapter } from '../formats/types.js';
import { SegmentWriter } from '../formats/segment.js';
import { ManifestManager } from '../formats/manifest.js';
import { crc32 } from '../utils/crc32.js';

export interface CommitOptions {
  id: string;
  vectors: Float32Array | Uint16Array;
  metaJsonl: string;
  modelId: string;
  dims: number;
  dtype: 'f32' | 'f16';
  prev?: Manifest;
}

export class IndexWriter {
  private manifestManager: ManifestManager;

  constructor(
    private vault: VaultAdapter,
    private root: string = '.obsidian/plugins/semantic-index'
  ) {
    this.manifestManager = new ManifestManager(vault, root);
  }

  async commitSegment(options: CommitOptions): Promise<Manifest> {
    const { id, vectors, metaJsonl, modelId, dims, dtype, prev } = options;

    // Calculate rows from vectors
    const rows = vectors.length / dims;
    if (!Number.isInteger(rows)) {
      throw new Error('Vector length must be divisible by dims');
    }

    // Stage 1: Write to tmp
    await this.vault.ensureDir(`${this.root}/tmp`);
    
    const segmentData = SegmentWriter.write(
      { dims, rows, dtype, modelId },
      vectors
    );

    const tmpBinPath = `${this.root}/tmp/SEG-${id}.bin`;
    const tmpMetaPath = `${this.root}/tmp/SEG-${id}.jsonl`;

    await Promise.all([
      this.vault.writeBinaryAtomic(tmpBinPath, segmentData),
      this.vault.writeTextAtomic(tmpMetaPath, metaJsonl)
    ]);

    // Stage 2: Publish to segments
    await Promise.all([
      this.vault.ensureDir(`${this.root}/segments`),
      this.vault.ensureDir(`${this.root}/meta`)
    ]);

    const finalBinPath = `segments/${id}.bin`;
    const finalMetaPath = `meta/${id}.jsonl`;

    await Promise.all([
      this.vault.renameAtomic(tmpBinPath, `${this.root}/${finalBinPath}`),
      this.vault.renameAtomic(tmpMetaPath, `${this.root}/${finalMetaPath}`)
    ]);

    // Stage 3: Update manifest
    const crcValue = crc32(segmentData.subarray(0, segmentData.length - 4));
    
    const newSegment: SegmentRef = {
      id,
      rows,
      bin: finalBinPath,
      meta: finalMetaPath,
      crc: crcValue
    };

    const currentManifest = prev || await this.manifestManager.read();
    
    const manifest: Manifest = {
      version: 1,
      created_at: currentManifest?.created_at || new Date().toISOString(),
      model: {
        id: modelId,
        dims,
        dtype
      },
      segments: [...(currentManifest?.segments || []), newSegment],
      stats: {
        rows: (currentManifest?.stats.rows || 0) + rows,
        segments: (currentManifest?.stats.segments || 0) + 1
      }
    };

    // Model compatibility check
    if (currentManifest && (
      currentManifest.model.id !== modelId ||
      currentManifest.model.dims !== dims ||
      currentManifest.model.dtype !== dtype
    )) {
      throw new Error('Model mismatch with existing index');
    }

    await this.manifestManager.write(manifest);

    return manifest;
  }

  async cleanupTmp(): Promise<void> {
    try {
      const tmpFiles = await this.vault.listDir(`${this.root}/tmp`);
      await Promise.all(
        tmpFiles.map(file => this.vault.remove(`${this.root}/tmp/${file}`))
      );
    } catch {
      // Ignore cleanup errors
    }
  }
}