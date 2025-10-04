#!/usr/bin/env node

/**
 * Custom JSON formatter inspired by Clojure formatting conventions
 * - Compact formatting for small objects/arrays
 * - Aligned key-value pairs
 * - Minimal vertical space usage
 */

const fs = require('fs');

function formatJSON(obj, indent = 0, maxLineLength = 100) {
  const spaces = ' '.repeat(indent);
  
  if (obj === null || obj === undefined) {
    return 'null';
  }
  
  if (typeof obj !== 'object') {
    return JSON.stringify(obj);
  }
  
  if (Array.isArray(obj)) {
    // Try inline first
    const inline = '[' + obj.map(item => formatJSON(item, 0, maxLineLength)).join(', ') + ']';
    if (inline.length + indent <= maxLineLength && !inline.includes('\n')) {
      return inline;
    }
    
    // Otherwise, format vertically
    const items = obj.map((item, i) => {
      const formatted = formatJSON(item, indent + 2, maxLineLength);
      return spaces + '  ' + formatted;
    });
    return '[\n' + items.join(',\n') + '\n' + spaces + ']';
  }
  
  // Object formatting
  const entries = Object.entries(obj);
  if (entries.length === 0) {
    return '{}';
  }
  
  // Try inline for small objects
  const inline = '{' + entries.map(([k, v]) => 
    `"${k}": ${formatJSON(v, 0, maxLineLength)}`
  ).join(', ') + '}';
  
  if (inline.length + indent <= maxLineLength && !inline.includes('\n')) {
    return inline;
  }
  
  // For larger objects, align values
  const maxKeyLength = Math.max(...entries.map(([k]) => k.length));
  
  const formattedEntries = entries.map(([key, value], i) => {
    const keyPadding = ' '.repeat(maxKeyLength - key.length);
    const formattedValue = formatJSON(value, indent + maxKeyLength + 4, maxLineLength);
    
    // Special handling for arrays and objects to keep them compact
    if (typeof value === 'object' && value !== null && !Array.isArray(value)) {
      const keys = Object.keys(value);
      if (keys.length <= 3) {
        const inlineValue = formatJSON(value, 0, maxLineLength);
        if (inlineValue.length <= 60 && !inlineValue.includes('\n')) {
          return `${spaces}  "${key}"${keyPadding}: ${inlineValue}`;
        }
      }
    }
    
    return `${spaces}  "${key}"${keyPadding}: ${formattedValue}`;
  });
  
  return '{\n' + formattedEntries.join(',\n') + '\n' + spaces + '}';
}

// Read from stdin or file
let input = '';

if (process.argv.length > 2) {
  // Read from file
  input = fs.readFileSync(process.argv[2], 'utf8');
} else {
  // Read from stdin
  process.stdin.setEncoding('utf8');
  process.stdin.on('data', chunk => {
    input += chunk;
  });
  process.stdin.on('end', () => {
    processInput(input);
  });
}

function processInput(jsonString) {
  try {
    const obj = JSON.parse(jsonString);
    const formatted = formatJSON(obj);
    console.log(formatted);
  } catch (error) {
    console.error('Error parsing JSON:', error.message);
    process.exit(1);
  }
}

if (process.argv.length > 2) {
  processInput(input);
}