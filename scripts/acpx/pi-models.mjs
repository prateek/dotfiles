import { createRequire } from "node:module";
import { dirname, join } from "node:path";
import { existsSync, readFileSync, realpathSync } from "node:fs";
import { pathToFileURL } from "node:url";

let root = dirname(process.argv[2]);
while (!existsSync(join(root, "package.json")) ||
       JSON.parse(readFileSync(join(root, "package.json"), "utf8")).name !== "@earendil-works/pi-coding-agent") {
  const installed = join(root, "node_modules/@earendil-works/pi-coding-agent");
  if (existsSync(join(installed, "package.json"))) {
    root = realpathSync(installed);
    break;
  }
  const parent = dirname(root);
  if (parent === root) throw new Error("Cannot locate installed Pi package");
  root = parent;
}
const load = (path) => import(pathToFileURL(join(root, path)));
const { ModelRuntime } = await load("dist/core/model-runtime.js");
const { ReadOnlyAuthStorage } = await load("dist/core/auth-storage.js");
const { SettingsManager } = await load("dist/core/settings-manager.js");
const { DEFAULT_THINKING_LEVEL } = await load("dist/core/defaults.js");
const require = createRequire(join(root, "package.json"));
const aiRoot = require.resolve.paths("@earendil-works/pi-ai")
  .map((path) => join(path, "@earendil-works/pi-ai"))
  .find((path) => existsSync(join(path, "dist/index.js")));
if (!aiRoot) throw new Error("Cannot locate Pi's model runtime dependency");
const { getSupportedThinkingLevels, clampThinkingLevel } = await import(pathToFileURL(join(aiRoot, "dist/index.js")));
const settings = SettingsManager.create(process.cwd());
const runtime = await ModelRuntime.create({ credentials: new ReadOnlyAuthStorage(), allowModelNetwork: false });
const models = runtime.getAvailableSnapshot().map((model) => ({
  id: model.id,
  provider: model.provider,
  description: model.name,
  efforts: getSupportedThinkingLevels(model),
  default_effort: clampThinkingLevel(model, settings.getModelThinkingLevel(model.provider, model.id) ??
    settings.getDefaultThinkingLevel() ?? DEFAULT_THINKING_LEVEL),
  access: runtime.isUsingSubscription(model.provider) ? "included" : "paid",
}));
process.stdout.write(JSON.stringify({ models }));
