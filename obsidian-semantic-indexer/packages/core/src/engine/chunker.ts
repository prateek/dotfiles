/**
 * Smart text chunker with heading and boundary awareness
 */

import { createHashSync } from '../utils/hash.js';

export interface ChunkOptions {
  minTokens?: number;
  maxTokens?: number;
  overlapTokens?: number;
  respectHeadings?: boolean;
  respectCodeFences?: boolean;
  respectLists?: boolean;
}

export interface Chunk {
  id: string;
  content: string;
  offset: number;
  length: number;
  heading?: string;
  tokens: number;
}

export class TextChunker {
  private minTokens: number;
  private maxTokens: number;
  private overlapTokens: number;
  private respectHeadings: boolean;
  private respectCodeFences: boolean;
  private respectLists: boolean;

  constructor(options: ChunkOptions = {}) {
    this.minTokens = options.minTokens ?? 200;
    this.maxTokens = options.maxTokens ?? 300;
    this.overlapTokens = options.overlapTokens ?? 50;
    this.respectHeadings = options.respectHeadings ?? true;
    this.respectCodeFences = options.respectCodeFences ?? true;
    this.respectLists = options.respectLists ?? true;
  }

  chunk(content: string, filePath: string): Chunk[] {
    const chunks: Chunk[] = [];
    const lines = content.split('\n');
    
    let currentChunk: string[] = [];
    let currentTokens = 0;
    let currentOffset = 0;
    let currentHeading = '';
    let inCodeFence = false;
    let chunkIndex = 0;

    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];
      const lineTokens = this.estimateTokens(line);

      // Handle code fences
      if (line.startsWith('```')) {
        inCodeFence = !inCodeFence;
      }

      // Update current heading
      const headingMatch = line.match(/^#+\s+(.+)$/);
      if (headingMatch && !inCodeFence) {
        currentHeading = headingMatch[1].trim();
        
        // Force chunk boundary at headings if respected
        if (this.respectHeadings && currentChunk.length > 0) {
          chunks.push(this.createChunk(
            currentChunk,
            filePath,
            chunkIndex++,
            currentOffset,
            currentHeading
          ));
          currentChunk = [];
          currentTokens = 0;
          currentOffset += this.getByteLength(currentChunk.join('\n')) + 1;
        }
      }

      // Check if adding this line would exceed max tokens
      if (currentTokens + lineTokens > this.maxTokens && currentChunk.length > 0) {
        // Save current chunk
        chunks.push(this.createChunk(
          currentChunk,
          filePath,
          chunkIndex++,
          currentOffset,
          currentHeading
        ));

        // Start new chunk with overlap
        const overlapLines = this.getOverlapLines(currentChunk);
        currentChunk = overlapLines;
        currentTokens = overlapLines.reduce((sum, l) => sum + this.estimateTokens(l), 0);
        currentOffset += this.getByteLength(currentChunk.join('\n')) + 1;
      }

      currentChunk.push(line);
      currentTokens += lineTokens;

      // Check for natural boundaries
      if (this.shouldBreakChunk(line, lines[i + 1], inCodeFence, currentTokens)) {
        if (currentTokens >= this.minTokens) {
          chunks.push(this.createChunk(
            currentChunk,
            filePath,
            chunkIndex++,
            currentOffset,
            currentHeading
          ));
          currentChunk = [];
          currentTokens = 0;
          currentOffset = this.getByteOffset(content, i + 1);
        }
      }
    }

    // Don't forget the last chunk
    if (currentChunk.length > 0) {
      chunks.push(this.createChunk(
        currentChunk,
        filePath,
        chunkIndex++,
        currentOffset,
        currentHeading
      ));
    }

    return chunks;
  }

  private createChunk(
    lines: string[],
    filePath: string,
    index: number,
    offset: number,
    heading: string
  ): Chunk {
    const content = lines.join('\n');
    const length = this.getByteLength(content);
    
    // Generate stable chunk ID based on normalized content
    const normalizedContent = this.normalizeContent(content);
    const id = createHashSync(normalizedContent);

    return {
      id,
      content,
      offset,
      length,
      heading: heading || undefined,
      tokens: this.estimateTokens(content)
    };
  }

  private shouldBreakChunk(
    currentLine: string,
    nextLine: string | undefined,
    inCodeFence: boolean,
    currentTokens: number
  ): boolean {
    // Don't break inside code fences
    if (inCodeFence) return false;

    // Natural paragraph break (empty line)
    if (currentLine.trim() === '' && nextLine?.trim() !== '') {
      return true;
    }

    // List boundaries
    if (this.respectLists) {
      const isListItem = /^[\s]*[-*+\d]+[.)\s]/.test(currentLine);
      const nextIsListItem = nextLine && /^[\s]*[-*+\d]+[.)\s]/.test(nextLine);
      
      // Break after list ends
      if (isListItem && !nextIsListItem && nextLine?.trim() !== '') {
        return true;
      }
    }

    // Section dividers
    if (/^---+$|^===+$|^\*\*\*+$/.test(currentLine.trim())) {
      return true;
    }

    return false;
  }

  private getOverlapLines(lines: string[]): string[] {
    let overlapTokens = 0;
    const overlapLines: string[] = [];

    // Work backwards to find overlap
    for (let i = lines.length - 1; i >= 0; i--) {
      const lineTokens = this.estimateTokens(lines[i]);
      if (overlapTokens + lineTokens > this.overlapTokens) {
        break;
      }
      overlapLines.unshift(lines[i]);
      overlapTokens += lineTokens;
    }

    return overlapLines;
  }

  private estimateTokens(text: string): number {
    // Simple estimation: ~0.75 tokens per word, ~4 chars per token
    const words = text.split(/\s+/).filter(w => w.length > 0).length;
    const chars = text.length;
    return Math.max(Math.floor(words * 0.75), Math.floor(chars / 4));
  }

  private getByteLength(text: string): number {
    return new TextEncoder().encode(text).length;
  }

  private getByteOffset(content: string, lineIndex: number): number {
    const lines = content.split('\n');
    let offset = 0;
    for (let i = 0; i < lineIndex && i < lines.length; i++) {
      offset += this.getByteLength(lines[i]) + 1; // +1 for newline
    }
    return offset;
  }

  private normalizeContent(content: string): string {
    // Normalize whitespace and case for stable chunk IDs
    return content
      .toLowerCase()
      .replace(/\s+/g, ' ')
      .trim();
  }
}