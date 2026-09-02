#!/usr/bin/env zsh
#
# Tests for the machines.toml layered resolver (home/.chezmoitemplates/features.tmpl):
# layer precedence, list replacement, machine_type resolution, machines_local
# overrides, and fail-on-unknown-type.
#
set -euo pipefail
unsetopt xtrace 2>/dev/null || true
set +x 2>/dev/null || true
unsetopt verbose 2>/dev/null || true
set +v 2>/dev/null || true

die() {
  print -u2 -- "machines-features: $*"
  exit 1
}

DOTFILES_ROOT="${0:A:h:h}"
FEATURES="$DOTFILES_ROOT/home/.chezmoitemplates/features.tmpl"
tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

[[ -f "$FEATURES" ]] || die "missing resolver: $FEATURES"

# Empty config so this host's ambient [data] (e.g. machine_type) does not leak;
# only --override-data and the source's .chezmoidata feed the resolver.
empty_config="$tmp_root/chezmoi.toml"
: >"$empty_config"

# Render features.tmpl with the given --override-data JSON; emits the feature JSON.
resolve() {
  chezmoi \
    --source "$DOTFILES_ROOT" \
    --config "$empty_config" \
    --destination "$tmp_root/home" \
    --cache "$tmp_root/cache" \
    --persistent-state "$tmp_root/state.boltdb" \
    --no-tty \
    --override-data "$1" \
    execute-template --file "$FEATURES"
}

# assert_json <override> <python-expr-using-f> [label]
# f is the parsed feature dict; the expression must evaluate truthy.
assert_json() {
  local override="$1" expr="$2" label="${3:-$2}"
  local js
  js="$(resolve "$override")"
  FEATURES_JSON="$js" python3 -c '
import json, os, sys
f = json.loads(os.environ["FEATURES_JSON"])
expr, label = sys.argv[1], sys.argv[2]
if not eval(expr, {"f": f}):
    sys.stderr.write(f"machines-features: assertion failed: {label}\n  features={json.dumps(f)}\n")
    sys.exit(1)
' "$expr" "$label" || exit 1
}

# --- per-type composition matches the retired packages.machine_types ----------
assert_json '{"machine_type":"ci"}' \
  'f["groups"]==["core"] and f["run_install_scripts"] is True and f["apply_macos_defaults"] is True and f["secrets_enabled"] is False and f["private_overlay"] is False and f["elevation"]=="none" and f["granola_mcp"] is False and f["orca_mode"]=="none" and f["machine_type"]=="ci"' \
  "ci composition"

assert_json '{"machine_type":"personal"}' \
  'f["groups"]==["core","mac-desktop","ai-agent-apps","codex","developer-tools","personal-apps","forks"] and f["run_install_scripts"] is True and f["apply_macos_defaults"] is True and f["secrets_enabled"] is False and f["elevation"]=="none" and f["private_overlay"] is False and f["granola_mcp"] is True and f["orca_mode"]=="none"' \
  "personal composition"

assert_json '{"machine_type":"homelab"}' \
  'f["groups"]==["core","ai-agent-apps","codex","developer-tools","apple-development","homelab-overlay"] and f["runner_vm_name"]=="tartelet-runner" and f["runner_vm_count"]==1 and f["runner_scope"]=="repo" and f["runner_start_on_launch"] is True and f["granola_mcp"] is True' \
  "homelab composition"

if [[ "$(uname -s)" == "Linux" ]]; then
  assert_json '{"machine_type":"work"}' \
    'f["groups"]==["core"] and f["run_install_scripts"] is False and f["apply_macos_defaults"] is False and f["private_overlay"] is False and f["elevation"]=="none" and f["granola_mcp"] is False and f["orca_mode"]=="headless"' \
    "work x Linux composition"
else
  assert_json '{"machine_type":"work"}' \
    'f["groups"]==["core","mac-desktop","ai-agent-apps","developer-tools","work-apps","forks"] and f["private_overlay"] is True and f["elevation"]=="jamf-self-service" and f["granola_mcp"] is False and f["orca_mode"]=="none"' \
    "work x Darwin composition"
fi

# --- machine_type default: absent resolves to personal ------------------------
assert_json '{}' 'f["machine_type"]=="personal"' "absent machine_type -> personal"

# --- agent_session_wiki flags and wiki_host_alias invariants -------------------
# Asserted against the layer data itself, not the resolver: the resolver runs
# with THIS host's [machines.host.*] layer applied, so host-scoped keys
# (agent_session_wiki_ingest, wiki_host_alias) would leak into type-override
# assertions on any participating machine.
python3 - "$DOTFILES_ROOT/home/.chezmoidata/machines.toml" <<'PY' || exit 1
import sys, tomllib

machines = tomllib.load(open(sys.argv[1], "rb"))["machines"]
defaults = machines["defaults"]
types = machines["type"]

assert defaults["agent_session_wiki"] is False, defaults
assert defaults["agent_session_wiki_ingest"] is False, defaults
assert defaults["agent_session_wiki_sparse"] is False, defaults
assert "agent_session_wiki" not in types.get("ci", {}), "ci must inherit session wiki off"
for mt in ("personal", "homelab", "work"):
    assert types[mt].get("agent_session_wiki") is True, f"{mt} should sync sessions"
    assert "agent_session_wiki_ingest" not in types[mt], f"ingest is host-scoped, not type-scoped ({mt})"
assert types["work"].get("agent_session_wiki_sparse") is True, "work machines keep a sparse archive clone"
for mt in ("personal", "homelab"):
    assert not types[mt].get("agent_session_wiki_sparse"), f"{mt} machines hold the full archive"

hosts = machines.get("host", {})
aliases = {h: cfg["wiki_host_alias"] for h, cfg in hosts.items() if "wiki_host_alias" in cfg}
empty = [h for h, a in aliases.items() if not a.strip()]
assert not empty, f"empty wiki_host_alias on: {empty}"
# The alias becomes one path component (sessions/<alias>, health/<alias>.json,
# a sparse-checkout cone entry), so it must not carry separators or spaces.
import re
bad = [h for h, a in aliases.items() if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]*", a)]
assert not bad, f"wiki_host_alias must match [A-Za-z0-9][A-Za-z0-9._-]*: {bad}"
dupes = {a for a in aliases.values() if list(aliases.values()).count(a) > 1}
assert not dupes, f"duplicate wiki_host_alias values: {dupes}"
ingest_hosts = [h for h, cfg in hosts.items() if cfg.get("agent_session_wiki_ingest")]
assert len(ingest_hosts) <= 1, f"multiple ingest hosts: {ingest_hosts}"
for h in ingest_hosts:
    assert h in aliases, f"ingest host {h} lacks wiki_host_alias"
    assert not hosts[h].get("agent_session_wiki_sparse"), f"ingest host {h} cannot be sparse (the ingest reads every host)"
PY

# --- archive clone shape: work resolves sparse; the ingest host resolves full --
# Hostname overrides pick the host layer, so these hold on any machine.
assert_json '{"machine_type":"work","chezmoi":{"hostname":"no-such-host"}}' \
  'f["agent_session_wiki_sparse"] is True and f["agent_session_wiki_ingest"] is False' \
  "work resolves to a sparse archive clone"
assert_json '{"machine_type":"homelab","chezmoi":{"hostname":"m4mini"}}' \
  'f["agent_session_wiki_ingest"] is True and f["agent_session_wiki_sparse"] is False and f["wiki_host_alias"]=="m4mini"' \
  "m4mini owns the ingest role on a full clone"

# --- machines_local is the highest layer (overrides type + defaults) ----------
assert_json '{"machine_type":"personal","machines_local":{"secrets_enabled":true}}' \
  'f["secrets_enabled"] is True' "machines_local enables secrets"
assert_json '{"machine_type":"work","machines_local":{"elevation":"none"}}' \
  'f["elevation"]=="none"' "machines_local overrides work elevation"

# --- a list is replaced wholesale by the highest layer that sets it -----------
assert_json '{"machine_type":"work","machines_local":{"groups":["core"]}}' \
  'f["groups"]==["core"]' "machines_local replaces groups (no concat)"

# --- os layer composes for the host's matching .chezmoi.os --------------------
platform="${$(uname -s):l}"
synthetic_os="$(printf '{"machine_type":"personal","machines":{"os":{"%s":{"apply_macos_defaults":false}}}}' "$platform")"
assert_json "$synthetic_os" \
  'f["apply_macos_defaults"] is False and f["run_install_scripts"] is True' \
  "os.$platform layer composes above defaults, below machines_local"

# --- composite layer composes after type, before host-local ------------------
synthetic_composite="$(printf '{"machine_type":"work","machines":{"composite":{"work":{"%s":{"groups":["core"],"private_overlay":false,"elevation":"none","orca_mode":"headless"}}}}}' "$platform")"
assert_json "$synthetic_composite" \
  'f["groups"]==["core"] and f["private_overlay"] is False and f["elevation"]=="none" and f["orca_mode"]=="headless"' \
  "work.$platform synthetic composite overrides type.work"
synthetic_local="$(printf '{"machine_type":"work","machines":{"composite":{"work":{"%s":{"elevation":"none"}}}},"machines_local":{"elevation":"test-override"}}' "$platform")"
assert_json "$synthetic_local" \
  'f["elevation"]=="test-override"' \
  "machines_local overrides composite"

# The real Linux exception is data-driven, so verify it independent of the host
# OS running this test.
python3 - "$DOTFILES_ROOT/home/.chezmoidata/machines-composite.toml" <<'PY' || exit 1
import sys, tomllib

features = tomllib.load(open(sys.argv[1], "rb"))["machines"]["composite"]["work"]["linux"]
assert features == {
    "groups": ["core"],
    "run_install_scripts": False,
    "apply_macos_defaults": False,
    "private_overlay": False,
    "elevation": "none",
    "agent_clis": ["cursor-agent", "claude"],
    "agent_session_wiki": False,
    "orca_mode": "headless",
}, features
PY

# --- unknown machine_type fails loud (the typo guard) -------------------------
set +e
bogus="$(resolve '{"machine_type":"nope"}' 2>&1)"
rc=$?
set -e
[[ $rc -ne 0 ]] || die "unknown machine type should fail the resolver"
[[ $bogus == *"unknown machine type"* ]] || die "expected 'unknown machine type' error, got: $bogus"

print -- "OK machines-features"
