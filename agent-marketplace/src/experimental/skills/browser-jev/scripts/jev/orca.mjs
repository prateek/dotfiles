import { actionArguments, browserError, createObserver, decodeObservation } from "./dom.mjs";

function unwrap(response) {
  if (!response || response.ok !== true || !response.result || typeof response.result !== "object"
      || response.result.success === false || response.result.ok === false || response.result.error) {
    throw browserError("browser_command_failed");
  }
  return response.result;
}

export function createOrcaAdapter(browser, { command }) {
  const executable = process.env.ORCA_CLI_COMMAND
    || (process.env.ORCA_DEV_REPO_ROOT ? "orca-dev" : process.platform === "linux" && !process.env.ORCA_WORKTREE_ID ? "orca-ide" : "orca");
  const expression = createObserver();
  let boundIdentity;
  const scoped = ["--page", browser.pageId, "--worktree", browser.worktree, "--json"];
  const invoke = async (args, signal) => unwrap(await command(executable, [...args, ...scoped], { signal }));
  const identity = async (signal) => {
    const status = unwrap(await command(executable, ["status", "--json"], { signal }));
    const runtime = status.runtime;
    if (runtime?.reachable !== true || runtime.state !== "ready"
        || typeof runtime.runtimeId !== "string" || !runtime.runtimeId.trim()) throw browserError("browser_runtime_unavailable");
    const requiresForeground = !(status.app?.desktopWindowStatus === "openable" && status.graph?.state === "ready"
      && Array.isArray(runtime.capabilities) && runtime.capabilities.includes("browser.headless.v1"));
    const { tab } = await invoke(["tab", "show"], signal);
    if (!tab || tab.browserPageId !== browser.pageId || typeof tab.worktreeId !== "string") throw browserError("browser_identity_mismatch");
    if (browser.worktree.startsWith("id:") && browser.worktree.slice(3) !== tab.worktreeId) throw browserError("browser_identity_mismatch");
    const currentIdentity = JSON.stringify([runtime.runtimeId, requiresForeground, tab.worktreeId, tab.profileId ?? null]);
    if (boundIdentity !== undefined && boundIdentity !== currentIdentity) throw browserError("browser_identity_mismatch");
    boundIdentity = currentIdentity;
    return { ...tab, requiresForeground };
  };
  return {
    async observe(job, { signal } = {}) {
      const before = await identity(signal);
      const result = await invoke(["eval", "--expression", expression(job)], signal);
      const observed = decodeObservation(result.result);
      const after = await identity(signal);
      if (before.worktreeId !== after.worktreeId || before.profileId !== after.profileId
          || typeof result.origin !== "string" || result.origin !== observed.url) throw browserError("browser_identity_mismatch");
      return { ...observed, requiresForeground: after.requiresForeground };
    },
    async execute(action, { signal } = {}) {
      await identity(signal);
      await invoke(actionArguments(action, true), signal);
      await identity(signal);
      return { accepted: true };
    },
  };
}
