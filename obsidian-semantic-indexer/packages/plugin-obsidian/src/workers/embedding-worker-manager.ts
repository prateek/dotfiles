/**
 * Manager for embedding worker with backpressure and error handling
 */

import type { SemanticIndexSettings } from '../settings/settings.js';

export interface EmbeddingResult {
  vectors: Float32Array;
  dims: number;
}

interface PendingRequest {
  chunks: string[];
  resolve: (result: EmbeddingResult) => void;
  reject: (error: Error) => void;
  startTime: number;
}

export class EmbeddingWorkerManager {
  private worker: Worker | null = null;
  private pendingRequests = new Map<string, PendingRequest>();
  private isModelLoaded = false;
  private batchSize: number;
  private maxBatchSize: number;
  private minBatchSize = 1;
  private creditWindow = 3;
  private creditsUsed = 0;
  private retryCount = 0;
  private maxRetries = 3;

  constructor(private settings: SemanticIndexSettings) {
    this.batchSize = settings.maxConcurrentChunks;
    this.maxBatchSize = settings.maxConcurrentChunks;
  }

  async start(): Promise<void> {
    if (this.worker) return;

    // Create worker with proper module loading
    const workerUrl = new URL('./embedding.worker.js', import.meta.url);
    this.worker = new Worker(workerUrl, { type: 'module' });

    this.worker.onmessage = (event) => this.handleWorkerMessage(event);
    this.worker.onerror = (error) => this.handleWorkerError(error);

    // Load model
    await this.loadModel();
  }

  async stop(): Promise<void> {
    if (!this.worker) return;

    // Unload model
    if (this.isModelLoaded) {
      this.worker.postMessage({ type: 'Unload' });
    }

    // Reject pending requests
    for (const [, request] of this.pendingRequests) {
      request.reject(new Error('Worker stopped'));
    }
    this.pendingRequests.clear();

    // Terminate worker
    this.worker.terminate();
    this.worker = null;
    this.isModelLoaded = false;
  }

  async embedBatch(chunks: string[]): Promise<EmbeddingResult> {
    if (!this.worker || !this.isModelLoaded) {
      throw new Error('Worker not ready');
    }

    // Apply backpressure
    while (this.creditsUsed >= this.creditWindow) {
      await new Promise(resolve => setTimeout(resolve, 50));
    }

    // Split into smaller batches if needed
    const batches: string[][] = [];
    for (let i = 0; i < chunks.length; i += this.batchSize) {
      batches.push(chunks.slice(i, i + this.batchSize));
    }

    // Process batches
    const results: Float32Array[] = [];
    let dims = 0;

    for (const batch of batches) {
      const result = await this.processBatch(batch);
      results.push(result.vectors);
      dims = result.dims;
    }

    // Combine results
    const totalLength = results.reduce((sum, arr) => sum + arr.length, 0);
    const combined = new Float32Array(totalLength);
    let offset = 0;

    for (const result of results) {
      combined.set(result, offset);
      offset += result.length;
    }

    return { vectors: combined, dims };
  }

  updateSettings(settings: SemanticIndexSettings): void {
    this.settings = settings;
    this.maxBatchSize = settings.maxConcurrentChunks;
    this.batchSize = Math.min(this.batchSize, this.maxBatchSize);
  }

  reduceBatchSize(): void {
    this.batchSize = Math.max(this.minBatchSize, Math.floor(this.batchSize * 0.75));
    console.log(`Reduced batch size to ${this.batchSize}`);
  }

  private async loadModel(): Promise<void> {
    if (!this.worker) throw new Error('Worker not initialized');

    return new Promise((resolve, reject) => {
      const batchId = this.generateBatchId();
      
      this.pendingRequests.set(batchId, {
        chunks: [],
        resolve: () => {
          this.isModelLoaded = true;
          resolve();
        },
        reject,
        startTime: Date.now()
      });

      this.worker!.postMessage({
        type: 'LoadModel',
        id: this.settings.modelId,
        source: this.settings.modelSource,
        dtype: this.settings.storageDtype
      });

      // Timeout after 60 seconds
      setTimeout(() => {
        if (this.pendingRequests.has(batchId)) {
          this.pendingRequests.delete(batchId);
          reject(new Error('Model loading timeout'));
        }
      }, 60000);
    });
  }

  private async processBatch(chunks: string[]): Promise<EmbeddingResult> {
    if (!this.worker) throw new Error('Worker not initialized');

    const batchId = this.generateBatchId();
    this.creditsUsed++;

    return new Promise((resolve, reject) => {
      this.pendingRequests.set(batchId, {
        chunks,
        resolve,
        reject,
        startTime: Date.now()
      });

      this.worker!.postMessage({
        type: 'EmbedBatch',
        chunks,
        batchId
      });

      // Timeout based on batch size
      const timeout = 30000 + chunks.length * 1000;
      setTimeout(() => {
        if (this.pendingRequests.has(batchId)) {
          this.pendingRequests.delete(batchId);
          this.creditsUsed--;
          reject(new Error('Embedding timeout'));
        }
      }, timeout);
    });
  }

  private handleWorkerMessage(event: MessageEvent): void {
    const response = event.data;

    switch (response.type) {
      case 'Loaded':
        console.log(`Model loaded, memory: ${(response.memUsed / 1024 / 1024).toFixed(2)}MB`);
        // Find and resolve the load request
        for (const [id, request] of this.pendingRequests) {
          if (request.chunks.length === 0) {
            request.resolve({ vectors: new Float32Array(0), dims: 0 });
            this.pendingRequests.delete(id);
            break;
          }
        }
        break;

      case 'Embedded':
        const request = this.pendingRequests.get(response.batchId);
        if (request) {
          const elapsed = Date.now() - request.startTime;
          
          // Adjust batch size based on performance
          if (elapsed > 5000 && this.batchSize > this.minBatchSize) {
            this.reduceBatchSize();
          } else if (elapsed < 1000 && this.batchSize < this.maxBatchSize) {
            this.batchSize = Math.min(this.maxBatchSize, this.batchSize + 1);
          }

          request.resolve({ vectors: response.vectors, dims: response.dims });
          this.pendingRequests.delete(response.batchId);
          this.creditsUsed--;
          this.retryCount = 0; // Reset retry count on success
        }
        break;

      case 'Error':
        console.error('Worker error:', response.error);
        // Reject all pending requests with this error
        for (const [id, request] of this.pendingRequests) {
          request.reject(new Error(response.error));
          this.pendingRequests.delete(id);
        }
        this.creditsUsed = 0;
        break;

      case 'Unloaded':
        this.isModelLoaded = false;
        break;

      case 'Pong':
        // Health check response
        break;
    }
  }

  private async handleWorkerError(error: ErrorEvent): Promise<void> {
    console.error('Worker crashed:', error);
    
    // Save pending requests
    const pending = new Map(this.pendingRequests);
    this.pendingRequests.clear();
    this.creditsUsed = 0;

    // Attempt recovery
    if (this.retryCount < this.maxRetries) {
      this.retryCount++;
      console.log(`Attempting worker recovery (${this.retryCount}/${this.maxRetries})`);
      
      try {
        await this.stop();
        await new Promise(resolve => setTimeout(resolve, 1000 * this.retryCount));
        await this.start();
        
        // Retry pending requests
        for (const [, request] of pending) {
          try {
            const result = await this.embedBatch(request.chunks);
            request.resolve(result);
          } catch (retryError) {
            request.reject(retryError as Error);
          }
        }
      } catch (recoveryError) {
        // Recovery failed, reject all pending
        for (const [, request] of pending) {
          request.reject(new Error('Worker recovery failed'));
        }
      }
    } else {
      // Max retries exceeded, reject all pending
      for (const [, request] of pending) {
        request.reject(new Error('Worker crashed, max retries exceeded'));
      }
    }
  }

  private generateBatchId(): string {
    return `batch-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
  }
}