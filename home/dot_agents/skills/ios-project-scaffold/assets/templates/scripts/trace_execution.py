# ABOUTME: Runs a clean end-to-end __APP_NAME__ validation sequence and captures structured timing, resource, and log telemetry.
# ABOUTME: Produces a waterfall-style trace for build/test bottleneck analysis under build/traces/ after the run completes.

from __future__ import annotations

import argparse
from dataclasses import asdict, dataclass
from datetime import datetime, UTC
import json
import os
from pathlib import Path
import queue
import re
import shutil
import subprocess
import sys
import tempfile
import threading
import time


STEP_SEQUENCE: tuple[str, ...] = (
    "clean",
    "build-iphone",
    "build-ipad",
    "test-unit-iphone",
    "test-unit-ipad",
    "test-snapshot-iphone",
    "test-snapshot-ipad",
    "test-ui-iphone",
    "test-ui-ipad",
    "test-visual-iphone",
    "test-visual-ipad",
)

TIME_HEADER_PATTERN = re.compile(r"^\s*(?P<real>\d+(?:\.\d+)?) real\s+(?P<user>\d+(?:\.\d+)?) user\s+(?P<sys>\d+(?:\.\d+)?) sys$")
TIME_METRIC_PATTERN = re.compile(r"^\s*(?P<value>\d+)\s+(?P<name>[A-Za-z ].+?)\s*$")
TEST_CASE_PATTERN = re.compile(
    r"^Test Case '-\[(?P<suite>[^\s]+)\s+(?P<name>[^\]]+)\]' (?P<status>passed|failed|skipped) \((?P<seconds>\d+(?:\.\d+)?) seconds\)\.$"
)
XCBEAUTIFY_SUITE_PATTERN = re.compile(r"^Test Suite '(?P<suite>[^']+)' started at .+$")
XCBEAUTIFY_CASE_PATTERN = re.compile(
    r"^\s*(?P<symbol>✔|✖|⊘)\s+(?P<name>\S+)\s+\((?P<seconds>\d+(?:\.\d+)?) seconds\)$"
)
XCBEAUTIFY_FAILURE_PATTERN = re.compile(r"^\s*✖\s+(?P<name>\S+)(?:,|$)")
TUIST_TOTAL_PATTERN = re.compile(r"^Total time taken:\s+(?P<seconds>\d+(?:\.\d+)?)s$")
PROCESS_KEYWORDS = (
    "__APP_SLUG___worktree.py",
    "xcodebuild",
    "xcbeautify",
    "swift-frontend",
    "simctl",
    "tuist",
    "fastlane",
    "actool",
    "ibtool",
)


@dataclass
class StepResult:
    name: str
    command: list[str]
    started_at: str
    finished_at: str
    duration_seconds: float
    exit_code: int
    log_path: str
    time_metrics: dict[str, float | int]
    tuist_generate_seconds: list[float]
    test_cases: list[dict[str, object]]
    resources_before: dict[str, object]
    resources_after: dict[str, object]


def now_iso() -> str:
    return datetime.now(UTC).isoformat()


def parse_time_metrics(raw: str) -> dict[str, float | int]:
    metrics: dict[str, float | int] = {}
    for line in raw.splitlines():
        header_match = TIME_HEADER_PATTERN.match(line)
        if header_match:
            metrics["real_seconds"] = float(header_match.group("real"))
            metrics["user_seconds"] = float(header_match.group("user"))
            metrics["sys_seconds"] = float(header_match.group("sys"))
            continue
        metric_match = TIME_METRIC_PATTERN.match(line)
        if not metric_match:
            continue
        key = metric_match.group("name").strip().replace(" ", "_")
        metrics[key] = int(metric_match.group("value"))
    return metrics


def parse_test_case_durations(raw: str) -> list[dict[str, object]]:
    cases: list[dict[str, object]] = []
    current_suite: str | None = None
    for line in raw.splitlines():
        stripped = line.strip()
        suite_match = XCBEAUTIFY_SUITE_PATTERN.match(stripped)
        if suite_match:
            suite_name = suite_match.group("suite")
            if suite_name not in {"All tests"} and not suite_name.endswith(".xctest"):
                current_suite = suite_name
            continue

        match = TEST_CASE_PATTERN.match(stripped)
        if not match:
            xcbeautify_match = XCBEAUTIFY_CASE_PATTERN.match(line.rstrip())
            if xcbeautify_match and current_suite is not None:
                status = {
                    "✔": "passed",
                    "✖": "failed",
                    "⊘": "skipped",
                }[xcbeautify_match.group("symbol")]
                cases.append(
                    {
                        "suite": current_suite,
                        "name": xcbeautify_match.group("name"),
                        "status": status,
                        "duration_seconds": float(xcbeautify_match.group("seconds")),
                    }
                )
                continue
            failure_match = XCBEAUTIFY_FAILURE_PATTERN.match(line.rstrip())
            if failure_match is None or current_suite is None:
                continue
            cases.append(
                {
                    "suite": current_suite,
                    "name": failure_match.group("name"),
                    "status": "failed",
                    "duration_seconds": 0.0,
                }
            )
            continue
        cases.append(
            {
                "suite": match.group("suite"),
                "name": match.group("name"),
                "status": match.group("status"),
                "duration_seconds": float(match.group("seconds")),
            }
        )
    return cases


def parse_tuist_generate_durations(raw: str) -> list[float]:
    durations: list[float] = []
    for line in raw.splitlines():
        match = TUIST_TOTAL_PATTERN.match(line.strip())
        if match:
            durations.append(float(match.group("seconds")))
    return durations


def cpu_seconds(step: StepResult) -> float:
    return float(step.time_metrics.get("user_seconds", 0.0)) + float(step.time_metrics.get("sys_seconds", 0.0))


def wait_ratio(step: StepResult) -> float | None:
    real_seconds = float(step.time_metrics.get("real_seconds", 0.0))
    total_cpu_seconds = cpu_seconds(step)
    if real_seconds <= 0 or total_cpu_seconds <= 0:
        return None
    return real_seconds / total_cpu_seconds


def flatten_test_cases(steps: list[StepResult]) -> list[dict[str, object]]:
    cases: list[dict[str, object]] = []
    for step in steps:
        for case in step.test_cases:
            cases.append(
                {
                    "step": step.name,
                    "suite": case["suite"],
                    "name": case["name"],
                    "status": case["status"],
                    "duration_seconds": case["duration_seconds"],
                }
            )
    return cases


def count_case_statuses(cases: list[dict[str, object]]) -> dict[str, int]:
    counts = {"passed": 0, "failed": 0, "skipped": 0}
    for case in cases:
        status = case.get("status")
        if status in counts:
            counts[status] += 1
    return counts


def step_result_from_dict(payload: dict[str, object]) -> StepResult:
    return StepResult(
        name=str(payload["name"]),
        command=list(payload["command"]),
        started_at=str(payload["started_at"]),
        finished_at=str(payload["finished_at"]),
        duration_seconds=float(payload["duration_seconds"]),
        exit_code=int(payload["exit_code"]),
        log_path=str(payload["log_path"]),
        time_metrics=dict(payload.get("time_metrics", {})),
        tuist_generate_seconds=list(payload.get("tuist_generate_seconds", [])),
        test_cases=list(payload.get("test_cases", [])),
        resources_before=dict(payload.get("resources_before", {})),
        resources_after=dict(payload.get("resources_after", {})),
    )


def du_kb(path: Path) -> int:
    if not path.exists():
        return 0
    completed = subprocess.run(
        ["du", "-sk", str(path)],
        check=True,
        capture_output=True,
        text=True,
    )
    return int(completed.stdout.split()[0])


def load_doctor_state(repo_root: Path) -> dict[str, object]:
    completed = subprocess.run(
        ["python3", "scripts/__APP_SLUG___worktree.py", "doctor-state"],
        check=True,
        capture_output=True,
        text=True,
        cwd=repo_root,
    )
    return json.loads(completed.stdout)


def simulator_paths(repo_root: Path) -> dict[str, Path]:
    doctor = load_doctor_state(repo_root)
    simulators = doctor.get("simulators", {})
    paths: dict[str, Path] = {}
    for family, metadata in simulators.items():
        if not isinstance(metadata, dict):
            continue
        udid = metadata.get("udid")
        if isinstance(udid, str):
            paths[family] = Path.home() / "Library/Developer/CoreSimulator/Devices" / udid
    return paths


def resource_snapshot(repo_root: Path) -> dict[str, object]:
    sim_paths = simulator_paths(repo_root)
    snapshot: dict[str, object] = {
        "build_kb": du_kb(repo_root / "build"),
        "derived_iphone_kb": du_kb(repo_root / "build" / "derived" / "iphone"),
        "derived_ipad_kb": du_kb(repo_root / "build" / "derived" / "ipad"),
        "results_kb": du_kb(repo_root / "build" / "results"),
        "screenshots_kb": du_kb(repo_root / "build" / "screenshots"),
        "archives_kb": du_kb(repo_root / "build" / "archives"),
        "exports_kb": du_kb(repo_root / "build" / "exports"),
        "simulators": {},
    }
    for family, path in sim_paths.items():
        snapshot["simulators"][family] = {
            "path": str(path),
            "size_kb": du_kb(path),
        }
    return snapshot


def sample_processes(repo_root: Path) -> list[dict[str, object]]:
    completed = subprocess.run(
        ["ps", "-axo", "pid=,ppid=,%cpu=,rss=,etime=,command="],
        check=True,
        capture_output=True,
        text=True,
    )
    samples: list[dict[str, object]] = []
    for line in completed.stdout.splitlines():
        stripped = line.strip()
        if not stripped:
            continue
        parts = stripped.split(None, 5)
        if len(parts) != 6:
            continue
        pid, ppid, cpu, rss, etime, command = parts
        if str(repo_root) not in command and not any(keyword in command for keyword in PROCESS_KEYWORDS):
            continue
        samples.append(
            {
                "pid": int(pid),
                "ppid": int(ppid),
                "cpu_percent": float(cpu),
                "rss_kb": int(rss),
                "elapsed": etime,
                "command": command,
            }
        )
    return samples


def trace_output_directory(repo_root: Path, timestamp: str) -> Path:
    return repo_root / "build" / "traces" / timestamp


def run_step(repo_root: Path, step_name: str, output_dir: Path) -> StepResult:
    log_dir = output_dir / "logs"
    log_dir.mkdir(parents=True, exist_ok=True)
    log_path = log_dir / f"{step_name}.log"
    process_samples_path = output_dir / "process-samples.jsonl"

    command = ["/usr/bin/time", "-l", "make", step_name]
    started_at = now_iso()
    started = time.monotonic()
    resources_before = resource_snapshot(repo_root)

    process = subprocess.Popen(
        command,
        cwd=repo_root,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,
    )

    stop_event = threading.Event()
    sample_queue: queue.Queue[dict[str, object]] = queue.Queue()

    def sampler() -> None:
        while not stop_event.is_set():
            sample_queue.put(
                {
                    "timestamp": now_iso(),
                    "step": step_name,
                    "processes": sample_processes(repo_root),
                }
            )
            stop_event.wait(1.0)

    sampler_thread = threading.Thread(target=sampler, daemon=True)
    sampler_thread.start()

    with log_path.open("w") as handle:
        assert process.stdout is not None
        for line in process.stdout:
            handle.write(line)
        return_code = process.wait()

    stop_event.set()
    sampler_thread.join(timeout=2)

    with process_samples_path.open("a") as handle:
        while not sample_queue.empty():
            handle.write(json.dumps(sample_queue.get()) + "\n")

    finished_at = now_iso()
    duration_seconds = round(time.monotonic() - started, 3)
    resources_after = resource_snapshot(repo_root)
    raw_log = log_path.read_text(errors="ignore")

    return StepResult(
        name=step_name,
        command=command,
        started_at=started_at,
        finished_at=finished_at,
        duration_seconds=duration_seconds,
        exit_code=return_code,
        log_path=str(log_path),
        time_metrics=parse_time_metrics(raw_log),
        tuist_generate_seconds=parse_tuist_generate_durations(raw_log),
        test_cases=parse_test_case_durations(raw_log),
        resources_before=resources_before,
        resources_after=resources_after,
    )


def write_summary(output_dir: Path, steps: list[StepResult]) -> None:
    summary_path = output_dir / "summary.json"
    markdown_path = output_dir / "summary.md"
    total_duration = round(sum(step.duration_seconds for step in steps), 3)
    payload = {
        "generated_at": now_iso(),
        "steps": [asdict(step) for step in steps],
        "total_duration_seconds": total_duration,
    }
    summary_path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")

    all_cases = flatten_test_cases(steps)
    lines = [
        "# __APP_NAME__ Execution Trace",
        "",
        f"- Generated at: `{payload['generated_at']}`",
        f"- Total duration: `{total_duration:.3f}s`",
        "",
        "| Step | Start Offset (s) | Duration (s) | % Total | Exit | Real (s) | CPU (s) | Wait Ratio | Max RSS | Test Cases | Failed | Skipped |",
        "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |",
    ]
    offset = 0.0
    for step in steps:
        max_rss = step.time_metrics.get("maximum_resident_set_size", 0)
        step_cpu_seconds = cpu_seconds(step)
        step_wait_ratio = wait_ratio(step)
        total_percent = (step.duration_seconds / total_duration * 100) if total_duration > 0 else 0
        wait_ratio_text = f"{step_wait_ratio:.2f}" if step_wait_ratio is not None else "n/a"
        case_counts = count_case_statuses(step.test_cases)
        lines.append(
            f"| `{step.name}` | {offset:.3f} | {step.duration_seconds:.3f} | {total_percent:.1f}% | "
            f"{step.exit_code} | {step.time_metrics.get('real_seconds', 0):.2f} | {step_cpu_seconds:.2f} | "
            f"{wait_ratio_text} | {max_rss} | {len(step.test_cases)} | {case_counts['failed']} | {case_counts['skipped']} |"
        )
        offset += step.duration_seconds
    lines.append("")
    if all_cases:
        lines.append("## Slowest Test Cases")
        lines.append("")
        lines.append("| Step | Test Case | Status | Duration (s) |")
        lines.append("| --- | --- | --- | ---: |")
        for case in sorted(all_cases, key=lambda item: item["duration_seconds"], reverse=True)[:15]:
            lines.append(
                f"| `{case['step']}` | `{case['suite']} {case['name']}` | {case['status']} | {float(case['duration_seconds']):.3f} |"
            )
        lines.append("")
    lines.append("## Per-step notes")
    lines.append("")
    for step in steps:
        lines.append(f"### `{step.name}`")
        lines.append(f"- Started: `{step.started_at}`")
        lines.append(f"- Finished: `{step.finished_at}`")
        lines.append(f"- Log: `{Path(step.log_path).name}`")
        if "real_seconds" in step.time_metrics:
            lines.append(f"- `/usr/bin/time -l` real: {float(step.time_metrics['real_seconds']):.2f}s")
        lines.append(f"- CPU time: {cpu_seconds(step):.2f}s")
        step_wait_ratio = wait_ratio(step)
        if step_wait_ratio is not None:
            lines.append(f"- Wait ratio (`real / (user + sys)`): {step_wait_ratio:.2f}")
        if step.tuist_generate_seconds:
            lines.append(f"- Tuist generate durations observed in log: {', '.join(f'{value:.3f}s' for value in step.tuist_generate_seconds)}")
        if step.test_cases:
            case_counts = count_case_statuses(step.test_cases)
            lines.append(
                f"- Test results: {case_counts['passed']} passed, {case_counts['failed']} failed, {case_counts['skipped']} skipped"
            )
            slowest = sorted(step.test_cases, key=lambda item: item["duration_seconds"], reverse=True)[:5]
            lines.append("- Slowest test cases:")
            for case in slowest:
                lines.append(f"  - `{case['suite']} {case['name']}` `{case['status']}` in {case['duration_seconds']:.3f}s")
        before_build = step.resources_before.get("build_kb", 0)
        after_build = step.resources_after.get("build_kb", 0)
        lines.append(f"- `build/` size delta: {after_build - before_build} KB")
        lines.append("")
    markdown_path.write_text("\n".join(lines))


def refresh_summary(output_dir: Path) -> None:
    summary_path = output_dir / "summary.json"
    payload = json.loads(summary_path.read_text())
    steps: list[StepResult] = []
    for raw_step in payload.get("steps", []):
        step = step_result_from_dict(raw_step)
        log_path = Path(step.log_path)
        if not log_path.exists():
            fallback_log_path = output_dir / "logs" / log_path.name
            if fallback_log_path.exists():
                step.log_path = str(fallback_log_path)
                log_path = fallback_log_path
        if log_path.exists():
            raw_log = log_path.read_text(errors="ignore")
            step.time_metrics = parse_time_metrics(raw_log)
            step.tuist_generate_seconds = parse_tuist_generate_durations(raw_log)
            step.test_cases = parse_test_case_durations(raw_log)
        steps.append(step)
    write_summary(output_dir, steps)


def finalize_trace_directory(staging_dir: Path, repo_root: Path, timestamp: str) -> Path:
    final_dir = trace_output_directory(repo_root, timestamp)
    final_dir.parent.mkdir(parents=True, exist_ok=True)
    if final_dir.exists():
        shutil.rmtree(final_dir)
    shutil.copytree(staging_dir, final_dir)
    return final_dir


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", default=str(Path(__file__).resolve().parents[1]))
    parser.add_argument("--step", action="append", dest="steps", help="Override the default step sequence")
    parser.add_argument("--refresh-summary", dest="refresh_summary_path", help="Refresh summary.json and summary.md for an existing trace directory")
    args = parser.parse_args(argv)

    if args.refresh_summary_path:
        refresh_summary(Path(args.refresh_summary_path).resolve())
        print(Path(args.refresh_summary_path).resolve())
        return 0

    repo_root = Path(args.repo_root).resolve()
    timestamp = datetime.now(UTC).strftime("%Y%m%d-%H%M%S")
    steps = args.steps if args.steps else list(STEP_SEQUENCE)

    with tempfile.TemporaryDirectory(prefix=f"__APP_SLUG__-trace-{timestamp}-") as tempdir:
        staging_dir = Path(tempdir)
        results: list[StepResult] = []
        exit_code = 0
        for step_name in steps:
            result = run_step(repo_root, step_name, staging_dir)
            results.append(result)
            if result.exit_code != 0:
                exit_code = result.exit_code
                break
        write_summary(staging_dir, results)
        final_dir = finalize_trace_directory(staging_dir, repo_root, timestamp)
        print(final_dir)
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
