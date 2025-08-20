/**
 * Segment binary format implementation
 * 
 * Format:
 * - Header (little-endian):
 *   - u32 dims
 *   - u32 rows  
 *   - u8 dtype (0=f32, 1=f16)
 *   - u16 modelIdLen
 *   - bytes[modelIdLen] modelId (utf-8)
 * - Payload: row-major vectors (rows × dims × bytesPerScalar)
 * - Trailer: u32 crc32 of (header + payload)
 */

import { DTYPE_SIZES } from './types.js';
import { crc32 } from '../utils/crc32.js';

export const DTYPE_CODES = {
  f32: 0,
  f16: 1
} as const;

export interface SegmentHeader {
  dims: number;
  rows: number;
  dtype: 'f32' | 'f16';
  modelId: string;
}

export class SegmentWriter {
  static write(header: SegmentHeader, vectors: Float32Array | Uint16Array): Uint8Array {
    const modelIdBytes = new TextEncoder().encode(header.modelId);
    const headerSize = 4 + 4 + 1 + 2 + modelIdBytes.length;
    const vectorsSize = header.rows * header.dims * DTYPE_SIZES[header.dtype];
    const totalSize = headerSize + vectorsSize + 4; // +4 for CRC trailer

    const buffer = new ArrayBuffer(totalSize);
    const view = new DataView(buffer);
    const bytes = new Uint8Array(buffer);

    let offset = 0;

    // Write header
    view.setUint32(offset, header.dims, true); offset += 4;
    view.setUint32(offset, header.rows, true); offset += 4;
    view.setUint8(offset, DTYPE_CODES[header.dtype]); offset += 1;
    view.setUint16(offset, modelIdBytes.length, true); offset += 2;
    bytes.set(modelIdBytes, offset); offset += modelIdBytes.length;

    // Write vectors
    if (header.dtype === 'f32' && vectors instanceof Float32Array) {
      const vectorBytes = new Uint8Array(vectors.buffer, vectors.byteOffset, vectors.byteLength);
      bytes.set(vectorBytes, offset);
    } else if (header.dtype === 'f16' && vectors instanceof Uint16Array) {
      const vectorBytes = new Uint8Array(vectors.buffer, vectors.byteOffset, vectors.byteLength);
      bytes.set(vectorBytes, offset);
    } else {
      throw new Error('Vector type mismatch with dtype');
    }
    offset += vectorsSize;

    // Calculate and write CRC32 (excluding the CRC itself)
    const crcValue = crc32(bytes.subarray(0, offset));
    view.setUint32(offset, crcValue, true);

    return bytes;
  }
}

export class SegmentReader {
  static read(data: Uint8Array): { header: SegmentHeader; vectors: Float32Array | Uint16Array; crc: number } {
    const view = new DataView(data.buffer, data.byteOffset, data.byteLength);
    let offset = 0;

    // Read header
    const dims = view.getUint32(offset, true); offset += 4;
    const rows = view.getUint32(offset, true); offset += 4;
    const dtypeCode = view.getUint8(offset); offset += 1;
    const modelIdLen = view.getUint16(offset, true); offset += 2;
    
    const modelIdBytes = data.subarray(offset, offset + modelIdLen);
    const modelId = new TextDecoder().decode(modelIdBytes);
    offset += modelIdLen;

    const dtype = dtypeCode === 0 ? 'f32' : 'f16';
    const header: SegmentHeader = { dims, rows, dtype, modelId };

    // Read vectors
    const vectorsSize = rows * dims * DTYPE_SIZES[dtype];
    let vectors: Float32Array | Uint16Array;
    
    if (dtype === 'f32') {
      vectors = new Float32Array(data.buffer, data.byteOffset + offset, rows * dims);
    } else {
      vectors = new Uint16Array(data.buffer, data.byteOffset + offset, rows * dims);
    }
    offset += vectorsSize;

    // Read and verify CRC
    const storedCrc = view.getUint32(offset, true);
    const calculatedCrc = crc32(data.subarray(0, offset));
    
    if (storedCrc !== calculatedCrc) {
      throw new Error(`CRC mismatch: stored=${storedCrc}, calculated=${calculatedCrc}`);
    }

    return { header, vectors, crc: storedCrc };
  }

  static validate(data: Uint8Array): boolean {
    try {
      this.read(data);
      return true;
    } catch {
      return false;
    }
  }
}