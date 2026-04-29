#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


def load_json(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as handle:
        data = json.load(handle)
    if not isinstance(data, dict):
        raise ValueError(f"{path} must contain a JSON object")
    return data


def normalize(value: object) -> str:
    if value is None:
        return ""
    if isinstance(value, list):
        return " ".join(normalize(item) for item in value)
    if isinstance(value, dict):
        return " ".join(normalize(item) for item in value.values())
    return str(value).lower()


def validate_shape(manifest: dict) -> list[str]:
    required = {
        "repo": dict,
        "positioning": dict,
        "audiences": list,
        "pages": list,
        "workflows": list,
        "media": list,
        "implementation": dict,
        "quality_gates": list,
        "writing": dict,
    }
    errors: list[str] = []
    for key, expected_type in required.items():
        if key not in manifest:
            errors.append(f"missing top-level field: {key}")
            continue
        if not isinstance(manifest[key], expected_type):
            errors.append(f"{key} should be a {expected_type.__name__}")
    if "ux_review" in manifest and not isinstance(manifest["ux_review"], dict):
        errors.append("ux_review should be a dict when present")
    if "visual_direction" in manifest and not isinstance(manifest["visual_direction"], dict):
        errors.append("visual_direction should be a dict when present")
    return errors


def page_blobs(manifest: dict) -> list[str]:
    blobs = []
    for page in manifest.get("pages", []):
        if isinstance(page, dict):
            blobs.append(normalize(page))
    return blobs


def workflow_blobs(manifest: dict) -> list[str]:
    blobs = []
    for workflow in manifest.get("workflows", []):
        if isinstance(workflow, dict):
            blobs.append(normalize(workflow))
    return blobs


def audience_blobs(manifest: dict) -> list[str]:
    blobs = []
    for audience in manifest.get("audiences", []):
        if isinstance(audience, dict):
            blobs.append(normalize(audience))
    return blobs


def quality_gate_blob(manifest: dict) -> str:
    return " ".join(
        normalize(gate)
        for gate in manifest.get("quality_gates", [])
        if isinstance(gate, dict) or isinstance(gate, str)
    )


def has_page_keyword_group(blobs: list[str], group: list[str]) -> bool:
    return any(any(token.lower() in blob for token in group) for blob in blobs)


def score_manifest(manifest: dict) -> tuple[int, dict[str, int], list[str]]:
    notes: list[str] = []
    breakdown = {
        "repo": 0,
        "audiences": 0,
        "information_architecture": 0,
        "workflows": 0,
        "media": 0,
        "implementation": 0,
        "writing": 0,
    }

    repo = manifest.get("repo", {})
    positioning = manifest.get("positioning", {})
    audiences = manifest.get("audiences", [])
    pages = manifest.get("pages", [])
    workflows = manifest.get("workflows", [])
    media = manifest.get("media", [])
    implementation = manifest.get("implementation", {})
    writing = manifest.get("writing", {})
    ux_review = manifest.get("ux_review", {})
    visual_direction = manifest.get("visual_direction", {})
    page_text = page_blobs(manifest)
    workflow_text = workflow_blobs(manifest)
    quality_blob = quality_gate_blob(manifest)
    accessibility_blob = normalize(writing.get("accessibility"))
    ui_review_blob = " ".join([quality_blob, accessibility_blob, normalize(ux_review)])

    if repo.get("name"):
        breakdown["repo"] += 2
    if repo.get("source"):
        breakdown["repo"] += 1
    if repo.get("product_type"):
        breakdown["repo"] += 3
    if isinstance(repo.get("surfaces"), list) and repo.get("surfaces"):
        breakdown["repo"] += 2
    if positioning.get("promise"):
        breakdown["repo"] += 1
    if positioning.get("proof_points"):
        breakdown["repo"] += 1

    audience_dicts = [a for a in audiences if isinstance(a, dict)]
    if len(audience_dicts) >= 2:
        breakdown["audiences"] += 6
    elif len(audience_dicts) == 1:
        breakdown["audiences"] += 3
    if audience_dicts and all(a.get("needs") for a in audience_dicts):
        breakdown["audiences"] += 5
    if audience_dicts and all(a.get("technical_level") for a in audience_dicts):
        breakdown["audiences"] += 2
    if writing.get("plain_language_for") or writing.get("glossary"):
        breakdown["audiences"] += 2

    if any(isinstance(page, dict) and page.get("kind") == "landing" for page in pages):
        breakdown["information_architecture"] += 5
    elif has_page_keyword_group(page_text, ["home", "overview"]):
        breakdown["information_architecture"] += 3
    if has_page_keyword_group(page_text, ["quickstart", "getting started"]):
        breakdown["information_architecture"] += 4
    workflow_pages = [
        page
        for page in pages
        if isinstance(page, dict) and page.get("kind") in {"workflow", "recipe", "integration"}
    ]
    if len(workflow_pages) >= 2:
        breakdown["information_architecture"] += 6
    elif len(workflow_pages) == 1:
        breakdown["information_architecture"] += 3
    if has_page_keyword_group(page_text, ["reference", "command", "manual"]) and has_page_keyword_group(
        page_text, ["faq", "troubleshooting", "recovery"]
    ):
        breakdown["information_architecture"] += 5

    workflow_dicts = [w for w in workflows if isinstance(w, dict)]
    if len(workflow_dicts) >= 3:
        breakdown["workflows"] += 6
    elif len(workflow_dicts) >= 1:
        breakdown["workflows"] += 3
    if workflow_dicts and all(w.get("summary") for w in workflow_dicts):
        breakdown["workflows"] += 4
    if workflow_dicts and all(w.get("audiences") for w in workflow_dicts):
        breakdown["workflows"] += 4
    if workflow_dicts and all(w.get("evidence") for w in workflow_dicts):
        breakdown["workflows"] += 4
    if has_page_keyword_group(workflow_text, ["install", "setup"]) and has_page_keyword_group(
        workflow_text, ["troubleshoot", "recover", "automation", "integrate", "manage"]
    ):
        breakdown["workflows"] += 2

    media_dicts = [m for m in media if isinstance(m, dict)]
    if media_dicts:
        breakdown["media"] += 3
    if any("hero" in normalize(m.get("purpose")) or "home" in normalize(m.get("purpose")) for m in media_dicts):
        breakdown["media"] += 4
    if media_dicts and all(m.get("workflow") for m in media_dicts):
        breakdown["media"] += 3
    if media_dicts and all(m.get("tool") and m.get("validation") for m in media_dicts):
        breakdown["media"] += 3
    product_type = normalize(repo.get("product_type"))
    media_blob = normalize(media_dicts)
    if "cli" in product_type and "terminal-demo" in media_blob:
        breakdown["media"] += 2
    elif ("app" in product_type or "browser" in product_type or "end-user" in product_type) and (
        "browser-screenshot" in media_blob or "screen-demo" in media_blob
    ):
        breakdown["media"] += 2

    if implementation.get("stack"):
        breakdown["implementation"] += 2
    if implementation.get("reason"):
        breakdown["implementation"] += 2
    if implementation.get("content_sources"):
        breakdown["implementation"] += 2
    if implementation.get("reference_strategy"):
        breakdown["implementation"] += 2
    if implementation.get("verification_commands") or len(manifest.get("quality_gates", [])) >= 3:
        breakdown["implementation"] += 2

    if writing.get("tone"):
        breakdown["writing"] += 3
    if writing.get("accessibility"):
        breakdown["writing"] += 3
    if writing.get("plain_language_for"):
        breakdown["writing"] += 2
    if writing.get("glossary") is True:
        breakdown["writing"] += 2

    score = sum(breakdown.values())

    if breakdown["information_architecture"] < 12:
        notes.append("information architecture is still thin")
    if breakdown["media"] < 8:
        notes.append("media strategy is underspecified")
    if breakdown["implementation"] < 6:
        notes.append("implementation and verification plan needs more detail")
    if not any(
        keyword in ui_review_blob
        for keyword in [
            "focus",
            "keyboard",
            "responsive",
            "viewport",
            "reduced motion",
            "alt text",
            "accessibility review",
            "visual review",
        ]
    ):
        notes.append("no explicit rendered UI/UX review gate recorded")
    if media_dicts and not any(
        keyword in ui_review_blob
        for keyword in [
            "reduced motion",
            "poster",
            "fallback",
            "transcript",
            "captions",
            "motion alone",
        ]
    ):
        notes.append("media plan should mention motion fallback or transcript coverage")
    if not visual_direction:
        notes.append("no explicit visual direction recorded")
    elif not all(
        visual_direction.get(key)
        for key in [
            "concept",
            "memorable_hook",
            "typography",
            "color_strategy",
            "composition",
            "motion",
        ]
    ):
        notes.append("visual direction is present but underspecified")

    return score, breakdown, notes


def evaluate_case(manifest: dict, case: dict) -> list[str]:
    failures: list[str] = []
    repo = manifest.get("repo", {})
    page_text = page_blobs(manifest)
    workflow_text = workflow_blobs(manifest)
    audience_text = audience_blobs(manifest)
    media_blob = normalize(manifest.get("media", []))
    quality_blob = quality_gate_blob(manifest)

    allowed_product_types = [item.lower() for item in case.get("allowed_product_types", [])]
    if allowed_product_types and normalize(repo.get("product_type")) not in allowed_product_types:
        failures.append("product_type does not match allowed case values")

    for group in case.get("required_audience_keyword_groups", []):
        if not has_page_keyword_group(audience_text, group):
            failures.append(f"missing audience coverage for keyword group: {group}")

    for group in case.get("required_page_keyword_groups", []):
        if not has_page_keyword_group(page_text, group):
            failures.append(f"missing page coverage for keyword group: {group}")

    for group in case.get("required_workflow_keyword_groups", []):
        if not has_page_keyword_group(workflow_text, group):
            failures.append(f"missing workflow coverage for keyword group: {group}")

    for kind in case.get("required_media_kinds", []):
        if kind.lower() not in media_blob:
            failures.append(f"missing media kind: {kind}")

    for tool in case.get("required_media_tools", []):
        if tool.lower() not in media_blob:
            failures.append(f"missing media tool: {tool}")

    for keyword in case.get("required_quality_gate_keywords", []):
        if keyword.lower() not in quality_blob:
            failures.append(f"missing quality gate keyword: {keyword}")

    return failures


def render_single_result(path: Path, score: int, breakdown: dict[str, int], shape_errors: list[str], case_failures: list[str], notes: list[str], min_score: int) -> str:
    status = "PASS" if not shape_errors and not case_failures and score >= min_score else "FAIL"
    lines = [
        f"Manifest: {path}",
        f"Status: {status}",
        f"Score: {score}/100 (required: {min_score})",
        "Breakdown:",
    ]
    for key, value in breakdown.items():
        lines.append(f"- {key}: {value}")
    if shape_errors:
        lines.append("Shape errors:")
        lines.extend(f"- {error}" for error in shape_errors)
    if case_failures:
        lines.append("Case failures:")
        lines.extend(f"- {failure}" for failure in case_failures)
    if notes:
        lines.append("Notes:")
        lines.extend(f"- {note}" for note in notes)
    return "\n".join(lines)


def evaluate_manifest(manifest_path: Path, case_path: Path | None, min_score_override: int | None = None) -> tuple[bool, str]:
    manifest = load_json(manifest_path)
    shape_errors = validate_shape(manifest)
    score, breakdown, notes = score_manifest(manifest)

    case_failures: list[str] = []
    min_score = 70
    if case_path is not None:
        case = load_json(case_path)
        case_failures = evaluate_case(manifest, case)
        min_score = int(case.get("min_score", min_score))
    if min_score_override is not None:
        min_score = min_score_override

    passed = not shape_errors and not case_failures and score >= min_score
    output = render_single_result(
        manifest_path,
        score,
        breakdown,
        shape_errors,
        case_failures,
        notes,
        min_score,
    )
    return passed, output


def evaluate_suite(suite_path: Path) -> tuple[bool, str]:
    suite = load_json(suite_path)
    cases = suite.get("cases", [])
    if not isinstance(cases, list):
        raise ValueError("suite.json must contain a 'cases' list")

    outputs: list[str] = []
    failed = False
    for item in cases:
        if not isinstance(item, dict):
            raise ValueError("each suite case must be an object")
        manifest_path = (suite_path.parent / item["manifest"]).resolve()
        case_path = (suite_path.parent / item["case"]).resolve() if item.get("case") else None
        expect_pass = bool(item.get("expect_pass", True))
        min_score_override = item.get("min_score")
        actual_pass, result = evaluate_manifest(manifest_path, case_path, min_score_override=min_score_override)
        status_line = f"Suite item: {item.get('name', manifest_path.name)}"
        outputs.append(status_line)
        outputs.append(result)
        if actual_pass != expect_pass:
            failed = True
            outputs.append(f"Expectation mismatch: expected pass={expect_pass}, got pass={actual_pass}")
        outputs.append("")
    return not failed, "\n".join(outputs).rstrip()


def main() -> int:
    parser = argparse.ArgumentParser(description="Evaluate repo guideline site manifests.")
    parser.add_argument("--manifest", type=Path, help="Path to a single site-manifest.json file")
    parser.add_argument("--case", type=Path, help="Path to a case expectation JSON file")
    parser.add_argument("--suite", type=Path, help="Path to a suite JSON file")
    parser.add_argument("--min-score", type=int, help="Override the minimum passing score")
    args = parser.parse_args()

    if bool(args.manifest) == bool(args.suite):
        parser.error("Provide exactly one of --manifest or --suite")

    try:
        if args.suite:
            passed, output = evaluate_suite(args.suite.resolve())
        else:
            passed, output = evaluate_manifest(
                args.manifest.resolve(),
                args.case.resolve() if args.case else None,
                min_score_override=args.min_score,
            )
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2

    print(output)
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
