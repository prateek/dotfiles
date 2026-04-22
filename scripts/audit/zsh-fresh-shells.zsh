#!/usr/bin/env zsh

set -euo pipefail
unsetopt xtrace 2>/dev/null || true
set +x 2>/dev/null || true
unsetopt verbose 2>/dev/null || true
set +v 2>/dev/null || true
setopt typeset_silent 2>/dev/null || true

zmodload zsh/zpty
zmodload zsh/zselect
zmodload zsh/datetime

typeset -gr AUDIT_SCRIPT_NAME="${0:t}"
typeset -gr DEFAULT_DOTFILES_ROOT="$HOME/dotfiles"
typeset -gr DEFAULT_SAFE_PATH='/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin'
typeset -gr DEFAULT_ZSH_BENCH_ROOT="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles-zsh-startup-bench/zsh-bench"
typeset -gr ZSH_BENCH_REPO='https://github.com/romkatv/zsh-bench'
typeset -gr ZSH_BENCH_COMMIT='a3c48d65b9078ee1f8bbd4da8631a8fbc885c52a'

typeset -gA SUBJECT_current=(
  substrate macos-host
  shell /bin/zsh
  overlay current
)

typeset -ga VERIFY_CHECKS=(
  prompt_first_paint
  startup_clean
  env_dotfiles
  env_ghpath
  env_editor
  env_ghcup_use_xdg_dirs
  option_interactivecomments
  option_nomatch
  path_home_bin_first
  path_go_bin
  path_pnpm_bin
  path_mise_shims
  histfile
  histsize
  savehist
  extended_history
  hist_ignore_space
  inc_append_history
  keytimeout
  word_style_shell
  vi_escape_binding
  alt_backspace
  alt_backspace_emacs
  alt_left
  alt_right
  tab_emacs_widget
  tab_viins_widget
  ctrl_r_binding
  ctrl_t_emacs_binding
  ctrl_t_viins_binding
  ctrl_t_vicmd_binding
  vicmd_paren
  vicmd_as
  vicmd_q
  vicmd_v
  viins_ctrl_p
  vicmd_ctrl_u
  direnv_enter_leave
  zoxide_jump
  ghc_usage
  gsp_behavior
)

typeset -gA BENCH_BUDGETS=(
  first_prompt_lag_ms 320
  first_command_lag_ms 320
  command_lag_ms 12
  input_lag_ms 6
)

typeset -gi audit_passes=0
typeset -gi audit_failures=0
typeset -gi audit_infos=0
typeset -g audit_tmp_root=''
typeset -g audit_keep_tmp=0
typeset -g audit_dotfiles_root="$DEFAULT_DOTFILES_ROOT"
typeset -g audit_zsh_bench_root="$DEFAULT_ZSH_BENCH_ROOT"
typeset -g audit_mode='verify'

usage() {
  cat <<EOF
Usage:
  $AUDIT_SCRIPT_NAME verify [--dotfiles-root PATH] [--keep-tmp]
  $AUDIT_SCRIPT_NAME bench  [--dotfiles-root PATH] [--zsh-bench-root PATH] [--keep-tmp]
  $AUDIT_SCRIPT_NAME diagnose [--dotfiles-root PATH] [--keep-tmp]
  $AUDIT_SCRIPT_NAME selftest [--dotfiles-root PATH] [--zsh-bench-root PATH]
  source $AUDIT_SCRIPT_NAME doctor

Modes:
  verify    Fresh-shell correctness checks on a synthetic home.
  bench     Startup benchmark using pinned external zsh-bench.
  diagnose  Fresh-shell diagnostic dump for hook and widget provenance.
  selftest  End-to-end regression checks for this harness.
  doctor    Source-only current-shell helper.
EOF
}

die() {
  print -u2 -- "$AUDIT_SCRIPT_NAME: $*"
  exit 2
}

cleanup() {
  if [[ -n "$audit_tmp_root" && -d "$audit_tmp_root" && "$audit_keep_tmp" -ne 0 ]]; then
    print -u2 -- "$AUDIT_SCRIPT_NAME: tmp_root=$audit_tmp_root"
    return 0
  fi

  if [[ -n "$audit_tmp_root" && -d "$audit_tmp_root" && "$audit_keep_tmp" -eq 0 ]]; then
    rm -rf "$audit_tmp_root"
  fi
}

emit_result() {
  local mode="$1"
  local result_status="$2"
  local check_id="$3"
  local detail="${4:-}"

  case "$result_status" in
    PASS) (( audit_passes += 1 )) ;;
    FAIL) (( audit_failures += 1 )) ;;
    INFO) (( audit_infos += 1 )) ;;
  esac

  print -- "RESULT|$mode|$result_status|$check_id|$detail"
}

emit_summary() {
  local mode="$1"
  print -- "SUMMARY|$mode|passed=$audit_passes|failed=$audit_failures|info=$audit_infos"
}

emit_single_result_from_blob() {
  local mode="$1"
  local blob="$2"
  local check_id="$3"
  local compact="${blob//$'\n'/ }"

  if [[ "$compact" == *"PASS"* ]]; then
    emit_result "$mode" PASS "$check_id" "$compact"
  else
    emit_result "$mode" FAIL "$check_id" "${compact:-no structured result captured}"
  fi
}

reset_counters() {
  audit_passes=0
  audit_failures=0
  audit_infos=0
}

parse_args() {
  local -a args=("$@")

  if (( $#args == 0 )); then
    audit_mode='verify'
    return 0
  fi

  case "$1" in
    verify|bench|diagnose|selftest|doctor|--help|-h)
      audit_mode="$1"
      shift
      ;;
    *)
      die "unknown mode: $1"
      ;;
  esac

  if [[ "$audit_mode" == '--help' || "$audit_mode" == '-h' ]]; then
    usage
    exit 0
  fi

  while (( $# > 0 )); do
    case "$1" in
      --dotfiles-root)
        shift
        (( $# > 0 )) || die "missing value for --dotfiles-root"
        audit_dotfiles_root="${1:A}"
        ;;
      --zsh-bench-root)
        shift
        (( $# > 0 )) || die "missing value for --zsh-bench-root"
        audit_zsh_bench_root="${1:A}"
        ;;
      --keep-tmp)
        audit_keep_tmp=1
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      *)
        die "unsupported argument: $1"
        ;;
    esac
    shift
  done
}

ensure_tmp_root() {
  if [[ -n "$audit_tmp_root" ]]; then
    return 0
  fi
  audit_tmp_root="$(mktemp -d)"
  trap cleanup EXIT
}

prepare_home() {
  local dotfiles_root="$1"
  local home_dir="$audit_tmp_root/home"

  mkdir -p "$home_dir"
  mkdir -p \
    "$home_dir/bin" \
    "$home_dir/.local/bin" \
    "$home_dir/.local/share/mise/shims" \
    "$home_dir/.local/state" \
    "$home_dir/.cache" \
    "$home_dir/go/bin" \
    "$home_dir/Library/pnpm" \
    "$home_dir/code/FlameGraph" \
    "$home_dir/.cargo/bin"
  mkdir -p "$home_dir/.config"

  ln -snf "$dotfiles_root" "$home_dir/dotfiles"
  ln -snf "$home_dir/dotfiles/zprofile" "$home_dir/.zprofile"
  ln -snf "$home_dir/dotfiles/zshrc" "$home_dir/.zshrc"
  ln -snf "$home_dir/dotfiles/zshenv" "$home_dir/.zshenv"

  if [[ -d "$HOME/.zinit" ]]; then
    ln -snf "$HOME/.zinit" "$home_dir/.zinit"
  fi

  print -r -- "$home_dir"
}

write_runner_script() {
  local home_dir="$1"
  local cwd="$2"
  local output="$audit_tmp_root/run-shell.zsh"

  cat >"$output" <<EOF
#!/usr/bin/env zsh
cd ${(q)cwd}
exec env -i \
  HOME=${(q)home_dir} \
  PATH=${(q)DEFAULT_SAFE_PATH} \
  TERM=xterm-256color \
  SHELL=/bin/zsh \
  USER=${(q)${USER:-prateek}} \
  LOGNAME=${(q)${LOGNAME:-${USER:-prateek}}} \
  ZDOTDIR=${(q)home_dir} \
  DOTFILES_SKIP_LAUNCHCTL_SYNC=1 \
  /bin/zsh -il
EOF
  chmod +x "$output"
  print -r -- "$output"
}

session_start() {
  local session_name="$1"
  local home_dir="$2"
  local cwd="$3"
  local runner

  runner="$(write_runner_script "$home_dir" "$cwd")"
  zpty -b "$session_name" "$runner"
}

session_stop() {
  local session_name="$1"
  if zpty -t "$session_name" >/dev/null 2>&1; then
    zpty -w "$session_name" "exit" || true
  fi
  zpty -d "$session_name" 2>/dev/null || true
}

session_read_until() {
  local session_name="$1"
  local pattern="$2"
  local timeout="${3:-5}"
  local buffer=''
  local chunk=''
  local start=$EPOCHREALTIME

  while (( EPOCHREALTIME - start < timeout )); do
    while zpty -rt "$session_name" chunk >/dev/null 2>&1; do
      buffer+="$chunk"
      [[ "$buffer" == *"$pattern"* ]] && {
        REPLY="$buffer"
        return 0
      }
    done
    zselect -t 0.05 2>/dev/null || true
  done

  REPLY="$buffer"
  return 1
}

session_send_and_wait_for_prompt() {
  local session_name="$1"
  local command_text="$2"
  local timeout="${3:-8}"
  local buffer chunk quiet_start

  zpty -w "$session_name" "$command_text"
  session_read_until "$session_name" 'λ' "$timeout" || true
  buffer="$REPLY"
  quiet_start=$EPOCHREALTIME

  while (( EPOCHREALTIME - quiet_start < 0.25 )); do
    if zpty -rt "$session_name" chunk >/dev/null 2>&1; then
      buffer+="$chunk"
      quiet_start=$EPOCHREALTIME
      continue
    fi
    zselect -t 0.05 2>/dev/null || true
  done

  REPLY="$buffer"
}

extract_prefixed_lines() {
  local text="$1"
  local prefix="$2"
  local line

  for line in ${(f)text}; do
    if [[ "$line" == *"$prefix"* ]]; then
      print -r -- "$prefix${line#*"$prefix"}"
    fi
  done
  return 0
}

count_result_lines() {
  local text="$1"
  local line
  local -a parts

  for line in ${(f)text}; do
    [[ "$line" == RESULT\|* ]] || continue
    parts=(${(s:|:)line})
    case "${parts[3]-}" in
      PASS) (( audit_passes += 1 )) ;;
      FAIL) (( audit_failures += 1 )) ;;
      INFO) (( audit_infos += 1 )) ;;
    esac
  done
}

write_verify_probe() {
  local output="$audit_tmp_root/verify-probe.zsh"

  cat >"$output" <<'EOF'
audit_emit_result() {
  print -r -- "RESULT|verify|$1|$2|$3"
}

audit_pass() {
  audit_emit_result PASS "$1" "$2"
}

audit_fail() {
  audit_emit_result FAIL "$1" "$2"
}

audit_info() {
  audit_emit_result INFO "$1" "$2"
}

audit_expect_equal() {
  local check_id="$1"
  local expected="$2"
  local observed="$3"

  if [[ "$observed" == "$expected" ]]; then
    audit_pass "$check_id" "$observed"
  else
    audit_fail "$check_id" "expected=$expected observed=$observed"
  fi
}

audit_expect_nonempty() {
  local check_id="$1"
  local observed="$2"

  if [[ -n "$observed" ]]; then
    audit_pass "$check_id" "$observed"
  else
    audit_fail "$check_id" "observed=EMPTY"
  fi
}

audit_expect_function_present() {
  local check_id="$1"
  local fn="$2"
  local resolved

  resolved="$(whence -w "$fn" 2>/dev/null || true)"
  if [[ "$resolved" == *"function"* || "$resolved" == *"builtin"* || "$resolved" == *"autoload"* ]]; then
    audit_pass "$check_id" "$resolved"
  else
    audit_fail "$check_id" "missing function: $fn"
  fi
}

audit_expect_hook_contains() {
  local check_id="$1"
  local array_name="$2"
  local expected="$3"
  local -a values

  values=("${(@P)array_name}")
  if (( ${values[(Ie)$expected]} )); then
    audit_pass "$check_id" "${(j:|:)values}"
  else
    audit_fail "$check_id" "${(j:|:)values}"
  fi
}

audit_expect_path_contains() {
  local check_id="$1"
  local expected="$2"

  if (( ${path[(Ie)$expected]} )); then
    audit_pass "$check_id" "$expected"
  else
    audit_fail "$check_id" "missing PATH entry: $expected"
  fi
}

audit_expect_command_available() {
  local check_id="$1"
  local cmd="$2"
  local resolved

  resolved="$(command -v "$cmd" 2>/dev/null || true)"
  if [[ -n "$resolved" ]]; then
    audit_pass "$check_id" "$resolved"
  else
    audit_fail "$check_id" "command not found: $cmd"
  fi
}

audit_expect_zstyle_line() {
  local check_id="$1"
  local context="$2"
  local style_name="$3"
  local expected="$4"
  local observed

  observed="$(zstyle -L "$context" "$style_name" 2>/dev/null || true)"
  if [[ "$observed" == "$expected" ]]; then
    audit_pass "$check_id" "$observed"
  else
    audit_fail "$check_id" "expected=$expected observed=${observed:-EMPTY}"
  fi
}

audit_expect_option_on() {
  local check_id="$1"
  local option_name="$2"

  if [[ -o "$option_name" ]]; then
    audit_pass "$check_id" "$option_name=on"
  else
    audit_fail "$check_id" "$option_name=off"
  fi
}

audit_expect_binding_contains() {
  local check_id="$1"
  local keymap="$2"
  local sequence="$3"
  local needle="$4"
  local binding

  binding="$(bindkey -M "$keymap" "$sequence" 2>/dev/null || true)"
  if [[ "$binding" == *"$needle"* ]]; then
    audit_pass "$check_id" "$binding"
  else
    audit_fail "$check_id" "${binding:-missing binding}"
  fi
}

audit_probe_direnv() {
  local probe_root="$1"
  local direnv_root="$probe_root/direnv-demo"
  local direnv_var='DOTFILES_AUDIT_DIRENV'
  local enter_value leave_value

  if ! command -v direnv >/dev/null 2>&1; then
    audit_fail direnv_enter_leave "direnv missing"
    print -r -- "__AUDIT_DONE__|direnv"
    return 0
  fi

  mkdir -p "$direnv_root"
  print "export $direnv_var=ready" >"$direnv_root/.envrc"
  (
    cd "$direnv_root"
    direnv allow . >/dev/null 2>&1 || true
  )
  cd /
  cd "$direnv_root"
  enter_value="${(P)direnv_var-UNSET}"
  cd /
  leave_value="${(P)direnv_var-UNSET}"
  if [[ "$enter_value" == ready && "$leave_value" == UNSET ]]; then
    audit_pass direnv_enter_leave "enter=$enter_value leave=$leave_value"
  else
    audit_fail direnv_enter_leave "enter=$enter_value leave=$leave_value"
  fi

  print -r -- "__AUDIT_DONE__|direnv"
}

audit_probe_zoxide() {
  local probe_root="$1"
  local zoxide_root="$probe_root/zoxide-demo"
  local alpha="$zoxide_root/alpha"
  local beta="$zoxide_root/beta"
  local jump_path=''
  local z_path=''

  mkdir -p "$alpha" "$beta"
  cd "$alpha"
  cd "$beta"

  if ! command -v j >/dev/null 2>&1 || ! command -v z >/dev/null 2>&1; then
    audit_fail zoxide_jump "j_or_z_missing"
    return 0
  fi

  if j alpha >/dev/null 2>&1; then
    jump_path="$PWD"
  fi
  cd "$beta"
  if z alpha >/dev/null 2>&1; then
    z_path="$PWD"
  fi

  if [[ "$jump_path" == "$alpha" && "$z_path" == "$alpha" ]]; then
    audit_pass zoxide_jump "j=$jump_path z=$z_path"
  else
    audit_fail zoxide_jump "j=$jump_path z=$z_path expected=$alpha"
  fi
}

audit_probe_helpers() {
  local scratch_root="$1"
  local err_file="$scratch_root/helper.err"
  local out_file="$scratch_root/helper.out"
  local rc=0

  : >| "$err_file"
  : >| "$out_file"

  set +e
  ghc >"$out_file" 2>"$err_file"
  rc=$?
  set -e
  if [[ "$rc" -eq 2 && "$(<"$err_file")" == *"usage: ghc"* ]]; then
    audit_pass ghc_usage "rc=$rc"
  else
    audit_fail ghc_usage "rc=$rc stderr=$(tr '\n' ' ' <"$err_file")"
  fi

  local gs_bin
  gs_bin="$(whence -p gs 2>/dev/null || true)"
  : >| "$err_file"
  : >| "$out_file"
  if [[ -n "$gs_bin" ]]; then
    set +e
    gsp --help >"$out_file" 2>"$err_file"
    rc=$?
    set -e
    if [[ "$rc" -eq 0 && "$(<"$out_file")" == *"git-spice"* ]]; then
      audit_pass gsp_behavior "backend=$gs_bin"
    elif [[ "$rc" -eq 127 && "$(<"$err_file")" == *"does not look like git-spice"* ]]; then
      audit_pass gsp_behavior "backend=$gs_bin rejected_as_non_git_spice"
    else
      audit_fail gsp_behavior "backend=$gs_bin rc=$rc stdout=$(tr '\n' ' ' <"$out_file") stderr=$(tr '\n' ' ' <"$err_file")"
    fi
  else
    set +e
    gsp >"$out_file" 2>"$err_file"
    rc=$?
    set -e
    if [[ "$rc" -eq 127 && "$(<"$err_file")" == *"not found on PATH"* ]]; then
      audit_pass gsp_behavior "backend=missing rc=$rc"
    else
      audit_fail gsp_behavior "backend=missing rc=$rc stderr=$(tr '\n' ' ' <"$err_file")"
    fi
  fi
}

audit_wait_for_shell_ready() {
  local attempts=50
  local tab_binding ctrl_r_binding

  while (( attempts-- > 0 )); do
    tab_binding="$(bindkey -M viins '^I' 2>/dev/null || true)"
    ctrl_r_binding="$(bindkey '^R' 2>/dev/null || true)"

    if [[ "$tab_binding" == *"fzf-tab-complete"* && "$ctrl_r_binding" == *"fzf-history-widget"* ]]; then
      return 0
    fi

    sleep 0.1
  done

  return 1
}

audit_verify_all() {
  local probe_root="$1"

  audit_wait_for_shell_ready || true

  audit_info subject "shell=$SHELL zsh=$ZSH_VERSION"
  audit_expect_equal env_dotfiles "$HOME/dotfiles" "${DOTFILES:-}"
  audit_expect_equal env_ghpath "$HOME/code/github.com" "${GHPATH:-}"
  audit_expect_equal env_editor "nvim" "${EDITOR:-}"
  audit_expect_equal env_ghcup_use_xdg_dirs "1" "${GHCUP_USE_XDG_DIRS:-}"
  audit_expect_option_on option_interactivecomments interactivecomments
  audit_expect_option_on option_nomatch nomatch
  audit_expect_equal path_home_bin_first "$HOME/bin" "${path[1]-}"
  audit_expect_path_contains path_go_bin "$HOME/go/bin"
  audit_expect_path_contains path_pnpm_bin "$HOME/Library/pnpm"
  audit_expect_path_contains path_mise_shims "$HOME/.local/share/mise/shims"

  audit_expect_equal histfile "$HOME/.zhistory" "${HISTFILE:-}"
  audit_expect_equal histsize "30000" "${HISTSIZE:-}"
  audit_expect_equal savehist "30000" "${SAVEHIST:-}"
  audit_expect_option_on extended_history extendedhistory
  audit_expect_option_on hist_ignore_space histignorespace
  audit_expect_option_on inc_append_history incappendhistory

  audit_expect_equal keytimeout "1" "${KEYTIMEOUT:-}"
  audit_expect_zstyle_line word_style_shell ':zle:*' word-style "zstyle ':zle:*' word-style shell"
  audit_expect_binding_contains vi_escape_binding viins $'\e' vi-cmd-mode
  audit_expect_binding_contains alt_backspace viins '^[^?' backward-kill-word
  audit_expect_binding_contains alt_backspace_emacs emacs '^[^?' backward-kill-word
  audit_expect_binding_contains alt_left main '^[^[[D' backward-word
  audit_expect_binding_contains alt_right main '^[^[[C' forward-word
  audit_expect_binding_contains tab_emacs_widget emacs '^I' fzf-tab-complete
  audit_expect_binding_contains tab_viins_widget viins '^I' fzf-tab-complete
  audit_expect_binding_contains ctrl_r_binding main '^R' fzf-history-widget
  audit_expect_binding_contains ctrl_t_emacs_binding emacs '^T' fzf-file-widget
  audit_expect_binding_contains ctrl_t_viins_binding viins '^T' fzf-file-widget
  audit_expect_binding_contains ctrl_t_vicmd_binding vicmd '^T' fzf-file-widget
  audit_expect_binding_contains vicmd_paren vicmd ')' vi-forward-command
  audit_expect_binding_contains vicmd_as vicmd 'as' select-a-command
  audit_expect_binding_contains vicmd_q vicmd q push-line
  audit_expect_binding_contains vicmd_v vicmd v edit-command-line
  audit_expect_binding_contains viins_ctrl_p viins '^P' insert-last-command-output
  audit_expect_binding_contains vicmd_ctrl_u vicmd '^U' url_select

  audit_probe_zoxide "$probe_root"
  audit_probe_helpers "$probe_root"

  print -r -- "__AUDIT_DONE__|verify_core"
}

audit_diagnose_all() {
  print -r -- "INFO|diagnose|pure_prompt_hook|$(whence -w prompt_pure_precmd 2>/dev/null || true)"
  print -r -- "INFO|diagnose|pure_async_helper|$(whence -w async_start_worker 2>/dev/null || true)"
  print -r -- "INFO|diagnose|completion_init|$(whence -w compinit 2>/dev/null || true)"
  print -r -- "INFO|diagnose|completion_dispatcher|$(whence -w _main_complete 2>/dev/null || true)"
  print -r -- "INFO|diagnose|fzf_tab_widget|$(whence -w fzf-tab-complete 2>/dev/null || true)"
  print -r -- "INFO|diagnose|syntax_highlighting_loader|$(whence -w fast-theme 2>/dev/null || true)"
  print -r -- "INFO|diagnose|direnv_hook|$(whence -w _direnv_hook 2>/dev/null || true)"
  print -r -- "INFO|diagnose|zoxide_hook|$(whence -w __zoxide_hook 2>/dev/null || true)"
  print -r -- "INFO|diagnose|fzf_tab_wraps_fzf_completion|${_ftb_orig_widget-UNSET}"
  print -r -- "INFO|diagnose|widgets|$(bindkey -M viins '^I' 2>/dev/null || true)"
  print -r -- "INFO|diagnose|precmd|${(j:|:)precmd_functions}"
  print -r -- "INFO|diagnose|preexec|${(j:|:)preexec_functions}"
  print -r -- "INFO|diagnose|chpwd|${(j:|:)chpwd_functions}"
  print -r -- "INFO|diagnose|command_direnv_available|$(command -v direnv 2>/dev/null || print -r -- MISSING)"
  print -r -- "INFO|diagnose|command_j_available|$(command -v j 2>/dev/null || print -r -- MISSING)"
  print -r -- "INFO|diagnose|command_z_available|$(command -v z 2>/dev/null || print -r -- MISSING)"
  print -r -- "INFO|diagnose|command_gsp_available|$(command -v gsp 2>/dev/null || print -r -- MISSING)"
  print -r -- "__AUDIT_DONE__|diagnose"
}
EOF

  print -r -- "$output"
}

run_verify() {
  local dotfiles_root="$1"
  local home_dir neutral_cwd probe_root session_name='audit_verify'
  local startup_output child_output direnv_output raw_results

  ensure_tmp_root
  home_dir="$(prepare_home "$dotfiles_root")"
  neutral_cwd="$audit_tmp_root/neutral"
  probe_root="$audit_tmp_root/probes"
  mkdir -p "$neutral_cwd" "$probe_root"

  session_start "$session_name" "$home_dir" "$neutral_cwd"
  {
    session_read_until "$session_name" 'λ' 8 || true
    startup_output="$REPLY"

    if [[ "$startup_output" == *'λ'* ]]; then
      emit_result verify PASS prompt_first_paint 'observed=λ'
    else
      emit_result verify FAIL prompt_first_paint 'prompt symbol λ not observed'
    fi

    if [[ "$startup_output" == *'bindkey:'* || "$startup_output" == *'not found at'* || "$startup_output" == *'command not found'* || "$startup_output" == *'Could not find the init script'* ]]; then
      emit_result verify FAIL startup_clean 'startup emitted an error marker'
    else
      emit_result verify PASS startup_clean 'no startup error markers observed'
    fi

    local probe_file
    probe_file="$(write_verify_probe)"
    session_send_and_wait_for_prompt "$session_name" "source ${(q)probe_file}"
    session_send_and_wait_for_prompt "$session_name" "true"
    session_send_and_wait_for_prompt "$session_name" "true"
    session_send_and_wait_for_prompt "$session_name" "true"
    zpty -w "$session_name" "audit_probe_direnv ${(q)probe_root}"
    session_read_until "$session_name" '__AUDIT_DONE__|direnv' 12 || true
    direnv_output="$REPLY"
    session_send_and_wait_for_prompt "$session_name" "true"
    zpty -w "$session_name" "audit_verify_all ${(q)probe_root}"
    session_read_until "$session_name" '__AUDIT_DONE__|verify_core' 12 || true
    child_output="$REPLY"
  } always {
    session_stop "$session_name"
  }

  raw_results="$(extract_prefixed_lines "$direnv_output" 'RESULT|')"
  if [[ -n "$raw_results" ]]; then
    print -r -- "$raw_results"
    count_result_lines "$raw_results"
  else
    emit_single_result_from_blob verify "$direnv_output" direnv_enter_leave || true
  fi

  raw_results="$(extract_prefixed_lines "$child_output" 'RESULT|')"
  if [[ -n "$raw_results" ]]; then
    print -r -- "$raw_results"
    count_result_lines "$raw_results"
  fi

  emit_summary verify
  (( audit_failures == 0 ))
}

resolve_zsh_bench_root() {
  local root="$1"

  [[ -n "$root" ]] || root="$DEFAULT_ZSH_BENCH_ROOT"

  if [[ ! -d "$root/.git" ]]; then
    REPLY=''
    return 1
  fi

  local commit
  commit="$(git -C "$root" rev-parse HEAD 2>/dev/null || true)"
  if [[ "$commit" != "$ZSH_BENCH_COMMIT" ]]; then
    REPLY="$commit"
    return 2
  fi

  REPLY="$root"
  return 0
}

median_of_list() {
  local raw="$1"
  local cleaned="${raw#*\(}"
  cleaned="${cleaned%\)}"
  cleaned="${cleaned//[$'\t\r\n']/ }"
  local -a values sorted
  local -F 6 median

  values=(${=cleaned})
  (( $#values > 0 )) || return 1
  sorted=(${(on)values})

  if (( $#sorted % 2 )); then
    median="${sorted[$(( $#sorted / 2 + 1 ))]}"
  else
    local left=$(( $#sorted / 2 ))
    local right=$(( left + 1 ))
    median=$(( (sorted[left] + sorted[right]) / 2.0 ))
  fi

  REPLY="$median"
}

run_bench() {
  local dotfiles_root="$1"
  local requested_root="$2"
  local resolved_root dependency_detail dependency_rc
  local home_dir neutral_cwd raw_output raw_file line metric median budget candidate

  ensure_tmp_root
  if resolve_zsh_bench_root "$requested_root"; then
    dependency_rc=0
  else
    dependency_rc=$?
  fi

  if (( dependency_rc != 0 )); then
    case "$dependency_rc" in
      1)
        emit_result bench FAIL zsh_bench_dependency "missing checkout at $requested_root; bootstrap with: git clone $ZSH_BENCH_REPO $requested_root && git -C $requested_root checkout $ZSH_BENCH_COMMIT"
        ;;
      2)
        emit_result bench FAIL zsh_bench_dependency "expected_commit=$ZSH_BENCH_COMMIT observed_commit=$REPLY root=$requested_root"
        ;;
    esac
    emit_summary bench
    return 2
  fi

  resolved_root="$REPLY"
  dependency_detail="root=$resolved_root commit=$ZSH_BENCH_COMMIT"
  emit_result bench INFO zsh_bench_dependency "$dependency_detail"

  home_dir="$(prepare_home "$dotfiles_root")"
  neutral_cwd="$audit_tmp_root/neutral-bench"
  mkdir -p "$neutral_cwd"
  raw_file="$audit_tmp_root/zsh-bench.raw"

  (
    cd "$neutral_cwd"
    env -i \
      HOME="$home_dir" \
      PATH="$DEFAULT_SAFE_PATH" \
      TERM=xterm-256color \
      SHELL=/bin/zsh \
      USER="${USER:-prateek}" \
      LOGNAME="${LOGNAME:-${USER:-prateek}}" \
      ZDOTDIR="$home_dir" \
      DOTFILES_SKIP_LAUNCHCTL_SYNC=1 \
      "$resolved_root/zsh-bench" --raw
  ) >"$raw_file"

  raw_output="$(<"$raw_file")"
  for metric in ${(k)BENCH_BUDGETS}; do
    line=''
    for candidate in ${(f)raw_output}; do
      if [[ "$candidate" == "$metric="* ]]; then
        line="$candidate"
        break
      fi
    done
    if [[ -z "$line" ]]; then
      emit_result bench FAIL "$metric" 'metric missing from zsh-bench output'
      continue
    fi
    median_of_list "$line" || {
      emit_result bench FAIL "$metric" 'could not compute median'
      continue
    }
    median="$REPLY"
    budget="${BENCH_BUDGETS[$metric]}"
    if (( ${median%.*} <= budget )) || (( median <= budget )); then
      emit_result bench PASS "$metric" "median=$median budget=$budget"
    else
      emit_result bench FAIL "$metric" "median=$median budget=$budget"
    fi
  done

  emit_summary bench
  (( audit_failures == 0 ))
}

run_diagnose() {
  local dotfiles_root="$1"
  local home_dir neutral_cwd session_name='audit_diagnose'
  local child_output result_lines

  ensure_tmp_root
  home_dir="$(prepare_home "$dotfiles_root")"
  neutral_cwd="$audit_tmp_root/neutral-diagnose"
  mkdir -p "$neutral_cwd"

  session_start "$session_name" "$home_dir" "$neutral_cwd"
  {
    session_read_until "$session_name" 'λ' 8 || true
    local probe_file
    probe_file="$(write_verify_probe)"
    zpty -w "$session_name" "source ${(q)probe_file}"
    zpty -w "$session_name" "audit_diagnose_all"
    session_read_until "$session_name" '__AUDIT_DONE__|diagnose' 8 || true
    child_output="$REPLY"
  } always {
    session_stop "$session_name"
  }

  result_lines="$(extract_prefixed_lines "$child_output" 'INFO|diagnose|')"
  if [[ -n "$result_lines" ]]; then
    print -r -- "$result_lines"
  fi
}

run_doctor() {
  if ! (return 0 2>/dev/null); then
    print -u2 -- "doctor mode must be sourced from an interactive zsh: source $audit_dotfiles_root/scripts/audit/zsh-fresh-shells.zsh doctor"
    exit 2
  fi

  if [[ -z ${ZSH_VERSION:-} || ! -o interactive || ! -o zle ]]; then
    print -u2 -- "doctor mode requires an interactive zsh with zle enabled"
    return 2
  fi

  emit_result doctor INFO mode 'current interactive shell'
  emit_result doctor INFO dotfiles_root "${DOTFILES:-UNSET}"
  emit_result doctor INFO tab_viins_widget "$(bindkey -M viins '^I' 2>/dev/null || true)"
  emit_result doctor INFO ctrl_r_binding "$(bindkey '^R' 2>/dev/null || true)"
  emit_result doctor INFO precmd_functions "${(j:|:)precmd_functions}"
  emit_summary doctor
  return 0
}

selftest_run_capture() {
  local expected_rc="$1"
  shift

  local capture_file output rc
  capture_file="$(mktemp)"
  set +e
  "$@" >"$capture_file" 2>&1
  rc=$?
  set -e
  output="$(<"$capture_file")"
  rm -f "$capture_file"

  if [[ "$rc" -ne "$expected_rc" ]]; then
    print -u2 -- "$output"
    die "selftest expected rc=$expected_rc, got rc=$rc for: $*"
  fi

  REPLY="$output"
}

selftest_exec_verify() {
  reset_counters
  audit_tmp_root=''
  audit_keep_tmp=0
  run_verify "$1"
}

selftest_exec_bench() {
  reset_counters
  audit_tmp_root=''
  audit_keep_tmp=0
  run_bench "$1" "$2"
}

selftest_assert_contains() {
  local haystack="$1"
  local needle="$2"
  [[ "$haystack" == *"$needle"* ]] || die "selftest missing expected text: $needle"
}

selftest_assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  [[ "$haystack" != *"$needle"* ]] || die "selftest saw unexpected text: $needle"
}

run_selftest() {
  local dotfiles_root="$1"
  local zsh_bench_root="$2"
  local verify_output bench_output missing_bench_output negative_output
  local selftest_tmp overlay_root

  selftest_run_capture 0 \
    selftest_exec_verify "$dotfiles_root"
  verify_output="$REPLY"
  selftest_assert_contains "$verify_output" "RESULT|verify|PASS|prompt_first_paint|"
  selftest_assert_contains "$verify_output" "RESULT|verify|PASS|path_home_bin_first|"
  selftest_assert_contains "$verify_output" "RESULT|verify|PASS|path_go_bin|"
  selftest_assert_contains "$verify_output" "RESULT|verify|PASS|path_pnpm_bin|"
  selftest_assert_contains "$verify_output" "RESULT|verify|PASS|word_style_shell|"
  selftest_assert_contains "$verify_output" "RESULT|verify|PASS|alt_backspace_emacs|"
  selftest_assert_contains "$verify_output" "RESULT|verify|PASS|direnv_enter_leave|"
  selftest_assert_contains "$verify_output" "RESULT|verify|PASS|zoxide_jump|"
  selftest_assert_contains "$verify_output" "RESULT|verify|PASS|ghc_usage|"
  selftest_assert_contains "$verify_output" "RESULT|verify|PASS|gsp_behavior|"
  selftest_assert_contains "$verify_output" "SUMMARY|verify|"
  selftest_assert_not_contains "$verify_output" "RESULT|verify|FAIL|"

  selftest_run_capture 0 \
    selftest_exec_bench "$dotfiles_root" "$zsh_bench_root"
  bench_output="$REPLY"
  selftest_assert_contains "$bench_output" "RESULT|bench|INFO|zsh_bench_dependency|"
  selftest_assert_contains "$bench_output" "RESULT|bench|PASS|first_prompt_lag_ms|"
  selftest_assert_contains "$bench_output" "RESULT|bench|PASS|first_command_lag_ms|"
  selftest_assert_contains "$bench_output" "RESULT|bench|PASS|command_lag_ms|"
  selftest_assert_contains "$bench_output" "RESULT|bench|PASS|input_lag_ms|"
  selftest_assert_contains "$bench_output" "SUMMARY|bench|"
  selftest_assert_not_contains "$bench_output" "RESULT|bench|FAIL|"

  selftest_run_capture 2 \
    selftest_exec_bench "$dotfiles_root" "$dotfiles_root/does-not-exist"
  missing_bench_output="$REPLY"
  selftest_assert_contains "$missing_bench_output" "RESULT|bench|FAIL|zsh_bench_dependency|"

  selftest_tmp="$(mktemp -d)"
  overlay_root="$selftest_tmp/dotfiles"
  rsync -a --exclude .git "$dotfiles_root/" "$overlay_root/"
  perl -0pi -e 's/^\s*KEYTIMEOUT=1\n/# KEYTIMEOUT=1\n/m' "$overlay_root/zsh/lib/keybind.zsh"

  selftest_run_capture 1 \
    selftest_exec_verify "$overlay_root"
  negative_output="$REPLY"
  selftest_assert_contains "$negative_output" "RESULT|verify|FAIL|keytimeout|"
  selftest_assert_contains "$negative_output" "SUMMARY|verify|"
  rm -rf "$selftest_tmp"

  print -- "SELFTEST|PASS|zsh-fresh-shells"
}

main() {
  parse_args "$@"

  [[ -d "$audit_dotfiles_root" ]] || die "dotfiles root not found: $audit_dotfiles_root"

  case "$audit_mode" in
    verify)
      reset_counters
      run_verify "$audit_dotfiles_root"
      ;;
    bench)
      reset_counters
      run_bench "$audit_dotfiles_root" "$audit_zsh_bench_root"
      ;;
    diagnose)
      run_diagnose "$audit_dotfiles_root"
      ;;
    selftest)
      run_selftest "$audit_dotfiles_root" "$audit_zsh_bench_root"
      ;;
    doctor)
      run_doctor
      ;;
    *)
      die "unsupported mode: $audit_mode"
      ;;
  esac
}

main "$@"
