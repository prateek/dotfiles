/**
 * Ledger for tracking indexed file states
 */

import type { Ledger, LedgerEntry, VaultAdapter } from './types.js';

export class LedgerManager {
  private ledgerPath: string;

  constructor(
    private vault: VaultAdapter,
    private root: string = '.obsidian/plugins/semantic-index'
  ) {
    this.ledgerPath = `${this.root}/ledger.json`;
  }

  async read(): Promise<Ledger> {
    try {
      const content = await this.vault.readText(this.ledgerPath);
      return JSON.parse(content) as Ledger;
    } catch {
      return {};
    }
  }

  async write(ledger: Ledger): Promise<void> {
    const content = JSON.stringify(ledger, null, 2);
    await this.vault.writeTextAtomic(this.ledgerPath, content);
  }

  async update(path: string, entry: LedgerEntry): Promise<void> {
    const ledger = await this.read();
    ledger[path] = entry;
    await this.write(ledger);
  }

  async remove(path: string): Promise<void> {
    const ledger = await this.read();
    delete ledger[path];
    await this.write(ledger);
  }

  async needsReindex(path: string, stats: { mtimeMs: number; size: number }, hash: string): Promise<boolean> {
    const ledger = await this.read();
    const entry = ledger[path];

    if (!entry) {
      return true; // Not indexed yet
    }

    // Check if file has been modified
    if (entry.mtimeMs !== stats.mtimeMs || entry.size !== stats.size) {
      return true;
    }

    // Check content hash if available
    if (hash && entry.lastHash !== hash) {
      return true;
    }

    return false;
  }

  async findRenames(currentHash: string, currentPath: string): Promise<string[]> {
    const ledger = await this.read();
    const renames: string[] = [];

    for (const [path, entry] of Object.entries(ledger)) {
      if (path !== currentPath && entry.lastHash === currentHash) {
        renames.push(path);
      }
    }

    return renames;
  }
}