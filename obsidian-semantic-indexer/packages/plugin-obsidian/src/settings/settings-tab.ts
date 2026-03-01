/**
 * Settings tab for the plugin
 */

import { App, PluginSettingTab, Setting, Notice } from 'obsidian';
import type SemanticIndexPlugin from '../main.js';

export class SemanticIndexSettingTab extends PluginSettingTab {
  plugin: SemanticIndexPlugin;

  constructor(app: App, plugin: SemanticIndexPlugin) {
    super(app, plugin);
    this.plugin = plugin;
  }

  display(): void {
    const { containerEl } = this;
    containerEl.empty();

    containerEl.createEl('h2', { text: 'Semantic Index Settings' });

    // Model Settings
    containerEl.createEl('h3', { text: 'Model Configuration' });

    new Setting(containerEl)
      .setName('Embedding model')
      .setDesc('Model used for generating embeddings')
      .addDropdown(dropdown => dropdown
        .addOption('Xenova/bge-small-en-v1.5', 'BGE Small English (recommended)')
        .addOption('Xenova/all-MiniLM-L6-v2', 'MiniLM L6 v2')
        .setValue(this.plugin.settings.modelId)
        .onChange(async (value) => {
          // Check if model change requires rebuild
          if (value !== this.plugin.settings.modelId) {
            const rebuild = await this.confirmRebuild();
            if (rebuild) {
              this.plugin.settings.modelId = value;
              await this.plugin.saveSettings();
              await this.plugin.rebuildIndex();
            }
          }
        }));

    new Setting(containerEl)
      .setName('Storage data type')
      .setDesc('Float16 uses less memory but may have slightly lower quality')
      .addDropdown(dropdown => dropdown
        .addOption('f32', 'Float32 (higher quality)')
        .addOption('f16', 'Float16 (lower memory)')
        .setValue(this.plugin.settings.storageDtype)
        .onChange(async (value: 'f32' | 'f16') => {
          this.plugin.settings.storageDtype = value;
          await this.plugin.saveSettings();
        }));

    // Performance Settings
    containerEl.createEl('h3', { text: 'Performance' });

    new Setting(containerEl)
      .setName('Max concurrent chunks')
      .setDesc('Number of chunks to process in parallel')
      .addSlider(slider => slider
        .setLimits(1, 32, 1)
        .setValue(this.plugin.settings.maxConcurrentChunks)
        .setDynamicTooltip()
        .onChange(async (value) => {
          this.plugin.settings.maxConcurrentChunks = value;
          await this.plugin.saveSettings();
        }));

    new Setting(containerEl)
      .setName('Reconcile interval')
      .setDesc('How often to check for file changes (minutes)')
      .addSlider(slider => slider
        .setLimits(5, 60, 5)
        .setValue(this.plugin.settings.reconcileIntervalMinutes)
        .setDynamicTooltip()
        .onChange(async (value) => {
          this.plugin.settings.reconcileIntervalMinutes = value;
          await this.plugin.saveSettings();
        }));

    new Setting(containerEl)
      .setName('Enable ANN acceleration')
      .setDesc('Use approximate nearest neighbor search for faster queries')
      .addToggle(toggle => toggle
        .setValue(this.plugin.settings.enableANN)
        .onChange(async (value) => {
          this.plugin.settings.enableANN = value;
          await this.plugin.saveSettings();
        }));

    // Search Settings
    containerEl.createEl('h3', { text: 'Search' });

    new Setting(containerEl)
      .setName('Default search mode')
      .setDesc('Search mode to use by default')
      .addDropdown(dropdown => dropdown
        .addOption('hybrid', 'Hybrid (recommended)')
        .addOption('dense', 'Dense only')
        .addOption('lexical', 'Lexical only')
        .setValue(this.plugin.settings.defaultSearchMode)
        .onChange(async (value: 'hybrid' | 'dense' | 'lexical') => {
          this.plugin.settings.defaultSearchMode = value;
          await this.plugin.saveSettings();
        }));

    new Setting(containerEl)
      .setName('Lexical weight')
      .setDesc('Weight for lexical search in hybrid mode')
      .addSlider(slider => slider
        .setLimits(0, 1, 0.1)
        .setValue(this.plugin.settings.lexicalWeight)
        .setDynamicTooltip()
        .onChange(async (value) => {
          this.plugin.settings.lexicalWeight = value;
          this.plugin.settings.denseWeight = 1 - value;
          await this.plugin.saveSettings();
        }));

    new Setting(containerEl)
      .setName('Search results count')
      .setDesc('Number of results to show')
      .addSlider(slider => slider
        .setLimits(5, 50, 5)
        .setValue(this.plugin.settings.searchResultsCount)
        .setDynamicTooltip()
        .onChange(async (value) => {
          this.plugin.settings.searchResultsCount = value;
          await this.plugin.saveSettings();
        }));

    // Chunking Settings
    containerEl.createEl('h3', { text: 'Chunking' });

    new Setting(containerEl)
      .setName('Chunk size')
      .setDesc('Target chunk size in tokens')
      .addText(text => text
        .setPlaceholder('200-300')
        .setValue(`${this.plugin.settings.chunkMinTokens}-${this.plugin.settings.chunkMaxTokens}`)
        .onChange(async (value) => {
          const match = value.match(/(\d+)-(\d+)/);
          if (match) {
            this.plugin.settings.chunkMinTokens = parseInt(match[1]);
            this.plugin.settings.chunkMaxTokens = parseInt(match[2]);
            await this.plugin.saveSettings();
          }
        }));

    new Setting(containerEl)
      .setName('Chunk overlap')
      .setDesc('Number of tokens to overlap between chunks')
      .addSlider(slider => slider
        .setLimits(0, 100, 10)
        .setValue(this.plugin.settings.chunkOverlapTokens)
        .setDynamicTooltip()
        .onChange(async (value) => {
          this.plugin.settings.chunkOverlapTokens = value;
          await this.plugin.saveSettings();
        }));

    // Ignore Patterns
    containerEl.createEl('h3', { text: 'Ignore Patterns' });

    new Setting(containerEl)
      .setName('Ignore globs')
      .setDesc('File patterns to exclude from indexing (one per line)')
      .addTextArea(text => text
        .setPlaceholder('**/.obsidian/**\n**/*.png')
        .setValue(this.plugin.settings.ignoreGlobs.join('\n'))
        .onChange(async (value) => {
          this.plugin.settings.ignoreGlobs = value.split('\n').filter(line => line.trim());
          await this.plugin.saveSettings();
        }));

    // UI Settings
    containerEl.createEl('h3', { text: 'User Interface' });

    new Setting(containerEl)
      .setName('Show status chip')
      .setDesc('Show indexing status in search panel')
      .addToggle(toggle => toggle
        .setValue(this.plugin.settings.showStatusChip)
        .onChange(async (value) => {
          this.plugin.settings.showStatusChip = value;
          await this.plugin.saveSettings();
        }));

    new Setting(containerEl)
      .setName('Debug mode')
      .setDesc('Enable debug logging and metrics')
      .addToggle(toggle => toggle
        .setValue(this.plugin.settings.debugMode)
        .onChange(async (value) => {
          this.plugin.settings.debugMode = value;
          await this.plugin.saveSettings();
        }));

    // Actions
    containerEl.createEl('h3', { text: 'Maintenance' });

    new Setting(containerEl)
      .setName('Rebuild index')
      .setDesc('Delete and rebuild the entire index')
      .addButton(button => button
        .setButtonText('Rebuild')
        .setWarning()
        .onClick(async () => {
          await this.plugin.rebuildIndex();
        }));

    new Setting(containerEl)
      .setName('Verify integrity')
      .setDesc('Check index health and find issues')
      .addButton(button => button
        .setButtonText('Verify')
        .onClick(async () => {
          new Notice('Verifying index integrity...');
          const result = await this.plugin.indexingService.verifyIntegrity();
          if (result.ok) {
            new Notice('Index is healthy!');
          } else {
            new Notice(`Found ${result.issues.length} issues. Check admin panel.`);
          }
        }));
  }

  private async confirmRebuild(): Promise<boolean> {
    return new Promise((resolve) => {
      const notice = new Notice('', 0);
      const container = notice.noticeEl;
      container.empty();
      
      container.createEl('div', { text: 'Changing model requires rebuilding the index. Continue?' });
      
      const buttonContainer = container.createEl('div', { cls: 'mod-button-container' });
      
      buttonContainer.createEl('button', { text: 'Cancel', cls: 'mod-cta' })
        .addEventListener('click', () => {
          notice.hide();
          resolve(false);
        });
      
      buttonContainer.createEl('button', { text: 'Rebuild', cls: 'mod-warning' })
        .addEventListener('click', () => {
          notice.hide();
          resolve(true);
        });
    });
  }
}