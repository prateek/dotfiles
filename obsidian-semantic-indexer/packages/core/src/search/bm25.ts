/**
 * BM25 implementation for lexical search
 */

export interface BM25Document {
  id: string;
  content: string;
  path: string;
}

export interface BM25Options {
  k1?: number; // Term frequency saturation parameter
  b?: number;  // Length normalization parameter
  stemming?: boolean;
  stopwords?: Set<string>;
}

export interface BM25SearchResult {
  id: string;
  path: string;
  score: number;
  matches: string[];
}

// Common English stopwords
const DEFAULT_STOPWORDS = new Set([
  'a', 'an', 'and', 'are', 'as', 'at', 'be', 'by', 'for', 'from',
  'has', 'he', 'in', 'is', 'it', 'its', 'of', 'on', 'that', 'the',
  'to', 'was', 'will', 'with', 'the', 'this', 'but', 'they', 'have',
  'had', 'what', 'when', 'where', 'who', 'which', 'why', 'how'
]);

export class BM25Index {
  private documents = new Map<string, BM25Document>();
  private termFrequencies = new Map<string, Map<string, number>>();
  private documentFrequencies = new Map<string, number>();
  private avgDocLength = 0;
  private k1: number;
  private b: number;
  private stemming: boolean;
  private stopwords: Set<string>;

  constructor(options: BM25Options = {}) {
    this.k1 = options.k1 ?? 1.2;
    this.b = options.b ?? 0.75;
    this.stemming = options.stemming ?? true;
    this.stopwords = options.stopwords ?? DEFAULT_STOPWORDS;
  }

  addDocument(doc: BM25Document): void {
    this.documents.set(doc.id, doc);
    
    const tokens = this.tokenize(doc.content);
    const termFreq = new Map<string, number>();

    // Count term frequencies
    for (const token of tokens) {
      termFreq.set(token, (termFreq.get(token) || 0) + 1);
    }

    // Update document frequencies
    for (const term of termFreq.keys()) {
      this.documentFrequencies.set(
        term,
        (this.documentFrequencies.get(term) || 0) + 1
      );
    }

    this.termFrequencies.set(doc.id, termFreq);
    this.updateAvgDocLength();
  }

  removeDocument(id: string): void {
    const termFreq = this.termFrequencies.get(id);
    if (!termFreq) return;

    // Update document frequencies
    for (const term of termFreq.keys()) {
      const df = this.documentFrequencies.get(term) || 0;
      if (df <= 1) {
        this.documentFrequencies.delete(term);
      } else {
        this.documentFrequencies.set(term, df - 1);
      }
    }

    this.documents.delete(id);
    this.termFrequencies.delete(id);
    this.updateAvgDocLength();
  }

  search(query: string, k: number = 20): BM25SearchResult[] {
    const queryTokens = this.tokenize(query);
    if (queryTokens.length === 0) return [];

    const scores = new Map<string, number>();
    const matches = new Map<string, Set<string>>();
    const N = this.documents.size;

    for (const [docId, doc] of this.documents) {
      let score = 0;
      const docMatches = new Set<string>();
      const termFreq = this.termFrequencies.get(docId)!;
      const docLength = Array.from(termFreq.values()).reduce((a, b) => a + b, 0);

      for (const term of queryTokens) {
        const tf = termFreq.get(term) || 0;
        if (tf === 0) continue;

        const df = this.documentFrequencies.get(term) || 0;
        const idf = Math.log((N - df + 0.5) / (df + 0.5));
        
        const numerator = tf * (this.k1 + 1);
        const denominator = tf + this.k1 * (1 - this.b + this.b * (docLength / this.avgDocLength));
        
        score += idf * (numerator / denominator);
        docMatches.add(term);
      }

      if (score > 0) {
        scores.set(docId, score);
        matches.set(docId, docMatches);
      }
    }

    // Sort by score and return top k
    return Array.from(scores.entries())
      .sort((a, b) => b[1] - a[1])
      .slice(0, k)
      .map(([id, score]) => {
        const doc = this.documents.get(id)!;
        return {
          id,
          path: doc.path,
          score,
          matches: Array.from(matches.get(id) || [])
        };
      });
  }

  private tokenize(text: string): string[] {
    // Simple tokenization with optional stemming
    let tokens = text
      .toLowerCase()
      .replace(/[^\w\s]/g, ' ')
      .split(/\s+/)
      .filter(token => token.length > 1)
      .filter(token => !this.stopwords.has(token));

    if (this.stemming) {
      tokens = tokens.map(token => this.stem(token));
    }

    return tokens;
  }

  private stem(word: string): string {
    // Very simple Porter stemmer rules (subset)
    if (word.endsWith('ies')) {
      return word.slice(0, -3) + 'y';
    }
    if (word.endsWith('es')) {
      return word.slice(0, -2);
    }
    if (word.endsWith('s') && !word.endsWith('ss')) {
      return word.slice(0, -1);
    }
    if (word.endsWith('ed')) {
      return word.slice(0, -2);
    }
    if (word.endsWith('ing')) {
      return word.slice(0, -3);
    }
    if (word.endsWith('ly')) {
      return word.slice(0, -2);
    }
    return word;
  }

  private updateAvgDocLength(): void {
    if (this.documents.size === 0) {
      this.avgDocLength = 0;
      return;
    }

    let totalLength = 0;
    for (const termFreq of this.termFrequencies.values()) {
      totalLength += Array.from(termFreq.values()).reduce((a, b) => a + b, 0);
    }
    this.avgDocLength = totalLength / this.documents.size;
  }

  // Serialization for persistence
  serialize(): string {
    return JSON.stringify({
      documents: Array.from(this.documents.entries()),
      termFrequencies: Array.from(this.termFrequencies.entries()).map(([k, v]) => [k, Array.from(v.entries())]),
      documentFrequencies: Array.from(this.documentFrequencies.entries()),
      avgDocLength: this.avgDocLength
    });
  }

  static deserialize(data: string, options?: BM25Options): BM25Index {
    const index = new BM25Index(options);
    const parsed = JSON.parse(data);
    
    index.documents = new Map(parsed.documents);
    index.termFrequencies = new Map(
      parsed.termFrequencies.map(([k, v]: [string, [string, number][]]) => [k, new Map(v)])
    );
    index.documentFrequencies = new Map(parsed.documentFrequencies);
    index.avgDocLength = parsed.avgDocLength;
    
    return index;
  }

  getMemoryUsage(): number {
    // Rough estimate of memory usage in bytes
    let size = 0;
    
    // Documents
    for (const doc of this.documents.values()) {
      size += doc.id.length * 2 + doc.content.length * 2 + doc.path.length * 2;
    }
    
    // Term frequencies
    for (const [docId, terms] of this.termFrequencies) {
      size += docId.length * 2;
      for (const [term] of terms) {
        size += term.length * 2 + 8; // string + number
      }
    }
    
    // Document frequencies
    for (const [term] of this.documentFrequencies) {
      size += term.length * 2 + 8;
    }
    
    return size;
  }
}