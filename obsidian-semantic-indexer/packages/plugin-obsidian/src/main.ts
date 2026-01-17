/**
 * Obsidian Semantic Indexer Plugin
 */

import { Plugin, Notice, type MarkdownView } from 'obsidian';
import { ObsidianVaultAdapter } from './adapters/obsidian-vault-adapter.js';
import { SemanticIndexSettings, DEFAULT_SETTINGS } from './settings/settings.js';
import { SemanticIndexSettingTab } from './settings/settings-tab.js';
import { IndexingService } from './services/indexing-service.js';
import { SearchService } from './services/search-service.js';
import { SearchModal } from './components/search-modal.js';
import { AdminModal } from './components/admin-modal.js';
import { StatusChip } from './components/status-chip.js';
import type { VaultAdapter } from '@osi/core';

export default class SemanticIndexPlugin extends Plugin {
  settings: SemanticIndexSettings;
  vaultAdapter: VaultAdapter;
  indexingService: IndexingService;
  searchService: SearchService;
  statusChip: StatusChip;

  async onload() {
    console.log('Loading Semantic Index plugin');

    // Load settings
    await this.loadSettings();

    // Initialize adapter
    this.vaultAdapter = new ObsidianVaultAdapter(this.app.vault);

    // Initialize services
    this.indexingService = new IndexingService(
      this.vaultAdapter,
      this.app.vault,
      this.settings
    );

    this.searchService = new SearchService(
      this.vaultAdapter,
      this.indexingService,
      this.settings
    );

    // Add settings tab
    this.addSettingTab(new SemanticIndexSettingTab(this.app, this));

    // Add search command
    this.addCommand({
      id: 'semantic-search',
      name: 'Semantic Search',
      callback: () => this.openSearchModal()
    });

    // Add ribbon icon
    this.addRibbonIcon('search', 'Semantic Search', () => {
      this.openSearchModal();
    });

    // Initialize status chip
    this.statusChip = new StatusChip(this);
    this.registerDomEvent(document, 'click', (evt) => {
      if ((evt.target as HTMLElement).matches('.semantic-index-status-chip')) {
        this.openAdminModal();
      }
    });

    // Start background services
    await this.startServices();

    // Register for file changes
    this.registerEvent(
      this.app.vault.on('create', (file) => {
        if (file.extension === 'md') {
          this.indexingService.enqueueFile(file.path);
        }
      })
    );

    this.registerEvent(
      this.app.vault.on('modify', (file) => {
        if (file.extension === 'md') {
          this.indexingService.enqueueFile(file.path);
        }
      })
    );

    this.registerEvent(
      this.app.vault.on('delete', (file) => {
        if (file.extension === 'md') {
          this.indexingService.removeFile(file.path);
        }
      })
    );

    this.registerEvent(
      this.app.vault.on('rename', (file, oldPath) => {
        if (file.extension === 'md') {
          this.indexingService.handleRename(oldPath, file.path);
        }
      })
    );
  }

  async onunload() {
    console.log('Unloading Semantic Index plugin');
    
    // Stop services
    await this.stopServices();
    
    // Clean up UI
    this.statusChip?.destroy();
  }

  async loadSettings() {
    this.settings = Object.assign({}, DEFAULT_SETTINGS, await this.loadData());
  }

  async saveSettings() {
    await this.saveData(this.settings);
    
    // Update services with new settings
    this.indexingService.updateSettings(this.settings);
    this.searchService.updateSettings(this.settings);
  }

  private async startServices() {
    try {
      await this.indexingService.start();
      await this.searchService.start();
      
      // Schedule initial reconciliation
      setTimeout(() => {
        this.indexingService.reconcile();
      }, 5000);
      
    } catch (error) {
      console.error('Failed to start services:', error);
      new Notice('Semantic Index: Failed to start indexing service');
    }
  }

  private async stopServices() {
    await this.indexingService.stop();
    await this.searchService.stop();
  }

  private openSearchModal() {
    new SearchModal(this.app, this.searchService, this.settings).open();
  }

  private openAdminModal() {
    new AdminModal(this.app, this).open();
  }

  async rebuildIndex() {
    const confirmed = await this.confirmDialog(
      'Rebuild Index',
      'This will delete the current index and rebuild it from scratch. Continue?'
    );

    if (confirmed) {
      new Notice('Rebuilding index...');
      await this.indexingService.rebuild();
    }
  }

  private async confirmDialog(title: string, message: string): Promise<boolean> {
    return new Promise((resolve) => {
      const modal = this.app.workspace.activeWindow.createEl('div', { cls: 'modal' });
      const backdrop = this.app.workspace.activeWindow.createEl('div', { cls: 'modal-bg' });
      
      modal.createEl('h2', { text: title });
      modal.createEl('p', { text: message });
      
      const buttonContainer = modal.createEl('div', { cls: 'modal-button-container' });
      
      buttonContainer.createEl('button', { text: 'Cancel' })
        .addEventListener('click', () => {
          modal.remove();
          backdrop.remove();
          resolve(false);
        });
      
      buttonContainer.createEl('button', { text: 'Confirm', cls: 'mod-cta' })
        .addEventListener('click', () => {
          modal.remove();
          backdrop.remove();
          resolve(true);
        });
      
      backdrop.addEventListener('click', () => {
        modal.remove();
        backdrop.remove();
        resolve(false);
      });
    });
  }
}