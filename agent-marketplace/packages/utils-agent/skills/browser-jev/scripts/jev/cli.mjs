import { open } from 'node:fs/promises';
import { constants } from 'node:fs';
import { validateJob, runJob } from './runner.mjs';
import { decideWithCloudflare } from './cloudflare.mjs';

export async function runCli(job) {
  job = validateJob(job);
  const { command, claimBrowser } = await import('./process.mjs');
  const cancellation = new AbortController();
  const cancel = () => cancellation.abort();
  process.once('SIGINT', cancel);
  process.once('SIGTERM', cancel);
  let release;
  let result;
  try {
    if (job.browser.driver === 'agent-browser') {
      const file = await open(job.browser.config, constants.O_RDONLY | constants.O_NONBLOCK);
      try {
        const stat = await file.stat();
        if (!stat.isFile() || stat.size > 4096) throw Object.assign(new Error(), { code: 'browser_config_invalid' });
        let config;
        try { config = JSON.parse(await file.readFile('utf8')); }
        catch { throw Object.assign(new Error(), { code: 'browser_config_invalid' }); }
        if (config === null || typeof config !== 'object' || Array.isArray(config) || Object.keys(config).length) throw Object.assign(new Error(), { code: 'browser_config_invalid' });
      } finally { await file.close(); }
    }
    release = await claimBrowser(job.browser);
    const driver = job.browser.driver === 'orca' ? await import('./orca.mjs') : await import('./agent-browser.mjs');
    const browser = job.browser.driver === 'orca' ? driver.createOrcaAdapter(job.browser, { command }) : driver.createAgentBrowserAdapter(job.browser, { command });
    result = await runJob(job, { browser, signal: cancellation.signal,
      decide: (request, { signal }) => decideWithCloudflare(request, {
        token: process.env.CLOUDFLARE_API_TOKEN, accountId: process.env.CLOUDFLARE_ACCOUNT_ID,
        model: job.provider.model, signal,
      }),
    });
  } catch (error) {
    result = { version: 1, status: 'handoff', reason: typeof error.code === 'string' && /^[a-z][a-z0-9_]{0,63}$/.test(error.code) ? error.code : 'execution_failed',
      browser: job.browser, receipts: [], counters: { actions: 0, decisions: 0 } };
  } finally {
    try { await release?.(); }
    catch { result.cleanup = 'browser_lock_release_failed'; }
    process.removeListener('SIGINT', cancel);
    process.removeListener('SIGTERM', cancel);
  }
  return result;
}
