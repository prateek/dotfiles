"""Versioned public request and host contracts; no I/O."""

from __future__ import annotations

import datetime as dt
import math
import re
from urllib.parse import urlsplit
from . import sources
from .sources import SOURCES as SOURCES, Invalid as Invalid

VERSION = 1
AREAS = ("web", "code", "social", "shopping")
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
    "result_limit",
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
            if k == "area":
                if set(v) - set(AREAS):
                    raise Invalid(f"unknown area: {sorted(set(v) - set(AREAS))}")
            else:
                for source in v:
                    sources.resolve(source)
        elif k == "free_only":
            if type(v) is not bool:
                raise Invalid("free_only must be boolean")
        elif k in {"limit", "total_limit", "result_limit", "max_calls"}:
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
    if any(
        sources.excluded(s, value.get("exclude_source", []))
        for s in value.get("source", []) + value.get("require_source", [])
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


DISCOVERY_OPERATIONS = {
    "page.discover",
    "code.discover",
    "repo.discover",
    "issue.discover",
    "post.discover",
    "video.discover",
    "product.discover",
}
AREA_OPERATIONS = {
    "web": {
        "page.discover",
        "page.inspect",
        "comments.read",
        "transcript.read",
        "offer.inspect",
    },
    "code": {
        "code.discover",
        "repo.discover",
        "issue.discover",
        "page.discover",
        "page.inspect",
        "repo.inspect",
        "repo.commits",
        "quota.diagnose",
        "tool.diagnose",
    },
    "social": {
        "post.discover",
        "video.discover",
        "issue.discover",
        "page.discover",
        "page.inspect",
        "comments.read",
        "transcript.read",
        "item.read",
    },
    "shopping": {
        "product.discover",
        "page.discover",
        "post.discover",
        "video.discover",
        "page.inspect",
        "offer.inspect",
        "comments.read",
        "transcript.read",
    },
}


def bounded(value, label, maximum=512):
    string(value, label)
    if len(value) > maximum:
        raise Invalid(f"{label} exceeds {maximum} characters")


def context(rows):
    if not isinstance(rows, list) or len(rows) > 24:
        raise Invalid("context must be a list of at most 24 facts")
    names = set()
    for row in rows:
        obj(row, ("name", "value", "origin"), ("name", "value", "origin"), "context")
        bounded(row["name"], "context name", 64)
        if row["name"] in names:
            raise Invalid("Duplicate context name")
        names.add(row["name"])
        if row["origin"] not in ("explicit", "conversation", "saved", "assumption"):
            raise Invalid("Unknown context origin")
        values = row["value"] if isinstance(row["value"], list) else [row["value"]]
        if len(values) > 16:
            raise Invalid("Context lists are limited to 16 scalars")
        for value in values:
            if isinstance(value, str):
                bounded(value, "context value")
            elif type(value) in (int, float):
                if not math.isfinite(value):
                    raise Invalid("Context numbers must be finite")
            elif type(value) is not bool:
                raise Invalid("Context values must be public scalars or scalar lists")


def source_decisions(rows, facets):
    if not isinstance(rows, list) or len(rows) > 64:
        raise Invalid("source_decisions must be a list of at most 64 decisions")
    ids = set()
    by_id = {f["id"]: f for f in facets}
    for row in rows:
        fields = ("id", "family", "sources", "reason", "disposition", "facet_ids")
        obj(row, fields, fields, "source decision")
        for key in ("id", "family", "reason"):
            bounded(row[key], "decision " + key, 512 if key == "reason" else 64)
        if row["id"] in ids:
            raise Invalid("Duplicate source decision id")
        ids.add(row["id"])
        if row["disposition"] not in (
            "selected",
            "not_relevant",
            "excluded",
            "deferred",
        ):
            raise Invalid("Unknown source decision disposition")
        strings(row["sources"], "decision sources")
        strings(row["facet_ids"], "decision facet_ids")
        if len(row["sources"]) > 16 or len(row["facet_ids"]) > 32:
            raise Invalid("Source decision exceeds source/facet limit")
        for source in row["sources"]:
            sources.resolve(source)
        if set(row["facet_ids"]) - by_id.keys():
            raise Invalid("Source decision links an unknown facet")
        if row["disposition"] == "selected" and not row["facet_ids"]:
            raise Invalid("Selected source decision requires a facet")
        if row["disposition"] != "selected" and row["facet_ids"]:
            raise Invalid("Only selected source decisions may link facets")
        for facet_id in row["facet_ids"]:
            facet = by_id[facet_id]
            scopes = ["site:" + d for d in sources.domains(facet)] or [facet["source"]]
            if not all(
                any(sources.contains(source, scope) for source in row["sources"])
                for scope in scopes
            ):
                raise Invalid("Source decision does not cover its linked facet scope")


def request(value, legacy=False):
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
            "intent",
            "source_decisions",
            "operation",
        ),
        label="request",
    )
    if "intent" in value:
        intent = obj(
            value["intent"],
            ("request", "requirements", "hard_constraints", "context", "breadth"),
            ("request",),
            "intent",
        )
        string(intent["request"], "original request")
        for key in ("requirements", "hard_constraints"):
            strings(intent.get(key, []), key)
        context(intent.get("context", []))
        if "breadth" in intent and intent["breadth"] not in (
            "focused",
            "ordinary",
            "wide",
        ):
            raise Invalid("Unknown exploration breadth")
    if "operation" in value:
        if value.get("facets") or value.get("prepared_jobs"):
            raise Invalid("Set operations on facets when using a structured request")
        if value["operation"] not in DISCOVERY_OPERATIONS:
            raise Invalid("Query operation must be a discovery operation")
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
                "query_language",
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
        if f["area"] not in AREAS:
            raise Invalid("Unknown area")
        sources.resolve(f["source"])
        if not re.fullmatch(
            r"[a-z]+\.(discover|inspect|read|commits|diagnose)", f["operation"]
        ):
            raise Invalid("invalid operation")
        if not legacy and f["operation"] not in AREA_OPERATIONS[f["area"]]:
            areas = [
                area
                for area, operations in AREA_OPERATIONS.items()
                if f["operation"] in operations
            ]
            remedy = (
                f"choose --area from {', '.join(areas)} or set an explicit facet area"
                if areas
                else "choose an operation listed by capabilities"
            )
            raise Invalid(
                f"unsupported area/operation: {f['operation']} in {f['area']}; {remedy}"
            )
        if "query_language" in f:
            if (
                not isinstance(f["query_language"], str)
                or len(f["query_language"]) > 64
                or not re.fullmatch(
                    r"[A-Za-z]{2,8}(?:-[A-Za-z0-9]{1,8})*", f["query_language"]
                )
            ):
                raise Invalid("query_language must be a language tag")
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
        if not legacy:
            sources.domains(f)
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
    source_decisions(value.get("source_decisions", []), rows)
    return value


def host_manifest(value):
    version(value, ("capabilities",), ("capabilities",), "host manifest")
    if not isinstance(value["capabilities"], list):
        raise Invalid("host capabilities must be a list")
    seen = set()
    for c in value["capabilities"]:
        obj(
            c,
            ("id", "tool", "operations", "runtime", "identity", "cost", "sources"),
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
        if "sources" in c:
            strings(c["sources"], "host sources")
            for source in c["sources"]:
                sources.resolve(source)
        for k in ("runtime", "identity"):
            if k in c:
                string(c[k], k)
    return value
