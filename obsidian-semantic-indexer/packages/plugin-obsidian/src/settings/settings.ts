/**
 * Plugin settings definitions
 */

export interface SemanticIndexSettings {
  // Model settings
  modelId: string;
  modelSource: 'builtin' | 'download';
  storageDtype: 'f32' | 'f16';
  
  // Performance settings
  maxConcurrentChunks: number;
  reconcileIntervalMinutes: number;
  enableANN: boolean;
  
  // Search settings
  defaultSearchMode: 'hybrid' | 'dense' | 'lexical';
  lexicalWeight: number;
  denseWeight: number;
  searchResultsCount: number;
  
  // Indexing settings
  ignoreGlobs: string[];
  chunkMinTokens: number;
  chunkMaxTokens: number;
  chunkOverlapTokens: number;
  
  // UI settings
  showStatusChip: boolean;
  debugMode: boolean;
  
  // Memory limits
  maxMemoryMB: number;
  maxBM25MemoryMB: number;
  maxANNMemoryMB: number;
}

export const DEFAULT_SETTINGS: SemanticIndexSettings = {
  // Model
  modelId: 'Xenova/bge-small-en-v1.5',
  modelSource: 'download',
  storageDtype: 'f32',
  
  // Performance
  maxConcurrentChunks: 4, // Mobile default, will be adjusted based on device
  reconcileIntervalMinutes: 10,
  enableANN: false, // Off by default on mobile
  
  // Search
  defaultSearchMode: 'hybrid',
  lexicalWeight: 0.5,
  denseWeight: 0.5,
  searchResultsCount: 20,
  
  // Indexing
  ignoreGlobs: [
    '**/.obsidian/**',
    '**/*.png',
    '**/*.jpg',
    '**/*.jpeg',
    '**/*.gif',
    '**/*.pdf',
    '**/*.excalidraw.md',
    '**/node_modules/**',
    '**/.git/**'
  ],
  chunkMinTokens: 200,
  chunkMaxTokens: 300,
  chunkOverlapTokens: 50,
  
  // UI
  showStatusChip: true,
  debugMode: false,
  
  // Memory
  maxMemoryMB: 150,
  maxBM25MemoryMB: 32,
  maxANNMemoryMB: 64
};

// Adjust defaults based on platform
export function adjustSettingsForPlatform(settings: SemanticIndexSettings): SemanticIndexSettings {
  const adjusted = { ...settings };
  
  // Check if we're on desktop
  const isDesktop = !window.matchMedia('(max-width: 768px)').matches;
  const hasHighMemory = 'memory' in performance && 
    (performance as any).memory.jsHeapSizeLimit > 1024 * 1024 * 1024; // > 1GB
  
  if (isDesktop && hasHighMemory) {
    adjusted.maxConcurrentChunks = 16;
    adjusted.enableANN = true;
    adjusted.maxMemoryMB = 512;
    adjusted.maxBM25MemoryMB = 128;
    adjusted.maxANNMemoryMB = 256;
  }
  
  return adjusted;
}