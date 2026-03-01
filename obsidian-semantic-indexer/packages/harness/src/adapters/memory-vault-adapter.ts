/**
 * In-memory vault adapter for testing
 */

import type { VaultAdapter } from '@osi/core';

export class MemoryVaultAdapter implements VaultAdapter {
  private files = new Map<string, Uint8Array>();
  private stats = new Map<string, { mtimeMs: number; size: number }>();

  async readBinary(path: string): Promise<Uint8Array> {
    const data = this.files.get(path);
    if (!data) {
      throw new Error(`File not found: ${path}`);
    }
    return new Uint8Array(data);
  }

  async writeBinaryAtomic(path: string, data: Uint8Array): Promise<void> {
    // Ensure parent directory exists
    await this.ensureDir(this.getParentPath(path));
    
    // Write file
    this.files.set(path, new Uint8Array(data));
    this.stats.set(path, {
      mtimeMs: Date.now(),
      size: data.length
    });
  }

  async readText(path: string): Promise<string> {
    const data = await this.readBinary(path);
    return new TextDecoder().decode(data);
  }

  async writeTextAtomic(path: string, text: string): Promise<void> {
    const data = new TextEncoder().encode(text);
    await this.writeBinaryAtomic(path, data);
  }

  async renameAtomic(from: string, to: string): Promise<void> {
    const data = this.files.get(from);
    const stat = this.stats.get(from);
    
    if (!data || !stat) {
      throw new Error(`File not found: ${from}`);
    }

    // Ensure target directory exists
    await this.ensureDir(this.getParentPath(to));

    // Move file
    this.files.set(to, data);
    this.stats.set(to, stat);
    this.files.delete(from);
    this.stats.delete(from);
  }

  async stat(path: string): Promise<{ mtimeMs: number; size: number } | null> {
    return this.stats.get(path) || null;
  }

  async listDir(path: string): Promise<string[]> {
    const normalizedPath = path.endsWith('/') ? path : path + '/';
    const files: string[] = [];

    for (const [filePath] of this.files) {
      if (filePath.startsWith(normalizedPath)) {
        const relativePath = filePath.slice(normalizedPath.length);
        const firstSlash = relativePath.indexOf('/');
        
        if (firstSlash === -1) {
          // Direct child file
          files.push(relativePath);
        }
      }
    }

    return files;
  }

  async ensureDir(path: string): Promise<void> {
    // In memory adapter, directories are implicit
    // Just mark that the directory exists
    if (path && !this.files.has(path + '/.dir')) {
      this.files.set(path + '/.dir', new Uint8Array(0));
    }
  }

  async exists(path: string): Promise<boolean> {
    return this.files.has(path) || this.files.has(path + '/.dir');
  }

  async remove(path: string): Promise<void> {
    // Remove file or directory marker
    this.files.delete(path);
    this.files.delete(path + '/.dir');
    this.stats.delete(path);

    // Remove all children if it was a directory
    const normalizedPath = path.endsWith('/') ? path : path + '/';
    const toRemove: string[] = [];
    
    for (const [filePath] of this.files) {
      if (filePath.startsWith(normalizedPath)) {
        toRemove.push(filePath);
      }
    }

    for (const filePath of toRemove) {
      this.files.delete(filePath);
      this.stats.delete(filePath);
    }
  }

  private getParentPath(path: string): string {
    const parts = path.split('/');
    parts.pop();
    return parts.join('/');
  }

  // Testing utilities
  clear(): void {
    this.files.clear();
    this.stats.clear();
  }

  getFileCount(): number {
    return Array.from(this.files.keys()).filter(path => !path.endsWith('/.dir')).length;
  }

  getAllFiles(): string[] {
    return Array.from(this.files.keys()).filter(path => !path.endsWith('/.dir'));
  }

  snapshot(): Map<string, Uint8Array> {
    return new Map(this.files);
  }

  restore(snapshot: Map<string, Uint8Array>): void {
    this.files = new Map(snapshot);
    
    // Rebuild stats
    this.stats.clear();
    for (const [path, data] of this.files) {
      if (!path.endsWith('/.dir')) {
        this.stats.set(path, {
          mtimeMs: Date.now(),
          size: data.length
        });
      }
    }
  }
}