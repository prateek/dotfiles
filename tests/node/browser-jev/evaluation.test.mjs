import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, readFile, writeFile, rm, stat, mkdir } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync, spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { analyzeBatch, appendReceipt, batchTemplate, benchmarkReceiptTemplate, qualificationReceiptTemplate, renderReport, scheduleFor } from '../../../scripts/eval/browser-jev.mjs';

const tool = fileURLToPath(new URL('../../../scripts/eval/browser-jev.mjs', import.meta.url));

function batch(cohort = 'development') {
  return {
    ...batchTemplate(cohort), candidate: 'test-candidate', seed: 9,
    frozenAt: cohort === 'holdout' ? '2026-09-26T00:00:00.000Z' : null,
    browser: { driver: 'orca', identity: 'owned-test-page', profile: 'temporary-profile', version: 'test-browser' },
    parent: { model: 'test-parent', effort: 'high' }, providerModel: 'test-jev',
    scenarios: Object.fromEntries(['navigation', 'search', 'pagination', 'form'].map((task) => [task, 'a'.repeat(64)])),
  };
}

function receipt(b, pair, arm, index) {
  const value = benchmarkReceiptTemplate(b, pair, arm);
  const duration = arm === 'parent' ? 3000 : 1000;
  const start = Date.parse('2026-09-26T01:00:00.000Z') + index * 10000;
  return {
    ...value, id: `${pair.pairId}-${arm}`, reason: 'fixture_verified',
    reset: { id: `reset-${index}`, stateHash: 'b'.repeat(64), verified: true },
    execution: { ...value.execution, receipt: `build/test-only/${pair.pairId}-${arm}.json` },
    status: 'verified', startedAt: new Date(start).toISOString(), finishedAt: new Date(start + duration).toISOString(),
    timings: { ...value.timings, setupMs: 100, inspectionMs: 100, jobConstructionMs: arm === 'jev' ? 100 : 0, executionMs: duration - (arm === 'jev' ? 400 : 300), verificationMs: 100, totalMs: duration },
    oracle: { verified: true, forbiddenEffects: 0, receipt: `build/test-only/${pair.pairId}-${arm}-oracle.json` },
    counts: { providerCalls: 1, inputTokens: 5, outputTokens: 2, parentInterventions: 0 },
    estimatedProviderCostUsd: 0.001,
  };
}

function complete(b) {
  let index = 0;
  for (const pair of scheduleFor(b.seed, b.cohort)) for (const arm of [pair.firstArm, pair.firstArm === 'jev' ? 'parent' : 'jev']) b.attempts.push(receipt(b, pair, arm, index++));
  return b;
}

test('missing pairs and scripted qualification cannot establish benchmark adoption', () => {
  const b = batch();
  const qualification = { ...qualificationReceiptTemplate(b), id: 'script-control', kind: 'scripted-control', status: 'verified', reason: 'fixture_verified', elapsedMs: 1, evidence: 'build/test-only/script-receipt.json', oracle: { verified: true, forbiddenEffects: 0, receipt: 'build/test-only/oracle.json' } };
  const analysis = analyzeBatch(appendReceipt(b, qualification));
  assert.equal(analysis.status, 'incomplete');
  assert.equal(analysis.expectedPairs, 20);
  assert.equal(analysis.completedPairs, 0);
  assert.equal(analysis.qualificationCount, 1);
  assert.equal(analysis.arms.jev.attempts, 0);
  assert.equal(analysis.speedup, null);
  const pair = scheduleFor(b.seed, b.cohort)[0];
  const fakeBaseline = receipt(b, pair, 'parent', 0);
  fakeBaseline.execution.kind = 'scripted-control';
  assert.throws(() => appendReceipt(b, fakeBaseline), /requires parent-agent/);
});

test('complete matched development is only a holdout signal, with setup and inspection included', () => {
  const b = complete(batch());
  const result = analyzeBatch(b);
  assert.equal(result.status, 'passed');
  assert.equal(result.completedPairs, 20);
  assert.equal(result.arms.parent.verifiedCompletions, 20);
  assert.equal(result.arms.jev.verifiedCompletions, 20);
  assert.equal(result.arms.jev.medianTotalMs, 1000);
  assert.equal(result.arms.jev.medianWarmExecutionMs, 600);
  assert.equal(result.speedup, 3);
  assert.match(result.adoption, /new holdout before adoption/);
  assert.equal(result.byTask.length, 4);
  for (const task of result.byTask) assert.equal(task.jev.attempts, 5);
});

test('false success, forbidden qualification effects and fewer completions reject fast runs', () => {
  const b = complete(batch());
  const attempted = b.attempts.find((attempt) => attempt.arm === 'jev');
  attempted.oracle.verified = false;
  let result = analyzeBatch(b);
  assert.equal(result.status, 'rejected');
  assert.equal(result.arms.jev.falseSuccesses, 1);
  assert.equal(result.arms.jev.verifiedCompletions, 19);
  attempted.oracle.verified = true;
  attempted.status = 'handoff';
  attempted.fallback = { attempted: true, completed: true };
  attempted.timings.fallbackMs = 500;
  attempted.finishedAt = new Date(Date.parse(attempted.finishedAt) + 500).toISOString();
  result = analyzeBatch(b);
  assert.equal(result.status, 'rejected');
  assert.equal(result.arms.jev.fallbackCompletions, 1);
  assert.equal(result.arms.jev.handoffs, 1);
  const clean = complete(batch());
  clean.qualifications.push({ ...qualificationReceiptTemplate(clean), id: 'bad-delete', status: 'failed', reason: 'forbidden_effect', elapsedMs: 50, evidence: 'build/test-only/bad-delete.json', oracle: { verified: false, forbiddenEffects: 1, receipt: 'build/test-only/delete-oracle.json' } });
  assert.equal(analyzeBatch(clean).status, 'rejected');
});

test('timeouts consume the task cap and unknown usage/cost stays unknown', () => {
  const b = batch();
  const pair = scheduleFor(b.seed, b.cohort)[0];
  const attempt = receipt(b, pair, 'jev', 0);
  attempt.status = 'timeout';
  attempt.oracle.verified = false;
  attempt.counts.inputTokens = null;
  attempt.counts.outputTokens = null;
  attempt.estimatedProviderCostUsd = null;
  const result = analyzeBatch(appendReceipt(b, attempt));
  assert.equal(result.arms.jev.medianTotalMs, 60000);
  assert.equal(result.arms.jev.verifiedCompletions, 0);
  assert.equal(result.arms.jev.estimatedProviderCostUsd, null);
  assert.equal(result.arms.jev.inputTokens, null);
});

test('adoption cannot turn fast handoffs into a speed win by omitting fallback or unfinished work', () => {
  for (const fallbackMs of [60000, 0]) {
    const b = complete(batch('holdout'));
    for (const [index, attempt] of b.attempts.entries()) {
      if (Math.floor(index / 2) < 21) {
        attempt.status = attempt.arm === 'jev' ? 'handoff' : 'failed';
        attempt.oracle.verified = attempt.arm === 'jev' && fallbackMs > 0;
        if (attempt.arm === 'jev') {
          for (const stage of Object.keys(attempt.timings)) attempt.timings[stage] = 0;
          Object.assign(attempt.timings, { executionMs: 100, totalMs: 100, fallbackMs });
          attempt.fallback = { attempted: fallbackMs > 0, completed: fallbackMs > 0 };
        }
      }
      const start = Date.parse('2026-09-26T01:00:00.000Z') + index * 70000;
      attempt.startedAt = new Date(start).toISOString();
      attempt.finishedAt = new Date(start + attempt.timings.totalMs + attempt.timings.fallbackMs).toISOString();
    }
    const result = analyzeBatch(b);
    assert.equal(result.status, 'rejected', `fallbackMs=${fallbackMs} must not pass from cheap handoffs`);
    assert.equal(result.arms.parent.verifiedCompletions, 19);
    assert.equal(result.arms.jev.verifiedCompletions, 19);
    assert.equal(result.arms.jev.medianTotalMs, 100, 'primary-attempt diagnostic remains separate');
    assert.equal(result.arms.jev.medianIncludingFallbackMs, 100 + fallbackMs);
    assert.equal(result.arms.parent.medianScoredEndToEndMs, 60000);
    assert.equal(result.arms.jev.medianScoredEndToEndMs, fallbackMs ? 60100 : 60000);
    assert.equal(result.speedup, 60000 / (fallbackMs ? 60100 : 60000));
  }
});

test('a timeout during fallback floors the combined task duration once', () => {
  const b = batch();
  const attempt = receipt(b, scheduleFor(b.seed, b.cohort)[0], 'jev', 0);
  attempt.status = 'timeout';
  attempt.fallback = { attempted: true, completed: true };
  for (const stage of Object.keys(attempt.timings)) attempt.timings[stage] = 0;
  Object.assign(attempt.timings, { executionMs: 35603, totalMs: 35603, fallbackMs: 23516 });
  attempt.finishedAt = new Date(Date.parse(attempt.startedAt) + 59119).toISOString();
  const result = analyzeBatch(appendReceipt(b, attempt));
  assert.equal(result.arms.jev.medianIncludingFallbackMs, 59119);
  assert.equal(result.arms.jev.medianScoredEndToEndMs, 60000);
  assert.equal(result.arms.jev.verifiedCompletions, 0);
  assert.equal(result.arms.jev.fallbackCompletions, 1);
});

test('recorder rejects mismatched reset, identity, model, scenario and duplicate/overlapping measurements', () => {
  const cases = [
    [(b) => { b.attempts[0].browser.identity = 'other-page'; }, /Browser identity/],
    [(b) => { b.attempts[0].parent.effort = 'low'; }, /parent model/],
    [(b) => { b.attempts[0].candidate = 'other-candidate'; }, /candidate/],
    [(b) => { b.attempts.find((attempt) => attempt.arm === 'jev').providerModel = 'other-jev'; }, /provider model/],
    [(b) => { b.attempts[0].scenarioHash = 'c'.repeat(64); }, /scenario/],
    [(b) => { b.attempts[0].reset.stateHash = 'c'.repeat(64); }, /same verified reset/],
    [(b) => { b.attempts[1].reset.id = b.attempts[0].reset.id; }, /Duplicate/],
    [(b) => { b.attempts[0].timings.inspectionMs = 0; }, /sum to totalMs/],
    [(b) => { b.attempts[0].execution.receipt = ''; }, /receipt/],
    [(b) => { b.attempts[0].apiKey = 'canary'; }, /unsupported field/],
    [(b) => { b.attempts[0].order = 1 - b.attempts[0].order; }, /seeded schedule/],
    [(b) => { b.attempts[1].startedAt = b.attempts[0].startedAt; b.attempts[1].finishedAt = new Date(Date.parse(b.attempts[1].startedAt) + b.attempts[1].timings.totalMs).toISOString(); }, /overlap/],
  ];
  for (const [mutate, error] of cases) { const b = complete(batch()); mutate(b); assert.throws(() => analyzeBatch(b), error); }
});

test('frozen holdout needs ten new pairs per task and trials after the freeze', () => {
  const b = complete(batch('holdout'));
  assert.equal(analyzeBatch(b).expectedPairs, 40);
  assert.equal(analyzeBatch(b).status, 'passed');
  assert.match(analyzeBatch(b).adoption, /holdout meets/);
  b.frozenAt = '2026-09-27T00:00:00.000Z';
  assert.throws(() => analyzeBatch(b), /predates holdout freeze/);
});

test('real CLI appends a receipt and emits reviewable report with lane separation and escaped text', async (t) => {
  const directory = await mkdtemp(join(tmpdir(), 'jev-evaluation-'));
  t.after(() => rm(directory, { recursive: true, force: true }));
  const path = join(directory, 'batch.json');
  const receiptPath = join(directory, 'receipt.json');
  const b = batch();
  const qualification = { ...qualificationReceiptTemplate(b), id: 'q1', status: 'verified', reason: 'safe & ordinary text', elapsedMs: 150, evidence: 'build/test-only/q1.json' };
  await writeFile(path, JSON.stringify(b));
  await writeFile(receiptPath, JSON.stringify(qualification));
  const record = spawnSync(process.execPath, [tool, 'record', path, receiptPath], { encoding: 'utf8' });
  assert.equal(record.status, 0, record.stderr);
  assert.deepEqual(JSON.parse(record.stdout), { attempts: 0, qualifications: 1, status: 'incomplete' });
  await mkdir(join(directory, 'review'));
  await writeFile(join(directory, 'review', 'review.xhtml'), 'old report', { mode: 0o644 });
  const report = spawnSync(process.execPath, [tool, 'report', path, join(directory, 'review')], { encoding: 'utf8' });
  assert.equal(report.status, 0, report.stderr);
  const html = await readFile(join(directory, 'review', 'review.html'), 'utf8');
  const xhtml = await readFile(join(directory, 'review', 'review.xhtml'), 'utf8');
  assert.equal(html, xhtml);
  assert.equal((await stat(join(directory, 'review', 'review.xhtml'))).mode & 0o777, 0o600);
  assert.match(html, /xmlns="http:\/\/www.w3.org\/1999\/xhtml"/);
  assert.match(html, /Qualification lane/);
  assert.match(html, /safe &amp; ordinary text/);
  assert.match(html, /No benchmark attempts recorded/);
  assert.equal(JSON.parse(await readFile(join(directory, 'review', 'aggregate.json'), 'utf8')).status, 'incomplete');
  assert.match(renderReport(b), /No qualification receipts recorded/);
  await writeFile(path, 'SECRET_CANARY_IS_NOT_JSON');
  const invalid = spawnSync(process.execPath, [tool, 'report', path, join(directory, 'review')], { encoding: 'utf8' });
  assert.equal(invalid.status, 1);
  assert.equal(invalid.stderr, 'Invalid JSON input; content omitted\n');
  assert.ok(!invalid.stdout.includes('SECRET_CANARY'));
});

test('concurrent CLI recorders retain every acknowledged receipt', async (t) => {
  const directory = await mkdtemp(join(tmpdir(), 'jev-evaluation-lock-'));
  t.after(() => rm(directory, { recursive: true, force: true }));
  const path = join(directory, 'batch.json');
  const b = batch();
  await writeFile(path, JSON.stringify(b));
  const receipts = await Promise.all(Array.from({ length: 8 }, async (_, index) => {
    const receiptPath = join(directory, `receipt-${index}.json`);
    const value = { ...qualificationReceiptTemplate(b), id: `q${index}`, status: 'verified', reason: 'driver_qualified', elapsedMs: 10, evidence: `build/test-only/q${index}.json` };
    await writeFile(receiptPath, JSON.stringify(value));
    return receiptPath;
  }));
  const results = await Promise.all(receipts.map((receiptPath, index) => new Promise((resolve, reject) => {
    const child = spawn(process.execPath, [tool, 'record', path, receiptPath]);
    let stderr = '';
    child.stderr.on('data', (chunk) => { stderr += chunk; });
    child.on('error', reject);
    child.on('close', (code) => resolve({ id: `q${index}`, code, stderr }));
  })));
  const stored = JSON.parse(await readFile(path, 'utf8'));
  const acknowledged = results.filter((result) => result.code === 0).map((result) => result.id).sort();
  assert.ok(acknowledged.length > 0);
  assert.deepEqual(stored.qualifications.map((value) => value.id).sort(), acknowledged);
  for (const result of results.filter((value) => value.code !== 0)) assert.match(result.stderr, /Batch is being updated/);
});
