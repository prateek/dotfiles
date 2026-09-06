const fs = require("node:fs");
const [template, mode] = process.argv.slice(2);
const html = fs.readFileSync(template, "utf8");
const input = JSON.parse(fs.readFileSync(0, "utf8"));
let result;
if (mode === "admit") {
  const body = html.slice(html.indexOf("// skill-console:admit-begin"), html.indexOf("// skill-console:admit-end"));
  const admit = new Function(body + "\nreturn admit;")();
  result = input.map(({entries, budget}) => {
    const got = admit(entries, budget);
    return {
      mode: got.mode, demand_chars: got.demand_chars, rendered_chars: got.rendered_chars,
      headroom_chars: got.headroom_chars, all_pinned: got.all_pinned,
      full: got.full, name_only: got.name_only,
    };
  });
} else if (mode === "write-safe") {
  const body = html.slice(html.indexOf("const WIDE_RE = "), html.indexOf("function safeWidth"));
  const writeSafe = new Function(body + "\nreturn writeSafe;")();
  result = input.map(cp => cp === null ? null : writeSafe("a" + String.fromCodePoint(cp) + "b")[0]);
} else {
  throw new Error(`unknown browser scenario ${mode}`);
}
process.stdout.write(JSON.stringify(result));
