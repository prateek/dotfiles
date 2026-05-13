#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.14"
# dependencies = [
#   "pyyaml",
# ]
# ///
"""Execute iOS app flow audits step-by-step using ios-simulator-skill.

Captures screenshots and accessibility trees at each step, outputs structured JSON results.
"""

import argparse
import json
import os
import re
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

from workflow_matrix import normalize_device_matrix, validate_workflow_devices, workflow_lane_ids

# Canonical ios-simulator-skill location (shared ~/.agents/skills source of truth).
# Falls back to the legacy ~/.claude/skills path if the canonical one is missing.
_CANONICAL_SIM_SKILL_DIR = os.path.expanduser("~/.agents/skills/ios-simulator-skill")
_LEGACY_SIM_SKILL_DIR = os.path.expanduser(
    "~/.claude/skills/ios-simulator/ios-simulator-skill"
)
DEFAULT_SIM_SKILL_DIR = (
    _CANONICAL_SIM_SKILL_DIR
    if os.path.isdir(_CANONICAL_SIM_SKILL_DIR)
    else _LEGACY_SIM_SKILL_DIR
)


ENV_RE = re.compile(r"\$\{([A-Za-z_][A-Za-z0-9_]*)\}|\$([A-Za-z_][A-Za-z0-9_]*)")


def _expand_env(value):
    """Recursively expand ${VAR} and $VAR references. Missing vars raise KeyError.

    Expansion happens in-memory only. The expanded structure is never
    written to disk, so plaintext credentials don't land in a resolved
    YAML or results.json.
    """
    if isinstance(value, str):
        def replace(match):
            name = match.group(1) or match.group(2)
            if name not in os.environ:
                raise KeyError(f"env var ${{{name}}} is not set")
            return os.environ[name]
        return ENV_RE.sub(replace, value)
    if isinstance(value, dict):
        return {k: _expand_env(v) for k, v in value.items()}
    if isinstance(value, list):
        return [_expand_env(v) for v in value]
    return value


def load_workflows(path: str) -> dict:
    """Load workflow definitions from YAML file with in-memory env var expansion."""
    try:
        import yaml
    except ImportError:
        print(
            "PyYAML not installed. Re-run this entrypoint through uv so its script metadata is applied.",
            file=sys.stderr,
        )
        sys.exit(1)
    with open(path) as f:
        data = yaml.safe_load(f)
    return _expand_env(data)


def run_sim_script(sim_skill_dir: str, script: str, args: list[str]) -> tuple[bool, str]:
    """Run an ios-simulator-skill script and return (success, output)."""
    script_path = os.path.join(sim_skill_dir, "scripts", script)
    cmd = ["python3", script_path] + args
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
    output = result.stdout.strip()
    if result.returncode != 0:
        output = result.stderr.strip() or output
    return result.returncode == 0, output


def list_available_simulators() -> list[dict]:
    result = subprocess.run(
        ["xcrun", "simctl", "list", "devices", "available", "-j"],
        capture_output=True,
        text=True,
        timeout=30,
        check=False,
    )
    if result.returncode != 0:
        return []
    try:
        payload = json.loads(result.stdout)
    except json.JSONDecodeError:
        return []

    simulators: list[dict] = []
    for runtime, devices in (payload.get("devices") or {}).items():
        for device in devices:
            if not device.get("isAvailable", True):
                continue
            simulators.append({
                "runtime": runtime,
                "name": device.get("name"),
                "udid": device.get("udid"),
                "state": device.get("state"),
            })
    return simulators


def resolve_lane_device(lane: dict, simulators: list[dict]) -> dict:
    if lane.get("udid") or not lane.get("device"):
        return lane
    matches = [sim for sim in simulators if sim.get("name") == lane["device"]]
    if not matches:
        raise RuntimeError(f"no available simulator named '{lane['device']}'")
    match = next((sim for sim in matches if sim.get("state") == "Booted"), matches[0])
    resolved = dict(lane)
    resolved["udid"] = match.get("udid")
    resolved["resolved_runtime"] = match.get("runtime")
    return resolved


def ensure_simulator_booted(udid: str | None) -> tuple[bool, str]:
    if not udid:
        return True, "using booted simulator"

    state_result = subprocess.run(
        ["xcrun", "simctl", "list", "devices", udid],
        capture_output=True,
        text=True,
        timeout=15,
        check=False,
    )
    if "Booted" in state_result.stdout:
        return True, "already booted"

    boot_result = subprocess.run(
        ["xcrun", "simctl", "boot", udid],
        capture_output=True,
        text=True,
        timeout=30,
        check=False,
    )
    if boot_result.returncode != 0 and "Unable to boot device in current state: Booted" not in boot_result.stderr:
        return False, boot_result.stderr.strip() or boot_result.stdout.strip()

    bootstatus = subprocess.run(
        ["xcrun", "simctl", "bootstatus", udid, "-b"],
        capture_output=True,
        text=True,
        timeout=120,
        check=False,
    )
    if bootstatus.returncode != 0:
        return False, bootstatus.stderr.strip() or bootstatus.stdout.strip()
    return True, "booted"


def capture_screenshot(output_dir: str, name: str, udid: str | None = None) -> str | None:
    """Capture a simulator screenshot and return the file path."""
    filepath = os.path.join(output_dir, f"{name}.png")
    device = udid or "booted"
    result = subprocess.run(
        ["xcrun", "simctl", "io", device, "screenshot", filepath],
        capture_output=True, text=True, timeout=10,
    )
    if result.returncode == 0:
        return filepath
    return None


def capture_accessibility(sim_skill_dir: str, udid: str | None = None) -> dict:
    """Capture the current accessibility tree."""
    json_args = ["--json"]
    if udid:
        json_args = ["--udid", udid] + json_args
    ok, output = run_sim_script(sim_skill_dir, "screen_mapper.py", json_args)
    if ok:
        try:
            return json.loads(output)
        except json.JSONDecodeError:
            pass
    # Fallback: return the raw text
    verbose_args = ["--verbose"]
    if udid:
        verbose_args = ["--udid", udid] + verbose_args
    ok2, output2 = run_sim_script(sim_skill_dir, "screen_mapper.py", verbose_args)
    return {"raw": output2}


def reset_keychain(udid: str | None = None) -> tuple[bool, str]:
    """Reset the simulator keychain to clear persisted auth/session state."""
    device = udid or "booted"
    result = subprocess.run(
        ["xcrun", "simctl", "keychain", device, "reset"],
        capture_output=True,
        text=True,
        timeout=30,
        check=False,
    )
    output = result.stdout.strip() or result.stderr.strip() or "Reset keychain"
    return result.returncode == 0, output


def execute_step(
    step: dict, app_config: dict, sim_skill_dir: str,
    output_dir: str, wf_name: str, step_index: int, udid: str | None,
) -> dict:
    """Execute a single workflow step and return results."""
    action = step.get("action", "")
    description = step.get("description", "")
    step_name = step.get("name", f"step{step_index}")
    screenshot_id = f"{wf_name}_{step_name}"

    result = {
        "step_index": step_index,
        "action": action,
        "description": description,
        "name": step_name,
        "success": False,
        "output": "",
        "screenshot_path": None,
        "accessibility": None,
        "timestamp": datetime.now().isoformat(),
        "interaction_type": action,
    }

    start_time = time.time()

    if action == "tap":
        target = step.get("target", {})
        args = []
        if "text" in target:
            args = ["--find-text", target["text"], "--tap"]
        elif "id" in target:
            args = ["--find-id", target["id"], "--tap"]
        elif "type" in target:
            args = ["--find-type", target["type"], "--tap"]
        elif "coordinates" in target:
            coords = target["coordinates"]
            args = ["--long-press", f"{coords[0]},{coords[1]}", "--duration", "0.1"]
        if udid:
            args = ["--udid", udid] + args
        if "coordinates" in target:
            ok, output = run_sim_script(sim_skill_dir, "gesture.py", args)
            result["success"] = ok
            result["output"] = output
            result["interaction_type"] = "tap (coordinates)"
        elif args:
            ok, output = run_sim_script(sim_skill_dir, "navigator.py", args)
            result["success"] = ok
            result["output"] = output
            result["interaction_type"] = f"tap ({list(target.keys())[0]})"

    elif action == "type":
        value = step.get("value", "")
        keyboard_args = ["--type", value]
        if udid:
            keyboard_args = ["--udid", udid] + keyboard_args
        ok, output = run_sim_script(sim_skill_dir, "keyboard.py", keyboard_args)
        result["success"] = ok
        # Do NOT echo the typed value or the keyboard.py output into results.
        # Typed values may be passwords or tokens — treat them as opaque.
        if ok:
            result["output"] = f"Typed <redacted, {len(value)} chars>"
        else:
            # Preserve error signal but strip any echo of the value.
            result["output"] = f"type failed (len={len(value)})"
        result["interaction_type"] = "keyboard input"

    elif action == "swipe":
        direction = step.get("direction", "up")
        swipe_args = ["--swipe", direction]
        if udid:
            swipe_args = ["--udid", udid] + swipe_args
        ok, output = run_sim_script(sim_skill_dir, "gesture.py", swipe_args)
        result["success"] = ok
        result["output"] = output
        result["interaction_type"] = f"swipe {direction}"

    elif action == "scroll":
        direction = step.get("direction", "down")
        amount = str(step.get("amount", 3))
        scroll_args = ["--scroll", direction, "--scroll-amount", amount]
        if udid:
            scroll_args = ["--udid", udid] + scroll_args
        ok, output = run_sim_script(
            sim_skill_dir, "gesture.py",
            scroll_args,
        )
        result["success"] = ok
        result["output"] = output
        result["interaction_type"] = f"scroll {direction} x{amount}"

    elif action == "wait":
        duration = step.get("duration", 2)
        time.sleep(duration)
        result["success"] = True
        result["output"] = f"Waited {duration}s"
        result["interaction_type"] = f"wait {duration}s"

    elif action == "screenshot":
        result["success"] = True
        result["output"] = "Screenshot captured"
        result["interaction_type"] = "capture"

    elif action == "launch":
        bundle_id = app_config.get("bundle_id", "")
        launch_args = ["--launch", bundle_id]
        if udid:
            launch_args = ["--udid", udid] + launch_args
        ok, output = run_sim_script(
            sim_skill_dir, "app_launcher.py", launch_args,
        )
        result["success"] = ok
        result["output"] = output
        result["interaction_type"] = "app launch"

    elif action == "terminate":
        bundle_id = app_config.get("bundle_id", "")
        terminate_args = ["--terminate", bundle_id]
        if udid:
            terminate_args = ["--udid", udid] + terminate_args
        ok, output = run_sim_script(
            sim_skill_dir, "app_launcher.py", terminate_args,
        )
        result["success"] = ok
        result["output"] = output
        result["interaction_type"] = "app terminate"

    elif action == "reset_keychain":
        ok, output = reset_keychain(udid)
        result["success"] = ok
        result["output"] = output
        result["interaction_type"] = "keychain reset"

    elif action == "back":
        back_args = ["--swipe", "right"]
        if udid:
            back_args = ["--udid", udid] + back_args
        ok, output = run_sim_script(sim_skill_dir, "gesture.py", back_args)
        result["success"] = ok
        result["output"] = output
        result["interaction_type"] = "swipe back"

    else:
        result["output"] = f"Unknown action: {action}"

    result["duration_ms"] = int((time.time() - start_time) * 1000)

    # Capture screenshot after step (unless explicitly disabled)
    should_screenshot = step.get("screenshot", True)
    if should_screenshot:
        time.sleep(0.5)  # Brief settle time
        screenshot_path = capture_screenshot(output_dir, screenshot_id, udid=udid)
        result["screenshot_path"] = screenshot_path

    # Capture accessibility tree
    accessibility = capture_accessibility(sim_skill_dir, udid=udid)
    result["accessibility"] = accessibility

    return result


def run_workflow(
    workflow: dict, app_config: dict, sim_skill_dir: str, output_dir: str,
    udid: str | None, lane: dict,
) -> dict:
    """Execute all steps in a workflow and return structured results."""
    wf_name = workflow.get("name", "unknown").replace(" ", "_").lower()
    wf_output_dir = os.path.join(output_dir, wf_name)
    os.makedirs(wf_output_dir, exist_ok=True)

    wf_result = {
        "name": workflow.get("name", "Unknown"),
        "description": workflow.get("description", ""),
        "tags": workflow.get("tags", []),
        "device_lane": lane.get("id", "default"),
        "device_name": lane.get("device"),
        "device_udid": lane.get("udid"),
        "device_traits": lane.get("traits", []),
        "steps": [],
        "start_time": datetime.now().isoformat(),
        "success": True,
    }

    steps = workflow.get("steps", [])
    for i, step in enumerate(steps):
        step_result = execute_step(
            step, app_config, sim_skill_dir, wf_output_dir, wf_name, i, udid,
        )
        wf_result["steps"].append(step_result)
        if not step_result["success"] and step.get("required", True):
            print(f"  Step {i} failed: {step_result['output']}", file=sys.stderr)

    wf_result["end_time"] = datetime.now().isoformat()
    wf_result["success"] = all(s["success"] for s in wf_result["steps"])
    return wf_result


def main():
    parser = argparse.ArgumentParser(description="Run iOS app workflow tests")
    parser.add_argument("--workflows", required=True, help="Path to workflow YAML file")
    parser.add_argument("--app-bundle-id", help="Override app bundle ID from YAML")
    parser.add_argument("--output-dir", default="/tmp/workflow-audit-output",
                        help="Directory for screenshots and results")
    parser.add_argument("--sim-skill-dir", default=DEFAULT_SIM_SKILL_DIR,
                        help="Path to ios-simulator-skill directory")
    parser.add_argument("--udid", help="Specific simulator UDID to target")
    parser.add_argument("--workflow", help="Run only this workflow (by name)")
    parser.add_argument("--json", action="store_true", help="Output JSON summary")
    args = parser.parse_args()

    config = load_workflows(args.workflows)
    app_config = config.get("app", {})
    if args.app_bundle_id:
        app_config["bundle_id"] = args.app_bundle_id

    os.makedirs(args.output_dir, exist_ok=True)

    workflows = config.get("workflows", [])
    if args.workflow:
        workflows = [w for w in workflows if w.get("name") == args.workflow]
        if not workflows:
            print(f"Workflow '{args.workflow}' not found", file=sys.stderr)
            sys.exit(1)

    lanes = normalize_device_matrix(config, cli_udid=args.udid)
    validation_errors = validate_workflow_devices(workflows, lanes)
    if validation_errors:
        for error in validation_errors:
            print(error, file=sys.stderr)
        sys.exit(1)

    simulators = list_available_simulators()
    resolved_lanes = {}
    try:
        resolved_lanes = {
            lane["id"]: resolve_lane_device(lane, simulators)
            for lane in lanes
        }
    except RuntimeError as exc:
        print(str(exc), file=sys.stderr)
        sys.exit(1)

    all_results = {
        "app": app_config,
        "run_time": datetime.now().isoformat(),
        "device_matrix": list(resolved_lanes.values()),
        "workflows": [],
    }

    for wf in workflows:
        wf_name = wf.get("name", "Unknown")
        for lane_id in workflow_lane_ids(wf, lanes):
            lane = resolved_lanes[lane_id]
            ok, boot_message = ensure_simulator_booted(lane.get("udid"))
            if not ok:
                print(f"Running workflow: {wf_name} [{lane_id}]", file=sys.stderr)
                print(f"  FAIL: could not boot simulator: {boot_message}", file=sys.stderr)
                all_results["workflows"].append({
                    "name": wf_name,
                    "description": wf.get("description", ""),
                    "tags": wf.get("tags", []),
                    "device_lane": lane.get("id", "default"),
                    "device_name": lane.get("device"),
                    "device_udid": lane.get("udid"),
                    "device_traits": lane.get("traits", []),
                    "steps": [],
                    "start_time": datetime.now().isoformat(),
                    "end_time": datetime.now().isoformat(),
                    "success": False,
                    "boot_error": boot_message,
                })
                continue

            print(f"Running workflow: {wf_name} [{lane_id}]")
            wf_result = run_workflow(
                wf,
                app_config,
                args.sim_skill_dir,
                args.output_dir,
                lane.get("udid"),
                lane,
            )
            all_results["workflows"].append(wf_result)

            step_count = len(wf_result["steps"])
            passed = sum(1 for s in wf_result["steps"] if s["success"])
            status = "PASS" if wf_result["success"] else "FAIL"
            print(f"  {status}: {passed}/{step_count} steps succeeded ({boot_message})")

    # Save results
    results_path = os.path.join(args.output_dir, "results.json")
    with open(results_path, "w") as f:
        json.dump(all_results, f, indent=2, default=str)
    print(f"\nResults saved to {results_path}")

    if args.json:
        summary = {
            "total_workflows": len(all_results["workflows"]),
            "passed": sum(1 for w in all_results["workflows"] if w["success"]),
            "failed": sum(1 for w in all_results["workflows"] if not w["success"]),
            "results_path": results_path,
        }
        print(json.dumps(summary, indent=2))

    return 0 if all(w["success"] for w in all_results["workflows"]) else 1


if __name__ == "__main__":
    sys.exit(main())
