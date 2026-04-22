#!/usr/bin/env zsh

set -euo pipefail
unsetopt xtrace 2>/dev/null || true
set +x 2>/dev/null || true
unsetopt verbose 2>/dev/null || true
set +v 2>/dev/null || true
setopt typeset_silent 2>/dev/null || true

die() {
  print -u2 -- "bench-zsh-startup: $*"
  exit 1
}

note() {
  print -- "$*"
}

require_cmd() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || die "missing required command: $cmd"
}

keep_tmp=0
for arg in "$@"; do
  case "$arg" in
    --keep-tmp)
      keep_tmp=1
      ;;
    *)
      die "unsupported argument: $arg"
      ;;
  esac
done

DOTFILES_ROOT="${0:A:h:h:h}"
FIXTURES_ROOT="$DOTFILES_ROOT/tests/fixtures/antidote"
SAFE_PATH="/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
CACHE_ROOT="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles-zsh-startup-bench"
ZSH_BENCH_ROOT="$CACHE_ROOT/zsh-bench"
ANTIDOTE_SRC_ROOT="$CACHE_ROOT/antidote-src"
ANTIDOTE_PLUGIN_HOME="$CACHE_ROOT/antidote-home"
P10K_SRC_ROOT="$CACHE_ROOT/powerlevel10k"
TMP_ROOT="$(mktemp -d)"

cleanup() {
  if (( keep_tmp )); then
    note "tmp_root=$TMP_ROOT"
    return 0
  fi
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

require_cmd git
require_cmd zsh
require_cmd python3
require_cmd rsync
[[ -r "$HOME/.zinit/bin/zinit.zsh" ]] || die "missing current zinit install at $HOME/.zinit/bin/zinit.zsh"
[[ -r "$FIXTURES_ROOT/prompt.txt" ]] || die "missing antidote fixture: $FIXTURES_ROOT/prompt.txt"
[[ -r "$FIXTURES_ROOT/precompinit.txt" ]] || die "missing antidote fixture: $FIXTURES_ROOT/precompinit.txt"
[[ -r "$FIXTURES_ROOT/postcompinit.txt" ]] || die "missing antidote fixture: $FIXTURES_ROOT/postcompinit.txt"

ensure_git_checkout() {
  local url="$1"
  local dir="$2"

  if [[ -d "$dir/.git" ]]; then
    return 0
  fi

  mkdir -p "${dir:h}"
  git clone --depth=1 "$url" "$dir" >/dev/null 2>&1 || die "failed to clone $url into $dir"
}

link_startup_files() {
  local home_dir="$1"

  ln -snf "$home_dir/dotfiles/zprofile" "$home_dir/.zprofile"
  ln -snf "$home_dir/dotfiles/zshrc" "$home_dir/.zshrc"
  ln -snf "$home_dir/dotfiles/zshenv" "$home_dir/.zshenv"
}

write_antidote_init() {
  local dotfiles_dir="$1"
  local output="$dotfiles_dir/antidote-init.zsh"

  cat >"$output" <<'EOF'
#!/usr/bin/env zsh

antidote_cache_root="${XDG_CACHE_HOME:-$HOME/.cache}/antidote"
antidote_plugins_root="$DOTFILES_ROOT/tests/fixtures/antidote"

antidote_prompt_txt="$antidote_plugins_root/prompt.txt"
antidote_precompinit_txt="$antidote_plugins_root/precompinit.txt"
antidote_postcompinit_txt="$antidote_plugins_root/postcompinit.txt"

antidote_prompt_zsh="$antidote_cache_root/prompt.zsh"
antidote_precompinit_zsh="$antidote_cache_root/precompinit.zsh"
antidote_postcompinit_zsh="$antidote_cache_root/postcompinit.zsh"

antidote_ensure_static() {
  local source_file="$1"
  local static_file="$2"

  [[ -r "$source_file" ]] || return 1
  mkdir -p -- "${static_file:h}"

  if [[ ! -r "$static_file" || "$source_file" -nt "$static_file" ]]; then
    antidote bundle <"$source_file" >"$static_file"
  fi
}

antidote_load_prompt() {
  antidote_ensure_static "$antidote_prompt_txt" "$antidote_prompt_zsh" || return 0
  source_if_readable "$antidote_prompt_zsh"
}

antidote_load_postprompt() {
  antidote_ensure_static "$antidote_precompinit_txt" "$antidote_precompinit_zsh" || return 0
  source_if_readable "$antidote_precompinit_zsh"

  autoload -Uz compinit
  compinit

  antidote_ensure_static "$antidote_postcompinit_txt" "$antidote_postcompinit_zsh" || return 0
  source_if_readable "$antidote_postcompinit_zsh"

  if command -v direnv >/dev/null 2>&1; then
    eval "$(direnv hook zsh)"
  fi
}

antidote_load_prompt

if [[ -o interactive && -o zle ]]; then
  typeset -gi __antidote_bootstrap_done=0
  __antidote_bootstrap_postprompt() {
    (( __antidote_bootstrap_done )) && return 0
    __antidote_bootstrap_done=1
    antidote_load_postprompt
  }
  zle -N zle-line-init __antidote_bootstrap_postprompt
fi
EOF

  chmod +x "$output"
}

write_antidote_init_sh() {
  local dotfiles_dir="$1"
  local output="$dotfiles_dir/init.sh"

  cat >"$output" <<'EOF'
#!/usr/bin/env zsh
# vim:syntax=sh
# vim:filetype=sh

source_if_readable() {
  local f="$1"
  [[ -r "$f" ]] || return 1
  source "$f"
}

sync_launchctl_path() {
  local launchctl_path=""

  launchctl_path="$(/bin/launchctl getenv PATH 2>/dev/null || true)"
  if [[ "$launchctl_path" == "$PATH" ]]; then
    return 0
  fi

  /bin/launchctl setenv PATH "$PATH"
}

DOTFILES_ROOT="${DOTFILES:-${ZSHCONFIG:-$HOME/dotfiles}}"
ZSHCONFIG="${ZSHCONFIG:-$DOTFILES_ROOT}"

if ! source_if_readable "$HOME/.antidote/antidote.zsh"; then
  print -u2 "antidote not found at \$HOME/.antidote/antidote.zsh (install antidote to use this benchmark)."
  return 0 2>/dev/null || exit 0
fi

zsh_fns=${ZSHCONFIG}/zsh/autoload
if [[ -d "$zsh_fns" ]]; then
    fpath=("$zsh_fns" $fpath)
    for func in "$zsh_fns"/*(N); do
        [[ -f "$func" ]] || continue
        autoload -Uz "${func:t}"
    done
fi
unset zsh_fns

if ! source_if_readable "$DOTFILES_ROOT/antidote-init.zsh"; then
  print -u2 "Missing $DOTFILES_ROOT/antidote-init.zsh; skipping plugin setup."
fi

zsh_libs=${ZSHCONFIG}/zsh/lib
if [[ -d "$zsh_libs" ]]; then
   for file in "$zsh_libs"/*.zsh(N); do
      source "$file"
   done
fi
unset zsh_libs

extras=${ZSHCONFIG}/zsh/extra
if [[ -d "$extras" ]]; then
   for file in "$extras"/*.zsh(N); do
      source "$file"
   done
fi
unset extras

if [[ -x /bin/launchctl && -o interactive && -o login ]]; then
    sync_launchctl_path
fi
EOF

  chmod +x "$output"
}

setup_zinit_home() {
  local home_dir="$TMP_ROOT/zinit-home"

  mkdir -p "$home_dir"
  ln -snf "$DOTFILES_ROOT" "$home_dir/dotfiles"
  link_startup_files "$home_dir"
  ln -snf "$HOME/.zinit" "$home_dir/.zinit"

  print -r -- "$home_dir"
}

setup_antidote_home() {
  local home_dir="$TMP_ROOT/antidote-home"

  mkdir -p "$home_dir"
  rsync -a --exclude .git "$DOTFILES_ROOT/" "$home_dir/dotfiles/"
  write_antidote_init "$home_dir/dotfiles"
  write_antidote_init_sh "$home_dir/dotfiles"
  link_startup_files "$home_dir"

  mkdir -p "$home_dir/.antidote"
  ln -snf "$ANTIDOTE_SRC_ROOT/antidote.zsh" "$home_dir/.antidote/antidote.zsh"
  ln -snf "$ANTIDOTE_SRC_ROOT/functions" "$home_dir/.antidote/functions"

  print -r -- "$home_dir"
}

setup_p10k_home() {
  local home_dir="$TMP_ROOT/p10k-home"
  local skel_dir="$ZSH_BENCH_ROOT/configs/powerlevel10k/skel"

  [[ -d "$skel_dir" ]] || die "missing p10k skel dir: $skel_dir"
  mkdir -p "$home_dir"
  rsync -a "$skel_dir/" "$home_dir/"
  ln -snf "$P10K_SRC_ROOT" "$home_dir/powerlevel10k"

  print -r -- "$home_dir"
}

run_zsh_bench() {
  local lane="$1"
  local home_dir="$2"
  local cache_dir="$3"
  local output="$TMP_ROOT/$lane-zsh-bench.raw"
  local -a env_cmd

  mkdir -p "$cache_dir"

  env_cmd=(
    env -i
    HOME="$home_dir"
    PATH="$SAFE_PATH"
    TERM=xterm-256color
    SHELL=/bin/zsh
    USER="${USER:-prateek}"
    LOGNAME="${LOGNAME:-${USER:-prateek}}"
    XDG_CACHE_HOME="$cache_dir"
  )

  if [[ "$lane" == antidote ]]; then
    env_cmd+=(ANTIDOTE_HOME="$ANTIDOTE_PLUGIN_HOME")
  fi

  "${env_cmd[@]}" "$ZSH_BENCH_ROOT/zsh-bench" --raw >"$output"
  print -r -- "$output"
}

write_pty_commands() {
  local output="$1"

  cat >"$output" <<'EOF'
print "AUDIT pure_precmd=$(whence -w prompt_pure_precmd 2>/dev/null)"
print "AUDIT async_start_worker=$(whence -w async_start_worker 2>/dev/null)"
print "AUDIT compinit=$(whence -w compinit 2>/dev/null)"
print "AUDIT main_complete=$(whence -w _main_complete 2>/dev/null)"
print "AUDIT fzf_tab=$(whence -w fzf-tab-complete 2>/dev/null)"
print "AUDIT fast_theme=$(whence -w fast-theme 2>/dev/null)"
print "AUDIT direnv_hook=$(whence -w _direnv_hook 2>/dev/null)"
print "AUDIT zoxide_hook=$(whence -w __zoxide_hook 2>/dev/null)"
print "AUDIT meta_del=$(bindkey -M viins '^[^?')"
print "AUDIT tab_emacs=$(bindkey -M emacs '^I')"
print "AUDIT tab_viins=$(bindkey -M viins '^I')"
print "AUDIT ftb_orig=${_ftb_orig_widget-UNSET}"
print "AUDIT vicmd_paren=$(bindkey -M vicmd ')')"
print "AUDIT vicmd_as=$(bindkey -M vicmd 'as')"
print "AUDIT precmd=${(j:|:)precmd_functions}"
print "AUDIT preexec=${(j:|:)preexec_functions}"
print "AUDIT chpwd=${(j:|:)chpwd_functions}"
print "AUDIT direnv_cmd=$(command -v direnv || echo MISSING)"

tmp="$(mktemp -d)"
mkdir -p "$tmp/demo"
print 'export DNV_TEST=smoke' > "$tmp/demo/.envrc"
cd "$tmp/demo"

if command -v direnv >/dev/null 2>&1; then
  direnv allow . >/dev/null 2>&1 || true
  cd / && cd "$tmp/demo"
  print "AUDIT direnv_smoke=${DNV_TEST-MISSING}"
else
  print "AUDIT direnv_smoke=NO_DIRENV"
fi

rm -rf "$tmp"
exit
EOF
}

run_pty_audit() {
  local lane="$1"
  local home_dir="$2"
  local cache_dir="$3"
  local commands_file="$TMP_ROOT/$lane-pty-commands.zsh"
  local output_file="$TMP_ROOT/$lane-pty-output.txt"
  local json_file="$TMP_ROOT/$lane-pty.json"
  local -a env_cmd

  mkdir -p "$cache_dir" "$TMP_ROOT/neutral-cwd"
  write_pty_commands "$commands_file"

  env_cmd=(
    env -i
    HOME="$home_dir"
    PATH="$SAFE_PATH"
    TERM=xterm-256color
    SHELL=/bin/zsh
    USER="${USER:-prateek}"
    LOGNAME="${LOGNAME:-${USER:-prateek}}"
    XDG_CACHE_HOME="$cache_dir"
    python3 -
    "$output_file"
    "$commands_file"
    "$TMP_ROOT/neutral-cwd"
  )

  if [[ "$lane" == antidote ]]; then
    env_cmd=(
      env -i
      HOME="$home_dir"
      PATH="$SAFE_PATH"
      TERM=xterm-256color
      SHELL=/bin/zsh
      USER="${USER:-prateek}"
      LOGNAME="${LOGNAME:-${USER:-prateek}}"
      XDG_CACHE_HOME="$cache_dir"
      ANTIDOTE_HOME="$ANTIDOTE_PLUGIN_HOME"
      python3 -
      "$output_file"
      "$commands_file"
      "$TMP_ROOT/neutral-cwd"
    )
  fi

  "${env_cmd[@]}" <<'PY'
import os
import pty
import select
import subprocess
import sys
import time

output_path, commands_path, cwd = sys.argv[1:4]
with open(commands_path, "r", encoding="utf-8") as fh:
    commands = fh.read().splitlines()

env = os.environ.copy()
master, slave = pty.openpty()
proc = subprocess.Popen(
    ["/bin/zsh", "-il"],
    stdin=slave,
    stdout=slave,
    stderr=slave,
    cwd=cwd,
    env=env,
    close_fds=True,
)
os.close(slave)

chunks = []

def drain_until_quiet(timeout=8.0, quiet=0.25):
    deadline = time.time() + timeout
    last = time.time()
    while time.time() < deadline:
        wait = max(0.0, min(0.2, deadline - time.time()))
        r, _, _ = select.select([master], [], [], wait)
        if master in r:
            try:
                chunk = os.read(master, 4096)
            except OSError:
                break
            if not chunk:
                break
            chunks.append(chunk)
            last = time.time()
            continue
        if time.time() - last >= quiet:
            break

drain_until_quiet()
for line in commands:
    os.write(master, (line + "\n").encode("utf-8"))
    drain_until_quiet(timeout=2.0, quiet=0.15)

deadline = time.time() + 10.0
while time.time() < deadline:
    r, _, _ = select.select([master], [], [], 0.2)
    if master in r:
        try:
            chunk = os.read(master, 4096)
        except OSError:
            break
        if not chunk:
            break
        chunks.append(chunk)
    if proc.poll() is not None:
        break

proc.wait(timeout=5)

with open(output_path, "wb") as fh:
    fh.write(b"".join(chunks))
PY

  python3 - "$output_file" "$json_file" <<'PY'
import json
import re
import sys

src, dst = sys.argv[1:3]
text = open(src, "rb").read().decode("utf-8", "replace")
text = re.sub(r"\x1b\][^\x07]*\x07", "", text)
text = re.sub(r"\x1b\[[0-9;?]*[ -/]*[@-~]", "", text)
text = text.replace("\r", "")
text = text.replace("\b", "")

audit = {}
for line in text.splitlines():
    if not line.startswith("AUDIT "):
        continue
    key, value = line[6:].split("=", 1)
    audit[key] = value

with open(dst, "w", encoding="utf-8") as fh:
    json.dump(audit, fh, indent=2, sort_keys=True)
PY

  print -r -- "$json_file"
}

emit_report() {
  local zinit_bench="$1"
  local antidote_bench="$2"
  local p10k_bench="$3"
  local zinit_audit="$4"
  local antidote_audit="$5"

  python3 - "$zinit_bench" "$antidote_bench" "$p10k_bench" "$zinit_audit" "$antidote_audit" <<'PY'
import json
import statistics
import sys

zinit_bench_path, antidote_bench_path, p10k_bench_path, zinit_audit_path, antidote_audit_path = sys.argv[1:6]

def parse_bench(path):
    data = {}
    for raw in open(path, encoding="utf-8"):
        raw = raw.strip()
        if not raw or "=" not in raw:
            continue
        key, value = raw.split("=", 1)
        key = key.strip()
        value = value.strip()
        if not (value.startswith("(") and value.endswith(")")):
            continue
        parts = [part for part in value[1:-1].split() if part]
        values = [float(part) for part in parts]
        data[key] = {
            "mean": statistics.mean(values),
            "median": statistics.median(values),
            "min": min(values),
            "max": max(values),
        }
    return data

def load_json(path):
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)

zinit_bench = parse_bench(zinit_bench_path)
antidote_bench = parse_bench(antidote_bench_path)
p10k_bench = parse_bench(p10k_bench_path)
zinit_audit = load_json(zinit_audit_path)
antidote_audit = load_json(antidote_audit_path)

strict_keys = [
    "pure_precmd",
    "async_start_worker",
    "compinit",
    "main_complete",
    "fzf_tab",
    "fast_theme",
    "direnv_hook",
    "zoxide_hook",
    "meta_del",
    "tab_emacs",
    "tab_viins",
    "ftb_orig",
    "vicmd_paren",
    "vicmd_as",
    "direnv_smoke",
]

info_keys = [
    "direnv_cmd",
    "precmd",
    "preexec",
    "chpwd",
]

reason_map = {
    "direnv_cmd": "zinit installs a managed direnv binary, while the antidote prototype relies on whatever direnv is already on PATH.",
    "precmd": "zinit contributes @zinit-scheduler, while the antidote prototype defers postprompt work through zle-line-init instead.",
    "chpwd": "zinit adds @zinit-scheduler to chpwd when turbo loading plugins, while the antidote prototype does not.",
}

gaps = []
for key in strict_keys:
    zinit_value = zinit_audit.get(key, "MISSING")
    antidote_value = antidote_audit.get(key, "MISSING")
    if zinit_value != antidote_value:
        gaps.append({
            "key": key,
            "zinit": zinit_value,
            "antidote": antidote_value,
            "reason": reason_map.get(key, "Antidote does not match the current zinit baseline for this feature."),
        })

notes = []
for key in info_keys:
    zinit_value = zinit_audit.get(key, "MISSING")
    antidote_value = antidote_audit.get(key, "MISSING")
    if zinit_value != antidote_value:
        notes.append({
            "key": key,
            "zinit": zinit_value,
            "antidote": antidote_value,
            "reason": reason_map.get(key, "Observed difference between the zinit baseline and the antidote prototype."),
        })

metrics = [
    "first_prompt_lag_ms",
    "first_command_lag_ms",
    "command_lag_ms",
    "input_lag_ms",
]

flags = [
    "has_compsys",
    "has_syntax_highlighting",
    "has_git_prompt",
]

lanes = {
    "zinit": zinit_bench,
    "antidote": antidote_bench,
    "p10k": p10k_bench,
}

print("==> zsh-bench")
for metric in metrics:
    values = []
    for lane_name in ("zinit", "antidote", "p10k"):
        values.append(f"{lane_name}={lanes[lane_name][metric]['mean']:.3f}ms")
    print(f"{metric}: " + " ".join(values))

print()
print("==> detected capabilities")
for flag in flags:
    values = []
    for lane_name in ("zinit", "antidote", "p10k"):
        values.append(f"{lane_name}={int(round(lanes[lane_name][flag]['mean']))}")
    print(f"{flag}: " + " ".join(values))

print()
print("==> zinit vs antidote strict feature diff")
if gaps:
    for gap in gaps:
        print(f"{gap['key']}:")
        print(f"  zinit:    {gap['zinit']}")
        print(f"  antidote: {gap['antidote']}")
        print(f"  reason:   {gap['reason']}")
else:
    print("No strict feature gaps found.")

print()
print("==> zinit vs antidote informational differences")
if notes:
    for note in notes:
        print(f"{note['key']}:")
        print(f"  zinit:    {note['zinit']}")
        print(f"  antidote: {note['antidote']}")
        print(f"  reason:   {note['reason']}")
else:
    print("No informational differences found.")

print()
print("==> raw report")
print(json.dumps({
    "bench": lanes,
    "audit": {
        "zinit": zinit_audit,
        "antidote": antidote_audit,
        "gaps": gaps,
        "notes": notes,
    },
}, indent=2, sort_keys=True))
PY
}

note "==> ensuring benchmark dependencies"
ensure_git_checkout "https://github.com/romkatv/zsh-bench" "$ZSH_BENCH_ROOT"
ensure_git_checkout "https://github.com/mattmc3/antidote" "$ANTIDOTE_SRC_ROOT"
ensure_git_checkout "https://github.com/romkatv/powerlevel10k.git" "$P10K_SRC_ROOT"
mkdir -p "$ANTIDOTE_PLUGIN_HOME"

note "==> building isolated homes"
zinit_home="$(setup_zinit_home)"
antidote_home="$(setup_antidote_home)"
p10k_home="$(setup_p10k_home)"

note "==> running zsh-bench"
zinit_bench="$(run_zsh_bench zinit "$zinit_home" "$TMP_ROOT/zinit-cache")"
antidote_bench="$(run_zsh_bench antidote "$antidote_home" "$TMP_ROOT/antidote-cache")"
p10k_bench="$(run_zsh_bench p10k "$p10k_home" "$TMP_ROOT/p10k-cache")"

note "==> auditing interactive shell features"
zinit_audit="$(run_pty_audit zinit "$zinit_home" "$TMP_ROOT/zinit-cache")"
antidote_audit="$(run_pty_audit antidote "$antidote_home" "$TMP_ROOT/antidote-cache")"

emit_report "$zinit_bench" "$antidote_bench" "$p10k_bench" "$zinit_audit" "$antidote_audit"
