#!/usr/bin/env bash
set -euo pipefail

if ! command -v osascript >/dev/null 2>&1; then
  echo "error: osascript not found (this script requires macOS)" >&2
  exit 1
fi

out="${1:-"$HOME/Desktop/chrome-tabs-$(date +%F-%H%M%S).md"}"
mkdir -p "$(dirname "$out")"

osascript -l JavaScript <<'JXA' >"$out"
function run() {
  const chrome = Application('Google Chrome');

  let md = `# Chrome tabs (${new Date().toISOString()})\n\n`;
  chrome.windows().forEach((w, i) => {
    md += `## Window ${i + 1}\n\n`;
    w.tabs().forEach((t) => {
      const title = (t.title() || 'Untitled').replace(/[\[\]\r\n]/g, ' ');
      const url = t.url() || '';
      md += `- [${title}](${url})\n`;
    });
    md += '\n';
  });

  return md;
}
JXA

echo "Saved: $out"
