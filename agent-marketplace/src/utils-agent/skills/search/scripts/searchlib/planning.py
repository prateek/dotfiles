"""Resolve choices and route candidates without source calls or writes."""

import hashlib
import json
import os
from pathlib import Path
from . import contracts as c, io, registry, sources

BUILTINS = {
    "strategy": "free-first",
    "limit": 10,
    "total_limit": 30,
    "result_limit": 5,
    "free_only": False,
    "via": "auto",
}
PLAN_FIELDS = (
    "request",
    "host",
    "jobs",
    "choices",
    "budget",
    "notices",
    "total_limit",
    "plan_id",
)


def preference_path(scope):
    if scope == "user":
        return (
            Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
            / "agent-search/preferences.json"
        )
    for path in (Path.cwd(), *Path.cwd().parents):
        if (path / ".git").exists():
            return path / ".agents/search.json"
    raise c.Invalid("Repo preferences require a Git root")


def load_preferences(scope):
    try:
        path = preference_path(scope)
    except c.Invalid:
        if scope == "repo":
            return {}
        raise
    if not path.exists():
        return {}
    data = c.version(io.read(path), ("choices",), ("choices",), "preferences")
    return c.obj(data["choices"], c.CHOICES, label="choices")


def validated_choices(entries, scope, notices):
    c.obj(entries, c.CHOICES, label="choices")
    for k, v in entries.items():
        is_preference = k.startswith("prefer_") or k == "strategy"
        try:
            c.choices({k: v})
        except c.Invalid:
            if is_preference and scope in ("user", "repo"):
                notices.append(f"Omitted invalid {scope} preference: {k}")
                continue
            raise
        if k in ("provider", "prefer_provider") and v not in registry.REGISTRY:
            if k == "prefer_provider":
                notices.append(f"Omitted unknown {scope} preference: {v}")
                continue
            raise c.Invalid(f"Unknown {scope} provider constraint: {v}")
        yield k, v


def resolve(request, saved=True):
    levels = [("builtin", BUILTINS)]
    if saved:
        levels += [
            ("user", load_preferences("user")),
            ("repo", load_preferences("repo")),
        ]
    levels += [
        ("conversation", request.get("conversation_choices", {})),
        ("explicit", request.get("choices", {})),
    ]
    resolved, origins, notices = {}, {}, []
    for scope, entries in levels:
        for k, v in validated_choices(entries, scope, notices):
            is_preference = k.startswith("prefer_") or k == "strategy"
            resolved[k] = v
            origins[k] = {
                "value": v,
                "kind": "preference" if is_preference else "constraint",
                "scope": scope,
            }
    c.choices(resolved)
    return resolved, origins, notices


def save_preferences(scope, selections, reset=False):
    path = preference_path(scope)
    with io.lock(path):
        if reset:
            if path.exists():
                path.unlink()
            return
        c.choices(selections)
        for k in ("provider", "prefer_provider"):
            if k in selections:
                registry.validate_provider(selections[k])
        notices = []
        prior = dict(validated_choices(load_preferences(scope), scope, notices))
        io.atomic(
            path, {"schema_version": 1, "choices": c.choices({**prior, **selections})}
        )
        return notices


def supports(p, f, choices):
    if (
        not sources.provider_supports(p, f["source"])
        or f["operation"] not in p["operations"]
    ):
        return "unsupported operation/source"
    if set(f.get("filters", {})) - set(p["filters"]):
        return "unsupported filters"
    if "native_query" in f and f["native_query"]["dialect"] != p["id"]:
        return "native dialect mismatch"
    provider, via = (
        f.get("provider", choices.get("provider")),
        f.get("via", choices.get("via", "auto")),
    )
    if provider and p["id"] != provider:
        return "provider constraint"
    if via != "auto" and p["method"] != via:
        return "method constraint"
    binding = p.get("host_binding")
    if binding and f["operation"] not in binding["operations"]:
        return "host operation unavailable"
    if (
        binding
        and "sources" in binding
        and not any(sources.contains(x, f["source"]) for x in binding["sources"])
    ):
        return "host source unavailable"
    if choices.get("browser"):
        if (
            p["method"] != "browser"
            or not binding
            or binding.get("runtime") != choices["browser"]
        ):
            return "browser runtime constraint"
    if choices.get("free_only") and p["cost"] != "free":
        return "free-only constraint"
    return None


def score(p, choices):
    preferred = p["id"] == choices.get("prefer_provider") or p["method"] == choices.get(
        "prefer_via"
    )
    native_first = p["id"] in (
        "github-code",
        "github-repos",
        "github-issues",
        "github-meta",
        "hn",
    )
    free = p["cost"] == "free"
    strategy_rank = not free
    if choices["strategy"] == "balanced":
        strategy_rank = p["method"] in ("browser", "host")
    order = ("host-web", "startpage", "ddg", "serper", "exa", "brave", "searchapi")
    return (
        not preferred,
        not native_first,
        strategy_rank,
        order.index(p["id"]) if p["id"] in order else len(order),
    )


def fingerprint(value):
    return hashlib.sha256(
        json.dumps(
            value, sort_keys=True, separators=(",", ":"), allow_nan=False
        ).encode()
    ).hexdigest()


def plan(req, manifest=None, saved=True, legacy=False):
    c.request(req, legacy=legacy)
    manifest = c.host_manifest(manifest or {"schema_version": 1, "capabilities": []})
    for provider in req.get("authorized_paid", []):
        registry.validate_provider(provider)
    choices, origins, notices = resolve(req, saved)
    facets = req.get("facets", req.get("prepared_jobs"))
    if not facets:
        areas = choices.get("area", [])
        selected = list(
            dict.fromkeys(choices.get("source", []) + choices.get("require_source", []))
        )
        if len(areas) > 1:
            raise c.Invalid("Multiple areas require explicit source/operation facets")
        if not selected:
            pin = registry.REGISTRY.get(choices.get("provider"), {})
            native_sources = (
                pin.get("sources", []) if pin.get("source_scope") == "named" else []
            )
            if areas and areas != ["web"]:
                if (
                    len(native_sources) != 1
                    or c.SOURCES[native_sources[0]][0] != areas[0]
                ):
                    raise c.Invalid(
                        "Select a source or explicit facets for this area; inspect capabilities for eligible routes"
                    )
                selected = native_sources
            else:
                selected = ["web"]
        if any(
            sources.excluded(x, choices.get("exclude_source", [])) for x in selected
        ):
            raise c.Invalid(
                "Default source is excluded; select another source explicitly"
            )
        facets = []
        for index, source in enumerate(selected):
            area = areas[0] if areas else c.SOURCES.get(source, ("web", None))[0]
            facets.append(
                {
                    "id": f"f{index + 1}",
                    "area": area,
                    "source": source,
                    "operation": req.get("operation", c.DISCOVERY[area]),
                }
            )
    facets = json.loads(json.dumps(facets))
    c.request({"schema_version": 1, "facets": facets}, legacy=legacy)
    areas = set(f["area"] for f in facets)
    count = choices.get(
        "max_calls", min(8, (5 if "code" in areas else 3) + 2 * (len(areas) - 1))
    )
    has_discovery = any(f["operation"].endswith(".discover") for f in facets)
    enrich = count
    if has_discovery:
        enrich = min(2 if "code" in areas else 1, count - 1)
    allocation = c.budget(
        req.get(
            "budget",
            {
                "calls": count,
                "discovery": count - enrich,
                "enrichment": enrich,
                "opens": choices.get("max_opens", 6),
                "wall_seconds": choices.get("timeout", 120),
            },
        )
    )
    for option, counter in (
        ("max_calls", "calls"),
        ("max_opens", "opens"),
        ("timeout", "wall_seconds"),
    ):
        if option in choices and allocation[counter] > choices[option]:
            raise c.Invalid(f"Explicit budget exceeds {option}")
    caps = registry.capabilities(manifest, req.get("authorized_paid", []))
    selected_scopes = choices.get("source", []) + (
        choices.get("require_source", []) if legacy else []
    )
    jobs = []
    for f in facets:
        if "area" in choices and f["area"] not in choices["area"]:
            raise c.Invalid("Facet conflicts with selected areas")
        if choices.get("source") and not any(
            sources.contains(x, f["source"]) for x in selected_scopes
        ):
            raise c.Invalid("Facet conflicts with selected sources")
        if f.get("provider"):
            registry.validate_provider(f["provider"])
        if (
            f.get("provider")
            and choices.get("provider")
            and f["provider"] != choices["provider"]
        ):
            raise c.Invalid("Conflicting provider constraints")
        if f.get("via") and choices.get("via", "auto") not in ("auto", f["via"]):
            raise c.Invalid("Conflicting method constraints")
        if "native_query" in f:
            registry.validate_provider(f["native_query"]["dialect"])
        elif f.get("terms") or req.get("terms"):
            f["terms"] = f.get("terms", req.get("terms"))
        f.setdefault("filters", {})
        for k in ("since", "until", "location"):
            if k in ("since", "until") and not f["operation"].endswith(".discover"):
                continue
            if k in choices:
                if "native_query" in f:
                    raise c.Invalid("Native queries cannot receive automatic filters")
                if k in f["filters"] and f["filters"][k] != choices[k]:
                    raise c.Invalid(f"Conflicting {k} constraints for facet {f['id']}")
                f["filters"][k] = choices[k]
        c.choices(
            {
                k: f["filters"][k]
                for k in ("since", "until", "location")
                if k in f["filters"]
            }
        )
        f.setdefault("limit", choices["limit"])
        f.setdefault("needs", ["relevance"])
        if (
            f["operation"]
            in ("page.inspect", "offer.inspect", "comments.read", "transcript.read")
            and "url" not in f["filters"]
        ):
            raise c.Invalid(f"{f['operation']} requires filters.url")
        if (
            f["operation"] == "item.read"
            and not str(f["filters"].get("item_id", "")).isdigit()
        ):
            raise c.Invalid("item.read requires numeric filters.item_id")
        if f["operation"] in ("repo.inspect", "repo.commits") and not f["filters"].get(
            "repo"
        ):
            raise c.Invalid("Repository enrichment requires filters.repo")
        eligible, skipped = [], []
        excluded = sources.excluded(f["source"], choices.get("exclude_source", []))
        if "url" in f["filters"]:
            target = f["filters"]["url"]
            if not sources.destination_allowed(target, f):
                raise c.Invalid(
                    "Inspection URL is outside the facet source/domain scope"
                )
            excluded = excluded or sources.destination_excluded(
                target, f["source"], choices.get("exclude_source", [])
            )
        pin = f.get("provider", choices.get("provider"))
        if pin and not excluded:
            reason = supports(next(p for p in caps if p["id"] == pin), f, choices)
            if reason:
                raise c.Invalid(
                    f"Provider {pin} conflicts with {reason} for facet {f['id']}"
                )
        for p in caps:
            reason = "excluded" if excluded else supports(p, f, choices)
            if reason is None and p["readiness"] == "configured_unverified":
                eligible.append(p)
            elif reason is None or (
                sources.provider_supports(p, f["source"])
                and f["operation"] in p["operations"]
            ):
                skipped.append(
                    {
                        "provider": p["id"],
                        "reason": reason or p["readiness"],
                        "detail": reason or p["detail"],
                    }
                )
        eligible.sort(key=lambda p: score(p, choices))
        skipped.sort(
            key=lambda row: row["reason"]
            not in {
                "requires_host",
                "missing_credential",
                "missing_tool",
                "unauthorized",
            }
        )
        jobs.append(
            {
                "facet": f,
                "routes": [p["id"] for p in eligible],
                "skipped": skipped,
                "excluded": excluded,
            }
        )
    missing = {
        required
        for required in choices.get("require_source", [])
        if not any(sources.contains(required, f["source"]) for f in facets)
    }
    if missing:
        raise c.Invalid(f"Required sources have no facets: {sorted(missing)}")
    c.source_decisions(req.get("source_decisions", []), facets)
    result = {
        "schema_version": 1,
        "request": {**req, "choices": choices, "conversation_choices": {}},
        "host": manifest,
        "jobs": jobs,
        "choices": origins,
        "budget": allocation,
        "notices": notices,
        "total_limit": choices["total_limit"],
    }
    result["plan_id"] = fingerprint(result)
    return result


def validate_plan(value):
    c.version(
        value,
        PLAN_FIELDS,
        PLAN_FIELDS,
        "plan",
    )
    if (
        fingerprint({k: v for k, v in value.items() if k != "plan_id"})
        != value["plan_id"]
    ):
        raise c.Invalid("Plan fingerprint mismatch")
    # Re-resolve from trusted registry and current environment, never execute file-supplied commands.
    try:
        fresh = plan(value["request"], value["host"], saved=False)
    except c.Invalid as exc:
        raise c.Invalid(
            f"Saved plan needs re-planning; inspect and create a new plan: {exc}"
        ) from exc
    if fresh["jobs"] != value["jobs"] or fresh["budget"] != value["budget"]:
        raise c.Invalid("Capabilities or plan changed; inspect and create a new plan")
    return value
