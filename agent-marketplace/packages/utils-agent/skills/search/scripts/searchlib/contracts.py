"""Versioned public request and host contracts; no I/O."""

from __future__ import annotations

import datetime as dt
import math
import re
from urllib.parse import urlsplit

VERSION = 1
AREAS = ("web", "code", "social", "shopping")
SOURCES = {
    "web": ("web", None),
    "github": ("code", "github.com"),
    "hn": ("social", "news.ycombinator.com"),
    "reddit": ("social", "reddit.com"),
    "x": ("social", "x.com"),
    "youtube": ("social", "youtube.com"),
    "google-shopping": ("shopping", None),
    "amazon": ("shopping", "amazon.com"),
    "alibaba": ("shopping", "alibaba.com"),
    "marketplace": ("shopping", "facebook.com/marketplace"),
    "ubereats": ("shopping", "ubereats.com"),
    "instacart": ("shopping", "instacart.com"),
    "skills": ("code", "skills.sh"),
}
DEFAULT_SOURCE = dict(zip(AREAS, ("web", "github", "hn", "amazon")))
DISCOVERY = {
    "web": "page.discover",
    "code": "code.discover",
    "social": "post.discover",
    "shopping": "product.discover",
}
CHOICES = {
    "area",
    "source",
    "exclude_source",
    "require_source",
    "provider",
    "via",
    "prefer_provider",
    "prefer_via",
    "browser",
    "strategy",
    "free_only",
    "since",
    "until",
    "location",
    "limit",
    "total_limit",
    "max_calls",
    "max_opens",
    "timeout",
}
FILTERS = {
    "domains",
    "since",
    "until",
    "location",
    "repo",
    "path",
    "language",
    "revision",
    "url",
    "item_id",
}
STATUSES = {
    "success",
    "empty",
    "partial",
    "timeout",
    "transient",
    "rate_limited",
    "challenge",
    "auth_failed",
    "schema_error",
    "failed",
    "constraint_failed",
    "unavailable",
    "budget_exhausted",
    "interrupted",
}


class Invalid(ValueError):
    pass


def obj(value, allowed, required=(), label="document"):
    if not isinstance(value, dict):
        raise Invalid(f"{label} must be an object")
    unknown, missing = set(value) - set(allowed), set(required) - set(value)
    if unknown or missing:
        raise Invalid(
            f"{label}: unknown fields {sorted(unknown)}; missing fields {sorted(missing)}"
        )
    return value


def version(value, allowed, required=(), label="document"):
    obj(
        value,
        set(allowed) | {"schema_version"},
        set(required) | {"schema_version"},
        label,
    )
    if type(value["schema_version"]) is not int or value["schema_version"] != VERSION:
        raise Invalid(f"{label}: unsupported schema_version")
    return value


def number(value, label, minimum=0):
    if (
        isinstance(value, bool)
        or not isinstance(value, (int, float))
        or not math.isfinite(value)
        or value < minimum
    ):
        raise Invalid(f"{label} must be a finite number >= {minimum}")
    return value


def integer(value, label, minimum=0):
    number(value, label, minimum)
    if type(value) is not int:
        raise Invalid(f"{label} must be an integer")
    return value


def string(value, label):
    if not isinstance(value, str) or not value.strip() or "\x00" in value:
        raise Invalid(f"{label} must be a nonempty string")
    return value


def strings(value, label):
    if not isinstance(value, list) or any(
        not isinstance(x, str) or not x for x in value
    ):
        raise Invalid(f"{label} must be a list of strings")
    return value


def web_url(value):
    string(value, "url")
    p = urlsplit(value)
    if p.scheme not in ("http", "https") or not p.hostname or p.username or p.password:
        raise Invalid("url must be http(s), without credentials")
    return value


def choices(value):
    obj(value, CHOICES, label="choices")
    for k, v in value.items():
        if k in {"area", "source", "exclude_source", "require_source"}:
            strings(v, k)
            allowed = AREAS if k == "area" else SOURCES
            if set(v) - set(allowed):
                raise Invalid(f"unknown {k}: {sorted(set(v) - set(allowed))}")
        elif k == "free_only":
            if type(v) is not bool:
                raise Invalid("free_only must be boolean")
        elif k in {"limit", "total_limit", "max_calls"}:
            integer(v, k, 1)
        elif k == "max_opens":
            integer(v, k)
        elif k == "timeout":
            number(v, k, 0.01)
        else:
            string(v, k)
    for k in ("via", "prefer_via"):
        if k in value and value[k] not in ("auto", "api", "native", "browser", "host"):
            raise Invalid(f"invalid {k}")
    if value.get("strategy", "free-first") not in ("free-first", "balanced"):
        raise Invalid("invalid strategy")
    if set(value.get("source", []) + value.get("require_source", [])) & set(
        value.get("exclude_source", [])
    ):
        raise Invalid("source inclusion and exclusion conflict")
    for k in ("since", "until"):
        if k in value:
            try:
                dt.date.fromisoformat(value[k])
            except ValueError as exc:
                raise Invalid(f"{k} must be YYYY-MM-DD") from exc
    if value.get("since", "") > value.get("until", "9999"):
        raise Invalid("since is after until")
    return value


def budget(value):
    obj(
        value,
        ("calls", "discovery", "enrichment", "opens", "wall_seconds"),
        ("calls", "discovery", "enrichment", "opens", "wall_seconds"),
        "budget",
    )
    for k, v in value.items():
        (number if k == "wall_seconds" else integer)(
            v, k, 0.01 if k == "wall_seconds" else 0
        )
    if value["discovery"] + value["enrichment"] > value["calls"]:
        raise Invalid("discovery + enrichment exceeds calls")
    return value


def request(value):
    version(
        value,
        (
            "terms",
            "facets",
            "choices",
            "conversation_choices",
            "budget",
            "authorized_paid",
            "prepared_jobs",
        ),
        label="request",
    )
    choices(value.get("choices", {}))
    choices(value.get("conversation_choices", {}))
    if "terms" in value:
        string(value["terms"], "terms")
    strings(value.get("authorized_paid", []), "authorized_paid")
    if "budget" in value:
        budget(value["budget"])
    if "facets" in value and "prepared_jobs" in value:
        raise Invalid("use facets or prepared_jobs, not both")
    rows = value.get("facets", value.get("prepared_jobs", []))
    if not isinstance(rows, list):
        raise Invalid("facets/prepared_jobs must be a list")
    ids = set()
    for f in rows:
        obj(
            f,
            (
                "id",
                "area",
                "source",
                "operation",
                "terms",
                "native_query",
                "filters",
                "needs",
                "limit",
                "provider",
                "via",
                "raw",
                "timeout",
            ),
            ("id", "area", "source", "operation"),
            "facet",
        )
        string(f["id"], "facet id")
        if f["id"] in ids:
            raise Invalid("duplicate facet id")
        ids.add(f["id"])
        for key in ("area", "source", "operation"):
            string(f[key], key)
        if (
            f["area"] not in AREAS
            or f["source"] not in SOURCES
            or SOURCES[f["source"]][0] != f["area"]
        ):
            raise Invalid("unknown or incompatible area/source")
        if not re.fullmatch(
            r"[a-z]+\.(discover|inspect|read|commits|diagnose)", f["operation"]
        ):
            raise Invalid("invalid operation")
        if "timeout" in f:
            number(f["timeout"], "facet timeout", 0.01)
        if "raw" in f and type(f["raw"]) is not bool:
            raise Invalid("raw must be boolean")
        if "terms" in f:
            string(f["terms"], "facet terms")
        if "limit" in f:
            integer(f["limit"], "facet limit", 1)
        strings(f.get("needs", []), "needs")
        choices({k: f[k] for k in ("provider", "via") if k in f})
        flt = obj(f.get("filters", {}), FILTERS, label="filters")
        for k, v in flt.items():
            strings(v, k) if k == "domains" else string(v, k)
        if "url" in flt:
            web_url(flt["url"])
        choices({k: flt[k] for k in ("since", "until", "location") if k in flt})
        if "native_query" in f:
            nq = obj(
                f["native_query"],
                ("dialect", "text"),
                ("dialect", "text"),
                "native_query",
            )
            string(nq["dialect"], "dialect")
            string(nq["text"], "native text")
            if flt or f.get("terms"):
                raise Invalid("native_query cannot be combined with terms/filters")
    if not rows and not value.get("terms"):
        raise Invalid("terms or facets are required")
    return value


def host_manifest(value):
    version(value, ("capabilities",), ("capabilities",), "host manifest")
    if not isinstance(value["capabilities"], list):
        raise Invalid("host capabilities must be a list")
    seen = set()
    for c in value["capabilities"]:
        obj(
            c,
            ("id", "tool", "operations", "runtime", "identity", "cost"),
            ("id", "tool", "operations"),
            "host capability",
        )
        if (
            c["id"] not in ("web.search", "web.fetch", "browser", "mcp:grep.app")
            or c["id"] in seen
        ):
            raise Invalid("unknown or duplicate host capability")
        seen.add(c["id"])
        string(c["tool"], "host tool")
        strings(c["operations"], "host operations")
        if c.get("cost", "unknown") not in ("free", "chargeable", "unknown"):
            raise Invalid("invalid host cost")
        for k in ("runtime", "identity"):
            if k in c:
                string(c[k], k)
    return value
