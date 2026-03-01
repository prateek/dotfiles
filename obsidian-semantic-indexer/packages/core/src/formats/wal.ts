/**
 * Write-Ahead Log implementation for crash-safe operations
 */

import type { WALEntry, VaultAdapter } from './types.js';

export class WAL {
  private walPath: string;

  constructor(
    private vault: VaultAdapter,
    private root: string = '.obsidian/plugins/semantic-index'
  ) {
    this.walPath = `${this.root}/wal/tasks.jsonl`;
  }

  async append(entry: WALEntry): Promise<void> {
    await this.vault.ensureDir(`${this.root}/wal`);
    
    const line = JSON.stringify(entry) + '\n';
    const existing = await this.readRaw();
    await this.vault.writeTextAtomic(this.walPath, existing + line);
  }

  async readAll(): Promise<WALEntry[]> {
    try {
      const content = await this.vault.readText(this.walPath);
      return content
        .split('\n')
        .filter(line => line.trim())
        .map(line => JSON.parse(line) as WALEntry);
    } catch {
      return [];
    }
  }

  async getPending(): Promise<Map<string, WALEntry>> {
    const entries = await this.readAll();
    const jobStates = new Map<string, WALEntry>();

    // Process entries in order to get final state of each job
    for (const entry of entries) {
      const existing = jobStates.get(entry.id);
      if (!existing || entry.enq_at! > existing.enq_at!) {
        jobStates.set(entry.id, entry);
      }
    }

    // Filter to only pending/started jobs
    const pending = new Map<string, WALEntry>();
    for (const [id, entry] of jobStates) {
      if (entry.status === 'pending' || entry.status === 'started') {
        pending.set(id, entry);
      }
    }

    return pending;
  }

  async compact(): Promise<void> {
    const entries = await this.readAll();
    const jobStates = new Map<string, WALEntry>();

    // Keep only the final state of each job
    for (const entry of entries) {
      jobStates.set(entry.id, entry);
    }

    // Keep only recent completed and all pending
    const cutoff = Date.now() - 24 * 60 * 60 * 1000; // 24 hours
    const compacted = Array.from(jobStates.values()).filter(
      entry => entry.status === 'pending' || 
               entry.status === 'started' ||
               (entry.done_at && entry.done_at > cutoff)
    );

    const content = compacted.map(e => JSON.stringify(e)).join('\n') + '\n';
    await this.vault.writeTextAtomic(this.walPath, content);
  }

  private async readRaw(): Promise<string> {
    try {
      return await this.vault.readText(this.walPath);
    } catch {
      return '';
    }
  }
}