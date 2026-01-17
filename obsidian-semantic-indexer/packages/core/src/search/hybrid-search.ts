/**
 * Hybrid search combining BM25 and vector search with reciprocal rank fusion
 */

import type { VaultAdapter } from '../formats/types.js';
import { BM25Index, type BM25SearchResult } from './bm25.js';
import { VectorSearchEngine, type VectorSearchResult } from './vector-search.js';

export interface HybridSearchOptions {
  k?: number;
  mode?: 'hybrid' | 'dense' | 'lexical';
  lexicalWeight?: number;
  denseWeight?: number;
  fusionK?: number; // Parameter for RRF
}

export interface HybridSearchResult {
  path: string;
  chunk_id?: string;
  score: number;
  heading?: string;
  offset?: number;
  length?: number;
  snippet?: string;
  matchType: 'hybrid' | 'dense' | 'lexical';
}

export class HybridSearchEngine {
  private vectorSearch: VectorSearchEngine;
  private bm25Index: BM25Index;
  private cache = new Map<string, { embedding: Float32Array; timestamp: number }>();
  private cacheMaxAge = 15 * 60 * 1000; // 15 minutes
  private cacheMaxSize = 256;

  constructor(
    vault: VaultAdapter,
    bm25Index: BM25Index,
    root: string = '.obsidian/plugins/semantic-index'
  ) {
    this.vectorSearch = new VectorSearchEngine(vault, root);
    this.bm25Index = bm25Index;
  }

  async search(
    query: string,
    queryEmbedding: Float32Array,
    options: HybridSearchOptions = {}
  ): Promise<HybridSearchResult[]> {
    const {
      k = 20,
      mode = 'hybrid',
      lexicalWeight = 0.5,
      denseWeight = 0.5,
      fusionK = 60
    } = options;

    // Check cache
    const cacheKey = query;
    const cached = this.cache.get(cacheKey);
    if (cached && Date.now() - cached.timestamp < this.cacheMaxAge) {
      queryEmbedding = cached.embedding;
    } else {
      // Update cache
      this.updateCache(cacheKey, queryEmbedding);
    }

    if (mode === 'lexical') {
      return this.lexicalOnlySearch(query, k);
    }

    if (mode === 'dense') {
      return this.denseOnlySearch(queryEmbedding, k);
    }

    // Hybrid mode
    const [lexicalResults, denseResults] = await Promise.all([
      this.bm25Index.search(query, k * 2),
      this.vectorSearch.search(queryEmbedding, k * 2)
    ]);

    return this.fuseResults(
      lexicalResults,
      denseResults,
      k,
      lexicalWeight,
      denseWeight,
      fusionK
    );
  }

  private async lexicalOnlySearch(query: string, k: number): Promise<HybridSearchResult[]> {
    const results = this.bm25Index.search(query, k);
    
    return results.map(result => ({
      path: result.path,
      score: this.normalizeScore(result.score, 'lexical'),
      matchType: 'lexical' as const,
      snippet: this.generateSnippet(result.path, result.matches)
    }));
  }

  private async denseOnlySearch(queryEmbedding: Float32Array, k: number): Promise<HybridSearchResult[]> {
    const results = await this.vectorSearch.search(queryEmbedding, k);
    
    return results.map(result => ({
      path: result.path,
      chunk_id: result.chunk_id,
      score: this.normalizeScore(result.score, 'dense'),
      heading: result.heading,
      offset: result.offset,
      length: result.length,
      matchType: 'dense' as const
    }));
  }

  private fuseResults(
    lexicalResults: BM25SearchResult[],
    denseResults: VectorSearchResult[],
    k: number,
    lexicalWeight: number,
    denseWeight: number,
    fusionK: number
  ): HybridSearchResult[] {
    const fusedScores = new Map<string, { score: number; result: HybridSearchResult }>();

    // Process lexical results
    lexicalResults.forEach((result, rank) => {
      const key = result.path;
      const rrfScore = 1 / (fusionK + rank + 1);
      
      fusedScores.set(key, {
        score: rrfScore * lexicalWeight,
        result: {
          path: result.path,
          score: 0, // Will be updated
          matchType: 'hybrid',
          snippet: this.generateSnippet(result.path, result.matches)
        }
      });
    });

    // Process dense results
    denseResults.forEach((result, rank) => {
      const key = `${result.path}#${result.chunk_id}`;
      const rrfScore = 1 / (fusionK + rank + 1);
      
      const existing = fusedScores.get(key);
      if (existing) {
        existing.score += rrfScore * denseWeight;
        // Merge result data
        existing.result.chunk_id = result.chunk_id;
        existing.result.heading = result.heading;
        existing.result.offset = result.offset;
        existing.result.length = result.length;
      } else {
        fusedScores.set(key, {
          score: rrfScore * denseWeight,
          result: {
            path: result.path,
            chunk_id: result.chunk_id,
            score: 0, // Will be updated
            heading: result.heading,
            offset: result.offset,
            length: result.length,
            matchType: 'hybrid'
          }
        });
      }
    });

    // Sort by fused score and update final scores
    const sortedResults = Array.from(fusedScores.values())
      .sort((a, b) => b.score - a.score)
      .slice(0, k)
      .map(({ score, result }) => ({
        ...result,
        score
      }));

    return sortedResults;
  }

  private normalizeScore(score: number, type: 'lexical' | 'dense'): number {
    // Normalize scores to [0, 1] range
    if (type === 'dense') {
      // Cosine similarity is already in [-1, 1], map to [0, 1]
      return (score + 1) / 2;
    } else {
      // BM25 scores need empirical normalization
      // Using sigmoid-like function
      return 1 / (1 + Math.exp(-score / 10));
    }
  }

  private generateSnippet(path: string, matches: string[]): string {
    // Placeholder for snippet generation
    // In real implementation, would load content and extract context
    return `...matches found for: ${matches.join(', ')}...`;
  }

  private updateCache(key: string, embedding: Float32Array): void {
    // LRU cache update
    this.cache.set(key, { embedding, timestamp: Date.now() });

    // Evict oldest entries if cache is too large
    if (this.cache.size > this.cacheMaxSize) {
      const entries = Array.from(this.cache.entries())
        .sort((a, b) => a[1].timestamp - b[1].timestamp);
      
      const toRemove = entries.slice(0, entries.length - this.cacheMaxSize);
      toRemove.forEach(([key]) => this.cache.delete(key));
    }
  }

  clearCache(): void {
    this.cache.clear();
  }
}