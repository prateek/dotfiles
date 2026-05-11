verbose = bool(os.environ.get("CHEZMOI_VERBOSE") or os.environ.get("DOTFILES_PLIST_VERBOSE"))

# Bundle ID from the target file path; used in stderr log lines.
target_path = "{{ .chezmoi.targetFile }}"
bundle_id = target_path.rsplit("/", 1)[-1].removesuffix(".plist")


# `desired_xml` is bound by the per-app stub above. Extract `chezmoi-delete`
# directive(s) from the rendered XML before parsing as a plist. The directive
# lives in an XML comment at the top of the fragment:
#   <!-- chezmoi-delete: key1, key2 -->
deletes: list[str] = []
for match in re.finditer(rb"<!--\s*chezmoi-delete:\s*([^-]+?)\s*-->", desired_xml):
    deletes.extend(k.strip() for k in match.group(1).decode().split(",") if k.strip())

desired = plistlib.loads(desired_xml)
if not isinstance(desired, dict):
    sys.exit(f"plist-merge[{bundle_id}]: desired plist must be a dict at root")


# Read current target plist from stdin (chezmoi modify_ contract).
raw = sys.stdin.buffer.read()
current = plistlib.loads(raw) if raw.strip() else {}
if not isinstance(current, dict):
    current = {}


def _byte_equal(a, b) -> bool:
    """Round-trip equality on binary plist bytes."""
    return (
        plistlib.dumps(a, fmt=plistlib.FMT_BINARY, sort_keys=False)
        == plistlib.dumps(b, fmt=plistlib.FMT_BINARY, sort_keys=False)
    )


# Track whether the merge actually mutated `current`. If nothing changed,
# preserve stdin bytes verbatim. plistlib can encode the same logical content
# differently based on integer widths, dict key order, or version bytes, and
# chezmoi compares stdin to stdout to decide whether to write.
mutated = False

# Pass 1: deletes
for key in deletes:
    if key in current:
        if verbose:
            print(f"plist-merge[{bundle_id}]: delete {key}", file=sys.stderr)
        current.pop(key, None)
        mutated = True

# Pass 2: upserts with no-op skip
for key, value in desired.items():
    if key in current and (current[key] == value or _byte_equal(current[key], value)):
        continue
    if verbose:
        state = "absent" if key not in current else "changed"
        print(f"plist-merge[{bundle_id}]: set {key} ({state})", file=sys.stderr)
    current[key] = copy.deepcopy(value)
    mutated = True

if not mutated and raw:
    sys.stdout.buffer.write(raw)
else:
    out = io.BytesIO()
    plistlib.dump(current, out, fmt=plistlib.FMT_BINARY, sort_keys=False)
    sys.stdout.buffer.write(out.getvalue())
