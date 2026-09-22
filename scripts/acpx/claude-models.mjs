import { createRequire } from "node:module";
import { pathToFileURL } from "node:url";

const require = createRequire(process.argv[2]);
const { query } = await import(pathToFileURL(require.resolve("@anthropic-ai/claude-agent-sdk")));
let finish;
const wait = new Promise((resolve) => { finish = resolve; });
const session = query({
  prompt: (async function* () { await wait; })(),
  options: { cwd: process.cwd(), settingSources: ["user"], persistSession: false, tools: [], mcpServers: {} },
});
try {
  const models = await session.supportedModels();
  process.stdout.write(JSON.stringify({ models: models.map((model) => ({
    id: model.resolvedModel ?? model.value,
    efforts: model.supportsEffort ? model.supportedEffortLevels ?? [] : [],
  })) }));
} finally {
  finish();
  session.close();
}
