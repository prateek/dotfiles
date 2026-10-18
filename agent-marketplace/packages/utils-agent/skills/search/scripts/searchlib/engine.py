"""Budgeted execution and exactly-once host settlement, with private checkpoints."""

from concurrent.futures import ThreadPoolExecutor, as_completed
from copy import deepcopy
from itertools import zip_longest
import datetime as dt
import time
import uuid
from urllib.parse import urlsplit
from . import contracts as c, io, registry, planning, identity
from .adapters import native, host

COUNTERS = ("calls", "discovery", "enrichment", "opens")


def now():
    return dt.datetime.now(dt.timezone.utc).isoformat()


def new_state(plan):
    return {
        "schema_version": 1,
        "run_id": uuid.uuid4().hex,
        "plan": plan,
        "deadline": time.time() + plan["budget"]["wall_seconds"],
        "usage": dict.fromkeys(COUNTERS, 0),
        "pending": {},
        "receipts": {},
        "outcomes": {},
        "attempts": [],
        "assessments": {},
        "started_at": now(),
    }


def validate_state(s):
    c.version(
        s,
        (
            "run_id",
            "plan",
            "deadline",
            "usage",
            "pending",
            "receipts",
            "outcomes",
            "attempts",
            "assessments",
            "started_at",
        ),
        (
            "run_id",
            "plan",
            "deadline",
            "usage",
            "pending",
            "receipts",
            "outcomes",
            "attempts",
            "assessments",
            "started_at",
        ),
        "state",
    )
    # Readiness may change after dispatch. Validate syntax/identity without re-planning pending work.
    p = s["plan"]
    c.version(p, planning.PLAN_FIELDS, planning.PLAN_FIELDS, "state plan")
    if (
        planning.fingerprint({k: v for k, v in p.items() if k != "plan_id"})
        != p["plan_id"]
    ):
        raise c.Invalid("State plan fingerprint mismatch")
    c.request(p["request"])
    c.host_manifest(p["host"])
    c.budget(p["budget"])
    c.integer(p["total_limit"], "total_limit", 1)
    if not isinstance(p["jobs"], list):
        raise c.Invalid("jobs must be a list")
    c.number(s["deadline"], "deadline")
    c.obj(s["usage"], COUNTERS, COUNTERS, "usage")
    for k in COUNTERS:
        c.integer(s["usage"][k], k)
    for name in ("pending", "receipts", "outcomes", "assessments"):
        if not isinstance(s[name], dict):
            raise c.Invalid(f"{name} must be an object")
    if not isinstance(s["attempts"], list):
        raise c.Invalid("attempts must be a list")
    for attempt in s["attempts"]:
        fields = ("facet_id", "provider", "status", "count", "observed_at")
        c.obj(attempt, fields, fields, "attempt")
        registry.validate_provider(attempt["provider"])
        if attempt["status"] not in c.STATUSES:
            raise c.Invalid("Unknown attempt status")
        c.integer(attempt["count"], "attempt count")
    for outcome in s["outcomes"].values():
        fields = (
            "facet_id",
            "provider",
            "status",
            "count",
            "observed_at",
            "detail",
            "results",
        )
        c.obj(outcome, (*fields, "raw", "retention_omitted"), fields, "outcome")
        registry.validate_provider(outcome["provider"])
        if outcome["status"] not in c.STATUSES:
            raise c.Invalid("Unknown outcome status")
        c.integer(outcome["count"], "outcome count")
        if not isinstance(outcome["results"], list):
            raise c.Invalid("outcome results must be a list")
        for row in outcome["results"]:
            fields = (
                "kind",
                "source",
                "url",
                "title",
                "excerpt",
                "fields",
                "observed_at",
                "evidence_level",
                "identity",
                "observations",
            )
            c.obj(row, fields, fields, "persisted result")
            c.web_url(row["url"])
            if not isinstance(row["identity"], list) or not isinstance(
                row["observations"], list
            ):
                raise c.Invalid("Invalid persisted result identity/observations")
    for receipt in s["receipts"].values():
        c.obj(
            receipt,
            ("attempt_id", "status", "digest"),
            ("attempt_id", "status"),
            "receipt",
        )
    for assessment in s["assessments"].values():
        c.obj(
            assessment,
            ("facet_id", "checks", "references", "note"),
            ("facet_id", "checks", "references"),
            "assessment",
        )
        c.strings(assessment["checks"], "checks")
        c.strings(assessment["references"], "references")
    for job in p["jobs"]:
        c.obj(
            job,
            ("facet", "routes", "skipped", "excluded"),
            ("facet", "routes", "skipped", "excluded"),
            "job",
        )
        for provider in job["routes"]:
            registry.validate_provider(provider)
        c.request({"schema_version": 1, "facets": [job["facet"]]})
    for work in s["pending"].values():
        c.obj(
            work,
            (
                "run_id",
                "work_item_id",
                "attempt_id",
                "operation",
                "payload",
                "reserved_budget",
                "facet_id",
                "provider",
                "kind",
            ),
            (
                "run_id",
                "work_item_id",
                "attempt_id",
                "reserved_budget",
                "facet_id",
                "provider",
                "kind",
            ),
            "pending work",
        )
        registry.validate_provider(work["provider"])
        c.obj(work["reserved_budget"], COUNTERS, COUNTERS, "reservation")
        for k in COUNTERS:
            c.integer(work["reserved_budget"][k], k)
    return s


def persisted(s):
    copy = deepcopy(s)
    for facet_id, outcome in copy["outcomes"].items():
        if (
            outcome.get("provider")
            and registry.REGISTRY[outcome["provider"]]["retention"] == "derived-only"
        ):
            outcome["results"] = []
            outcome.pop("raw", None)
            outcome["retention_omitted"] = True
            if facet_id in copy["assessments"]:
                copy["assessments"][facet_id]["references"] = []
                copy["assessments"][facet_id].pop("note", None)
    return copy


def checkpoint(s, path):
    if path:
        io.atomic(path, persisted(s))


def available(s, reservation):
    reserved = {
        k: sum(w["reserved_budget"][k] for w in s["pending"].values()) for k in COUNTERS
    }
    return time.time() < s["deadline"] and all(
        s["usage"][k] + reserved[k] + reservation[k] <= s["plan"]["budget"][k]
        for k in COUNTERS
    )


def reservation_for(f, p):
    category = "discovery" if f["operation"].endswith(".discover") else "enrichment"
    calls = native.max_calls(p, f) if p["method"] == "native" else 1
    return {
        **dict.fromkeys(COUNTERS, 0),
        "calls": calls,
        category: calls,
        "opens": 0
        if category == "discovery" or f["operation"].endswith(".diagnose")
        else 1,
    }


def reserve(s, f, p, path):
    reservation = reservation_for(f, p)
    if not available(s, reservation):
        return None
    binding = next(
        (b for b in s["plan"]["host"]["capabilities"] if b["id"] == p.get("host")), None
    )
    work = {
        "run_id": s["run_id"],
        "work_item_id": uuid.uuid4().hex,
        "attempt_id": uuid.uuid4().hex,
        "facet_id": f["id"],
        "provider": p["id"],
        "operation": f["operation"],
        "reserved_budget": reservation,
        "kind": "host" if p.get("host") else "direct",
        "payload": host.work(p, f, binding) if binding else {},
    }
    s["pending"][work["work_item_id"]] = work
    checkpoint(s, path)
    return work


def source_matches(url, f):
    p = urlsplit(url)

    def matches(domain):
        hostname, _, path = domain.partition("/")
        aliases = {"youtube.com": ["youtu.be"], "x.com": ["twitter.com"]}.get(
            hostname, []
        )
        return any(
            p.hostname == h or (p.hostname or "").endswith("." + h)
            for h in [hostname, *aliases]
        ) and (not path or p.path.startswith("/" + path))

    source_domain = c.SOURCES[f["source"]][1]
    domains = f.get("filters", {}).get("domains", [])
    return (not source_domain or matches(source_domain)) and (
        not domains or any(matches(d) for d in domains)
    )


def settle(s, work, outcome, usage=None, observed_at=None):
    f = next(
        j["facet"] for j in s["plan"]["jobs"] if j["facet"]["id"] == work["facet_id"]
    )
    p = registry.REGISTRY[work["provider"]]
    stamp = observed_at or now()
    rows = outcome.get("results", [])
    normalized, rejected_schema, rejected_source = [], 0, 0
    for rank, row in enumerate(rows, 1):
        try:
            candidate = identity.normalize([row], f, p, stamp, rank_start=rank)[0]
            native_repo = (
                p["method"] == "native"
                and f["source"] == "github"
                and candidate["fields"].get("repo")
            )
            if (
                not f["operation"].endswith(".diagnose")
                and not native_repo
                and not source_matches(candidate["url"], f)
            ):
                rejected_source += 1
                continue
            normalized.append(candidate)
        except (c.Invalid, TypeError, ValueError, AttributeError):
            rejected_schema += 1
    normalized = normalized[: f["limit"]]
    status = outcome.get("status", "schema_error")
    if rejected_schema or rejected_source:
        if normalized:
            status = "partial"
        else:
            status = "schema_error" if rejected_schema else "constraint_failed"
    elif status == "success" and not normalized:
        status = "empty"
    reservation = work["reserved_budget"]
    if usage is None:
        used = reservation.copy()
        if "calls" in outcome:
            count = min(outcome["calls"], reservation["calls"])
            used["calls"] = count
            for k in ("discovery", "enrichment"):
                if used[k]:
                    used[k] = count
    else:
        c.obj(usage, COUNTERS, COUNTERS, "host usage")
        for k in COUNTERS:
            c.integer(usage[k], k)
            if usage[k] > reservation[k]:
                raise c.Invalid(
                    "Host usage exceeds reservation; reconcile externally, do not replay"
                )
        if usage["calls"] != usage["discovery"] + usage["enrichment"]:
            raise c.Invalid("Host usage split does not equal calls")
        used = usage
    for k in COUNTERS:
        s["usage"][k] += used[k]
    record = {
        "facet_id": f["id"],
        "provider": p["id"],
        "status": status,
        "results": normalized,
        "count": len(normalized),
        "detail": outcome.get("detail", ""),
        "observed_at": stamp,
    }
    if f.get("raw") and "raw" in outcome:
        record["raw"] = outcome["raw"]
    rejected = rejected_schema + rejected_source
    if rejected:
        record["detail"] = (
            f"{record['detail']} Rejected {rejected} invalid or out-of-scope rows.".strip()
        )
    s["outcomes"][f["id"]] = record
    s["attempts"].append(
        {
            k: record[k]
            for k in ("facet_id", "provider", "status", "count", "observed_at")
        }
    )
    s["receipts"][work["work_item_id"]] = {
        "attempt_id": work["attempt_id"],
        "status": status,
    }
    del s["pending"][work["work_item_id"]]


def call(p, f, timeout):
    try:
        return registry.execute(p, f, timeout)
    except io.Failure as exc:
        return {"status": exc.status, "detail": exc.detail, "results": []}
    except (ValueError, KeyError, TypeError, AttributeError):
        return {
            "status": "schema_error",
            "detail": "Unexpected provider response",
            "results": [],
        }
    except Exception:
        return {
            "status": "failed",
            "detail": "Adapter failed unexpectedly",
            "results": [],
        }


def drive(s, path=None):
    with ThreadPoolExecutor(max_workers=2) as pool:
        while time.time() < s["deadline"]:
            scheduled, groups = [], set()
            pending_facets = {w["facet_id"] for w in s["pending"].values()}
            current_caps = {
                p["id"]: p
                for p in registry.capabilities(
                    s["plan"]["host"], s["plan"]["request"].get("authorized_paid", [])
                )
            }
            pending_groups = {
                registry.REGISTRY[w["provider"]].get("rate_group", w["provider"])
                for w in s["pending"].values()
            }
            jobs = sorted(
                s["plan"]["jobs"],
                key=lambda job: sum(
                    a["facet_id"] == job["facet"]["id"] for a in s["attempts"]
                ),
            )
            blocked_first_attempt = False
            for job in jobs:
                f = job["facet"]
                outcome = s["outcomes"].get(f["id"])
                attempts = [a for a in s["attempts"] if a["facet_id"] == f["id"]]
                if attempts and blocked_first_attempt:
                    continue
                if (
                    f["id"] in pending_facets
                    or len(attempts) >= 2
                    or (outcome and outcome.get("count", 0))
                ):
                    continue
                if (
                    outcome
                    and outcome["status"] in ("success", "empty")
                    and not job["routes"]
                ):
                    continue
                routes = [
                    p
                    for p in job["routes"]
                    if current_caps[p]["readiness"] == "configured_unverified"
                ]
                if attempts and attempts[-1]["status"] in ("timeout", "transient"):
                    routes = [attempts[-1]["provider"]]
                else:
                    routes = [
                        p for p in routes if p not in {a["provider"] for a in attempts}
                    ]
                routes = [
                    p
                    for p in routes
                    if not any(
                        a["provider"] == p
                        and a["status"] in ("rate_limited", "challenge", "auth_failed")
                        for a in s["attempts"]
                    )
                ]
                if not routes:
                    continue
                p = registry.REGISTRY[routes[0]]
                group = p.get("rate_group", p["id"])
                if group in groups | pending_groups:
                    if not attempts:
                        blocked_first_attempt = True
                    continue
                if len(s["pending"]) >= 2:
                    break
                work = reserve(s, f, p, path)
                if not work:
                    continue
                groups.add(group)
                if p.get("host"):
                    continue
                scheduled.append(
                    (
                        pool.submit(
                            call,
                            p,
                            f,
                            min(
                                f.get("timeout", 120),
                                max(0.01, s["deadline"] - time.time()),
                            ),
                        ),
                        work,
                    )
                )
            if not scheduled:
                break
            work_by_future = {future: work for future, work in scheduled}
            for future in as_completed(work_by_future):
                settle(s, work_by_future[future], future.result())
                checkpoint(s, path)
    return report(s)


def host_results(s, data):
    c.version(data, ("results",), ("results",), "host results")
    if not isinstance(data["results"], list):
        raise c.Invalid("host results must be a list")
    # Validate/settle on a copy; one bad envelope cannot partly commit a batch.
    updated = deepcopy(s)
    for r in data["results"]:
        c.obj(
            r,
            (
                "run_id",
                "work_item_id",
                "attempt_id",
                "status",
                "payload",
                "usage",
                "observed_at",
            ),
            (
                "run_id",
                "work_item_id",
                "attempt_id",
                "status",
                "payload",
                "observed_at",
            ),
            "host result",
        )
        if r["run_id"] != updated["run_id"]:
            raise c.Invalid("Wrong run_id")
        if r["status"] not in c.STATUSES:
            raise c.Invalid("Unknown host status")
        try:
            dt.datetime.fromisoformat(r["observed_at"])
        except (ValueError, TypeError):
            raise c.Invalid("Invalid observed_at") from None
        receipt = updated["receipts"].get(r["work_item_id"])
        digest = planning.fingerprint(r)
        if receipt:
            if (
                receipt["attempt_id"] != r["attempt_id"]
                or receipt.get("digest") != digest
            ):
                raise c.Invalid("Conflicting or stale duplicate result")
            continue
        w = updated["pending"].get(r["work_item_id"])
        if not w or w["attempt_id"] != r["attempt_id"]:
            raise c.Invalid("Unknown or stale attempt")
        payload = c.obj(
            r["payload"], ("results", "html", "detail", "raw"), label="host payload"
        )
        if "html" in payload:
            if w["provider"] not in ("ddg", "startpage"):
                raise c.Invalid(
                    "No HTML parser for this provider; submit parsed results"
                )
            parsed = host.parse(w["provider"], c.string(payload["html"], "html"))
            outcome = (
                parsed
                if r["status"] == "success"
                else {**parsed, "status": r["status"]}
            )
        else:
            if not isinstance(payload.get("results", []), list):
                raise c.Invalid("payload.results must be a list")
            for row in payload.get("results", []):
                c.obj(
                    row,
                    ("url", "title", "excerpt", "fields", "kind"),
                    ("url",),
                    "host row",
                )
                c.web_url(row["url"])
            outcome = {**payload, "status": r["status"]}
        settle(updated, w, outcome, r.get("usage"), r["observed_at"])
        updated["receipts"][r["work_item_id"]]["digest"] = digest
    return updated


def extend(s, data):
    c.version(data, ("prepared_jobs",), ("prepared_jobs",), "extension")
    c.request(data)
    old = s["plan"]
    prior_ids = {j["facet"]["id"] for j in old["jobs"]}
    if prior_ids & {f["id"] for f in data["prepared_jobs"]}:
        raise c.Invalid("Extension reuses a facet id")
    req = {
        **old["request"],
        "facets": [j["facet"] for j in old["jobs"]] + data["prepared_jobs"],
        "budget": old["budget"],
    }
    req.pop("prepared_jobs", None)
    resolved = planning.plan(req, old["host"], saved=False)
    resolved["jobs"] = old["jobs"] + resolved["jobs"][len(old["jobs"]) :]
    resolved["plan_id"] = planning.fingerprint(
        {k: v for k, v in resolved.items() if k != "plan_id"}
    )
    s["plan"] = resolved


def assess(s, data):
    c.version(data, ("run_id", "assessments"), ("run_id", "assessments"), "assessment")
    if data["run_id"] != s["run_id"]:
        raise c.Invalid("Wrong assessment run_id")
    if not isinstance(data["assessments"], list):
        raise c.Invalid("assessments must be a list")
    for a in data["assessments"]:
        c.obj(
            a,
            ("facet_id", "checks", "references", "note"),
            ("facet_id", "checks", "references"),
            "assessment",
        )
        jobs = [j for j in s["plan"]["jobs"] if j["facet"]["id"] == a["facet_id"]]
        if not jobs:
            raise c.Invalid("Unknown assessed facet")
        c.strings(a["checks"], "checks")
        c.strings(a["references"], "references")
        if not a["references"]:
            raise c.Invalid("Assessment requires evidence references")
        for ref in a["references"]:
            c.web_url(ref)
        if not s["outcomes"].get(a["facet_id"], {}).get("count"):
            raise c.Invalid("Cannot support a facet with no candidates")
        if set(a["checks"]) - set(jobs[0]["facet"]["needs"]):
            raise c.Invalid("Unknown assessment checks")
    for a in data["assessments"]:
        s["assessments"][a["facet_id"]] = a


def report(s):
    coverage, suggestions = [], []
    per_facet = [
        s["outcomes"].get(j["facet"]["id"], {}).get("results", [])
        for j in s["plan"]["jobs"]
    ]
    interleaved = [
        row for group in zip_longest(*per_facet) for row in group if row is not None
    ]
    grouped = identity.merge(interleaved)[: s["plan"]["total_limit"]]
    kept = {planning.fingerprint(row["identity"]) for row in grouped}
    outcomes = deepcopy(s["outcomes"])
    for out in outcomes.values():
        out["results"] = [
            r
            for r in out.get("results", [])
            if planning.fingerprint(r["identity"]) in kept
        ]
        out["returned_count"] = len(out["results"])
    for job in s["plan"]["jobs"]:
        f, out = job["facet"], s["outcomes"].get(job["facet"]["id"], {})
        supported = bool(out.get("count")) and set(f["needs"]) <= set(
            s["assessments"].get(f["id"], {}).get("checks", [])
        )
        pending = any(w["facet_id"] == f["id"] for w in s["pending"].values())
        if out:
            outcome = out["status"]
        elif pending:
            outcome = "pending"
        elif job["routes"]:
            if s["pending"] and time.time() < s["deadline"]:
                outcome = "deferred"
            elif any(
                available(s, reservation_for(f, registry.REGISTRY[p]))
                for p in job["routes"]
            ):
                outcome = "unavailable"
            else:
                outcome = "budget_exhausted"
        else:
            outcome = "unavailable"
        if job["excluded"]:
            status = "excluded"
        elif supported:
            status = "supported"
        elif out.get("count"):
            status = "discovery-only"
        elif outcome in ("pending", "deferred"):
            status = "unverified"
        else:
            status = "unavailable"
        coverage.append(
            {
                "facet_id": f["id"],
                "source": f["source"],
                "operation": f["operation"],
                "coverage": status,
                "outcome": outcome,
                "count": out.get("count", 0),
                "returned_count": outcomes.get(f["id"], {}).get("returned_count", 0),
                "skipped": job["skipped"],
                "retention_omitted": out.get("retention_omitted", False),
            }
        )
        if outcome in (
            "rate_limited",
            "timeout",
            "challenge",
            "auth_failed",
            "schema_error",
        ):
            suggestions.append(
                {
                    "facet_id": f["id"],
                    "gap": outcome,
                    "benefit": "Restore this configured route",
                    "next_step": "Inspect the reported provider; respect reset/login/challenge before retrying",
                    "prerequisites": [out.get("provider")],
                }
            )
        elif not job["routes"] and not job["excluded"]:
            known = job["skipped"]
            suggestions.append(
                {
                    "facet_id": f["id"],
                    "gap": "unconfigured" if known else "unsupported",
                    "benefit": f"Obtain {f['operation']} evidence from {f['source']}",
                    "next_step": "Configure an eligible route listed in skipped"
                    if known
                    else "Consult references/extending.md for this operation and constraints",
                    "prerequisites": [k["detail"] for k in known],
                }
            )
    return {
        "schema_version": 1,
        "run_id": s["run_id"],
        "plan_id": s["plan"]["plan_id"],
        "results": grouped,
        "coverage": coverage,
        "complete": any(x["coverage"] == "supported" for x in coverage)
        and all(x["coverage"] in ("supported", "excluded") for x in coverage),
        "pending": list(s["pending"].values()),
        "usage": s["usage"],
        "budget": s["plan"]["budget"],
        "deadline": s["deadline"],
        "attempts": s["attempts"],
        "outcomes": outcomes,
        "suggestions": suggestions,
        "notices": s["plan"]["notices"],
        "usage_unit": "adapter/tool operations; opaque internal HTTP fan-out unknown",
    }
