from __future__ import annotations

from typing import Any


def normalize_device_matrix(config: dict[str, Any], cli_udid: str | None = None) -> list[dict[str, Any]]:
    simulator = config.get("simulator") or {}
    matrix = config.get("device_matrix") or []
    if not matrix:
        return [{
            "id": "default",
            "device": simulator.get("device"),
            "udid": cli_udid,
            "traits": list(simulator.get("traits") or []),
            "default": True,
        }]

    lanes: list[dict[str, Any]] = []
    for index, raw_lane in enumerate(matrix):
        lanes.append({
            "id": raw_lane.get("id") or f"lane{index + 1}",
            "device": raw_lane.get("device") or simulator.get("device"),
            "udid": raw_lane.get("udid") or (cli_udid if len(matrix) == 1 else None),
            "traits": list(raw_lane.get("traits") or []),
            "default": raw_lane.get("default", index == 0),
        })
    return lanes


def workflow_lane_ids(workflow: dict[str, Any], lanes: list[dict[str, Any]]) -> list[str]:
    requested = workflow.get("devices") or []
    known_ids = [lane["id"] for lane in lanes]
    if requested:
        return [lane_id for lane_id in requested if lane_id in known_ids]

    defaults = [lane["id"] for lane in lanes if lane.get("default")]
    return defaults or known_ids[:1]


def validate_workflow_devices(workflows: list[dict[str, Any]], lanes: list[dict[str, Any]]) -> list[str]:
    known = {lane["id"] for lane in lanes}
    errors: list[str] = []
    for workflow in workflows:
        requested = workflow.get("devices") or []
        unknown = [lane_id for lane_id in requested if lane_id not in known]
        if unknown:
            errors.append(
                f"workflow '{workflow.get('name', 'Unnamed')}' references unknown device lanes: {', '.join(unknown)}"
            )
    return errors


def summarize_device_coverage(
    *,
    lanes: list[dict[str, Any]],
    workflows: list[dict[str, Any]],
    flow_results: dict[str, Any] | None,
    adaptive_signals: list[dict[str, Any]],
) -> dict[str, Any]:
    executed: dict[str, dict[str, Any]] = {}
    workflow_results = (((flow_results or {}).get("results") or {}).get("workflows") or [])
    for workflow_result in workflow_results:
        lane_id = workflow_result.get("device_lane") or "default"
        lane_entry = executed.setdefault(lane_id, {
            "id": lane_id,
            "device": workflow_result.get("device_name"),
            "traits": list(workflow_result.get("device_traits") or []),
            "workflow_count": 0,
        })
        lane_entry["workflow_count"] += 1

    coverage_gaps: list[str] = []
    adaptive_ui_detected = bool(adaptive_signals)
    if adaptive_ui_detected and len(executed) <= 1:
        coverage_gaps.append("Adaptive layout signals were detected but only one device lane executed.")

    regular_traits = {"regular", "ipad", "pad"}
    has_regular_lane = any(
        regular_traits.intersection(lane.get("traits") or [])
        for lane in executed.values()
    )
    if adaptive_ui_detected and not has_regular_lane:
        coverage_gaps.append("Adaptive layout signals were detected but no regular-width or iPad lane executed.")

    return {
        "adaptive_ui_detected": adaptive_ui_detected,
        "executed_lanes": list(executed.values()),
        "declared_lane_ids": [lane["id"] for lane in lanes],
        "workflow_lane_assignments": [
            {
                "name": workflow.get("name", ""),
                "devices": workflow_lane_ids(workflow, lanes),
                "tags": workflow.get("tags", []),
            }
            for workflow in workflows
        ],
        "coverage_gaps": coverage_gaps,
    }
