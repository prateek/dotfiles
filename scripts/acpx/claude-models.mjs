import { createRequire } from "node:module";
import { dirname, join } from "node:path";
import { existsSync, realpathSync } from "node:fs";
import { pathToFileURL } from "node:url";

let require = createRequire(process.argv[2]);
for (let directory = dirname(process.argv[2]); ; directory = dirname(directory)) {
  const manifest = join(directory, "node_modules/@agentclientprotocol/claude-agent-acp/package.json");
  if (existsSync(manifest)) {
    require = createRequire(realpathSync(manifest));
    break;
  }
  if (dirname(directory) === directory) break;
}
const { query } = await import(pathToFileURL(require.resolve("@anthropic-ai/claude-agent-sdk")));
let finish;
const wait = new Promise((resolve) => { finish = resolve; });
const accountOnly = process.argv.includes("--account-only");
const session = query({
  prompt: (async function* () { await wait; })(),
  options: { cwd: process.cwd(), settingSources: accountOnly ? ["user", "project", "local"] : ["user"],
    persistSession: false, tools: [], mcpServers: {} },
});
try {
  const account = await session.accountInfo();
  const vertex = process.env.CLAUDE_CODE_USE_VERTEX === "1";
  const apiKey = account.apiKeySource && account.apiKeySource !== "none";
  const firstParty = !account.apiProvider || account.apiProvider === "firstParty";
  const access = vertex
    ? (["vertex", "anthropicGoogleCloud"].includes(account.apiProvider) ? "included" : "unknown")
    : (firstParty && apiKey ? "paid" : firstParty && account.subscriptionType ? "included" : "unknown");
  const models = accountOnly ? [] : await session.supportedModels();
  process.stdout.write(JSON.stringify({ access, models: models.map((model) => ({
    id: model.resolvedModel ?? model.value,
    alias: model.value,
    description: model.description ?? model.displayName,
    default_effort: model.defaultEffortLevel ?? null,
    efforts: model.supportsEffort ? model.supportedEffortLevels ?? [] : [],
    access,
  })) }));
} finally {
  finish();
  session.close();
}
