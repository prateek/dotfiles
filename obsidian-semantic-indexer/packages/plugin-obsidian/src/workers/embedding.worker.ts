/**
 * Web Worker for computing embeddings
 */

import { pipeline, env } from '@xenova/transformers';

// Configure Transformers.js for browser environment
env.allowLocalModels = false;
env.backends.onnx.wasm.numThreads = 1;

interface LoadModelMessage {
  type: 'LoadModel';
  id: string;
  source: 'builtin' | 'download';
  dtype: 'f32' | 'f16';
}

interface EmbedBatchMessage {
  type: 'EmbedBatch';
  chunks: string[];
  batchId: string;
}

interface UnloadMessage {
  type: 'Unload';
}

interface PingMessage {
  type: 'Ping';
}

type WorkerMessage = LoadModelMessage | EmbedBatchMessage | UnloadMessage | PingMessage;

interface LoadedResponse {
  type: 'Loaded';
  memUsed: number;
}

interface EmbeddedResponse {
  type: 'Embedded';
  batchId: string;
  vectors: Float32Array;
  dims: number;
}

interface UnloadedResponse {
  type: 'Unloaded';
}

interface PongResponse {
  type: 'Pong';
}

interface ErrorResponse {
  type: 'Error';
  error: string;
}

type WorkerResponse = LoadedResponse | EmbeddedResponse | UnloadedResponse | PongResponse | ErrorResponse;

class EmbeddingWorker {
  private model: any = null;
  private modelId: string | null = null;
  private dims: number = 0;

  async handleMessage(message: WorkerMessage): Promise<WorkerResponse> {
    try {
      switch (message.type) {
        case 'LoadModel':
          return await this.loadModel(message);
        
        case 'EmbedBatch':
          return await this.embedBatch(message);
        
        case 'Unload':
          return await this.unload();
        
        case 'Ping':
          return { type: 'Pong' };
        
        default:
          throw new Error(`Unknown message type: ${(message as any).type}`);
      }
    } catch (error) {
      return {
        type: 'Error',
        error: error instanceof Error ? error.message : String(error)
      };
    }
  }

  private async loadModel(message: LoadModelMessage): Promise<LoadedResponse> {
    // Unload existing model
    if (this.model) {
      await this.unload();
    }

    // Load new model
    this.modelId = message.id;
    this.model = await pipeline('feature-extraction', message.id);

    // Get model dimensions by running a test embedding
    const testEmbedding = await this.model('test', { 
      pooling: 'mean', 
      normalize: true 
    });
    this.dims = testEmbedding.dims[testEmbedding.dims.length - 1];

    // Estimate memory usage
    const memUsed = this.estimateMemoryUsage();

    return {
      type: 'Loaded',
      memUsed
    };
  }

  private async embedBatch(message: EmbedBatchMessage): Promise<EmbeddedResponse> {
    if (!this.model) {
      throw new Error('Model not loaded');
    }

    const { chunks, batchId } = message;
    
    // Process chunks
    const embeddings = await this.model(chunks, {
      pooling: 'mean',
      normalize: true
    });

    // Convert to Float32Array
    const vectors = new Float32Array(chunks.length * this.dims);
    const data = embeddings.data;

    for (let i = 0; i < chunks.length; i++) {
      for (let j = 0; j < this.dims; j++) {
        vectors[i * this.dims + j] = data[i * this.dims + j];
      }
    }

    return {
      type: 'Embedded',
      batchId,
      vectors,
      dims: this.dims
    };
  }

  private async unload(): Promise<UnloadedResponse> {
    if (this.model) {
      // Dispose of model resources
      if (this.model.dispose) {
        await this.model.dispose();
      }
      this.model = null;
      this.modelId = null;
      this.dims = 0;
    }

    // Force garbage collection if available
    if ((globalThis as any).gc) {
      (globalThis as any).gc();
    }

    return { type: 'Unloaded' };
  }

  private estimateMemoryUsage(): number {
    // Rough estimate based on model size
    // This is a placeholder - actual memory usage varies
    const baseMemory = 50 * 1024 * 1024; // 50MB base
    const dimMemory = this.dims * 1024 * 1024; // 1MB per dimension
    return baseMemory + dimMemory;
  }
}

// Worker instance
const worker = new EmbeddingWorker();

// Message handler
self.onmessage = async (event: MessageEvent<WorkerMessage>) => {
  const response = await worker.handleMessage(event.data);
  
  // Transfer ArrayBuffers for efficiency
  if (response.type === 'Embedded') {
    self.postMessage(response, [response.vectors.buffer]);
  } else {
    self.postMessage(response);
  }
};