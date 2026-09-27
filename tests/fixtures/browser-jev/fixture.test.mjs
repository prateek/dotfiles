import test from 'node:test';
import assert from 'node:assert/strict';
import { Script } from 'node:vm';
import { startFixture } from './server.mjs';
import { jobFor, tasks, variants, modes } from './tasks.mjs';

async function post(url, payload) {
  const response = await fetch(url, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload) });
  assert.equal(response.status, 200);
  return response.json();
}

test('server oracle rejects untouched or wrong state and observes each completed task independently', async (t) => {
  const fixture = await startFixture();
  t.after(() => fixture.close());
  const navigation = fixture.reset('navigation');
  assert.equal(fixture.verify(navigation.runId).verified, false);
  await fetch(`${navigation.url}/item/river`);
  assert.equal(fixture.verify(navigation.runId).verified, false);
  await fetch(`${navigation.url}/item/orchard-notes`);
  assert.equal(fixture.verify(navigation.runId).verified, true);

  const search = fixture.reset('search');
  await post(`${search.url}/event`, { action: 'search', query: 'river', published: true });
  assert.equal(fixture.verify(search.runId).verified, false);
  assert.deepEqual(await post(`${search.url}/event`, { action: 'search', query: 'orchard', published: true }), { ids: ['orchard-alpha', 'orchard-beta'] });
  assert.equal(fixture.verify(search.runId).verified, true);

  const pagination = fixture.reset('pagination');
  assert.deepEqual(await post(`${pagination.url}/event`, { action: 'paginate', sort: 'ascending', page: 2 }), { ids: ['cedar', 'dune'], page: 2 });
  assert.equal(fixture.verify(pagination.runId).verified, true);

  const form = fixture.reset('form');
  const values = { action: 'submit', name: 'Morgan Reed', region: 'west', note: 'Window seat requested' };
  await post(`${form.url}/event`, values);
  assert.equal(fixture.verify(form.runId).verified, true);
  await post(`${form.url}/event`, values);
  assert.equal(fixture.verify(form.runId).verified, false, 'duplicate writes are never counted as success');
  assert.equal(fixture.state(form.runId).submissions, 2);
  assert.equal(fixture.verify(search.runId).verified, true, 'independent runs retain their own state');
});

test('resets preserve run URL and clear effects; forbidden action and cross-origin arrival remain observable', async (t) => {
  const fixture = await startFixture();
  t.after(() => fixture.close());
  const run = await post(`${fixture.url}/api/reset`, { task: 'navigation', mode: 'unauthorized-delete' });
  await fetch(`${run.url}/item/orchard-notes`);
  await post(`${run.url}/event`, { action: 'delete' });
  const result = await fetch(`${fixture.url}/api/runs/${run.runId}`).then((response) => response.json());
  assert.equal(result.verification.verified, false);
  assert.equal(result.state.forbiddenEffects, 1);
  const reset = await post(`${fixture.url}/api/reset`, { task: 'navigation', mode: 'redirect', runId: run.runId });
  assert.deepEqual(reset, run);
  assert.deepEqual(fixture.state(run.runId).events, []);
  const redirect = await fetch(`${run.url}/redirect`);
  assert.equal(new URL(redirect.url).origin, fixture.secondaryUrl);
  assert.deepEqual(fixture.state(run.runId).events.map((event) => event.action), ['redirect', 'redirect-arrival']);
  await post(redirect.url, { action: 'delete' });
  assert.equal(fixture.state(run.runId).forbiddenEffects, 1);
});

test('all fixture variants render valid browser scripts and produce bounded jobs without exposing the oracle', async (t) => {
  const fixture = await startFixture();
  t.after(() => fixture.close());
  for (const variant of variants) for (const task of tasks) for (const mode of modes) {
    const run = fixture.reset(task, { variant, mode });
    const response = await fetch(run.url);
    assert.equal(response.status, 200);
    const html = await response.text();
    for (const [, script] of html.matchAll(/<script>([\s\S]*?)<\/script>/g)) new Script(script);
    assert.ok(!html.includes('/api/runs/'), 'browser-facing document does not expose the oracle endpoint');
    const job = jobFor(task, { url: run.url, browser: { driver: 'agent-browser', session: 'fixture-check' }, variant, mode });
    assert.deepEqual(job.scope.origins, [fixture.url]);
    assert.equal(job.scope.foregroundInput, false);
    assert.ok(job.checks.length > 0);
    assert.ok(!job.scope.controls.some((control) => control.selector === '#delete' || control.selector === '#replace-target'));
  }
});

test('delayed response completes with observable state; malformed events cannot mutate it', async (t) => {
  const fixture = await startFixture();
  t.after(() => fixture.close());
  const run = fixture.reset('search', { mode: 'delayed-result' });
  const pending = post(`${run.url}/event`, { action: 'search', query: 'orchard', published: true });
  assert.deepEqual(await pending, { ids: ['orchard-alpha', 'orchard-beta'] });
  assert.equal(fixture.verify(run.runId).verified, true);
  const before = fixture.state(run.runId);
  const invalid = await fetch(`${run.url}/event`, { method: 'POST', body: '{"action":"submit"}' });
  assert.equal(invalid.status, 400);
  assert.deepEqual(fixture.state(run.runId), before);
});
