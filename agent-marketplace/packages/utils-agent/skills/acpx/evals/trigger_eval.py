#!/usr/bin/env python3
"""Trigger eval for the installed acpx skill.

Run each query in trigger-evals.json through `claude -p` inside the current
directory, watch the first tool call, and classify it. A run triggers when that
first call is the Skill tool selecting `utils-agent:acpx`. The process is killed
at that decision, so nothing the model chose ever executes.

This does not inject a temporary command the way skill-creator's run_eval.py
does. The skill under test must be installed, so the listing is the real one
and `utils-agent:acpx-cli` competes exactly as it does in use. Injecting a copy
next to an installed skill double-lists it, and the installed one wins.

The text and thinking the model emits before its first tool call are kept per
run: a miss whose pre-tool text says "read the file, then delegate" is the
first-tool rule, not a trigger failure, and only the transcript can tell.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import time
from collections import Counter
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

ROUTER = "utils-agent:acpx"
SIBLING = "utils-agent:acpx-cli"
SKILL_NAME = re.compile(r'"skill"\s*:\s*"([^"]*)"')


def first_tool(
    query: str, timeout: float, model: str | None, transcript: Path | None
) -> tuple[str, str | None, str]:
    """Return (label, model, pre_tool_text) for one run.

    Labels: `router`, `acpx-cli`, `skill:<name>`, a tool name such as `Bash` or
    `Agent`, `none` (the turn ended without a tool call), `timeout`, or `exit`
    (the process ended before any decision).
    """
    cmd = ["claude", "-p", query, "--output-format", "stream-json", "--verbose", "--include-partial-messages"]
    if model:
        cmd += ["--model", model]
    # Nesting claude -p inside a Claude Code session is fine for a subprocess;
    # the guard protects interactive terminals.
    env = {k: v for k, v in os.environ.items() if k != "CLAUDECODE"}
    proc = subprocess.Popen(
        cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, stdin=subprocess.DEVNULL, text=True, env=env
    )
    started = time.time()
    run_model = None
    pending_skill = False
    partial = ""
    pre_text: list[str] = []
    lines: list[str] = []
    label = None
    try:
        for line in proc.stdout:
            lines.append(line)
            if time.time() - started > timeout:
                label = "timeout"
                break
            try:
                event = json.loads(line)
            except ValueError:
                continue
            kind = event.get("type")
            if kind == "system" and event.get("subtype") == "init":
                run_model = event.get("model")
            elif kind == "stream_event":
                se = event.get("event", {})
                st = se.get("type")
                if st == "content_block_start":
                    block = se.get("content_block", {})
                    if block.get("type") == "tool_use":
                        if block.get("name") == "Skill":
                            pending_skill, partial = True, ""
                        else:
                            label = block.get("name") or "tool"
                            break
                elif st == "content_block_delta":
                    delta = se.get("delta", {})
                    if pending_skill and delta.get("type") == "input_json_delta":
                        partial += delta.get("partial_json", "")
                        match = SKILL_NAME.search(partial)
                        if match:
                            label = skill_label(match.group(1))
                            break
                    elif delta.get("type") == "text_delta":
                        pre_text.append(delta.get("text", ""))
                    elif delta.get("type") == "thinking_delta":
                        pre_text.append(delta.get("thinking", ""))
                elif st in ("content_block_stop", "message_stop"):
                    if pending_skill:
                        match = SKILL_NAME.search(partial)
                        label = skill_label(match.group(1)) if match else "skill:?"
                        break
                    if st == "message_stop":
                        label = "none"
                        break
            elif kind == "assistant":
                # Fallback when partial messages are not streamed.
                for block in event.get("message", {}).get("content", []):
                    if block.get("type") == "tool_use":
                        name = block.get("name", "")
                        label = skill_label(block.get("input", {}).get("skill", "")) if name == "Skill" else name
                        break
                if label:
                    break
            elif kind == "result":
                label = "none"
                break
    finally:
        if proc.poll() is None:
            proc.kill()
            proc.wait()
        if transcript is not None:
            transcript.write_text("".join(lines), encoding="utf-8")
    return label or "exit", run_model, "".join(pre_text).strip()


def skill_label(name: str) -> str:
    if name == ROUTER:
        return "router"
    if name == SIBLING:
        return "acpx-cli"
    return f"skill:{name}"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--eval-set", required=True, help="trigger-evals.json: [{query, should_trigger}]")
    parser.add_argument("--runs", type=int, default=3, help="runs per query (default 3)")
    parser.add_argument("--workers", type=int, default=3, help="concurrent claude -p processes (default 3)")
    parser.add_argument("--timeout", type=float, default=120, help="seconds per run (default 120)")
    parser.add_argument("--threshold", type=float, default=0.5, help="trigger rate that counts as triggered (default 0.5)")
    parser.add_argument("--model", default=None, help="claude -p --model; default is the user's configured model")
    parser.add_argument("--transcripts", default=None, help="directory that receives each run's event stream")
    parser.add_argument("--verbose", action="store_true", help="per-query table on stderr, with pre-tool text for misses")
    args = parser.parse_args()

    with open(args.eval_set, encoding="utf-8") as handle:
        eval_set = json.load(handle)
    transcripts = Path(args.transcripts) if args.transcripts else None
    if transcripts is not None:
        transcripts.mkdir(parents=True, exist_ok=True)

    labels: dict[str, list[str]] = {item["query"]: [] for item in eval_set}
    pre_texts: dict[str, list[str]] = {item["query"]: [] for item in eval_set}
    models: Counter[str] = Counter()

    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        futures = {}
        for index, item in enumerate(eval_set, start=1):
            for run in range(1, args.runs + 1):
                path = transcripts / f"{index:02d}-run{run}.jsonl" if transcripts is not None else None
                futures[pool.submit(first_tool, item["query"], args.timeout, args.model, path)] = item["query"]
        for future in as_completed(futures):
            query = futures[future]
            try:
                label, model, pre_text = future.result()
            except Exception as error:  # a crashed run is a miss, not a crash of the eval
                print(f"warning: run failed for {query[:60]!r}: {error}", file=sys.stderr)
                label, model, pre_text = "exit", None, ""
            labels[query].append(label)
            pre_texts[query].append(pre_text)
            if model:
                models[model] += 1

    results = []
    for item in eval_set:
        seen = labels[item["query"]]
        triggers = sum(1 for label in seen if label == "router")
        rate = triggers / len(seen) if seen else 0.0
        passed = rate >= args.threshold if item["should_trigger"] else rate < args.threshold
        results.append(
            {
                "query": item["query"],
                "should_trigger": item["should_trigger"],
                "trigger_rate": rate,
                "triggers": triggers,
                "runs": len(seen),
                "first_tools": seen,
                "pre_tool_text": pre_texts[item["query"]],
                "pass": passed,
            }
        )
    passed_total = sum(1 for result in results if result["pass"])
    output = {
        "skill": ROUTER,
        "models": dict(models),
        "results": results,
        "summary": {"total": len(results), "passed": passed_total, "failed": len(results) - passed_total},
    }

    if args.verbose:
        print(f"models: {dict(models) or 'unknown'}", file=sys.stderr)
        print(f"Results: {passed_total}/{len(results)} passed", file=sys.stderr)
        for result in results:
            status = "PASS" if result["pass"] else "FAIL"
            tools = ",".join(result["first_tools"])
            print(
                f"  [{status}] {result['triggers']}/{result['runs']} expected={result['should_trigger']} "
                f"[{tools}] {result['query'][:60]}",
                file=sys.stderr,
            )
            for label, text in zip(result["first_tools"], result["pre_tool_text"]):
                miss = (result["should_trigger"] and label != "router") or (not result["should_trigger"] and label == "router")
                if miss and text:
                    print(f"      {label}: {text[-220:]!r}", file=sys.stderr)
        if not any(result["triggers"] for result in results):
            print(
                f"note: {ROUTER} was never selected; check that utils-agent >= 1.3.0 is installed", file=sys.stderr
            )

    print(json.dumps(output, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
