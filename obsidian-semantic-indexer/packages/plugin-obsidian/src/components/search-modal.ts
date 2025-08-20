/**
 * Search modal component
 */

import { App, Modal, Setting, Notice, type TFile } from 'obsidian';
import type { SearchService, SearchResult } from '../services/search-service.js';
import type { SemanticIndexSettings } from '../settings/settings.js';

export class SearchModal extends Modal {
  private results: SearchResult[] = [];
  private searchInput: HTMLInputElement;
  private resultsContainer: HTMLDivElement;
  private isSearching = false;

  constructor(
    app: App,
    private searchService: SearchService,
    private settings: SemanticIndexSettings
  ) {
    super(app);
  }

  onOpen() {
    const { contentEl } = this;
    contentEl.empty();
    contentEl.addClass('semantic-search-modal');

    // Title
    contentEl.createEl('h2', { text: 'Semantic Search' });

    // Search input
    const searchContainer = contentEl.createDiv('search-input-container');
    
    this.searchInput = searchContainer.createEl('input', {
      type: 'text',
      placeholder: 'Search your vault semantically...',
      cls: 'semantic-search-input'
    });

    this.searchInput.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' && !this.isSearching) {
        this.performSearch();
      }
    });

    // Search button
    const searchButton = searchContainer.createEl('button', {
      text: 'Search',
      cls: 'mod-cta'
    });
    searchButton.addEventListener('click', () => this.performSearch());

    // Mode selector
    const modeContainer = contentEl.createDiv('search-mode-container');
    new Setting(modeContainer)
      .setName('Search mode')
      .addDropdown(dropdown => dropdown
        .addOption('hybrid', 'Hybrid')
        .addOption('dense', 'Semantic only')
        .addOption('lexical', 'Keyword only')
        .setValue(this.settings.defaultSearchMode)
        .onChange(value => {
          this.settings.defaultSearchMode = value as any;
        }));

    // Results container
    this.resultsContainer = contentEl.createDiv('search-results-container');

    // Focus search input
    this.searchInput.focus();
  }

  onClose() {
    const { contentEl } = this;
    contentEl.empty();
  }

  private async performSearch() {
    const query = this.searchInput.value.trim();
    if (!query) return;

    if (!this.searchService.isIndexReady()) {
      new Notice('Search index is not ready yet. Please wait...');
      return;
    }

    this.isSearching = true;
    this.resultsContainer.empty();
    this.resultsContainer.createDiv('search-loading').setText('Searching...');

    try {
      const startTime = performance.now();
      this.results = await this.searchService.search(query);
      const elapsed = performance.now() - startTime;

      this.displayResults(elapsed);
    } catch (error) {
      console.error('Search failed:', error);
      new Notice('Search failed: ' + error);
      this.resultsContainer.empty();
      this.resultsContainer.createDiv('search-error').setText('Search failed. Please try again.');
    } finally {
      this.isSearching = false;
    }
  }

  private displayResults(elapsed: number) {
    this.resultsContainer.empty();

    // Stats
    const stats = this.resultsContainer.createDiv('search-stats');
    stats.setText(`Found ${this.results.length} results in ${elapsed.toFixed(0)}ms`);

    // Results
    const resultsList = this.resultsContainer.createDiv('search-results-list');

    for (const result of this.results) {
      const resultEl = resultsList.createDiv('search-result-item');
      
      // Title with path
      const titleEl = resultEl.createDiv('search-result-title');
      const titleLink = titleEl.createEl('a', {
        text: this.getFileName(result.path),
        cls: 'search-result-file-link'
      });
      
      titleLink.addEventListener('click', (e) => {
        e.preventDefault();
        this.openFile(result.path);
      });

      // Path
      const pathEl = resultEl.createDiv('search-result-path');
      pathEl.setText(result.path);

      // Score and match type
      const metaEl = resultEl.createDiv('search-result-meta');
      metaEl.setText(`Score: ${result.score.toFixed(3)} | Type: ${result.matchType}`);

      // Snippet
      if (result.snippet) {
        const snippetEl = resultEl.createDiv('search-result-snippet');
        snippetEl.setText(result.snippet);
      }

      // Heading
      if (result.heading) {
        const headingEl = resultEl.createDiv('search-result-heading');
        headingEl.setText(`Under: ${result.heading}`);
      }
    }

    if (this.results.length === 0) {
      resultsList.createDiv('search-no-results').setText('No results found');
    }
  }

  private getFileName(path: string): string {
    const parts = path.split('/');
    const fileName = parts[parts.length - 1];
    return fileName.replace(/\.md$/, '');
  }

  private async openFile(path: string) {
    const file = this.app.vault.getAbstractFileByPath(path);
    if (file instanceof TFile) {
      await this.app.workspace.getLeaf().openFile(file);
      this.close();
    } else {
      new Notice(`File not found: ${path}`);
    }
  }
}