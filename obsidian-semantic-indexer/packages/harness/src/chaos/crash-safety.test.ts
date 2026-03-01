/**
 * Chaos testing for crash safety
 */

import { describe, it, expect, beforeEach } from 'vitest';
import * as fc from 'fast-check';
import {
  IndexWriter,
  WAL,
  LedgerManager,
  ManifestManager,
  verifyIntegrity,
  TextChunker,
  type WALEntry
} from '@osi/core';
import { MemoryVaultAdapter } from '../adapters/memory-vault-adapter.js';
import { FaultyVaultAdapter } from '../adapters/faulty-vault-adapter.js';

describe('Crash Safety Tests', () => {
  let memoryAdapter: MemoryVaultAdapter;
  let faultyAdapter: FaultyVaultAdapter;
  let indexWriter: IndexWriter;
  let wal: WAL;
  let ledger: LedgerManager;
  let manifestManager: ManifestManager;

  beforeEach(() => {
    memoryAdapter = new MemoryVaultAdapter();
    faultyAdapter = new FaultyVaultAdapter(memoryAdapter, {
      failureRate: 0,
      partialWriteRate: 0,
      corruptionRate: 0
    });
    
    indexWriter = new IndexWriter(faultyAdapter);
    wal = new WAL(faultyAdapter);
    ledger = new LedgerManager(faultyAdapter);
    manifestManager = new ManifestManager(faultyAdapter);
  });

  it('should maintain integrity after crash during segment write', async () => {
    // Create initial valid state
    const vectors = new Float32Array(100 * 384); // 100 vectors, 384 dims
    for (let i = 0; i < vectors.length; i++) {
      vectors[i] = Math.random();
    }

    const metaLines = Array(100).fill(0).map((_, i) => 
      JSON.stringify({
        path: `note${i}.md`,
        chunk_id: `chunk${i}`,
        off: i * 100,
        len: 100,
        hash: `hash${i}`
      })
    );

    // Take snapshot before operation
    const snapshotBefore = memoryAdapter.snapshot();

    // Set crash point during segment write
    faultyAdapter.setCrashPoint('writeBinaryAtomic');

    try {
      await indexWriter.commitSegment({
        id: 'seg001',
        vectors,
        metaJsonl: metaLines.join('\n'),
        modelId: 'test-model',
        dims: 384,
        dtype: 'f32'
      });
      expect.fail('Should have crashed');
    } catch (error) {
      expect(error.message).toContain('Simulated crash');
    }

    // Verify integrity after crash
    const result = await verifyIntegrity(memoryAdapter);
    expect(result.ok).toBe(true);

    // Verify we can still read manifest (should be old one or none)
    const manifest = await manifestManager.read();
    if (manifest) {
      expect(manifest.segments.length).toBe(0);
    }
  });

  it('should recover from partial manifest write', async () => {
    // Create a valid segment first
    const vectors = new Float32Array(10 * 384);
    const metaLines = Array(10).fill(0).map((_, i) => 
      JSON.stringify({ path: `note${i}.md`, chunk_id: `chunk${i}`, off: 0, len: 100, hash: 'test' })
    );

    await indexWriter.commitSegment({
      id: 'seg001',
      vectors,
      metaJsonl: metaLines.join('\n'),
      modelId: 'test-model',
      dims: 384,
      dtype: 'f32'
    });

    // Now simulate partial write during second commit
    faultyAdapter = new FaultyVaultAdapter(memoryAdapter, {
      partialWriteRate: 1.0 // Always partial write
    });
    indexWriter = new IndexWriter(faultyAdapter);

    try {
      await indexWriter.commitSegment({
        id: 'seg002',
        vectors,
        metaJsonl: metaLines.join('\n'),
        modelId: 'test-model',
        dims: 384,
        dtype: 'f32'
      });
      expect.fail('Should have failed with partial write');
    } catch (error) {
      expect(error.message).toContain('partial write');
    }

    // Reset adapter to normal
    faultyAdapter = new FaultyVaultAdapter(memoryAdapter);
    manifestManager = new ManifestManager(faultyAdapter);

    // Verify we can still read a valid manifest
    const manifest = await manifestManager.read();
    expect(manifest).not.toBeNull();
    expect(manifest!.segments.length).toBeGreaterThan(0);

    // Verify integrity
    const result = await verifyIntegrity(memoryAdapter);
    expect(result.ok).toBe(true);
  });

  it('should handle WAL corruption gracefully', async () => {
    // Write some valid WAL entries
    await wal.append({ id: 'job1', status: 'pending', enq_at: Date.now() });
    await wal.append({ id: 'job2', status: 'pending', enq_at: Date.now() });

    // Corrupt the WAL file
    const walPath = '.obsidian/plugins/semantic-index/wal/tasks.jsonl';
    const content = await memoryAdapter.readText(walPath);
    const corrupted = content + '\n{invalid json\n' + JSON.stringify({ id: 'job3', status: 'pending' });
    await memoryAdapter.writeTextAtomic(walPath, corrupted);

    // Should still be able to read valid entries
    const pending = await wal.getPending();
    expect(pending.size).toBeGreaterThanOrEqual(2);
  });

  describe('Property-based crash testing', () => {
    it('should maintain consistency through random crash sequences', async () => {
      await fc.assert(
        fc.asyncProperty(
          fc.array(fc.record({
            operation: fc.constantFrom('commit', 'wal', 'ledger', 'reconcile'),
            crashPoint: fc.constantFrom('before', 'during', 'after'),
            data: fc.record({
              vectors: fc.integer({ min: 1, max: 10 }),
              path: fc.string({ minLength: 1, maxLength: 20 })
            })
          }), { minLength: 1, maxLength: 10 }),
          async (operations) => {
            // Reset state
            memoryAdapter.clear();
            
            let lastValidManifest = null;
            
            for (const op of operations) {
              const snapshot = memoryAdapter.snapshot();
              
              try {
                if (op.operation === 'commit') {
                  // Inject crash if needed
                  if (op.crashPoint === 'during') {
                    faultyAdapter.setCrashPoint('writeBinaryAtomic');
                  }

                  const vectorCount = op.data.vectors;
                  const vectors = new Float32Array(vectorCount * 384);
                  const metaLines = Array(vectorCount).fill(0).map((_, i) => 
                    JSON.stringify({
                      path: `${op.data.path}${i}.md`,
                      chunk_id: `chunk_${Date.now()}_${i}`,
                      off: 0,
                      len: 100,
                      hash: 'test'
                    })
                  );

                  const manifest = await indexWriter.commitSegment({
                    id: `seg_${Date.now()}`,
                    vectors,
                    metaJsonl: metaLines.join('\n'),
                    modelId: 'test-model',
                    dims: 384,
                    dtype: 'f32',
                    prev: lastValidManifest
                  });

                  lastValidManifest = manifest;
                }
              } catch (error) {
                // Crash occurred, restore to snapshot
                if (error.message.includes('Simulated')) {
                  memoryAdapter.restore(snapshot);
                }
              }

              // Clear crash points
              faultyAdapter.clearCrashPoints();
            }

            // Verify final state integrity
            const result = await verifyIntegrity(memoryAdapter);
            expect(result.ok).toBe(true);

            // Verify we can read manifest
            const manifest = await manifestManager.read();
            if (manifest) {
              // Verify all referenced files exist
              for (const segment of manifest.segments) {
                expect(await memoryAdapter.exists(`.obsidian/plugins/semantic-index/${segment.bin}`)).toBe(true);
                expect(await memoryAdapter.exists(`.obsidian/plugins/semantic-index/${segment.meta}`)).toBe(true);
              }
            }

            return true;
          }
        ),
        { numRuns: 50 }
      );
    });
  });

  it('should handle concurrent operations with crashes', async () => {
    const operations = Array(10).fill(0).map((_, i) => ({
      id: `job${i}`,
      path: `note${i}.md`,
      vectors: new Float32Array(10 * 384)
    }));

    // Simulate concurrent operations with random crashes
    const promises = operations.map(async (op, index) => {
      // Add some randomness to crash timing
      if (Math.random() < 0.3) {
        faultyAdapter.setCrashPoint(index % 2 === 0 ? 'writeBinaryAtomic' : 'renameAtomic');
      }

      try {
        await wal.append({ id: op.id, path: op.path, status: 'pending', enq_at: Date.now() });
        
        await indexWriter.commitSegment({
          id: op.id,
          vectors: op.vectors,
          metaJsonl: JSON.stringify({ path: op.path, chunk_id: op.id, off: 0, len: 100, hash: 'test' }),
          modelId: 'test-model',
          dims: 384,
          dtype: 'f32'
        });

        await wal.append({ id: op.id, status: 'done', done_at: Date.now() });
      } catch (error) {
        await wal.append({ id: op.id, status: 'failed', done_at: Date.now(), err: error.message });
      }
    });

    // Wait for all operations
    await Promise.allSettled(promises);

    // Verify integrity
    const result = await verifyIntegrity(memoryAdapter);
    expect(result.ok).toBe(true);

    // Check WAL consistency
    const allEntries = await wal.readAll();
    const jobStates = new Map<string, string>();
    
    for (const entry of allEntries) {
      if (entry.status === 'done' || entry.status === 'failed') {
        jobStates.set(entry.id, entry.status);
      }
    }

    // Every job should have a final state
    for (const op of operations) {
      expect(jobStates.has(op.id)).toBe(true);
    }
  });
});