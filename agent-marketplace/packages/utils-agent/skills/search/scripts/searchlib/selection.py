"""Mechanical candidate accounting and host-authored relevance attestations."""

from copy import deepcopy
from itertools import zip_longest
from . import contracts as c, identity, planning, registry, diagnostics

FITS = ("direct", "partial", "adjacent", "irrelevant", "unassessed")
CONTENT_OPERATIONS = {
    "page.inspect",
    "offer.inspect",
    "comments.read",
    "transcript.read",
    "item.read",
}


def unassessed(reason="Awaiting host assessment"):
    return {
        "fit": "unassessed",
        "inspected": False,
        "verification": "unverified",
        "constraints": {},
        "reason": reason,
        "references": [],
    }


def content_rows(s):
    operations = {j["facet"]["id"]: j["facet"]["operation"] for j in s["plan"]["jobs"]}
    return [
        row
        for facet, out in s["outcomes"].items()
        for row in out.get("results", [])
        if operations[facet] in CONTENT_OPERATIONS or row["fields"].get("content")
    ]


def candidates(s):
    jobs = s["plan"]["jobs"]
    discovery = [j for j in jobs if j["facet"]["operation"].endswith(".discover")]
    rows = [
        s["outcomes"].get(j["facet"]["id"], {}).get("results", [])
        for j in discovery or jobs
    ]
    interleaved = [r for group in zip_longest(*rows) for r in group if r is not None]
    grouped = identity.merge(interleaved)
    assessments = s.get("selection", {}).get("assessments", {})
    selected = {r["candidate_id"] for r in s.get("selection", {}).get("selected", [])}
    reads_by_id = {}
    reads_by_request = {}
    for read in content_rows(s):
        reads_by_id.setdefault(planning.fingerprint(read["identity"]), []).append(read)
        requested = read["fields"].get("inspection_requested_url")
        if requested:
            reads_by_request.setdefault(requested, []).append(read)
    for row in grouped:
        key = planning.fingerprint(row["identity"])
        row["candidate_id"] = key
        reads = list(reads_by_id.get(key, []))
        for observation in row["observations"]:
            for read in reads_by_request.get(observation["url"], []):
                if read not in reads:
                    reads.append(read)
        row["evidence_digest"] = planning.fingerprint(
            [row["observations"], [r["observations"] for r in reads]]
        )
        row["content_evidence"] = list(dict.fromkeys(r["url"] for r in reads))
        assessment = assessments.get(key, unassessed())
        if assessment.get("evidence_digest") not in (None, row["evidence_digest"]):
            assessment = unassessed("New observations require reassessment")
        row["assessment"] = assessment
        if key in selected and assessment["fit"] in FITS[:3]:
            disposition = "selected"
        elif not assessment["inspected"]:
            disposition = "uninspected"
        elif (
            assessment["fit"] == "irrelevant"
            or "failed" in assessment["constraints"].values()
        ):
            disposition = "inspected_excluded"
        else:
            disposition = (
                "relevant_not_selected"
                if assessment["fit"] in FITS[:3]
                else "inspected_unassessed"
            )
        row["disposition"] = disposition
    return grouped


def validate_saved(value):
    c.obj(
        value,
        (
            "schema_version",
            "run_id",
            "assessments",
            "selected",
            "criteria",
            "gaps",
            "answer_status",
            "omitted_counts",
            "stopping_reason",
        ),
        ("assessments", "selected", "criteria", "gaps", "answer_status"),
        "saved selection",
    )
    if not isinstance(value["assessments"], dict) or not isinstance(
        value["selected"], list
    ):
        raise c.Invalid("Invalid saved selection collections")
    c.string(value["criteria"], "criteria")
    c.strings(value["gaps"], "gaps")
    if "stopping_reason" in value:
        c.bounded(value["stopping_reason"], "stopping_reason")
    if value["answer_status"] not in ("pending", "partial", "complete"):
        raise c.Invalid("Invalid saved answer_status")
    if "omitted_counts" in value:
        c.obj(
            value["omitted_counts"],
            ("selected", "inspected"),
            ("selected", "inspected"),
            "omitted counts",
        )
        for count in value["omitted_counts"].values():
            c.integer(count, "omitted count")
    fields = (
        "candidate_id",
        "evidence_digest",
        "fit",
        "inspected",
        "verification",
        "constraints",
        "reason",
        "references",
    )
    for key, a in value["assessments"].items():
        c.obj(a, fields, fields, "saved candidate assessment")
        if (
            a["candidate_id"] != key
            or a["fit"] not in FITS
            or type(a["inspected"]) is not bool
        ):
            raise c.Invalid("Invalid saved candidate assessment")
        c.string(a["evidence_digest"], "evidence_digest")
        c.string(a["reason"], "reason")
        c.strings(a["references"], "references")
        if not isinstance(a["constraints"], dict):
            raise c.Invalid("Invalid saved constraints")
    for item in value["selected"]:
        c.obj(
            item,
            ("candidate_id", "reason"),
            ("candidate_id", "reason"),
            "saved selection item",
        )
        c.string(item["candidate_id"], "candidate_id")
        c.string(item["reason"], "reason")


def apply(s, data):
    original_data = data
    data = diagnostics.redact(data)
    fields = ("run_id", "assessments", "selected", "criteria", "gaps", "answer_status")
    c.version(data, (*fields, "stopping_reason"), fields, "selection")
    if "stopping_reason" in data:
        c.bounded(data["stopping_reason"], "stopping_reason")
    if data["run_id"] != s["run_id"]:
        raise c.Invalid("Wrong selection run_id")
    if data["answer_status"] not in ("pending", "partial", "complete"):
        raise c.Invalid("Invalid answer_status")
    c.string(data["criteria"], "criteria")
    c.strings(data["gaps"], "gaps")
    if not isinstance(data["assessments"], list) or not isinstance(
        data["selected"], list
    ):
        raise c.Invalid("assessments and selected must be lists")
    pool = {r["candidate_id"]: r for r in candidates(s)}
    assessments = deepcopy(s.get("selection", {}).get("assessments", {}))
    constraints = s["plan"]["request"].get("intent", {}).get("hard_constraints", [])
    evidence = {
        r["url"] for out in s["outcomes"].values() for r in out.get("results", [])
    }
    seen = set()
    for a in data["assessments"]:
        fields = (
            "candidate_id",
            "evidence_digest",
            "fit",
            "inspected",
            "verification",
            "constraints",
            "reason",
            "references",
        )
        c.obj(a, fields, fields, "candidate assessment")
        key = c.string(a["candidate_id"], "candidate_id")
        if key not in pool or key in seen:
            raise c.Invalid("Unknown or duplicate candidate assessment")
        seen.add(key)
        if a["evidence_digest"] != pool[key]["evidence_digest"]:
            raise c.Invalid(
                "Candidate evidence changed; reassess the current observations"
            )
        if a["fit"] not in FITS or type(a["inspected"]) is not bool:
            raise c.Invalid("Invalid fit/inspected")
        if a["verification"] not in ("unverified", "verified", "failed"):
            raise c.Invalid("Invalid verification")
        if not a["inspected"] and (
            a["fit"] == "irrelevant" or a["verification"] != "unverified"
        ):
            raise c.Invalid("Uninspected candidates remain uncertain")
        c.string(a["reason"], "assessment reason")
        c.strings(a["references"], "references")
        if a["fit"] != "unassessed" and not a["references"]:
            raise c.Invalid("Assessed fit requires evidence references")
        for ref in a["references"]:
            c.web_url(ref)
            if ref not in evidence:
                raise c.Invalid("Assessment references must come from this run")
        if a["inspected"] and not (
            set(a["references"]) & set(pool[key]["content_evidence"])
        ):
            raise c.Invalid(
                "Inspected assessment requires content inspection of this candidate"
            )
        c.obj(a["constraints"], constraints, constraints, "hard constraints")
        if any(
            v not in ("met", "failed", "unknown") for v in a["constraints"].values()
        ):
            raise c.Invalid("Invalid constraint status")
        assessments[key] = deepcopy(a)
    selected, previous_fit = set(), -1
    for item in data["selected"]:
        c.obj(
            item,
            ("candidate_id", "reason"),
            ("candidate_id", "reason"),
            "selected candidate",
        )
        key = c.string(item["candidate_id"], "candidate_id")
        if key not in pool or key in selected:
            raise c.Invalid("Unknown or duplicate selected candidate")
        a = assessments.get(key, {})
        if a.get("evidence_digest") != pool[key]["evidence_digest"]:
            raise c.Invalid("Selected candidate needs current evidence assessment")
        if (
            a.get("fit") not in FITS[:3]
            or a.get("verification") == "failed"
            or "failed" in a.get("constraints", {}).values()
        ):
            raise c.Invalid(
                "Selected candidate must have assessed fit and no failed hard constraints"
            )
        if "unknown" in a["constraints"].values() and not data["gaps"]:
            raise c.Invalid("Unknown hard constraints require a coverage gap")
        rank = FITS.index(a["fit"])
        if rank < previous_fit:
            raise c.Invalid("Direct fit precedes partial and adjacent fit")
        previous_fit = rank
        c.string(item["reason"], "selection reason")
        selected.add(key)
    if len(selected) > s["plan"]["request"]["choices"].get("result_limit", 5):
        raise c.Invalid("Selection exceeds result_limit")
    if sum(a["inspected"] for a in assessments.values()) > s["plan"]["budget"]["opens"]:
        raise c.Invalid("Candidate inspections exceed the declared open budget")
    if data["answer_status"] == "complete" and (data["gaps"] or s["pending"]):
        raise c.Invalid("Complete answer cannot have gaps or pending work")
    if data["answer_status"] == "complete" and any(
        not assessments[key]["inspected"]
        or assessments[key]["verification"] != "verified"
        for key in selected
    ):
        raise c.Invalid("Complete answer requires inspected, verified selections")
    s["selection"] = {**deepcopy(data), "assessments": assessments}
    if original_data != data:
        s.setdefault("redactions", []).append("Credentials removed from selection text")


def summary(s, pool):
    selection = s.get("selection", {})
    jobs = s["plan"]["jobs"]
    discovery = [j for j in jobs if j["facet"]["operation"].endswith(".discover")]
    outs = [s["outcomes"].get(j["facet"]["id"], {}) for j in discovery or jobs]
    observations = sum(len(r["observations"]) for r in pool)
    attempts = []
    for job, out in zip(discovery or jobs, outs):
        attempts.extend(
            [a for a in s["attempts"] if a["facet_id"] == job["facet"]["id"]] or [out]
        )
    counts = {
        "fetched": sum(a.get("fetched_count", a.get("count", 0)) for a in attempts),
        "rejected_schema": sum(a.get("rejected_schema", 0) for a in attempts),
        "rejected_source": sum(a.get("rejected_source", 0) for a in attempts),
        "unique": len(pool),
        "duplicate_merged": observations - len(pool),
        "inspected": sum(r["assessment"]["inspected"] for r in pool),
        "selected": sum(r["disposition"] == "selected" for r in pool),
        "uninspected": sum(not r["assessment"]["inspected"] for r in pool),
        "inspected_excluded": sum(
            r["disposition"] == "inspected_excluded" for r in pool
        ),
        "relevant_not_selected": sum(
            r["disposition"] == "relevant_not_selected" for r in pool
        ),
        "not_visible": max(0, len(pool) - s["plan"]["total_limit"]),
    }
    omitted = any(o.get("retention_omitted") for o in outs)
    if omitted:
        counts["unique"] = None
        counts["duplicate_merged"] = None
    counts["retained_unique"] = len(pool)
    tails = []
    for job, out in zip(discovery or jobs, outs):
        if not job["facet"]["operation"].endswith(".discover"):
            continue
        pagination = out.get("pagination", {})
        count = pagination.get("unfetched_count")
        if count == 0:
            continue
        tails.append(
            {
                "facet_id": job["facet"]["id"],
                "reason": "provider_cap"
                if count is not None
                else "provider_tail_unknown",
                "count": count,
                "requested_limit": job["facet"]["limit"],
            }
        )
    omitted_counts = selection.get("omitted_counts")
    if omitted_counts:
        counts.update(omitted_counts)
    answer_status = selection.get("answer_status", "pending")
    gaps = list(selection.get("gaps", []))
    if not omitted_counts and counts["selected"] != len(selection.get("selected", [])):
        answer_status = "pending"
        gaps.append("Selected evidence changed; reassessment required")
    if s["pending"] and answer_status == "complete":
        answer_status = "pending"
        gaps.append("Additional work is pending")
    return {
        "counts": counts,
        "answer_status": answer_status,
        "criteria": selection.get("criteria", "Awaiting relevance selection"),
        "gaps": gaps,
        "retention_omitted": omitted,
        "selection_omitted_from_trace": bool(selection)
        and any(
            registry.REGISTRY.get(o.get("provider"), {}).get("retention")
            == "derived-only"
            for o in s["outcomes"].values()
        ),
        "redactions": s.get("redactions", []),
        "retention_limited": any(
            registry.REGISTRY.get(o.get("provider"), {}).get("retention")
            == "derived-only"
            for o in outs
        ),
        "never_fetched": tails,
        "measurement_limits": [
            "Counts measure retrieval and recorded attestations, not task quality",
            "Opaque provider fan-out, billing and unseen candidate identities are unknown",
        ],
    }


def receipt(s, facts, coverage):
    n = facts["counts"]
    providers = {}

    def add(name, count, status):
        provider = providers.setdefault(name, {"count": 0, "states": set()})
        provider["count"] += count
        provider["states"].add(status)

    attempted = set()
    for a in s["attempts"]:
        attempted.add(a["facet_id"])
        add(a["provider"], a.get("fetched_count", a["count"]), a["status"])
    for row in coverage:
        pending = [
            w["provider"]
            for w in s["pending"].values()
            if w["facet_id"] == row["facet_id"]
        ]
        if row["facet_id"] in attempted:
            for name in pending:
                add(name, 0, "pending")
            continue
        out = s["outcomes"].get(row["facet_id"], {})
        job = next(j for j in s["plan"]["jobs"] if j["facet"]["id"] == row["facet_id"])
        names = pending or ([out["provider"]] if out.get("provider") else job["routes"])
        if not names:
            names = [
                r["provider"]
                for r in row["skipped"]
                if r["reason"]
                in (
                    "missing_credential",
                    "missing_tool",
                    "requires_host",
                    "unauthorized",
                    "disabled",
                )
            ]
        for name in names or [row["source"]]:
            add(name, out.get("fetched_count", out.get("count", 0)), row["outcome"])
    labels = [
        f"{name} {p['count']} ({', '.join(sorted(p['states']))})"
        for name, p in providers.items()
    ]
    trace = s.get("trace", {}).get("state")
    unique = "unknown" if n["unique"] is None else n["unique"]
    rejected = n["rejected_schema"] + n["rejected_source"]
    rejection_note = (
        f"; {rejected} rejected (schema {n['rejected_schema']}, source {n['rejected_source']})"
        if rejected
        else ""
    )
    retention_note = (
        " (provider policy omits all selection text; aggregate counts retained)"
        if facts["selection_omitted_from_trace"]
        else ""
    )
    return (
        f"Search: {facts['answer_status']} · {n['fetched']} fetched → {unique} unique → "
        f"{n['inspected']} inspected → {n['selected']} selected{rejection_note}\n"
        f"Providers: {'; '.join(labels)}\nSelection: {facts['criteria']}\n"
        f"Trace: {trace or 'not persisted (in-memory execution)'}{retention_note}"
    )
