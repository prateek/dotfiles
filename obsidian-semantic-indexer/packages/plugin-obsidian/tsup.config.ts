import { defineConfig } from 'tsup';

export default defineConfig({
  entry: ['src/main.ts'],
  format: ['cjs'],
  dts: false,
  sourcemap: 'inline',
  clean: true,
  treeshake: true,
  splitting: false,
  target: 'es2022',
  platform: 'browser',
  external: ['obsidian', 'electron', '@codemirror/view', '@codemirror/state'],
  outExtension() {
    return {
      js: '.js'
    };
  },
  esbuildOptions(options) {
    options.outfile = 'main.js';
  }
});