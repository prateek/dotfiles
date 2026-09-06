import { tap } from 'node:test/reporters';

export default async function* requiredTests(source) {
  let passed = 0;
  async function* counted() {
    for await (const event of source) {
      // The aggregate counts an empty file as a passing test. File summaries
      // count tests registered with node:test instead.
      if (event.type === 'test:summary' && event.data.file) {
        passed += event.data.counts.passed;
      }
      yield event;
    }
  }
  yield* tap(counted());
  if (passed === 0) {
    process.stderr.write('No Node tests passed; empty, entirely skipped, or todo-only selection.\n');
    process.exitCode = 1;
  }
}
