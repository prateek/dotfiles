/**
 * Status chip component for showing indexing status
 */

import type SemanticIndexPlugin from '../main.js';

export class StatusChip {
  private statusEl: HTMLElement | null = null;
  private updateInterval: number | null = null;

  constructor(private plugin: SemanticIndexPlugin) {
    if (this.plugin.settings.showStatusChip) {
      this.create();
      this.startUpdating();
    }
  }

  private create() {
    // Find search container or create our own container
    const searchContainer = document.querySelector('.workspace-tab-header-container-inner');
    if (!searchContainer) return;

    this.statusEl = searchContainer.createDiv('semantic-index-status-chip');
    this.updateStatus();
  }

  private async updateStatus() {
    if (!this.statusEl) return;

    const stats = this.plugin.searchService.getIndexStats();
    const pending = await this.getPendingCount();

    if (pending > 0) {
      this.statusEl.setText(`Indexing • ${pending} pending`);
      this.statusEl.removeClass('fresh');
      this.statusEl.addClass('stale');
    } else if (stats) {
      const lastUpdate = await this.getLastUpdateTime();
      const timeAgo = this.formatTimeAgo(lastUpdate);
      this.statusEl.setText(`Fresh • ${timeAgo}`);
      this.statusEl.removeClass('stale');
      this.statusEl.addClass('fresh');
    } else {
      this.statusEl.setText('Not indexed');
      this.statusEl.removeClass('fresh');
      this.statusEl.removeClass('stale');
    }

    // Add click handler
    this.statusEl.onclick = () => {
      this.plugin.openAdminModal();
    };
  }

  private async getPendingCount(): Promise<number> {
    try {
      const wal = await this.plugin.vaultAdapter.readText('.obsidian/plugins/semantic-index/wal/tasks.jsonl');
      const lines = wal.split('\n').filter(line => line.trim());
      
      const jobs = new Map<string, any>();
      for (const line of lines) {
        try {
          const entry = JSON.parse(line);
          jobs.set(entry.id, entry);
        } catch {
          // Skip invalid lines
        }
      }

      let pending = 0;
      for (const job of jobs.values()) {
        if (job.status === 'pending' || job.status === 'started') {
          pending++;
        }
      }

      return pending;
    } catch {
      return 0;
    }
  }

  private async getLastUpdateTime(): Promise<number> {
    try {
      const manifest = await this.plugin.vaultAdapter.readText('.obsidian/plugins/semantic-index/manifest.json');
      const parsed = JSON.parse(manifest);
      return new Date(parsed.created_at).getTime();
    } catch {
      return 0;
    }
  }

  private formatTimeAgo(timestamp: number): string {
    if (!timestamp) return 'never';

    const seconds = Math.floor((Date.now() - timestamp) / 1000);
    
    if (seconds < 60) return 'just now';
    if (seconds < 3600) return `${Math.floor(seconds / 60)}m ago`;
    if (seconds < 86400) return `${Math.floor(seconds / 3600)}h ago`;
    return `${Math.floor(seconds / 86400)}d ago`;
  }

  private startUpdating() {
    // Update every 30 seconds
    this.updateInterval = window.setInterval(() => {
      this.updateStatus();
    }, 30000);

    // Also update on certain events
    this.plugin.registerEvent(
      this.plugin.app.vault.on('modify', () => {
        // Debounce updates
        setTimeout(() => this.updateStatus(), 1000);
      })
    );
  }

  destroy() {
    if (this.updateInterval !== null) {
      clearInterval(this.updateInterval);
      this.updateInterval = null;
    }

    if (this.statusEl) {
      this.statusEl.remove();
      this.statusEl = null;
    }
  }
}