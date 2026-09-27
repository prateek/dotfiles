import { actionArguments, browserError, createObserver, decodeObservation } from "./dom.mjs";

function unwrap(response) {
  if (!response || response.success !== true || !response.data || typeof response.data !== "object"
      || response.data.success === false || response.data.error) throw browserError("browser_command_failed");
  return response.data;
}

export function createAgentBrowserAdapter(browser, { command }) {
  const expression = createObserver();
  const config = browser.config ? ["--config", browser.config] : [];
  const flags = [...config, "--session", browser.session, "--pin-tab", "--json"];
  const invoke = async (args, signal) => unwrap(await command("agent-browser", [...flags, ...args], { signal }));
  const identity = async (signal) => {
    const { sessions } = unwrap(await command("agent-browser", [...config, "session", "list", "--json"], { signal }));
    if (!Array.isArray(sessions) || !sessions.includes(browser.session)) throw browserError("browser_session_missing");
    const { tabs } = await invoke(["tab", "list"], signal);
    const active = Array.isArray(tabs) ? tabs.filter((tab) => tab.active === true) : [];
    if (active.length !== 1 || active[0].targetId !== browser.pageId) throw browserError("browser_identity_mismatch");
    return active[0];
  };
  return {
    async observe(job, { signal } = {}) {
      await identity(signal);
      const result = await invoke(["eval", expression(job)], signal);
      const observed = decodeObservation(result.result);
      await identity(signal);
      return observed;
    },
    async execute(action, { signal } = {}) {
      await identity(signal);
      await invoke(actionArguments(action, false), signal);
      await identity(signal);
      return { accepted: true };
    },
  };
}
