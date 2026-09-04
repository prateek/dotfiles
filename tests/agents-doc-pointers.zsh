#!/usr/bin/env zsh

set -euo pipefail
unsetopt xtrace 2>/dev/null || true
set +x 2>/dev/null || true
unsetopt verbose 2>/dev/null || true
set +v 2>/dev/null || true
setopt typeset_silent 2>/dev/null || true

die() {
  print -u2 -- "agents-doc-pointers: $*"
  exit 1
}

DOTFILES_ROOT="${0:A:h:h}"
agents_md="$DOTFILES_ROOT/home/dot_agents/AGENTS.md"
docs_dir="$DOTFILES_ROOT/home/dot_agents/docs"

# This target is composed at chezmoi apply, so it has no source under docs/.
typeset -A generated_doc_sources
generated_doc_sources=(
  slack.md "$DOTFILES_ROOT/home/.chezmoitemplates/agent-slack-base.md"
)

doc_source() {
  print -r -- "${generated_doc_sources[$1]:-$docs_dir/$1}"
}

[[ -f "$agents_md" ]] || die "missing $agents_md"
[[ -d "$docs_dir" ]] || die "missing $docs_dir"

heading_count=$(grep -c '^## Convention pointers$' "$agents_md" || true)
(( heading_count == 1 )) \
  || die "expected exactly one '## Convention pointers' heading, found $heading_count"

pointer_lines=("${(@f)$(awk '/^## Convention pointers$/{p=1; next} p && /^#/{exit} p && /^- /' "$agents_md")}")
pointer_lines=("${(@)pointer_lines:#}")
(( ${#pointer_lines} > 0 )) || die "no bullets found under '## Convention pointers'"

typeset -A pointed
for line in "${pointer_lines[@]}"; do
  [[ "$line" =~ '^- .+: `~/\.agents/docs/([a-z0-9-]+\.md)`$' ]] \
    || die "pointer must read '- <trigger>: \`~/.agents/docs/<name>.md\`', got: $line"
  name="${match[1]}"
  [[ -z "${pointed[$name]:-}" ]] || die "duplicate pointer for $name"
  pointed[$name]=1
  source="$(doc_source "$name")"
  [[ -f "$source" ]] || die "pointer to $name has no source at $source"
done

for name in $(grep -o '~/\.agents/docs/[a-z0-9-]*\.md' "$agents_md" | sed 's#.*/##' | sort -u); do
  [[ -n "${pointed[$name]:-}" ]] \
    || die "$name is named in AGENTS.md but has no Convention pointers bullet"
done

# Walk links outward so two orphaned docs that link each other remain orphaned.
typeset -A reachable
queue=()
for name in "${(@k)pointed}"; do
  reachable[$name]=1
  queue+=("$name")
done

while (( ${#queue} > 0 )); do
  name="${queue[1]}"
  shift queue
  file="$(doc_source "$name")"
  for target in $(grep -o -E '\]\((\./)?[a-z0-9-]+\.md' "$file" | sed -E 's|^\]\((\./)?||' | sort -u); do
    [[ -f "$(doc_source "$target")" ]] \
      || die "$name links to $target, which has no convention source"
    [[ -n "${reachable[$target]:-}" ]] && continue
    reachable[$target]=1
    queue+=("$target")
  done
done

on_disk=("$docs_dir"/*.md(N))
for doc in "${on_disk[@]}"; do
  name="${doc:t}"
  [[ -n "${reachable[$name]:-}" ]] \
    || die "$name is unreachable: no AGENTS.md pointer or link from a pointed doc"
done

print -- "agents-doc-pointers: ok (${#pointed} pointers, ${#on_disk} docs on disk)"
