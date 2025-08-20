/**
 * CRC32 implementation for data integrity
 */

const CRC32_TABLE = new Uint32Array(256);

// Initialize CRC32 table
for (let i = 0; i < 256; i++) {
  let c = i;
  for (let j = 0; j < 8; j++) {
    c = (c & 1) ? (0xEDB88320 ^ (c >>> 1)) : (c >>> 1);
  }
  CRC32_TABLE[i] = c >>> 0;
}

export function crc32(data: Uint8Array): number {
  let crc = 0xFFFFFFFF;
  
  for (let i = 0; i < data.length; i++) {
    crc = (CRC32_TABLE[(crc ^ data[i]) & 0xFF] ^ (crc >>> 8)) >>> 0;
  }
  
  return (crc ^ 0xFFFFFFFF) >>> 0;
}