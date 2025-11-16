#!/usr/bin/env node
/**
 * Reorganize a VS Code settings.json (JSONC) file:
 * - Group top-level keys by prefix (segment before the first dot); language overrides (`"[lang]"`) grouped at bottom.
 * - Preserve original values (including nested comments) by slicing from source text via jsonc-parser AST.
 * - Sort keys alphabetically within each group.
 * - Insert simple group header comments.
 * - Write back only if content changed; create a .bak backup on first run.
 *
 * Note: We intentionally do NOT reformat nested objects/arrays to avoid losing comments.
 */
import fs from "fs";
import path from "path";
import process from "process";
import { parseTree } from "jsonc-parser";

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

  // Pull overrides out
  const nonOverrides = allGroups.filter((g) => g !== overridesKey);
  const hasOverrides = set.has(overridesKey);

  // Pinned first in given order, intersect with existing groups
  const pinnedOrdered = pinned.filter((g) => set.has(g));
  // Remaining groups (excluding pinned and overrides) alphabetical
  const remaining = nonOverrides.filter((g) => !pinnedOrdered.includes(g)).sort();

  let ordered = [];
  if (overridesPos === "top" && hasOverrides) ordered.push(overridesKey);
  ordered = ordered.concat(pinnedOrdered, remaining);
  if (overridesPos === "bottom" && hasOverrides) ordered.push(overridesKey);
  return ordered;
}

function sortPropsWithinGroups(groupToProps) {
  for (const props of groupToProps.values()) {
    props.sort((a, b) => a.key.localeCompare(b.key));
  }
}

function extractRootProperties(src, rootNode) {
  // rootNode is an 'object' node. Its children are property nodes.
  const props = [];
  if (!rootNode || rootNode.type !== "object" || !Array.isArray(rootNode.children)) return props;
  for (const propNode of rootNode.children) {
    if (!Array.isArray(propNode.children) || propNode.children.length < 2) continue;
    const keyNode = propNode.children[0];
    const valueNode = propNode.children[1];
    const key = keyNode.value; // string
    const valueText = src.slice(valueNode.offset, valueNode.offset + valueNode.length);
    props.push({ key, valueText });
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
    result = before + EOL + body + after.endsWith(EOL) ? after : after + EOL;
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
  const root = parseTree(src);
  if (!root || root.type !== "object") {
    console.error("Root of settings must be a JSON object.");
    process.exit(2);
  }
  const indent = detectIndent(src);
  const directive = parseDirective(src);
  const propsInOrder = extractRootProperties(src, root);
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


