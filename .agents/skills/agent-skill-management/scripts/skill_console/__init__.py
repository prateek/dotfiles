"""Shared data model and recovered constants for the skill console.

Every constant below was read out of the Claude Code executable identified by
``BINARY_SHA256``; none is derived. ``BINARY_PROVENANCE`` records the minified
symbol and the exact source fragment each value came from, so a test can
re-check them against a live binary whose hash still matches instead of letting
an upgrade skew every number silently.
"""

from __future__ import annotations

from collections.abc import Mapping
from dataclasses import dataclass
from enum import StrEnum
from pathlib import Path
from types import MappingProxyType

SCHEMA_VERSION = 1
CONSOLE_VERSION = "1"
BINARY_VERSION = "2.1.258"
BINARY_SHA256 = "b63136194160791c27cfa7b0403060d85eb0752991625fde8c09f9acacb17c78"

DEFAULT_BUDGET_FRACTION = 0.01
DEFAULT_BYTES_PER_TOKEN = 4
DEFAULT_CONTEXT_WINDOW = 200_000
DEFAULT_MAX_DESC_CHARS = 1536
DECAY_HALF_LIFE_DAYS = 7.0
DECAY_FLOOR = 0.1
MS_PER_DAY = 86_400_000
ROW_PREFIX = "- "
ROW_SEPARATOR = ": "
LISTING_JOIN = "\n"
WHEN_TO_USE_JOIN = " - "
ELLIPSIS = "…"

# gf(): 4 bytes per token when the normalized family is in this set, else 3.
LEGACY_BYTES_PER_TOKEN_FAMILIES = frozenset(
    {
        "claude-3-opus",
        "claude-3-sonnet",
        "claude-3-haiku",
        "claude-3-5-sonnet",
        "claude-3-5-haiku",
        "claude-3-7-sonnet",
        "claude-opus-4-0",
        "claude-opus-4-1",
        "claude-opus-4-5",
        "claude-opus-4-6",
        "claude-sonnet-4-0",
        "claude-sonnet-4-5",
        "claude-sonnet-4-6",
        "claude-haiku-4-5",
    }
)

# s_(): ordered substring match over the lower-cased id, first hit wins.
MODEL_FAMILIES = (
    "claude-fable-5-1",
    "claude-fable-5",
    "claude-mythos-5-1",
    "claude-mythos-5",
    "claude-opus-5",
    "claude-opus-4-8",
    "claude-opus-4-7",
    "claude-opus-4-6",
    "claude-opus-4-5",
    "claude-opus-4-1",
    "claude-sonnet-5",
    "claude-sonnet-4-6",
    "claude-sonnet-4-5",
    "claude-haiku-4-5",
    "claude-3-7-sonnet",
    "claude-3-5-sonnet",
    "claude-3-5-haiku",
    "claude-3-opus",
    "claude-3-sonnet",
    "claude-3-haiku",
)

# s_() tests these regexes at fixed points in the chain, each immediately after
# the named literal. The lookahead accepts a bare major version ("claude-opus-4")
# but not a one-digit minor, which the literals above already claimed.
MODEL_FAMILY_REGEX_BRANCHES = (
    ("claude-opus-4-1", r"claude-opus-4(?!-\d(?!\d))", "claude-opus-4-0"),
    ("claude-sonnet-4-5", r"claude-sonnet-4(?!-\d(?!\d))", "claude-sonnet-4-0"),
)

# SW: Bedrock inference-profile regions. s_() only uses them to retry its
# provider-id catalog lookup under the "us" prefix; the console does not carry
# that catalog, so the table is exported for completeness and re-verification.
REGION_PREFIXES = ("us", "eu", "apac", "jp", "au", "us-gov", "global")
DATE_SUFFIX_RE = r"-\d{8}$"

# The Unicode Character Database version behind budget.display_width's
# property tables (Emoji, Extended_Pictographic, Emoji_Modifier_Base,
# Other_Grapheme_Extend, SpacingMark exclusions, Prepend). They were generated
# from ICU 77.1 through Node 24's `\p{...}` regexes and Intl.Segmenter, and
# Python 3.14's unicodedata, which supplies the general categories and East
# Asian widths at run time, is the same version.
UNICODE_VERSION = "16.0.0"
# The Bun release whose stringWidth.cpp the port follows and whose
# `Bun.stringWidth` served as the differential oracle; the binary embeds 1.4.1,
# which has no separate tag or release asset.
BUN_STRING_WIDTH_VERSION = "1.4.0"


class Origin(StrEnum):
    REPO_LOCAL = "repo-local"
    REPO_VENDOR = "repo-vendor"
    REPO_PROJECT = "repo-project"
    USER_SKILL = "user-skill"
    USER_COMMAND = "user-command"
    THIRD_PARTY_PLUGIN = "third-party-plugin"
    BUILTIN = "builtin"


class Rendered(StrEnum):
    FULL = "full"
    NAME_ONLY = "name-only"


class Tree(StrEnum):
    SOURCE = "source"
    MARKETPLACE = "marketplace"
    CACHE = "cache"


class Harness(StrEnum):
    CLAUDE = "claude"
    CODEX = "codex"
    PI = "pi"


class Op(StrEnum):
    SET_DESCRIPTION = "set_description"
    SET_FRONTMATTER = "set_frontmatter"
    DELETE_SKILL = "delete_skill"
    SET_DEFAULT_LOADED = "set_default_loaded"
    SET_PACKAGE_ENABLED = "set_package_enabled"
    SET_BUDGET_FRACTION = "set_budget_fraction"


@dataclass(frozen=True, slots=True)
class Usage:
    usage_count: int
    last_used_at_ms: int


@dataclass(frozen=True, slots=True)
class SkillRecord:
    """One skill directory in one tree. Same skill in three trees -> three records."""

    tree: Tree
    package: str
    directory: str
    path: Path
    origin: Origin
    frontmatter_name: str
    description: str
    when_to_use: str | None
    disable_model_invocation: bool
    user_invocable: bool
    content_sha256: str
    # True when the frontmatter had no usable description and `description`
    # is the binary's body-derived fallback; plugin-loaded skills in that state
    # are not listed unless they carry `when_to_use`.
    description_derived: bool = False


@dataclass(frozen=True, slots=True)
class PackageRecord:
    name: str
    display_name: str
    path: Path
    default_loaded: bool
    render_claude: str
    render_codex: str
    marketplace: str
    skill_count: dict[Tree, int]


@dataclass(frozen=True, slots=True)
class ListingEntry:
    """Exactly what admission needs. Pure; no paths, no I/O."""

    name: str
    listing_text: str
    protected: bool
    forced_name_only: bool
    rank: float


@dataclass(frozen=True, slots=True)
class BudgetInputs:
    context_window: int
    bytes_per_token: int
    fraction: float
    max_desc_chars: int
    # The JS number from SLASH_COMMAND_TOOL_CHAR_BUDGET: the binary uses it
    # unrounded, so 0.5 and Infinity are legal here.
    env_budget: int | float | None


@dataclass(frozen=True, slots=True)
class RowCost:
    name: str
    index: int
    name_only_cost: int
    full_cost: int
    upgrade_cost: int
    capped: bool
    width_divergent: bool


@dataclass(frozen=True, slots=True)
class Admission:
    mode: str
    budget: int | float
    budget_from_env: bool
    demand_chars: int
    rendered_chars: int
    headroom_chars: int | float
    all_pinned: bool
    costs: tuple[RowCost, ...]
    rendered: Mapping[str, Rendered]
    full: tuple[str, ...]
    name_only: tuple[str, ...]
    capped: tuple[str, ...]


@dataclass(frozen=True, slots=True)
class Row:
    """A console row: one skill, joined across trees, with its live state."""

    name: str
    directory: str
    package: str
    origin: Origin
    protected: bool
    source_record: SkillRecord | None
    marketplace_record: SkillRecord | None
    cache_record: SkillRecord | None
    listed: bool
    repo_default: bool
    live_enabled: Mapping[Harness, bool]
    usage: Usage | None
    rank: float
    rendered: Rendered | None
    capped: bool
    width_divergent: bool
    derived_description: bool
    divergences: tuple[str, ...]


@dataclass(frozen=True, slots=True)
class Snapshot:
    schema_version: int
    harness: Harness
    console_version: str
    binary_version: str
    binary_hash: str
    binary_hash_matched: bool
    source_hash: str
    marketplace_hash: str
    cache_hash: str
    settings_hash: str
    usage_hash: str
    model: str
    context_window: int
    bytes_per_token: int
    fraction: float
    max_desc_chars: int
    budget_chars: int | float
    budget_env_override: int | float | None
    cwd: str
    project_root: str
    git_rev: str
    git_dirty: bool
    now_ms: int
    captured_at: str
    listing_capture_at: str | None


@dataclass(frozen=True, slots=True)
class Predicted:
    cap_chars: int
    mode_before: str
    mode_after: str
    demand_before: int
    demand_after: int
    rendered_before: int
    rendered_after: int
    full_before: int
    full_after: int
    name_only_before: int
    name_only_after: int
    newly_admitted: tuple[str, ...]
    newly_dropped: tuple[str, ...]
    added_name_only: int
    removed_name_only: int


@dataclass(frozen=True, slots=True)
class Operation:
    op: Op
    target: str
    key: str
    fields: Mapping[str, object]


@dataclass(frozen=True, slots=True)
class Decisions:
    schema_version: int
    harness: Harness
    snapshot: Snapshot
    predicted: Predicted
    operations: tuple[Operation, ...]


@dataclass(frozen=True, slots=True)
class Violation:
    code: str
    message: str
    pointer: str


# Per-origin operation permissions. The package-scoped ops describe the row's
# package, not the row; set_budget_fraction targets settings and belongs to no
# origin, so no row can carry it.
CAPABILITIES: Mapping[Origin, frozenset[Op]] = MappingProxyType(
    {
        Origin.REPO_LOCAL: frozenset(
            {
                Op.SET_DESCRIPTION,
                Op.SET_FRONTMATTER,
                Op.SET_DEFAULT_LOADED,
                Op.SET_PACKAGE_ENABLED,
            }
        ),
        Origin.REPO_VENDOR: frozenset(
            {
                Op.SET_DESCRIPTION,
                Op.SET_FRONTMATTER,
                Op.DELETE_SKILL,
                Op.SET_DEFAULT_LOADED,
                Op.SET_PACKAGE_ENABLED,
            }
        ),
        Origin.REPO_PROJECT: frozenset({Op.SET_DESCRIPTION, Op.SET_FRONTMATTER}),
        Origin.USER_SKILL: frozenset(),
        Origin.USER_COMMAND: frozenset(),
        Origin.THIRD_PARTY_PLUGIN: frozenset({Op.SET_PACKAGE_ENABLED}),
        Origin.BUILTIN: frozenset(),
    }
)


def capability_allows(origin: Origin, op: Op) -> bool:
    return op in CAPABILITIES[origin]


def qualified_name(package: str, directory: str) -> str:
    """The serializer's `cmd.name`: `<package>:<directory>` for plugin skills.

    Built-ins and unmanaged user skills have no package and are listed bare.
    """
    return f"{package}:{directory}" if package else directory


@dataclass(frozen=True, slots=True)
class Provenance:
    """Where a constant was read from in the binary named by BINARY_SHA256."""

    name: str
    symbol: str
    source: str


def _family_chain_source() -> str:
    """The body of s_() after its catalog branches, rebuilt from the tables above.

    Rebuilding it makes the exact chain order a checked fact: the string must
    appear verbatim in the binary.
    """
    branches = {
        after: (pattern, result)
        for after, pattern, result in MODEL_FAMILY_REGEX_BRANCHES
    }
    parts: list[str] = []
    for family in MODEL_FAMILIES:
        parts.append(f'if(e.includes("{family}"))return"{family}";')
        if family in branches:
            pattern, result = branches[family]
            parts.append(f'if(/{pattern}/.test(e))return"{result}";')
    parts.append("return Zx(e)}")
    return "".join(parts)


BINARY_PROVENANCE: tuple[Provenance, ...] = (
    Provenance("BINARY_VERSION", "VERSION", 'VERSION:"2.1.258"'),
    Provenance("DEFAULT_BUDGET_FRACTION", "x2o", "x2o=0.01"),
    Provenance("DEFAULT_BYTES_PER_TOKEN", "Q1n", "Q1n=4"),
    Provenance("DEFAULT_CONTEXT_WINDOW", "A2o", "A2o=200000"),
    Provenance("DEFAULT_MAX_DESC_CHARS", "R2o", "R2o=1536"),
    Provenance("DECAY_HALF_LIFE_DAYS", "HLe", "Math.pow(0.5,o/7)"),
    Provenance("DECAY_FLOOR", "HLe", "r.usageCount*Math.max(d,0.1)"),
    Provenance("MS_PER_DAY", "HLe", "(Date.now()-r.lastUsedAt)/86400000"),
    Provenance("ROW_PREFIX", "M7o", "`- ${e.name}: ${I7o(e)}`"),
    Provenance("ROW_SEPARATOR", "M7o", "`- ${e.name}: ${I7o(e)}`"),
    Provenance("LISTING_JOIN", "per", "_.map((z)=>z.full).join(`\n`)"),
    Provenance("WHEN_TO_USE_JOIN", "XOe", "`${e.description} - ${e.whenToUse}`"),
    Provenance("ELLIPSIS", "I7o", 'n.slice(0,r-1)+"\\u2026"'),
    Provenance(
        "LEGACY_BYTES_PER_TOKEN_FAMILIES",
        "Pne",
        'Pne=new Set(["claude-3-opus","claude-3-sonnet","claude-3-haiku",'
        '"claude-3-5-sonnet","claude-3-5-haiku","claude-3-7-sonnet",'
        '"claude-opus-4-0","claude-opus-4-1","claude-opus-4-5","claude-opus-4-6",'
        '"claude-sonnet-4-0","claude-sonnet-4-5","claude-sonnet-4-6","claude-haiku-4-5"])',
    ),
    Provenance("MODEL_FAMILIES", "s_", _family_chain_source()),
    Provenance("MODEL_FAMILY_REGEX_BRANCHES", "s_", _family_chain_source()),
    Provenance(
        "REGION_PREFIXES", "SW", 'SW=["us","eu","apac","jp","au","us-gov","global"]'
    ),
    Provenance(
        "DATE_SUFFIX_RE", "Zx", 'function Zx(e){return e.replace(/-\\d{8}$/,"")}'
    ),
    Provenance(
        "budget.bytes_per_token", "gf", '.replace(/[._]/g,"-");return Pne.has(r)?4:3'
    ),
    Provenance("budget.budget_chars", "iTe", "return Math.max(1,Math.floor(d))"),
    Provenance(
        "budget.parse_env_budget", "Zx", "let n=Number(e);if(!Number.isNaN(n))return n;"
    ),
    Provenance(
        "budget.admit",
        "per",
        "I.sort((z,fe)=>n(e[fe])-n(e[z]));for(let z of I){let fe=B(z)-F(z);if(fe<=j)W.add(z),j-=fe}",
    ),
    Provenance(
        "budget.admit.protected", "per", 'fe.type==="prompt"&&fe.source==="bundled"'
    ),
    Provenance("budget.display_width", "se", "Bun.stringWidth(t,n)"),
    Provenance("budget.display_width.options", "se", "n={ambiguousIsNarrow:!0}"),
    Provenance("budget.budget_chars.env", "iTe", "if(r)return r;let o=P2o()"),
    Provenance(
        "budget.context_cell",
        "Fx",
        'if(t<20)return"< 20";return`~${$n(Math.round(t/10)*10)}`',
    ),
    Provenance("budget.context_cell.tokens", "Wc", "Math.round(e.length/n)"),
)

# Where budget.display_width's rules come from. These fragments live in Bun's
# stringWidth.cpp (BUN_STRING_WIDTH_VERSION), not in the Claude executable, so
# they are checked against the source file rather than the binary.
UNICODE_PROVENANCE: tuple[Provenance, ...] = (
    Provenance("budget._codepoint_width", "widthFromFused", "return ambiguousAsWide ? 2 : 1;"),
    Provenance(
        "budget._codepoint_width.hangul",
        "static_assert",
        "widthFromFused(fusedClassify(0x1161), false) == 0); // hangul jungseong: zero width",
    ),
    Provenance(
        "budget._has_emoji_bit",
        "static_assert",
        "(fusedClassify(U'#') & kFusedEmojiBit) == 0); // '#': below the U+203C early-out",
    ),
    Provenance(
        "budget._cluster_width.flag", "GraphemeState::width", "if (regionalIndicator && count >= 2)"
    ),
    Provenance("budget._cluster_width.keycap", "GraphemeState::width", "if (keycap)"),
    Provenance(
        "budget._cluster_width.modifier", "GraphemeState::width", "if (emojiBase && (skinTone || zwj))"
    ),
    Provenance(
        "budget._cluster_width.vs16",
        "GraphemeState::width",
        "if (baseWidth == 2 || (vs16 && (emojiBase || firstCp == 0xA9 || firstCp == 0xAE)))",
    ),
    Provenance(
        "budget._cluster_width.cap", "GraphemeState::add", "std::min<uint32_t>(newWidth, 1023)"
    ),
    Provenance(
        "budget.display_width.surrogates",
        "decodeUTF16Codepoint",
        "Lone lead/trail surrogates and truncated pairs are skipped entirely",
    ),
    Provenance(
        "budget._grapheme_break", "computeGraphemeBreakNoControl", "// GB11: Emoji ZWJ sequence and Emoji modifier sequence"
    ),
    Provenance(
        "budget._ZERO_WIDTH_OVERRIDE_RANGES",
        "Bun.stringWidth",
        "measured over every code point with bun 1.4.0; see docs for the generator",
    ),
)
