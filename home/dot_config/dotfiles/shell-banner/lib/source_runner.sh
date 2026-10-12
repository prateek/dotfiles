# shellcheck shell=zsh
#
# Shared scaffolding for bin/sources/<name> scripts.
#
# Each source script declares its name, verb, and a `<source>_check` function
# that probes the underlying CLI and emits two values via two globals:
#
#   typeset -g BANNER_SOURCE_OUTDATED  # int
#   typeset -g BANNER_SOURCE_TOTAL     # int
#   typeset -g BANNER_SOURCE_RAW       # raw check output, persisted to status.txt
#   typeset -g BANNER_SOURCE_DISABLED_REASON  # set when the binary is absent
#
# `<source>_check` returns 0 on success, 1 on disabled (binary missing or
# explicitly skipped), or 2 on hard error after writing a stderr text into
# BANNER_SOURCE_ERROR.

banner_source_runner() {
  emulate -L zsh
  setopt no_nomatch typeset_silent

  local source="$1"
  local verb="$2"
  local check_fn="$3"
  shift 3

  local root='' state_dir=''
  while (( $# > 0 )); do
    case "$1" in
      --root)      root="$2"; shift 2 ;;
      --state-dir) state_dir="$2"; shift 2 ;;
      --help|-h)
        print -r -- "Usage: $source --root <feature-root> --state-dir <state-dir>"
        return 0
        ;;
      *)
        print -u2 -- "shell-banner $source: unknown argument: $1"
        return 2
        ;;
    esac
  done

  if [[ -z "$root" || -z "$state_dir" ]]; then
    print -u2 -- "Usage: $source --root <feature-root> --state-dir <state-dir>"
    return 2
  fi

  if [[ ! -r "$root/lib/cache.sh" || ! -r "$root/lib/sources.sh" ]]; then
    print -u2 -- "shell-banner $source: missing lib/cache.sh or lib/sources.sh under $root"
    return 2
  fi

  source "$root/lib/cache.sh"
  source "$root/lib/sources.sh"
  banner_load_config "$root"
  [[ -r "$root/local.env" ]] && banner_load_local_config "$root/local.env"

  local probe_umask="$(umask)"
  umask 077
  /bin/mkdir -p "$state_dir"
  /bin/chmod 700 "$state_dir" 2>/dev/null || true

  local now checked_label ttl params
  now="$(banner_now)"
  checked_label="$(banner_checked_label "$now")"
  ttl="$(banner_source_ttl "$source")"
  params="$(banner_source_params "$source")"

  typeset -g BANNER_SOURCE_OUTDATED=0
  typeset -g BANNER_SOURCE_TOTAL=0
  typeset -g BANNER_SOURCE_RAW=''
  typeset -g BANNER_SOURCE_DISABLED_REASON=''
  typeset -g BANNER_SOURCE_ERROR=''
  typeset -g BANNER_SOURCE_DETAIL=''

  # chezmoi derives its target file modes from the umask, so probing under the
  # 077 the cache writes want reports every managed entry as drifted.
  umask "$probe_umask"
  "$check_fn"
  local rc=$?
  umask 077

  case "$rc" in
    0)
      # Defensive clamp: if the source's <total> probe failed but its
      # outdated count is non-zero, render `N / N` rather than `N / 0`.
      if (( BANNER_SOURCE_TOTAL < BANNER_SOURCE_OUTDATED )); then
        BANNER_SOURCE_TOTAL="$BANNER_SOURCE_OUTDATED"
      fi
      banner_write_text_file "$state_dir/status.txt" "$BANNER_SOURCE_RAW"
      print -r -- "$now" >| "$state_dir/updated_at"
      banner_format_row_plain ok "$BANNER_SOURCE_OUTDATED" "$BANNER_SOURCE_TOTAL" "$verb" "$checked_label" \
        >| "$state_dir/module.txt"
      banner_format_row_ansi ok "$BANNER_SOURCE_OUTDATED" "$BANNER_SOURCE_TOTAL" "$verb" "$checked_label" \
        >| "$state_dir/module.ansi"
      if [[ -n "$BANNER_SOURCE_DETAIL" ]]; then
        local row
        for row in module.txt module.ansi; do
          print -r -- "$(<"$state_dir/$row")$BANNER_SOURCE_DETAIL" >| "$state_dir/$row"
        done
      fi
      banner_write_state_env "$state_dir" "$source" ok "$BANNER_SOURCE_OUTDATED" "$BANNER_SOURCE_TOTAL" \
        "$now" "$checked_label" "$params"
      /bin/rm -f "$state_dir/last_error"
      ;;
    1)
      local reason="${BANNER_SOURCE_DISABLED_REASON:-not installed}"
      banner_format_row_plain disabled 0 0 "$verb" "$checked_label" "$reason" \
        >| "$state_dir/module.txt"
      banner_format_row_ansi disabled 0 0 "$verb" "$checked_label" "$reason" \
        >| "$state_dir/module.ansi"
      banner_write_state_env "$state_dir" "$source" disabled 0 0 "$now" \
        "$checked_label" "$params"
      ;;
    *)
      banner_write_text_file "$state_dir/last_error" "updated_at=$now
source=$source
${BANNER_SOURCE_ERROR:-unknown error}"
      banner_format_row_plain error 0 0 "$verb" "$checked_label" \
        >| "$state_dir/module.txt"
      banner_format_row_ansi error 0 0 "$verb" "$checked_label" \
        >| "$state_dir/module.ansi"
      banner_write_state_env "$state_dir" "$source" error 0 0 "$now" \
        "$checked_label" "$params"
      return 1
      ;;
  esac

  return 0
}


# Helper: create a private temp file for capturing a probe's stderr.
#
# The caller's umask masks the owner bits mkstemp asks for, so `umask 0700`
# yields a mode-000 file the probe's own `2>` redirection cannot open.
banner_mktemp() {
  local prefix="$1" path
  path="$(/usr/bin/mktemp -t "$prefix.XXXXXX")" || return 1
  /bin/chmod 600 "$path" 2>/dev/null || true
  print -r -- "$path"
}

# Helper: count non-empty lines in a string.
banner_count_lines() {
  local count=0 line
  for line in "${(@f)1}"; do
    [[ -n "$line" ]] && (( count += 1 ))
  done
  print -r -- "$count"
}
