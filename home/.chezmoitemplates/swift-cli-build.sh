{{- /* Compile one Swift source file into ~/.local/bin/<name>.
       Call with (dict "name" <binary> "source" <Swift source text>). Embedding the source
       makes the calling run_onchange script's hash follow it. Skips cleanly when swiftc is
       absent (e.g. a bare machine before Xcode Command Line Tools). */ -}}
have swiftc || { warn "build-{{ .name }}: swiftc not found; skipping (install Xcode Command Line Tools)"; exit 0; }

out="${HOME}/.local/bin/{{ .name }}"
mkdir -p "$(dirname "$out")"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

cat >"${tmp}/{{ .name }}.swift" <<'SWIFT_SOURCE'
{{ .source }}
SWIFT_SOURCE

swiftc -O "${tmp}/{{ .name }}.swift" -o "$out"
chmod 0755 "$out"
log "build-{{ .name }}: compiled $out"
