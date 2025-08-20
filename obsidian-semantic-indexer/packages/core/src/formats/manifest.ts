/**
 * Manifest file format and operations
 */

import type { Manifest, VaultAdapter } from './types.js';

export class ManifestManager {
  constructor(
    private vault: VaultAdapter,
    private root: string = '.obsidian/plugins/semantic-index'
  ) {}

  private get manifestPath(): string {
    return `${this.root}/manifest.json`;
  }

  private get prevManifestPath(): string {
    return `${this.root}/manifest.prev.json`;
  }

  private get tmpManifestPath(): string {
    return `${this.root}/tmp/manifest.tmp`;
  }

  async read(): Promise<Manifest | null> {
    try {
      const content = await this.vault.readText(this.manifestPath);
      return JSON.parse(content) as Manifest;
    } catch {
      // Try previous manifest as fallback
      try {
        const content = await this.vault.readText(this.prevManifestPath);
        return JSON.parse(content) as Manifest;
      } catch {
        return null;
      }
    }
  }

  async write(manifest: Manifest): Promise<void> {
    // Ensure tmp directory exists
    await this.vault.ensureDir(`${this.root}/tmp`);

    // Write to temp file first
    const content = JSON.stringify(manifest, null, 2);
    await this.vault.writeTextAtomic(this.tmpManifestPath, content);

    // Backup current manifest if it exists
    const currentExists = await this.vault.exists(this.manifestPath);
    if (currentExists) {
      await this.vault.renameAtomic(this.manifestPath, this.prevManifestPath);
    }

    // Atomic swap
    await this.vault.renameAtomic(this.tmpManifestPath, this.manifestPath);
  }

  async validate(manifest: Manifest): Promise<{ ok: boolean; errors: string[] }> {
    const errors: string[] = [];

    if (manifest.version !== 1) {
      errors.push(`Unsupported manifest version: ${manifest.version}`);
    }

    if (!manifest.model?.id || !manifest.model?.dims || !manifest.model?.dtype) {
      errors.push('Invalid model configuration');
    }

    if (!Array.isArray(manifest.segments)) {
      errors.push('Invalid segments array');
    }

    // Verify segment files exist
    for (const segment of manifest.segments) {
      const [binExists, metaExists] = await Promise.all([
        this.vault.exists(`${this.root}/${segment.bin}`),
        this.vault.exists(`${this.root}/${segment.meta}`)
      ]);

      if (!binExists) {
        errors.push(`Missing segment binary: ${segment.bin}`);
      }
      if (!metaExists) {
        errors.push(`Missing segment metadata: ${segment.meta}`);
      }
    }

    return {
      ok: errors.length === 0,
      errors
    };
  }
}