// Resolve Orca's built-in default settings from the installed app bundle.
//
// Orca defines defaults in `out/main/index.js` as `getDefaultSettings(homedir)`
// plus a fixed web of helper consts/functions. We can't `require` that file (it
// pulls in Electron), so we slice out exactly those helper definitions and
// evaluate them in a vm sandbox with `process.platform` pinned to darwin.
//
// SYMBOLS is the transitive closure of `getDefaultSettings`, listed explicitly
// rather than auto-discovered: generic identifiers (id, command, host, …) alias
// unrelated top-level definitions and snowball into the whole bundle. The list
// is coupled to the bundle on purpose — if Orca renames a helper, extraction
// fails loudly, and that failure is the signal to update this list (and
// re-review the tracked settings).
import fs from "node:fs";
import vm from "node:vm";

const SYMBOLS = [
  "getDefaultSettings",
  "getDefaultWorkspaceDir",
  "defaultTerminalFontFamily",
  "getDefaultPrimarySelectionMiddleClickPaste",
  "getDefaultTerminalQuickCommands",
  "getDefaultNotificationSettings",
  "getDefaultSourceControlAiSettings",
  "getDefaultVoiceSettings",
  "DEFAULT_LEFT_SIDEBAR_TINT_COLOR",
  "DEFAULT_LEFT_SIDEBAR_TINT_OPACITY",
  "DEFAULT_SOURCE_CONTROL_GROUP_ORDER",
  "UI_LANGUAGE_SYSTEM",
  "DEFAULT_APP_ICON_ID",
  "DEFAULT_APP_FONT_FAMILY",
  "DEFAULT_EDITOR_AUTO_SAVE_DELAY_MS",
  "DEFAULT_TERMINAL_FONT_WEIGHT",
  "DEFAULT_TERMINAL_QUICK_COMMANDS",
  "DEFAULT_OPEN_IN_APPLICATIONS",
  "DEFAULT_DISABLED_TUI_AGENTS",
  "TASK_PROVIDERS",
  "YOLO_TUI_AGENT_ARGS",
  "YOLO_TUI_AGENT_ENV",
  "DEFAULT_TUI_AGENT_ARGS",
  "DEFAULT_TUI_AGENT_ENV",
  "SOURCE_CONTROL_TEXT_ACTION_IDS",
  "SOURCE_CONTROL_LAUNCH_ACTION_IDS",
  "SOURCE_CONTROL_ACTION_IDS",
  "DEFAULT_SOURCE_CONTROL_ACTION_COMMAND_TEMPLATES",
  "DEFAULT_SOURCE_CONTROL_AI_PR_CREATION_DEFAULTS",
];

const [, , bundlePath, homedir] = process.argv;
if (!bundlePath || !homedir) {
  console.error("usage: orca-extract-defaults.mjs <main/index.js> <homedir>");
  process.exit(2);
}

const src = fs.readFileSync(bundlePath, "utf8");

// Extract one top-level definition. function/class ends at the `}` closing its
// body (track only braces, so `()`/`[]` in the signature don't end it early);
// const/let/var ends at the depth-0 `;` (track all brackets). Strings and // and
// /* */ comments are skipped. Template-expression `${}` and regex literals are
// NOT modelled — none of SYMBOLS use them today; the post-eval sanity check
// below guards against silent breakage if a future helper does.
function extractDef(start) {
  const isFn = /^(?:export\s+)?(?:async\s+)?(?:function|class)\b/.test(src.slice(start, start + 40));
  let brace = 0;
  let all = 0;
  let opened = false;
  let str = null;
  let esc = false;
  let line = false;
  let block = false;
  for (let i = start; i < src.length; i++) {
    const c = src[i];
    const n = src[i + 1];
    if (line) { if (c === "\n") line = false; continue; }
    if (block) { if (c === "*" && n === "/") { block = false; i++; } continue; }
    if (str) {
      if (esc) esc = false;
      else if (c === "\\") esc = true;
      else if (c === str) str = null;
      continue;
    }
    if (c === "/" && n === "/") { line = true; i++; continue; }
    if (c === "/" && n === "*") { block = true; i++; continue; }
    if (c === '"' || c === "'" || c === "`") { str = c; continue; }
    if (isFn) {
      if (c === "{") { brace++; opened = true; }
      else if (c === "}") { brace--; if (opened && brace === 0) return src.slice(start, i + 1); }
      continue;
    }
    if (c === "{" || c === "[" || c === "(") all++;
    else if (c === "}" || c === "]" || c === ")") all--;
    else if (c === ";" && all === 0) return src.slice(start, i + 1);
  }
  return src.slice(start);
}

// Index top-level definitions by name (first occurrence at column 0). The bundle
// is pretty-printed, so declarations begin a line.
const DEF_RE = /(?:^|\n)((?:export\s+)?(?:async\s+)?(?:function|const|let|var|class)\s+([A-Za-z0-9_$]+))/g;
const chunkByName = new Map();
for (let m; (m = DEF_RE.exec(src)); ) {
  const name = m[2];
  if (chunkByName.has(name)) continue;
  const start = m.index + (m[0].startsWith("\n") ? 1 : 0);
  chunkByName.set(name, { start, text: extractDef(start) });
}

const missing = SYMBOLS.filter((s) => !chunkByName.has(s));
if (missing.length) {
  console.error(`FATAL: Orca's defaults structure changed — these helpers are gone or renamed: ${missing.join(", ")}`);
  process.exit(1);
}

// Source order so const dependencies resolve (the bundle orders definitions
// before their first use; function declarations hoist regardless).
const program =
  SYMBOLS.map((n) => chunkByName.get(n))
    .sort((a, b) => a.start - b.start)
    .map((c) => c.text)
    .join("\n") + `\n;getDefaultSettings(${JSON.stringify(homedir)});`;

let result;
try {
  result = vm.runInNewContext(program, { process: { platform: "darwin" } }, { timeout: 5000 });
} catch (e) {
  console.error("FATAL: evaluating Orca defaults failed — a helper outside SYMBOLS is now referenced. Update the extractor for this Orca version.");
  console.error(`  ${e && e.message ? e.message : e}`);
  process.exit(1);
}

if (!result || typeof result !== "object") {
  console.error("FATAL: getDefaultSettings did not return an object.");
  process.exit(1);
}

// Sanity check: catch a silently mis-extracted chunk (e.g. an unmodelled regex
// literal desyncing the scanner) before it poisons the snapshot.
const REQUIRED = ["theme", "terminalFontFamily", "workspaceDir", "terminalScrollbackBytes"];
const absent = REQUIRED.filter((k) => !(k in result));
if (absent.length || Object.keys(result).length < 100) {
  console.error(`FATAL: extracted defaults look wrong (${Object.keys(result).length} keys, missing: ${absent.join(", ") || "none"}). The extractor likely needs updating for this Orca version.`);
  process.exit(1);
}

process.stdout.write(JSON.stringify(result, null, 2) + "\n");
