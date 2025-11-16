#!/usr/bin/env node
/**
 * Reorganize a VS Code settings.json (JSONC) file:
 * - Group top-level keys by prefix (segment before the first dot); language overrides (`"[lang]"`) grouped at bottom.
 * - Preserve original values (including nested comments) by slicing from source text using a lightweight JSONC scanner.
 * - Sort keys alphabetically within each group.
 * - Insert simple group header comments.
 * - Write back only if content changed; create a .bak backup on first run.
 *
 * Note: We intentionally do NOT reformat nested objects/arrays to avoid losing comments.
 */
import fs from "fs";
import path from "path";
import process from "process";


function readFile(filePath) {
  return fs.readFileSync(filePath, "utf8");
}

function writeFileIfChanged(filePath, newContent) {
  const current = fs.readFileSync(filePath, "utf8");
  if (current === newContent) return false;
  // Write backup once
  const bakPath = `${filePath}.bak`;
  if (!fs.existsSync(bakPath)) {
    fs.writeFileSync(bakPath, current, "utf8");
  }
  fs.writeFileSync(filePath, newContent, "utf8");
  return true;
}

function detectIndent(src) {
  // Find indent used for top-level properties (default to 4 spaces)
  const m = src.match(/^\s*{\s*\n([ \t]+)"/m);
  if (m && m[1]) return m[1];
  return "    ";
}

function parseDirective(src) {
  // Look for a directive comment near top of file, e.g.:
  // // @vscode-settings-format: pinned=editor,workbench,files; overrides=bottom
  const head = src.slice(0, Math.min(src.length, 4000));
  const dirMatch = head.match(/@vscode-settings-format:\s*([^\n\r]+)/);
  if (!dirMatch) return { pinned: [], overrides: "bottom" };
  const body = dirMatch[1];
  const pinnedMatch = body.match(/pinned=([^;]+)/);
  const overridesMatch = body.match(/overrides=(\w+)/);
  const pinned = pinnedMatch ? pinnedMatch[1].split(",").map((s) => s.trim()).filter(Boolean) : [];
  const overrides = overridesMatch ? overridesMatch[1].trim() : "bottom";
  return { pinned, overrides };
}

function isOverrideKey(key) {
  return /^\[.*\]$/.test(key);
}

function groupKeyFor(key) {
  if (isOverrideKey(key)) return "__overrides__";
  const dot = key.indexOf(".");
  return dot === -1 ? key : key.slice(0, dot);
}

function buildGroups(propertiesInOrder) {
  const groupOrder = [];
  const groupToProps = new Map();
  for (const prop of propertiesInOrder) {
    const g = groupKeyFor(prop.key);
    if (!groupToProps.has(g)) {
      groupToProps.set(g, []);
      groupOrder.push(g);
    }
    groupToProps.get(g).push(prop);
  }
  return { groupOrder, groupToProps };
}

function reorderGroupsDynamic(groupOrder, groupToProps, directive) {
  const pinned = directive.pinned || [];
  const overridesPos = (directive.overrides || "bottom") === "top" ? "top" : "bottom";
  const overridesKey = "__overrides__";

  // Unique group list
  const set = new Set(groupOrder);
  const allGroups = Array.from(set);

  // Classification helpers
  const CORE = new Set([
    "editor",
    "workbench",
    "window",
    "files",
    "explorer",
    "terminal",
    "diffEditor",
    "security",
    "breadcrumbs",
    "outline",
    "debug",
    "remote"
  ]);
  const LANG = new Set([
    "go",
    "gopls",
    "python",
    "typescript",
    "javascript",
    "haskell",
    "rust-analyzer",
    "zig",
    "jupyter",
    "notebook",
    "ipynb",
    "markdown"
  ]);
  function isLanguageGroup(g) {
    return LANG.has(g) || /-analy[z|s]er$/.test(g);
  }
  function categoryRank(g) {
    if (g === overridesKey) return 3;
    if (CORE.has(g)) return 0;
    if (isLanguageGroup(g)) return 2;
    return 1; // extensions/integrations and everything else
  }

  // Pinned groups first in given order (if present)
  const pinnedOrdered = pinned.filter((g) => set.has(g));

  // Remaining groups, excluding pinned
  const remaining = allGroups.filter((g) => !pinnedOrdered.includes(g));

  // If overrides are to be forced at top/bottom, handle separately
  const hasOverrides = set.has(overridesKey);
  const remainingNoOverrides = remaining.filter((g) => g !== overridesKey);

  // Sort remaining by category rank, then alphabetically within category
  remainingNoOverrides.sort((a, b) => {
    const ra = categoryRank(a);
    const rb = categoryRank(b);
    if (ra !== rb) return ra - rb;
    return a.localeCompare(b);
  });

  let ordered = [];
  if (overridesPos === "top" && hasOverrides) ordered.push(overridesKey);
  ordered = ordered.concat(pinnedOrdered, remainingNoOverrides);
  if (overridesPos === "bottom" && hasOverrides) ordered.push(overridesKey);
  return ordered;
}

function sortPropsWithinGroups(groupToProps) {
  for (const props of groupToProps.values()) {
    props.sort((a, b) => a.key.localeCompare(b.key));
  }
}

// --- Lightweight JSONC scanning primitives (comments + strings + balancing) ---
function skipWhitespaceAndComments(src, i) {
  const n = src.length;
  while (i < n) {
    const ch = src[i];
    // whitespace
    if (ch === " " || ch === "\t" || ch === "\r" || ch === "\n") {
      i++;
      continue;
    }
    // line comment
    if (ch === "/" && src[i + 1] === "/") {
      i += 2;
      while (i < n && src[i] !== "\n" && src[i] !== "\r") i++;
      continue;
    }
    // block comment
    if (ch === "/" && src[i + 1] === "*") {
      i += 2;
      while (i < n && !(src[i] === "*" && src[i + 1] === "/")) i++;
      if (i < n) i += 2;
      continue;
    }
    break;
  }
  return i;
}

function parseJSONString(src, i) {
  // expects src[i] === '\"', returns index just after closing quote
  const n = src.length;
  i++; // skip opening quote
  let escaped = false;
  while (i < n) {
    const ch = src[i];
    if (escaped) {
      escaped = false;
      i++;
      continue;
    }
    if (ch === "\\") {
      escaped = true;
      i++;
      continue;
    }
    if (ch === "\"") {
      return i + 1;
    }
    i++;
  }
  return i;
}

function consumeValue(src, i, closeIndex) {
  // returns { end, terminator } where terminator is ',' or '}' or ''
  const n = src.length;
  let depthObj = 0;
  let depthArr = 0;
  let inString = false;
  let escaped = false;
  let inLineComment = false;
  let inBlockComment = false;
  for (; i < n; i++) {
    const ch = src[i];
    const next = src[i + 1];

    if (inLineComment) {
      if (ch === "\n" || ch === "\r") inLineComment = false;
      continue;
    }
    if (inBlockComment) {
      if (ch === "*" && next === "/") {
        inBlockComment = false;
        i++;
      }
      continue;
    }
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (ch === "\\") {
        escaped = true;
      } else if (ch === "\"") {
        inString = false;
      }
      continue;
    }

    // not in string/comment
    if (ch === "\"") {
      inString = true;
      continue;
    }
    if (ch === "/" && next === "/") {
      inLineComment = true;
      i++;
      continue;
    }
    if (ch === "/" && next === "*") {
      inBlockComment = true;
      i++;
      continue;
    }
    if (ch === "{") {
      depthObj++;
      continue;
    }
    if (ch === "}") {
      if (depthObj > 0) {
        depthObj--;
        continue;
      }
      // value ends before this closing brace of root
      return { end: i, terminator: "}" };
    }
    if (ch === "[") {
      depthArr++;
      continue;
    }
    if (ch === "]") {
      if (depthArr > 0) depthArr--;
      continue;
    }
    if (ch === "," && depthObj === 0 && depthArr === 0) {
      return { end: i, terminator: "," };
    }
  }
  return { end: n, terminator: "" };
}

function extractRootProperties(src) {
  const props = [];
  const openBraceIndex = src.indexOf("{");
  const closeBraceIndex = src.lastIndexOf("}");
  if (openBraceIndex === -1 || closeBraceIndex === -1 || closeBraceIndex <= openBraceIndex) {
    return props;
  }
  let i = openBraceIndex + 1;
  while (true) {
    i = skipWhitespaceAndComments(src, i);
    if (i >= closeBraceIndex) break;
    if (src[i] !== "\"") {
      // not a valid key start; try to advance to next quote or exit
      const nextQuote = src.indexOf("\"", i);
      if (nextQuote === -1 || nextQuote >= closeBraceIndex) break;
      i = nextQuote;
    }
    // parse key string
    const keyStart = i;
    const keyEnd = parseJSONString(src, i);
    const keyRaw = src.slice(keyStart, keyEnd);
    let key;
    try {
      key = JSON.parse(keyRaw);
    } catch {
      // skip malformed key
      i = keyEnd;
      continue;
    }
    i = skipWhitespaceAndComments(src, keyEnd);
    // find colon
    if (src[i] !== ":") {
      // advance to next ':' skipping comments/space
      while (i < closeBraceIndex) {
        if (src[i] === ":") break;
        if (src[i] === "/" && (src[i + 1] === "/" || src[i + 1] === "*")) {
          i = skipWhitespaceAndComments(src, i);
          continue;
        }
        i++;
      }
    }
    if (src[i] !== ":") break;
    i++; // skip ':'
    i = skipWhitespaceAndComments(src, i);
    const valueStart = i;
    const { end, terminator } = consumeValue(src, i, closeBraceIndex);
    const valueText = src.slice(valueStart, end);
    props.push({ key, valueText });
    if (terminator === ",") {
      i = end + 1;
      continue;
    } else if (terminator === "}") {
      // root object end
      break;
    } else {
      i = end;
      break;
    }
  }
  return props;
}

function buildOutput(src, groupsOrdered, groupToProps, indent) {
  const EOL = "\n";
  const openBraceIndex = src.indexOf("{");
  const closeBraceIndex = src.lastIndexOf("}");
  const before = openBraceIndex >= 0 ? src.slice(0, openBraceIndex + 1) : "{";
  const after = closeBraceIndex >= 0 ? src.slice(closeBraceIndex) : "}";

  const allPropsFlattened = [];
  for (const g of groupsOrdered) {
    for (const p of groupToProps.get(g) || []) {
      allPropsFlattened.push({ group: g, ...p });
    }
  }

  let body = "";
  let currentGroup = null;
  allPropsFlattened.forEach((p, idx) => {
    const isFirst = idx === 0;
    const isLast = idx === allPropsFlattened.length - 1;
    if (p.group !== currentGroup) {
      // Insert a separator (blank line) between groups, but not before the first group
      if (!isFirst) body += EOL;
      if (p.group !== "__overrides__") {
        body += `${indent}// === ${p.group} ===${EOL}`;
      } else {
        body += `${indent}// === language overrides ===${EOL}`;
      }
      currentGroup = p.group;
    }
    // Construct the property line(s)
    const keyJson = JSON.stringify(p.key);
    const comma = isLast ? "" : ",";
    // Avoid touching inner formatting/comments by reusing original value text
    // Ensure a space after colon for readability
    body += `${indent}${keyJson}: ${p.valueText}${comma}${EOL}`;
  });

  // Compose final text
  let result;
  if (before.trim() === "{") {
    result = "{" + EOL + body + "}" + EOL;
  } else {
    // Preserve any prefix before '{' and suffix after '}' if they exist
    const suffix = after.endsWith(EOL) ? after : after + EOL;
    result = before + EOL + body + suffix;
  }
  return result;
}

function main() {
  const target = process.argv[2];
  if (!target) {
    console.error("Usage: node scripts/format-vscode-settings.mjs <path/to/settings.json>");
    process.exit(2);
  }
  const abs = path.resolve(process.cwd(), target);
  if (!fs.existsSync(abs)) {
    console.error(`File not found: ${abs}`);
    process.exit(2);
  }
  const src = readFile(abs);
  const indent = detectIndent(src);
  const directive = parseDirective(src);
  const propsInOrder = extractRootProperties(src);
  const { groupOrder, groupToProps } = buildGroups(propsInOrder);
  sortPropsWithinGroups(groupToProps);
  const groupsOrdered = reorderGroupsDynamic(groupOrder, groupToProps, directive);
  const newText = buildOutput(src, groupsOrdered, groupToProps, indent);
  const changed = writeFileIfChanged(abs, newText);
  if (!changed) {
    console.log("No changes.");
  } else {
    console.log("settings.json reorganized.");
  }
}

main();
