/**
 * Index health and integrity checks
 */

import type { VaultAdapter } from '../formats/types.js';
import { ManifestManager } from '../formats/manifest.js';
import { SegmentReader } from '../formats/segment.js';

export interface IntegrityCheckResult {
  ok: boolean;
  issues: string[];
  stats: {
    segments: number;
    rows: number;
  };
  orphans: string[];
}

export async function verifyIntegrity(
  vault: VaultAdapter,
  root: string = '.obsidian/plugins/semantic-index'
): Promise<IntegrityCheckResult> {
  const issues: string[] = [];
  const orphans: string[] = [];
  const stats = { segments: 0, rows: 0 };

  try {
    // Load manifest
    const manifestManager = new ManifestManager(vault, root);
    const manifest = await manifestManager.read();

    if (!manifest) {
      issues.push('No manifest found');
      return { ok: false, issues, stats, orphans };
    }

    // Validate manifest
    const { errors } = await manifestManager.validate(manifest);
    issues.push(...errors);

    // Track referenced files
    const referencedFiles = new Set<string>();
    referencedFiles.add('manifest.json');
    referencedFiles.add('manifest.prev.json');
    referencedFiles.add('ledger.json');

    // Check each segment
    for (const segment of manifest.segments) {
      stats.segments++;
      referencedFiles.add(segment.bin);
      referencedFiles.add(segment.meta);

      try {
        // Verify segment binary
        const binPath = `${root}/${segment.bin}`;
        const binData = await vault.readBinary(binPath);
        
        const { header, crc } = SegmentReader.read(binData);
        
        // Verify CRC matches manifest
        if (crc !== segment.crc) {
          issues.push(`CRC mismatch for segment ${segment.id}: expected ${segment.crc}, got ${crc}`);
        }

        // Verify dimensions match
        if (header.dims !== manifest.model.dims) {
          issues.push(`Dimension mismatch in segment ${segment.id}: expected ${manifest.model.dims}, got ${header.dims}`);
        }

        // Verify row count
        if (header.rows !== segment.rows) {
          issues.push(`Row count mismatch in segment ${segment.id}: expected ${segment.rows}, got ${header.rows}`);
        }

        stats.rows += header.rows;

        // Verify metadata file
        const metaPath = `${root}/${segment.meta}`;
        const metaContent = await vault.readText(metaPath);
        const metaLines = metaContent.trim().split('\n').filter(line => line);
        
        if (metaLines.length !== segment.rows) {
          issues.push(`Metadata row count mismatch in segment ${segment.id}: expected ${segment.rows}, got ${metaLines.length}`);
        }

        // Validate each metadata line
        for (let i = 0; i < metaLines.length; i++) {
          try {
            JSON.parse(metaLines[i]);
          } catch {
            issues.push(`Invalid JSON in ${segment.meta} at line ${i + 1}`);
            break;
          }
        }

      } catch (error) {
        issues.push(`Failed to read segment ${segment.id}: ${error}`);
      }
    }

    // Find orphaned files
    const allDirs = ['segments', 'meta', 'wal', 'ann', 'tmp'];
    
    for (const dir of allDirs) {
      try {
        const dirPath = `${root}/${dir}`;
        const files = await vault.listDir(dirPath);
        
        for (const file of files) {
          const relativePath = `${dir}/${file}`;
          if (!referencedFiles.has(relativePath) && !isSystemFile(file)) {
            orphans.push(relativePath);
          }
        }
      } catch {
        // Directory might not exist
      }
    }

    return {
      ok: issues.length === 0,
      issues,
      stats,
      orphans
    };

  } catch (error) {
    issues.push(`Health check failed: ${error}`);
    return { ok: false, issues, stats, orphans };
  }
}

function isSystemFile(filename: string): boolean {
  const systemFiles = new Set([
    'tasks.jsonl',
    'ledger.json',
    'manifest.json',
    'manifest.prev.json',
    'manifest.tmp',
    'bm25.json',
    'visible.jsonl',
    'ring.jsonl'
  ]);
  
  return systemFiles.has(filename) || 
         filename.startsWith('.') || 
         filename.endsWith('.tmp');
}