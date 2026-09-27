#!/usr/bin/env node
import { readFile, mkdir, rename, open, unlink } from 'node:fs/promises';
import { resolve, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { isDeepStrictEqual } from 'node:util';

const TASKS = ['navigation', 'search', 'pagination', 'form'];
const STAGES = ['setupMs', 'inspectionMs', 'jobConstructionMs', 'executionMs', 'verificationMs', 'cleanupMs', 'overheadMs'];
const STATUSES = ['verified', 'handoff', 'failed', 'timeout'];
const HELP = `Record and analyze externally measured browser Jev trials. No browser,
model, credential lookup, or network call is performed by this tool.

  node scripts/eval/browser-jev.mjs template development > build/jev-batch.json
  node scripts/eval/browser-jev.mjs template holdout > build/jev-holdout.json
  node scripts/eval/browser-jev.mjs schedule build/jev-batch.json
  node scripts/eval/browser-jev.mjs receipt build/jev-batch.json qualification
  node scripts/eval/browser-jev.mjs receipt build/jev-batch.json search-1/jev
  node scripts/eval/browser-jev.mjs record build/jev-batch.json build/receipt.json
  node scripts/eval/browser-jev.mjs report build/jev-batch.json build/jev-review

Fill every template placeholder before recording trials. Run the printed seeded
schedule in order. Both arms borrow the same explicit page/session and profile.
Reset the fixture before EACH arm; record unique reset IDs and matching initial
state hashes. Include setup, parent inspection, job construction, execution,
independent verification and cleanup in measured totalMs. Stages are exclusive;
overheadMs records the remainder. fallbackMs is additional time after handoff.
Each receipt records start/end timestamps, fixture oracle evidence and a model
transcript or runner receipt. The analyzer checks declarations and arithmetic;
it cannot authenticate a supplied transcript or prove who measured a duration.

Development requires 5 paired repeats of each of 4 tasks; holdout requires 10.
Freeze candidate, scenario hashes and frozenAt before holdout. Never tune using
holdout results; promote a failed case to development and create a new holdout.
Use a separate batch per driver/model/effort combination. Credential variables
belong only to the process running Jev; this recorder never reads environment
credentials and provides no fields for raw page content, prompts, or credentials.
Supply sanitized reasons and evidence paths; free text is not a secret scrubber.

Benchmark receipt fields (all required; see exported benchmarkReceiptTemplate):
  lane,id,pairId,task,cohort,candidate,arm,order,browser,parent,providerModel,scenarioHash,reset,execution,
  status,reason,startedAt,finishedAt,timings,counts,oracle,fallback,estimatedProviderCostUsd

A parent benchmark requires execution.kind=parent-agent and a transcript receipt.
Hardcoded scripts are qualification only, never a parent-model baseline.
Qualification receipt fields (see qualificationReceiptTemplate):
  lane,id,task,kind,browser,status,reason,elapsedMs,evidence,oracle

Reports: review.html, review.xhtml, aggregate.json. An incomplete workload cannot
pass adoption. Qualification rows never enter benchmark medians or pass counts.
Adoption uses totalMs + fallbackMs. Timeouts and uncompleted outcomes consume at
least the full task cap, applied once to that combined duration. Primary-attempt
and warm timings remain separate diagnostics. A handoff is an autonomous failure
even when fallback completes it. A 2x result is specific to this recorded batch.
Concurrent recorders fail explicitly instead of overwriting each other's data.
After a killed recorder, clear its .lock only after confirming it is no longer running.
`;

function fail(message) { throw new Error(message); }
function object(value, name) { if (!value || typeof value !== 'object' || Array.isArray(value)) fail(`${name} must be an object`); }
function keys(value, allowed, name) {
  object(value, name);
  const extra = Object.keys(value).filter((key) => !allowed.includes(key));
  if (extra.length) fail(`${name}: unsupported field`);
  for (const key of allowed) if (!(key in value)) fail(`${name}.${key} is required`);
}
function text(value, name) {
  if (typeof value !== 'string' || !value.trim() || value.length > 500 || /[\r\n\u0000-\u001f]/.test(value) || value.startsWith('<')) fail(`${name} must be filled with a short, single-line value`);
}
function number(value, name, integer = false) {
  if (typeof value !== 'number' || !Number.isFinite(value) || value < 0 || (integer && !Number.isSafeInteger(value))) fail(`${name} must be a nonnegative ${integer ? 'integer' : 'number'}`);
}
function boolean(value, name) { if (typeof value !== 'boolean') fail(`${name} must be boolean`); }
function member(value, choices, name) { if (!choices.includes(value)) fail(`${name} must be one of ${choices.join(', ')}`); }
function hash(value, name) { if (typeof value !== 'string' || !/^[a-f0-9]{64}$/.test(value)) fail(`${name} must be a SHA-256 digest`); }
function timestamp(value, name) { text(value, name); const parsed = Date.parse(value); if (!Number.isFinite(parsed)) fail(`${name} must be a timestamp`); return parsed; }
function equal(left, right) { return isDeepStrictEqual(left, right); }

function browser(value, name) {
  keys(value, ['driver', 'identity', 'profile', 'version'], name);
  member(value.driver, ['orca', 'agent-browser'], `${name}.driver`);
  for (const key of ['identity', 'profile', 'version']) text(value[key], `${name}.${key}`);
}
function parent(value, name) { keys(value, ['model', 'effort'], name); text(value.model, `${name}.model`); text(value.effort, `${name}.effort`); }
function oracle(value, name) {
  keys(value, ['verified', 'forbiddenEffects', 'receipt'], name);
  boolean(value.verified, `${name}.verified`);
  number(value.forbiddenEffects, `${name}.forbiddenEffects`, true);
  text(value.receipt, `${name}.receipt`);
}

export function scheduleFor(seed, cohort) {
  number(seed, 'seed', true);
  if (seed > 0xffffffff) fail('seed must fit in uint32');
  member(cohort, ['development', 'holdout'], 'cohort');
  let state = seed >>> 0;
  const random = () => { state = (Math.imul(state, 1664525) + 1013904223) >>> 0; return state / 0x100000000; };
  const repeats = cohort === 'holdout' ? 10 : 5;
  const pairs = TASKS.flatMap((task) => Array.from({ length: repeats }, (_, index) => ({ pairId: `${task}-${index + 1}`, task })));
  for (let index = pairs.length - 1; index > 0; index -= 1) { const other = Math.floor(random() * (index + 1)); [pairs[index], pairs[other]] = [pairs[other], pairs[index]]; }
  return pairs.map((pair, index) => ({ ...pair, firstArm: index % 2 ? 'jev' : 'parent' }));
}

export function batchTemplate(cohort = 'development') {
  member(cohort, ['development', 'holdout'], 'cohort');
  return {
    version: 1, cohort, candidate: '<git revision and config digest>', seed: 20260926,
    frozenAt: cohort === 'holdout' ? '<ISO timestamp before the first trial>' : null,
    taskBudgetMs: 60000,
    browser: { driver: 'orca', identity: '<explicit page ID or named session>', profile: '<profile identity>', version: '<driver version>' },
    parent: { model: '<parent model>', effort: '<effort setting>' },
    providerModel: '<observed Jev model version>',
    scenarios: Object.fromEntries(TASKS.map((task) => [task, '<SHA-256 of frozen task and verifier>'])),
    attempts: [], qualifications: [],
  };
}

export function benchmarkReceiptTemplate(batch, pair, arm) {
  return {
    lane: 'benchmark', id: '<unique attempt ID>', pairId: pair.pairId, task: pair.task,
    cohort: batch.cohort, candidate: batch.candidate, arm, order: pair.firstArm === arm ? 0 : 1,
    browser: structuredClone(batch.browser), parent: structuredClone(batch.parent), providerModel: arm === 'jev' ? batch.providerModel : null, scenarioHash: batch.scenarios[pair.task],
    reset: { id: '<unique reset receipt ID>', stateHash: '<SHA-256 of reset fixture state>', verified: true },
    execution: { kind: arm === 'parent' ? 'parent-agent' : 'jev-runner', receipt: '<transcript or runner receipt path>' },
    status: 'failed', reason: '<measured outcome>', startedAt: '<ISO timestamp>', finishedAt: '<ISO timestamp>',
    timings: { ...Object.fromEntries(STAGES.map((stage) => [stage, 0])), totalMs: 0, fallbackMs: 0 },
    counts: { providerCalls: 0, inputTokens: null, outputTokens: null, parentInterventions: 0 },
    oracle: { verified: false, forbiddenEffects: 0, receipt: '<independent fixture oracle receipt path>' },
    fallback: { attempted: false, completed: false }, estimatedProviderCostUsd: null,
  };
}

export function qualificationReceiptTemplate(batch) {
  return { lane: 'qualification', id: '<unique qualification ID>', task: 'search', kind: 'driver', browser: structuredClone(batch.browser), status: 'failed', reason: '<measured outcome>', elapsedMs: 0, evidence: '<sanitized receipt path>', oracle: null };
}

function validateBatch(batch) {
  keys(batch, ['version', 'cohort', 'candidate', 'seed', 'frozenAt', 'taskBudgetMs', 'browser', 'parent', 'providerModel', 'scenarios', 'attempts', 'qualifications'], 'batch');
  if (batch.version !== 1) fail('Unsupported batch version');
  member(batch.cohort, ['development', 'holdout'], 'cohort');
  text(batch.candidate, 'candidate');
  scheduleFor(batch.seed, batch.cohort);
  if (batch.frozenAt !== null) timestamp(batch.frozenAt, 'frozenAt');
  if (batch.cohort === 'holdout' && batch.frozenAt === null) fail('Holdout requires frozenAt before any trials');
  number(batch.taskBudgetMs, 'taskBudgetMs');
  if (batch.taskBudgetMs <= 0) fail('taskBudgetMs must be positive');
  browser(batch.browser, 'browser'); parent(batch.parent, 'parent'); text(batch.providerModel, 'providerModel');
  keys(batch.scenarios, TASKS, 'scenarios');
  for (const task of TASKS) hash(batch.scenarios[task], `scenarios.${task}`);
  if (!Array.isArray(batch.attempts) || !Array.isArray(batch.qualifications)) fail('attempts and qualifications must be arrays');
}

function validateAttempt(attempt, batch, schedule) {
  keys(attempt, ['lane', 'id', 'pairId', 'task', 'cohort', 'candidate', 'arm', 'order', 'browser', 'parent', 'providerModel', 'scenarioHash', 'reset', 'execution', 'status', 'reason', 'startedAt', 'finishedAt', 'timings', 'counts', 'oracle', 'fallback', 'estimatedProviderCostUsd'], 'attempt');
  if (attempt.lane !== 'benchmark') fail('Only benchmark attempts belong in attempts');
  for (const key of ['id', 'pairId', 'reason']) text(attempt[key], `attempt.${key}`);
  member(attempt.task, TASKS, 'attempt.task'); member(attempt.arm, ['parent', 'jev'], 'attempt.arm');
  if (attempt.cohort !== batch.cohort) fail('Attempt cohort differs from frozen batch');
  if (attempt.candidate !== batch.candidate) fail('Attempt candidate differs from frozen batch');
  const pair = schedule.find((item) => item.pairId === attempt.pairId);
  if (!pair || pair.task !== attempt.task) fail('Attempt does not belong to the seeded task schedule');
  if (attempt.order !== (pair.firstArm === attempt.arm ? 0 : 1)) fail('Attempt order differs from alternating seeded schedule');
  browser(attempt.browser, 'attempt.browser'); parent(attempt.parent, 'attempt.parent');
  if (!equal(attempt.browser, batch.browser) || !equal(attempt.parent, batch.parent)) fail('Browser identity/profile/version or parent model/effort differs from batch');
  if (attempt.providerModel !== (attempt.arm === 'jev' ? batch.providerModel : null)) fail('Observed provider model differs from frozen batch');
  if (attempt.scenarioHash !== batch.scenarios[attempt.task]) fail('Attempt scenario differs from frozen task');
  keys(attempt.reset, ['id', 'stateHash', 'verified'], 'attempt.reset');
  text(attempt.reset.id, 'attempt.reset.id'); hash(attempt.reset.stateHash, 'attempt.reset.stateHash');
  if (attempt.reset.verified !== true) fail('A measured trial requires a verified fixture reset');
  keys(attempt.execution, ['kind', 'receipt'], 'attempt.execution'); text(attempt.execution.receipt, 'attempt.execution.receipt');
  const executionKind = attempt.arm === 'parent' ? 'parent-agent' : 'jev-runner';
  if (attempt.execution.kind !== executionKind) fail(`Benchmark ${attempt.arm} requires ${executionKind}; scripted controls are qualification only`);
  member(attempt.status, STATUSES, 'attempt.status');
  const start = timestamp(attempt.startedAt, 'attempt.startedAt');
  const finish = timestamp(attempt.finishedAt, 'attempt.finishedAt');
  if (finish < start || (batch.frozenAt && start < Date.parse(batch.frozenAt))) fail('Invalid trial times or trial predates holdout freeze');
  keys(attempt.timings, [...STAGES, 'totalMs', 'fallbackMs'], 'attempt.timings');
  for (const [key, value] of Object.entries(attempt.timings)) number(value, `attempt.timings.${key}`);
  const sum = STAGES.reduce((total, stage) => total + attempt.timings[stage], 0);
  if (Math.abs(sum - attempt.timings.totalMs) > 1) fail('Exclusive stage durations must sum to totalMs');
  if (Math.abs((finish - start) - attempt.timings.totalMs - attempt.timings.fallbackMs) > 1000) fail('Trial timestamps disagree with total plus fallback time');
  if (attempt.status === 'verified' && attempt.timings.totalMs > batch.taskBudgetMs) fail('A completion beyond the task cap must be recorded as timeout');
  keys(attempt.counts, ['providerCalls', 'inputTokens', 'outputTokens', 'parentInterventions'], 'attempt.counts');
  for (const [key, value] of Object.entries(attempt.counts)) if (value !== null || !['inputTokens', 'outputTokens'].includes(key)) number(value, `attempt.counts.${key}`, true);
  oracle(attempt.oracle, 'attempt.oracle');
  keys(attempt.fallback, ['attempted', 'completed'], 'attempt.fallback');
  boolean(attempt.fallback.attempted, 'attempt.fallback.attempted'); boolean(attempt.fallback.completed, 'attempt.fallback.completed');
  if (attempt.fallback.completed && !attempt.fallback.attempted) fail('Fallback completion requires a fallback attempt');
  if (attempt.status === 'verified' && attempt.fallback.attempted) fail('A result requiring fallback cannot be an autonomous verified completion');
  if (!attempt.fallback.attempted && attempt.timings.fallbackMs !== 0) fail('Fallback duration without a fallback attempt');
  if (attempt.estimatedProviderCostUsd !== null) number(attempt.estimatedProviderCostUsd, 'attempt.estimatedProviderCostUsd');
}

function validateQualification(receipt) {
  keys(receipt, ['lane', 'id', 'task', 'kind', 'browser', 'status', 'reason', 'elapsedMs', 'evidence', 'oracle'], 'qualification');
  if (receipt.lane !== 'qualification') fail('Qualification lane required');
  member(receipt.task, TASKS, 'qualification.task'); member(receipt.kind, ['driver', 'task', 'harness-invocation', 'scripted-control'], 'qualification.kind');
  for (const key of ['id', 'reason', 'evidence']) text(receipt[key], `qualification.${key}`);
  browser(receipt.browser, 'qualification.browser'); member(receipt.status, STATUSES, 'qualification.status'); number(receipt.elapsedMs, 'qualification.elapsedMs');
  if (receipt.oracle !== null) oracle(receipt.oracle, 'qualification.oracle');
}

function median(values) { if (!values.length) return null; const sorted = [...values].sort((a, b) => a - b); const middle = Math.floor(sorted.length / 2); return sorted.length % 2 ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2; }
function successful(attempt) { return attempt.status === 'verified' && attempt.oracle.verified && attempt.oracle.forbiddenEffects === 0 && attempt.counts.parentInterventions === 0; }
function scoreTime(attempt, budget) { return attempt.status === 'timeout' ? Math.max(budget, attempt.timings.totalMs) : attempt.timings.totalMs; }
function scoreEndToEnd(attempt, budget) {
  const elapsed = attempt.timings.totalMs + attempt.timings.fallbackMs;
  const completed = attempt.oracle.verified && attempt.oracle.forbiddenEffects === 0
    && (attempt.status === 'verified' || attempt.fallback.completed);
  return attempt.status === 'timeout' || !completed ? Math.max(budget, elapsed) : elapsed;
}

function summarize(attempts, budget) {
  const sum = (selector) => attempts.reduce((total, attempt) => total + selector(attempt), 0);
  return {
    attempts: attempts.length, verifiedCompletions: attempts.filter(successful).length,
    claimedCompletions: attempts.filter((attempt) => attempt.status === 'verified').length,
    falseSuccesses: attempts.filter((attempt) => attempt.status === 'verified' && !attempt.oracle.verified).length,
    forbiddenEffects: sum((attempt) => attempt.oracle.forbiddenEffects),
    handoffs: attempts.filter((attempt) => attempt.status === 'handoff').length,
    timeouts: attempts.filter((attempt) => attempt.status === 'timeout').length,
    parentInterventions: sum((attempt) => attempt.counts.parentInterventions),
    fallbackAttempts: attempts.filter((attempt) => attempt.fallback.attempted).length,
    fallbackCompletions: attempts.filter((attempt) => attempt.fallback.completed).length,
    providerCalls: sum((attempt) => attempt.counts.providerCalls),
    inputTokens: attempts.every((attempt) => attempt.counts.inputTokens !== null) ? sum((attempt) => attempt.counts.inputTokens) : null,
    outputTokens: attempts.every((attempt) => attempt.counts.outputTokens !== null) ? sum((attempt) => attempt.counts.outputTokens) : null,
    estimatedProviderCostUsd: attempts.every((attempt) => attempt.estimatedProviderCostUsd !== null) ? sum((attempt) => attempt.estimatedProviderCostUsd) : null,
    medianTotalMs: median(attempts.map((attempt) => scoreTime(attempt, budget))),
    medianWarmExecutionMs: median(attempts.map((attempt) => attempt.timings.executionMs)),
    medianIncludingFallbackMs: median(attempts.map((attempt) => attempt.timings.totalMs + attempt.timings.fallbackMs)),
    medianScoredEndToEndMs: median(attempts.map((attempt) => scoreEndToEnd(attempt, budget))),
    stagesTotalMs: Object.fromEntries(STAGES.map((stage) => [stage, sum((attempt) => attempt.timings[stage])])),
  };
}

export function analyzeBatch(batch) {
  validateBatch(batch);
  const schedule = scheduleFor(batch.seed, batch.cohort);
  const ids = new Set();
  const resetIds = new Set();
  const pairArms = new Set();
  for (const attempt of batch.attempts) {
    validateAttempt(attempt, batch, schedule);
    if (ids.has(attempt.id) || resetIds.has(attempt.reset.id) || pairArms.has(`${attempt.pairId}/${attempt.arm}`)) fail('Duplicate attempt, reset receipt, or pair arm; retain reruns in a separate batch');
    ids.add(attempt.id); resetIds.add(attempt.reset.id); pairArms.add(`${attempt.pairId}/${attempt.arm}`);
  }
  for (const receipt of batch.qualifications) { validateQualification(receipt); if (ids.has(receipt.id)) fail('Duplicate receipt ID'); ids.add(receipt.id); }
  const ordered = [];
  const pairs = schedule.map((pair) => {
    const attempts = batch.attempts.filter((attempt) => attempt.pairId === pair.pairId).sort((a, b) => a.order - b.order);
    ordered.push(...attempts);
    if (attempts.length === 2 && attempts[0].reset.stateHash !== attempts[1].reset.stateHash) fail('Paired arms did not start from the same verified reset state');
    return { ...pair, complete: attempts.length === 2, parent: attempts.find((attempt) => attempt.arm === 'parent')?.id ?? null, jev: attempts.find((attempt) => attempt.arm === 'jev')?.id ?? null };
  });
  for (let index = 1; index < ordered.length; index += 1) if (Date.parse(ordered[index - 1].finishedAt) > Date.parse(ordered[index].startedAt)) fail('Trials overlap or were run outside the seeded order');
  const arms = Object.fromEntries(['parent', 'jev'].map((arm) => [arm, summarize(batch.attempts.filter((attempt) => attempt.arm === arm), batch.taskBudgetMs)]));
  const byTask = TASKS.map((task) => ({ task, ...Object.fromEntries(['parent', 'jev'].map((arm) => [arm, summarize(batch.attempts.filter((attempt) => attempt.arm === arm && attempt.task === task), batch.taskBudgetMs)])) }));
  const missing = pairs.filter((pair) => !pair.complete).map((pair) => pair.pairId);
  const speedup = arms.jev.medianScoredEndToEndMs > 0 ? arms.parent.medianScoredEndToEndMs / arms.jev.medianScoredEndToEndMs : null;
  const violations = [];
  if (arms.parent.falseSuccesses + arms.jev.falseSuccesses > 0) violations.push('At least one claimed completion failed the independent oracle.');
  if (arms.parent.forbiddenEffects + arms.jev.forbiddenEffects > 0) violations.push('At least one unauthorized effect was recorded.');
  if (batch.qualifications.some((receipt) => receipt.oracle?.forbiddenEffects > 0 || (receipt.status === 'verified' && receipt.oracle?.verified === false))) violations.push('Qualification evidence includes a false success or unauthorized effect.');
  if (!missing.length && arms.jev.verifiedCompletions < arms.parent.verifiedCompletions) violations.push('Jev completed fewer tasks autonomously than the parent baseline.');
  if (!missing.length && (!Number.isFinite(speedup) || speedup < 2)) violations.push('Median end-to-end speedup is below 2x.');
  if (!missing.length && arms.jev.verifiedCompletions === 0) violations.push('No Jev task completed autonomously.');
  const status = violations.length ? 'rejected' : missing.length ? 'incomplete' : 'passed';
  return { version: 1, cohort: batch.cohort, candidate: batch.candidate, expectedPairs: schedule.length, completedPairs: pairs.length - missing.length, status, speedup, violations, missingPairs: missing, arms, byTask, pairs, qualificationCount: batch.qualifications.length, adoption: status === 'passed' ? (batch.cohort === 'holdout' ? 'Recorded holdout meets the opt-in trial gate; evidence references still need review.' : 'Development signal passed; freeze candidate and run a new holdout before adoption.') : 'Adoption is not established by this batch.' };
}

export function appendReceipt(batch, receipt) {
  const updated = structuredClone(batch);
  if (receipt.lane === 'benchmark') updated.attempts.push(receipt);
  else if (receipt.lane === 'qualification') updated.qualifications.push(receipt);
  else fail('Receipt lane must be benchmark or qualification');
  analyzeBatch(updated);
  return updated;
}

const escape = (value) => String(value ?? 'unknown').replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;').replaceAll("'", '&#39;');
const display = (value) => value === null ? 'unknown' : typeof value === 'number' ? Number(value.toFixed(2)).toLocaleString('en-US') : value;

export function renderReport(batch, aggregate = analyzeBatch(batch)) {
  const rows = batch.attempts.map((attempt) => `<tr><td>${escape(attempt.pairId)}</td><td>${escape(attempt.arm)}</td><td>${escape(attempt.status)}</td><td>${successful(attempt) ? 'yes' : 'no'}</td><td>${escape(display(scoreEndToEnd(attempt, batch.taskBudgetMs)))}</td><td>${escape(display(attempt.timings.fallbackMs))}</td><td>${attempt.oracle.forbiddenEffects}</td><td>${escape(attempt.reason)}<br /><small>${escape(attempt.execution.receipt)}<br />Oracle: ${escape(attempt.oracle.receipt)}</small></td></tr>`).join('');
  const qualificationRows = batch.qualifications.map((receipt) => `<tr><td>${escape(receipt.id)}</td><td>${escape(receipt.kind)}</td><td>${escape(receipt.browser.driver)}</td><td>${escape(receipt.status)}</td><td>${escape(display(receipt.elapsedMs))}</td><td>${escape(receipt.reason)}<br /><small>${escape(receipt.evidence)}</small></td></tr>`).join('');
  const comparisons = ['attempts', 'verifiedCompletions', 'falseSuccesses', 'forbiddenEffects', 'handoffs', 'timeouts', 'parentInterventions', 'fallbackAttempts', 'fallbackCompletions', 'providerCalls', 'inputTokens', 'outputTokens', 'estimatedProviderCostUsd', 'medianTotalMs', 'medianWarmExecutionMs', 'medianIncludingFallbackMs', 'medianScoredEndToEndMs'];
  const metrics = comparisons.map((key) => `<tr><th scope="row">${escape(key)}</th><td>${escape(display(aggregate.arms.parent[key]))}</td><td>${escape(display(aggregate.arms.jev[key]))}</td></tr>`).join('');
  const tasks = aggregate.byTask.map((task) => `<tr><th scope="row">${escape(task.task)}</th><td>${task.parent.verifiedCompletions}/${task.parent.attempts}</td><td>${task.jev.verifiedCompletions}/${task.jev.attempts}</td><td>${escape(display(task.parent.medianScoredEndToEndMs))}</td><td>${escape(display(task.jev.medianScoredEndToEndMs))}</td></tr>`).join('');
  const stages = STAGES.map((stage) => `<tr><th scope="row">${stage}</th><td>${escape(display(aggregate.arms.parent.stagesTotalMs[stage]))}</td><td>${escape(display(aggregate.arms.jev.stagesTotalMs[stage]))}</td></tr>`).join('');
  const limitations = aggregate.violations.map((item) => `<li>${escape(item)}</li>`).join('');
  const schedule = aggregate.pairs.map((pair) => `<tr><td>${escape(pair.pairId)}</td><td>${escape(pair.firstArm)}</td><td>${pair.complete ? 'complete' : 'missing arm(s)'}</td><td>${escape(pair.parent ?? 'missing')}</td><td>${escape(pair.jev ?? 'missing')}</td></tr>`).join('');
  return `<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" lang="en"><head><meta charset="utf-8" /><meta name="viewport" content="width=device-width, initial-scale=1" /><title>Jev browser evaluation — ${escape(batch.cohort)}</title><style>body{margin:0;background:#f6f5f1;color:#202a2d;font:16px/1.55 system-ui,sans-serif}main{max-width:1180px;margin:auto;padding:48px 24px}h1{font-size:clamp(2rem,5vw,3.6rem);line-height:1.08;max-width:850px}h2{margin-top:44px}.eyebrow{letter-spacing:.1em;text-transform:uppercase;font-size:.8rem}.verdict{border-left:6px solid #336358;background:#e7efe8;padding:18px 24px}.rejected{border-color:#974037;background:#f4e6e1}.incomplete{border-color:#b98528;background:#f4edda}.table{overflow-x:auto;margin:16px 0}table{border-collapse:collapse;width:100%;font-size:.9rem;background:white}td,th{padding:10px 12px;text-align:left;border-bottom:1px solid #d8dcd8;vertical-align:top}thead{background:#e9edeb}small{color:#52615c;overflow-wrap:anywhere}code{overflow-wrap:anywhere}details{margin:24px 0}summary{font-weight:600;cursor:pointer}.meta{color:#465953}ul{padding-left:24px}@media print{body{background:white}main{padding:0}details{display:block}table{font-size:9pt}h2{break-after:avoid}tr{break-inside:avoid}}</style></head><body><main>
<p class="eyebrow">Browser skill · ${escape(batch.cohort)} evaluation</p><h1>Measured execution, independent verification.</h1>
<div class="verdict ${escape(aggregate.status)}"><strong>${escape(aggregate.status.toUpperCase())}: ${aggregate.completedPairs}/${aggregate.expectedPairs} complete pairs</strong><p>${escape(aggregate.adoption)}</p><p>Scored end-to-end median speedup (including fallback): ${aggregate.speedup === null ? 'not available' : `${escape(display(aggregate.speedup))}x`}. Threshold: 2x, no lower completion count, zero false success and unauthorized effects.</p>${limitations ? `<ul>${limitations}</ul>` : ''}</div>
<p class="meta">Candidate: <code>${escape(batch.candidate)}</code><br />Driver: ${escape(batch.browser.driver)} ${escape(batch.browser.version)} · borrowed ${escape(batch.browser.identity)} · profile ${escape(batch.browser.profile)}<br />Parent: ${escape(batch.parent.model)} / ${escape(batch.parent.effort)} · Jev: ${escape(batch.providerModel)}<br />Seed: ${batch.seed} · budget: ${batch.taskBudgetMs} ms · frozen: ${escape(batch.frozenAt ?? 'development, not frozen')}</p>
<p>This report analyzes supplied receipts. It does not run models, authenticate transcripts, or turn scripted qualification into a parent-model benchmark. Inspect the referenced model and fixture receipts before accepting a result.</p>
<h2>Paired benchmark</h2><p>All recorded attempts count. Adoption compares primary plus fallback time. A timeout or uncompleted outcome is charged at least the task cap, applied once to the combined duration; unfinished tasks are not represented as fast completions. Handoffs and parent intervention remain autonomous failures. medianIncludingFallbackMs is observed combined time; medianScoredEndToEndMs includes these penalties and drives the gate. Primary-attempt and warm timings are diagnostics. Unknown usage or cost stays unknown.</p><div class="table"><table><thead><tr><th>Measure</th><th>Parent model</th><th>Jev runner</th></tr></thead><tbody>${metrics}</tbody></table></div>
<h2>Task outcomes</h2><div class="table"><table><thead><tr><th>Task</th><th>Parent verified</th><th>Jev verified</th><th>Parent scored end-to-end ms</th><th>Jev scored end-to-end ms</th></tr></thead><tbody>${tasks}</tbody></table></div>
<h2>Stage totals</h2><p>Setup, parent inspection, job construction and cleanup are part of end-to-end time. Warm execution is shown separately above.</p><div class="table"><table><thead><tr><th>Stage</th><th>Parent ms</th><th>Jev ms</th></tr></thead><tbody>${stages}</tbody></table></div>
<h2>Every benchmark attempt</h2><div class="table"><table><thead><tr><th>Pair</th><th>Arm</th><th>Reported result</th><th>Autonomous verified</th><th>Scored end-to-end ms</th><th>Fallback ms</th><th>Forbidden</th><th>Reason and evidence</th></tr></thead><tbody>${rows || '<tr><td colspan="8">No benchmark attempts recorded.</td></tr>'}</tbody></table></div>
<h2>Qualification lane</h2><p>These ${aggregate.qualificationCount} observations establish only their stated driver, task or harness behavior. They contribute no benchmark pairs, timing medians, or adoption success.</p><div class="table"><table><thead><tr><th>ID</th><th>Kind</th><th>Driver</th><th>Result</th><th>Elapsed ms</th><th>Evidence</th></tr></thead><tbody>${qualificationRows || '<tr><td colspan="6">No qualification receipts recorded.</td></tr>'}</tbody></table></div>
<details><summary>Seeded trial schedule and missing evidence</summary><div class="table"><table><thead><tr><th>Pair</th><th>First arm</th><th>Pair status</th><th>Parent receipt</th><th>Jev receipt</th></tr></thead><tbody>${schedule}</tbody></table></div></details>
<h2>Next iteration</h2><p>Classify the largest delay or failure from development evidence, state one hypothesis, and change one factor. Re-run the affected development tasks. Freeze candidate and scenario hashes before the holdout. A holdout used for tuning becomes development evidence and must be replaced. A passing development batch is only a signal to attempt that frozen comparison.</p>
</main></body></html>\n`;
}

async function readJson(path) {
  const source = await readFile(path, 'utf8');
  try { return JSON.parse(source); } catch { fail('Invalid JSON input; content omitted'); }
}
async function writePrivate(path, value) {
  const handle = await open(path, 'w', 0o600);
  try { await handle.chmod(0o600); await handle.writeFile(value); } finally { await handle.close(); }
}
async function writeJson(path, value) { await writePrivate(path, `${JSON.stringify(value, null, 2)}\n`); }

async function main(args) {
  const [command, path, destination] = args;
  if (!command || command === '--help' || command === 'help') { process.stdout.write(HELP); return; }
  if (command === 'template') { process.stdout.write(`${JSON.stringify(batchTemplate(path), null, 2)}\n`); return; }
  if (!path) fail('A batch JSON path is required');
  const batch = await readJson(path);
  const aggregate = analyzeBatch(batch);
  if (command === 'schedule') { process.stdout.write(`${JSON.stringify(scheduleFor(batch.seed, batch.cohort), null, 2)}\n`); return; }
  if (command === 'receipt') {
    let template;
    if (destination === 'qualification') template = qualificationReceiptTemplate(batch);
    else {
      const [pairId, arm] = (destination ?? '').split('/');
      member(arm, ['parent', 'jev'], 'receipt arm');
      const pair = scheduleFor(batch.seed, batch.cohort).find((item) => item.pairId === pairId);
      if (!pair) fail('Unknown pair ID');
      template = benchmarkReceiptTemplate(batch, pair, arm);
    }
    process.stdout.write(`${JSON.stringify(template, null, 2)}\n`);
    return;
  }
  if (command === 'record') {
    if (!destination) fail('A receipt JSON path is required');
    const lockPath = `${path}.lock`;
    let lock;
    try { lock = await open(lockPath, 'wx', 0o600); } catch (error) { if (error.code === 'EEXIST') fail('Batch is being updated; retry after the existing recorder finishes'); throw error; }
    const temporary = `${path}.${process.pid}.tmp`;
    try {
      await lock.writeFile(`${process.pid}\n`);
      const updated = appendReceipt(await readJson(path), await readJson(destination));
      await writeJson(temporary, updated);
      await rename(temporary, path);
      process.stdout.write(`${JSON.stringify({ attempts: updated.attempts.length, qualifications: updated.qualifications.length, status: analyzeBatch(updated).status })}\n`);
    } finally {
      await lock.close();
      await unlink(lockPath);
      await unlink(temporary).catch((error) => { if (error.code !== 'ENOENT') throw error; });
    }
    return;
  }
  if (command === 'report') {
    if (!destination) fail('A report output directory is required');
    await mkdir(destination, { recursive: true, mode: 0o700 });
    const report = renderReport(batch, aggregate);
    await writePrivate(join(destination, 'review.html'), report);
    await writePrivate(join(destination, 'review.xhtml'), report);
    await writeJson(join(destination, 'aggregate.json'), aggregate);
    process.stdout.write(`${JSON.stringify({ status: aggregate.status, completedPairs: aggregate.completedPairs, expectedPairs: aggregate.expectedPairs, report: resolve(destination, 'review.html') })}\n`);
    return;
  }
  fail('Unknown command; use --help');
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main(process.argv.slice(2)).catch((error) => { process.stderr.write(`${error.message}\n`); process.exitCode = 1; });
