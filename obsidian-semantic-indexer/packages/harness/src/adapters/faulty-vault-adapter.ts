/**
 * Faulty vault adapter for chaos testing
 */

import type { VaultAdapter } from '@osi/core';
import { MemoryVaultAdapter } from './memory-vault-adapter.js';

export interface FaultConfig {
  failureRate: number; // 0-1 probability of failure
  partialWriteRate: number; // 0-1 probability of partial write
  corruptionRate: number; // 0-1 probability of data corruption
  latencyMs?: { min: number; max: number }; // Random latency
  crashOnPattern?: RegExp; // Crash on specific file patterns
}

export class FaultyVaultAdapter implements VaultAdapter {
  private faults: FaultConfig;
  private operationCount = 0;
  private crashPoints = new Set<string>();

  constructor(
    private baseAdapter: VaultAdapter,
    faults: Partial<FaultConfig> = {}
  ) {
    this.faults = {
      failureRate: faults.failureRate ?? 0,
      partialWriteRate: faults.partialWriteRate ?? 0,
      corruptionRate: faults.corruptionRate ?? 0,
      latencyMs: faults.latencyMs,
      crashOnPattern: faults.crashOnPattern
    };
  }

  setCrashPoint(operation: string): void {
    this.crashPoints.add(operation);
  }

  clearCrashPoints(): void {
    this.crashPoints.clear();
  }

  async readBinary(path: string): Promise<Uint8Array> {
    await this.injectFault('readBinary', path);
    const data = await this.baseAdapter.readBinary(path);
    return this.maybeCorrupt(data);
  }

  async writeBinaryAtomic(path: string, data: Uint8Array): Promise<void> {
    await this.injectFault('writeBinaryAtomic', path);
    
    // Simulate partial write
    if (Math.random() < this.faults.partialWriteRate) {
      const partialLength = Math.floor(data.length * Math.random());
      const partialData = data.slice(0, partialLength);
      await this.baseAdapter.writeBinaryAtomic(path, partialData);
      throw new Error('Simulated partial write');
    }

    await this.baseAdapter.writeBinaryAtomic(path, data);
  }

  async readText(path: string): Promise<string> {
    await this.injectFault('readText', path);
    return await this.baseAdapter.readText(path);
  }

  async writeTextAtomic(path: string, text: string): Promise<void> {
    await this.injectFault('writeTextAtomic', path);
    
    // Simulate partial write
    if (Math.random() < this.faults.partialWriteRate) {
      const partialLength = Math.floor(text.length * Math.random());
      const partialText = text.slice(0, partialLength);
      await this.baseAdapter.writeTextAtomic(path, partialText);
      throw new Error('Simulated partial write');
    }

    await this.baseAdapter.writeTextAtomic(path, text);
  }

  async renameAtomic(from: string, to: string): Promise<void> {
    await this.injectFault('renameAtomic', from);
    
    // Simulate failure mid-rename (file disappears)
    if (Math.random() < this.faults.failureRate / 2) {
      await this.baseAdapter.remove(from);
      throw new Error('Simulated rename failure');
    }

    await this.baseAdapter.renameAtomic(from, to);
  }

  async stat(path: string): Promise<{ mtimeMs: number; size: number } | null> {
    await this.injectFault('stat', path);
    return await this.baseAdapter.stat(path);
  }

  async listDir(path: string): Promise<string[]> {
    await this.injectFault('listDir', path);
    return await this.baseAdapter.listDir(path);
  }

  async ensureDir(path: string): Promise<void> {
    await this.injectFault('ensureDir', path);
    await this.baseAdapter.ensureDir(path);
  }

  async exists(path: string): Promise<boolean> {
    await this.injectFault('exists', path);
    return await this.baseAdapter.exists(path);
  }

  async remove(path: string): Promise<void> {
    await this.injectFault('remove', path);
    await this.baseAdapter.remove(path);
  }

  private async injectFault(operation: string, path: string): Promise<void> {
    this.operationCount++;

    // Check crash points
    if (this.crashPoints.has(operation)) {
      this.crashPoints.delete(operation);
      throw new Error(`Simulated crash at ${operation}`);
    }

    // Check crash pattern
    if (this.faults.crashOnPattern && this.faults.crashOnPattern.test(path)) {
      throw new Error(`Simulated crash on pattern: ${path}`);
    }

    // Random failure
    if (Math.random() < this.faults.failureRate) {
      throw new Error(`Simulated failure in ${operation}`);
    }

    // Inject latency
    if (this.faults.latencyMs) {
      const delay = this.faults.latencyMs.min + 
        Math.random() * (this.faults.latencyMs.max - this.faults.latencyMs.min);
      await new Promise(resolve => setTimeout(resolve, delay));
    }
  }

  private maybeCorrupt(data: Uint8Array): Uint8Array {
    if (Math.random() >= this.faults.corruptionRate) {
      return data;
    }

    // Corrupt random bytes
    const corrupted = new Uint8Array(data);
    const numCorruptions = Math.floor(Math.random() * 10) + 1;
    
    for (let i = 0; i < numCorruptions; i++) {
      const index = Math.floor(Math.random() * corrupted.length);
      corrupted[index] = Math.floor(Math.random() * 256);
    }

    return corrupted;
  }

  getOperationCount(): number {
    return this.operationCount;
  }

  reset(): void {
    this.operationCount = 0;
    this.crashPoints.clear();
  }
}