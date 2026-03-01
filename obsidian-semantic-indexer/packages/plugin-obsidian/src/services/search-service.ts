/**
 * Search service for querying the semantic index
 */

import { type VaultAdapter, HybridSearchEngine, type HybridSearchResult } from '@osi/core';
import type { SemanticIndexSettings } from '../settings/settings.js';
import type { IndexingService } from './indexing-service.js';
import { EmbeddingWorkerManager } from '../workers/embedding-worker-manager.js';

export interface SearchResult extends HybridSearchResult {
  content?: string;
}

export class SearchService {
  private hybridSearch: HybridSearchEngine | null = null;
  private workerManager: EmbeddingWorkerManager;
  private isReady = false;

  constructor(
    private vaultAdapter: VaultAdapter,
    private indexingService: IndexingService,
    private settings: SemanticIndexSettings
  ) {
    this.workerManager = new EmbeddingWorkerManager(settings);
  }

  async start(): Promise<void> {
    await this.workerManager.start();
    this.updateSearchEngine();
    this.isReady = true;
  }

  async stop(): Promise<void> {
    this.isReady = false;
    await this.workerManager.stop();
  }

  updateSettings(settings: SemanticIndexSettings): void {
    this.settings = settings;
    this.workerManager.updateSettings(settings);
  }

  async search(query: string): Promise<SearchResult[]> {
    if (!this.isReady) {
      throw new Error('Search service not ready');
    }

    // Update search engine if needed
    this.updateSearchEngine();

    if (!this.hybridSearch) {
      // No index yet, return empty results
      return [];
    }

    // Generate query embedding
    const { vectors, dims } = await this.workerManager.embedBatch([query]);
    const queryEmbedding = vectors.slice(0, dims);

    // Perform search
    const results = await this.hybridSearch.search(
      query,
      queryEmbedding,
      {
        k: this.settings.searchResultsCount,
        mode: this.settings.defaultSearchMode,
        lexicalWeight: this.settings.lexicalWeight,
        denseWeight: this.settings.denseWeight
      }
    );

    // Load content snippets
    const enrichedResults: SearchResult[] = [];
    
    for (const result of results) {
      const enriched: SearchResult = { ...result };
      
      // Load snippet content if we have offset/length
      if (result.offset !== undefined && result.length !== undefined) {
        try {
          const content = await this.vaultAdapter.readText(result.path);
          const decoder = new TextDecoder();
          const encoder = new TextEncoder();
          
          // Extract snippet around the match
          const fullBytes = encoder.encode(content);
          const start = Math.max(0, result.offset - 100);
          const end = Math.min(fullBytes.length, result.offset + result.length + 100);
          
          const snippetBytes = fullBytes.slice(start, end);
          let snippet = decoder.decode(snippetBytes);
          
          // Clean up snippet
          if (start > 0) snippet = '...' + snippet.trimStart();
          if (end < fullBytes.length) snippet = snippet.trimEnd() + '...';
          
          enriched.snippet = snippet;
          enriched.content = snippet;
        } catch (error) {
          console.error(`Failed to load snippet for ${result.path}:`, error);
        }
      }
      
      enrichedResults.push(enriched);
    }

    return enrichedResults;
  }

  async searchWithFilters(
    query: string,
    filters: {
      paths?: string[];
      folders?: string[];
      tags?: string[];
      dateFrom?: Date;
      dateTo?: Date;
    }
  ): Promise<SearchResult[]> {
    // Get base results
    const results = await this.search(query);
    
    // Apply filters
    return results.filter(result => {
      // Path filter
      if (filters.paths && !filters.paths.includes(result.path)) {
        return false;
      }
      
      // Folder filter
      if (filters.folders) {
        const matchesFolder = filters.folders.some(folder => 
          result.path.startsWith(folder + '/')
        );
        if (!matchesFolder) return false;
      }
      
      // Tag filter would require parsing frontmatter
      // Date filter would require stat info
      // These can be implemented later
      
      return true;
    });
  }

  private updateSearchEngine(): void {
    const manifest = this.indexingService.getManifest();
    const bm25Index = this.indexingService.getBM25Index();
    
    if (manifest && bm25Index) {
      this.hybridSearch = new HybridSearchEngine(
        this.vaultAdapter,
        bm25Index
      );
    }
  }

  isIndexReady(): boolean {
    return this.isReady && this.hybridSearch !== null;
  }

  getIndexStats(): { documents: number; chunks: number } | null {
    const manifest = this.indexingService.getManifest();
    if (!manifest) return null;
    
    return {
      documents: this.indexingService.getBM25Index().search('', 0).length,
      chunks: manifest.stats.rows
    };
  }
}