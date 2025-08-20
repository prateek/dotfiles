/**
 * Vector search implementation with cosine similarity
 */

import type { Manifest, SegmentMeta, VaultAdapter } from '../formats/types.js';
import { SegmentReader } from '../formats/segment.js';
import { ManifestManager } from '../formats/manifest.js';

export interface VectorSearchResult {
  path: string;
  chunk_id: string;
  score: number;
  heading?: string;
  offset: number;
  length: number;
}

export class VectorSearchEngine {
  private manifestManager: ManifestManager;

  constructor(
    private vault: VaultAdapter,
    private root: string = '.obsidian/plugins/semantic-index'
  ) {
    this.manifestManager = new ManifestManager(vault, root);
  }

  async search(
    queryVector: Float32Array,
    k: number = 20,
    filterPaths?: Set<string>
  ): Promise<VectorSearchResult[]> {
    const manifest = await this.manifestManager.read();
    if (!manifest) {
      return [];
    }

    // Validate query vector dimensions
    if (queryVector.length !== manifest.model.dims) {
      throw new Error(`Query vector dims (${queryVector.length}) doesn't match index dims (${manifest.model.dims})`);
    }

    // Normalize query vector
    const normalizedQuery = this.normalize(queryVector);
    
    const candidates: Array<VectorSearchResult & { segmentId: string; rowIndex: number }> = [];

    // Search across all segments
    for (const segment of manifest.segments) {
      const results = await this.searchSegment(
        segment,
        normalizedQuery,
        manifest.model.dtype,
        filterPaths
      );
      candidates.push(...results);
    }

    // Sort by score descending and return top k
    candidates.sort((a, b) => b.score - a.score);
    
    return candidates.slice(0, k).map(({ segmentId, rowIndex, ...result }) => result);
  }

  private async searchSegment(
    segment: { id: string; bin: string; meta: string; rows: number },
    queryVector: Float32Array,
    dtype: 'f32' | 'f16',
    filterPaths?: Set<string>
  ): Promise<Array<VectorSearchResult & { segmentId: string; rowIndex: number }>> {
    // Load segment data
    const [binData, metaData] = await Promise.all([
      this.vault.readBinary(`${this.root}/${segment.bin}`),
      this.vault.readText(`${this.root}/${segment.meta}`)
    ]);

    const { vectors } = SegmentReader.read(binData);
    const metaLines = metaData.trim().split('\n');
    
    if (metaLines.length !== segment.rows) {
      throw new Error(`Metadata rows (${metaLines.length}) doesn't match segment rows (${segment.rows})`);
    }

    const results: Array<VectorSearchResult & { segmentId: string; rowIndex: number }> = [];

    for (let i = 0; i < segment.rows; i++) {
      const meta: SegmentMeta = JSON.parse(metaLines[i]);
      
      // Apply path filter if provided
      if (filterPaths && !filterPaths.has(meta.path)) {
        continue;
      }

      // Extract vector for this row
      const vectorStart = i * queryVector.length;
      const vectorEnd = vectorStart + queryVector.length;
      
      let vector: Float32Array;
      if (dtype === 'f32') {
        vector = (vectors as Float32Array).slice(vectorStart, vectorEnd);
      } else {
        // Convert f16 to f32 for computation
        const f16Vector = (vectors as Uint16Array).slice(vectorStart, vectorEnd);
        vector = this.f16ToF32(f16Vector);
      }

      // Compute cosine similarity
      const score = this.cosineSimilarity(queryVector, vector);

      results.push({
        path: meta.path,
        chunk_id: meta.chunk_id,
        score,
        heading: meta.heading,
        offset: meta.off,
        length: meta.len,
        segmentId: segment.id,
        rowIndex: i
      });
    }

    return results;
  }

  private normalize(vector: Float32Array): Float32Array {
    const magnitude = Math.sqrt(vector.reduce((sum, val) => sum + val * val, 0));
    if (magnitude === 0) return vector;
    
    const normalized = new Float32Array(vector.length);
    for (let i = 0; i < vector.length; i++) {
      normalized[i] = vector[i] / magnitude;
    }
    return normalized;
  }

  private cosineSimilarity(a: Float32Array, b: Float32Array): number {
    if (a.length !== b.length) {
      throw new Error('Vectors must have same dimensions');
    }

    let dotProduct = 0;
    let magnitudeA = 0;
    let magnitudeB = 0;

    for (let i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      magnitudeA += a[i] * a[i];
      magnitudeB += b[i] * b[i];
    }

    magnitudeA = Math.sqrt(magnitudeA);
    magnitudeB = Math.sqrt(magnitudeB);

    if (magnitudeA === 0 || magnitudeB === 0) {
      return 0;
    }

    return dotProduct / (magnitudeA * magnitudeB);
  }

  private f16ToF32(f16Array: Uint16Array): Float32Array {
    // Simplified float16 to float32 conversion
    const f32Array = new Float32Array(f16Array.length);
    
    for (let i = 0; i < f16Array.length; i++) {
      const h = f16Array[i];
      
      // Extract components
      const sign = (h & 0x8000) >> 15;
      const exponent = (h & 0x7C00) >> 10;
      const mantissa = h & 0x03FF;
      
      if (exponent === 0) {
        // Subnormal or zero
        f32Array[i] = (sign ? -1 : 1) * Math.pow(2, -14) * (mantissa / 1024);
      } else if (exponent === 31) {
        // Inf or NaN
        f32Array[i] = mantissa ? NaN : (sign ? -Infinity : Infinity);
      } else {
        // Normal number
        f32Array[i] = (sign ? -1 : 1) * Math.pow(2, exponent - 15) * (1 + mantissa / 1024);
      }
    }
    
    return f32Array;
  }
}