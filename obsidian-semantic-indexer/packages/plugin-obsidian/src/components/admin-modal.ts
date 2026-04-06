/**
 * Admin modal for index management
 */

import { App, Modal, Setting, Notice } from 'obsidian';
import type SemanticIndexPlugin from '../main.js';
import { verifyIntegrity, type IntegrityCheckResult } from '@osi/core';

export class AdminModal extends Modal {
  private plugin: SemanticIndexPlugin;
  private statsEl: HTMLElement;
  private issuesEl: HTMLElement;

  constructor(app: App, plugin: SemanticIndexPlugin) {
    super(app);
    this.plugin = plugin;
  }

  async onOpen() {
    const { contentEl } = this;
    contentEl.empty();
    contentEl.addClass('semantic-index-admin-modal');

    contentEl.createEl('h2', { text: 'Semantic Index Admin' });

    // Snapshot Stats Section
    const snapshotSection = contentEl.createDiv('admin-section');
    snapshotSection.createEl('h3', { text: 'Index Snapshot' });
    this.statsEl = snapshotSection.createDiv('admin-stats');
    await this.updateStats();

    // Health Check Section
    const healthSection = contentEl.createDiv('admin-section');
    healthSection.createEl('h3', { text: 'Health Status' });
    this.issuesEl = healthSection.createDiv('admin-issues');
    
    // Actions Section
    const actionsSection = contentEl.createDiv('admin-section');
    actionsSection.createEl('h3', { text: 'Maintenance Actions' });
    
    const actionsContainer = actionsSection.createDiv('admin-actions');

    // Verify Integrity Button
    new Setting(actionsContainer)
      .setName('Verify Integrity')
      .setDesc('Check index health and find issues')
      .addButton(button => button
        .setButtonText('Verify')
        .onClick(async () => {
          button.setDisabled(true);
          await this.verifyIntegrity();
          button.setDisabled(false);
        }));

    // Force Reconcile Button
    new Setting(actionsContainer)
      .setName('Force Reconcile')
      .setDesc('Check all files for changes and reindex if needed')
      .addButton(button => button
        .setButtonText('Reconcile')
        .onClick(async () => {
          button.setDisabled(true);
          new Notice('Starting reconciliation...');
          await this.plugin.indexingService.reconcile();
          new Notice('Reconciliation complete');
          button.setDisabled(false);
        }));

    // Rebuild Index Button
    new Setting(actionsContainer)
      .setName('Rebuild Index')
      .setDesc('Delete and rebuild the entire index from scratch')
      .addButton(button => button
        .setButtonText('Rebuild')
        .setWarning()
        .onClick(async () => {
          await this.plugin.rebuildIndex();
          this.close();
        }));

    // Compact Segments Button
    new Setting(actionsContainer)
      .setName('Compact Segments')
      .setDesc('Merge segments and remove deleted entries')
      .addButton(button => button
        .setButtonText('Compact')
        .onClick(async () => {
          button.setDisabled(true);
          new Notice('Segment compaction not yet implemented');
          button.setDisabled(false);
        }));

    // Export Debug Bundle Button
    new Setting(actionsSection)
      .setName('Export Debug Bundle')
      .setDesc('Export diagnostics for troubleshooting')
      .addButton(button => button
        .setButtonText('Export')
        .onClick(async () => {
          await this.exportDebugBundle();
        }));

    // Metrics Section (if debug mode)
    if (this.plugin.settings.debugMode) {
      const metricsSection = contentEl.createDiv('admin-section');
      metricsSection.createEl('h3', { text: 'Performance Metrics' });
      const metricsEl = metricsSection.createDiv('admin-metrics');
      await this.updateMetrics(metricsEl);
    }
  }

  onClose() {
    const { contentEl } = this;
    contentEl.empty();
  }

  private async updateStats() {
    this.statsEl.empty();

    const manifest = this.plugin.indexingService.getManifest();
    const searchStats = this.plugin.searchService.getIndexStats();

    if (!manifest) {
      this.statsEl.createDiv('admin-stat').setText('No index found');
      return;
    }

    // Model info
    const modelStat = this.statsEl.createDiv('admin-stat');
    modelStat.createDiv('admin-stat-label').setText('Model');
    modelStat.createDiv('admin-stat-value').setText(manifest.model.id.split('/').pop() || 'Unknown');

    // Dimensions
    const dimsStat = this.statsEl.createDiv('admin-stat');
    dimsStat.createDiv('admin-stat-label').setText('Dimensions');
    dimsStat.createDiv('admin-stat-value').setText(String(manifest.model.dims));

    // Segments
    const segmentsStat = this.statsEl.createDiv('admin-stat');
    segmentsStat.createDiv('admin-stat-label').setText('Segments');
    segmentsStat.createDiv('admin-stat-value').setText(String(manifest.stats.segments));

    // Total chunks
    const chunksStat = this.statsEl.createDiv('admin-stat');
    chunksStat.createDiv('admin-stat-label').setText('Total Chunks');
    chunksStat.createDiv('admin-stat-value').setText(String(manifest.stats.rows));

    // Documents
    if (searchStats) {
      const docsStat = this.statsEl.createDiv('admin-stat');
      docsStat.createDiv('admin-stat-label').setText('Documents');
      docsStat.createDiv('admin-stat-value').setText(String(searchStats.documents));
    }

    // Created date
    const createdStat = this.statsEl.createDiv('admin-stat');
    createdStat.createDiv('admin-stat-label').setText('Created');
    createdStat.createDiv('admin-stat-value').setText(
      new Date(manifest.created_at).toLocaleDateString()
    );
  }

  private async verifyIntegrity() {
    this.issuesEl.empty();
    this.issuesEl.setText('Verifying...');

    try {
      const result = await this.plugin.indexingService.verifyIntegrity();
      this.displayIntegrityResult(result);
    } catch (error) {
      this.issuesEl.empty();
      this.issuesEl.addClass('error');
      this.issuesEl.setText(`Verification failed: ${error}`);
    }
  }

  private displayIntegrityResult(result: IntegrityCheckResult) {
    this.issuesEl.empty();
    this.issuesEl.removeClass('error');

    if (result.ok) {
      this.issuesEl.addClass('success');
      this.issuesEl.setText('✓ Index is healthy');
    } else {
      this.issuesEl.addClass('error');
      const header = this.issuesEl.createDiv();
      header.setText(`Found ${result.issues.length} issues:`);
      
      const list = this.issuesEl.createEl('ul');
      for (const issue of result.issues.slice(0, 10)) {
        list.createEl('li').setText(issue);
      }
      
      if (result.issues.length > 10) {
        this.issuesEl.createDiv().setText(`... and ${result.issues.length - 10} more`);
      }
    }

    if (result.orphans.length > 0) {
      const orphansDiv = this.issuesEl.createDiv('admin-orphans');
      orphansDiv.setText(`${result.orphans.length} orphaned files found`);
    }
  }

  private async updateMetrics(container: HTMLElement) {
    // Get scheduler metrics
    const metrics = this.plugin.indexingService.scheduler.getMetrics();
    
    container.createDiv().setText(`Tasks completed: ${metrics.tasksCompleted}`);
    container.createDiv().setText(`Average slice time: ${metrics.avgSliceTime.toFixed(2)}ms`);
    container.createDiv().setText(`GC pauses detected: ${metrics.gcPauses}`);
    
    const queueInfo = container.createDiv();
    queueInfo.setText(
      `Queue lengths - High: ${metrics.queueLengths.high}, ` +
      `Normal: ${metrics.queueLengths.normal}, ` +
      `Low: ${metrics.queueLengths.low}`
    );

    // Memory usage
    if ('memory' in performance) {
      const memory = (performance as any).memory;
      const usedMB = (memory.usedJSHeapSize / 1024 / 1024).toFixed(2);
      const limitMB = (memory.jsHeapSizeLimit / 1024 / 1024).toFixed(2);
      container.createDiv().setText(`Memory: ${usedMB}MB / ${limitMB}MB`);
    }
  }

  private async exportDebugBundle() {
    new Notice('Preparing debug bundle...');

    try {
      const bundle: any = {
        timestamp: new Date().toISOString(),
        version: this.plugin.manifest.version,
        settings: this.sanitizeSettings(this.plugin.settings),
        stats: {
          manifest: this.plugin.indexingService.getManifest(),
          searchStats: this.plugin.searchService.getIndexStats()
        },
        integrity: await this.plugin.indexingService.verifyIntegrity(),
        system: {
          platform: navigator.platform,
          userAgent: navigator.userAgent,
          obsidianVersion: (this.app as any).version
        }
      };

      // Add recent WAL entries
      try {
        const wal = await this.plugin.vaultAdapter.readText('.obsidian/plugins/semantic-index/wal/tasks.jsonl');
        const lines = wal.split('\n').filter(l => l).slice(-100); // Last 100 entries
        bundle.recentWAL = lines.map(l => {
          try {
            return JSON.parse(l);
          } catch {
            return { error: 'Invalid JSON' };
          }
        });
      } catch {
        bundle.recentWAL = [];
      }

      // Create and download file
      const blob = new Blob([JSON.stringify(bundle, null, 2)], { type: 'application/json' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `osi-debug-${Date.now()}.json`;
      a.click();
      URL.revokeObjectURL(url);

      new Notice('Debug bundle exported');
    } catch (error) {
      new Notice(`Failed to export debug bundle: ${error}`);
    }
  }

  private sanitizeSettings(settings: any): any {
    const sanitized = { ...settings };
    // Remove any sensitive paths or patterns
    if (sanitized.ignoreGlobs) {
      sanitized.ignoreGlobs = sanitized.ignoreGlobs.map((glob: string) => 
        glob.replace(/\/Users\/[^/]+/, '/Users/***')
          .replace(/\/home\/[^/]+/, '/home/***')
          .replace(/C:\\Users\\[^\\]+/, 'C:\\Users\\***')
      );
    }
    return sanitized;
  }
}