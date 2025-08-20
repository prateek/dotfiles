/**
 * Obsidian vault adapter implementation
 */

import { type Vault, normalizePath } from 'obsidian';
import type { VaultAdapter } from '@osi/core';

export class ObsidianVaultAdapter implements VaultAdapter {
  constructor(private vault: Vault) {}

  async readBinary(path: string): Promise<Uint8Array> {
    const normalizedPath = normalizePath(path);
    const buffer = await this.vault.readBinary(normalizedPath);
    return new Uint8Array(buffer);
  }

  async writeBinaryAtomic(path: string, data: Uint8Array): Promise<void> {
    const normalizedPath = normalizePath(path);
    await this.ensureDir(this.getParentPath(normalizedPath));
    await this.vault.createBinary(normalizedPath, data);
  }

  async readText(path: string): Promise<string> {
    const normalizedPath = normalizePath(path);
    return await this.vault.read(normalizedPath);
  }

  async writeTextAtomic(path: string, text: string): Promise<void> {
    const normalizedPath = normalizePath(path);
    await this.ensureDir(this.getParentPath(normalizedPath));
    
    // Obsidian's create is atomic for new files, modify for existing
    const exists = await this.exists(normalizedPath);
    if (exists) {
      await this.vault.modify(normalizedPath, text);
    } else {
      await this.vault.create(normalizedPath, text);
    }
  }

  async renameAtomic(from: string, to: string): Promise<void> {
    const normalizedFrom = normalizePath(from);
    const normalizedTo = normalizePath(to);
    await this.ensureDir(this.getParentPath(normalizedTo));
    await this.vault.rename(normalizedFrom, normalizedTo);
  }

  async stat(path: string): Promise<{ mtimeMs: number; size: number } | null> {
    const normalizedPath = normalizePath(path);
    const file = this.vault.getAbstractFileByPath(normalizedPath);
    
    if (!file || file.children !== undefined) {
      return null; // Not a file or doesn't exist
    }

    return {
      mtimeMs: file.stat.mtime,
      size: file.stat.size
    };
  }

  async listDir(path: string): Promise<string[]> {
    const normalizedPath = normalizePath(path);
    const folder = this.vault.getAbstractFileByPath(normalizedPath);
    
    if (!folder || !folder.children) {
      return [];
    }

    return folder.children
      .filter(child => child.children === undefined) // Files only
      .map(file => file.name);
  }

  async ensureDir(path: string): Promise<void> {
    const normalizedPath = normalizePath(path);
    if (!normalizedPath) return;

    const parts = normalizedPath.split('/');
    let currentPath = '';

    for (const part of parts) {
      currentPath = currentPath ? `${currentPath}/${part}` : part;
      
      if (!await this.exists(currentPath)) {
        await this.vault.createFolder(currentPath);
      }
    }
  }

  async exists(path: string): Promise<boolean> {
    const normalizedPath = normalizePath(path);
    return this.vault.getAbstractFileByPath(normalizedPath) !== null;
  }

  async remove(path: string): Promise<void> {
    const normalizedPath = normalizePath(path);
    const file = this.vault.getAbstractFileByPath(normalizedPath);
    
    if (file) {
      await this.vault.delete(file);
    }
  }

  private getParentPath(path: string): string {
    const parts = path.split('/');
    parts.pop();
    return parts.join('/');
  }
}