import argparse
import json
from pathlib import Path
import sys
from . import contracts as c, engine, io, planning, registry, diagnostics, selection


def options(parser):
    for key in sorted(c.CHOICES):
        flag = "--" + key.replace("_", "-")
        if key == "free_only":
            parser.add_argument(flag, action="store_true", default=None)
        elif key in ("limit", "total_limit", "result_limit", "max_calls", "max_opens"):
            parser.add_argument(flag, type=int)
        elif key == "timeout":
            parser.add_argument(flag, type=float)
        else:
            parser.add_argument(flag)
    parser.add_argument(
        "--capabilities", help="Host manifest from actual tool inventory"
    )
    parser.add_argument(
        "--allow-paid",
        help="Comma-separated providers already authorized with account cap/prepaid allowance",
    )
    parser.add_argument(
        "--no-defaults",
        action="store_true",
        help="Ignore saved user/repo choices for prepared callers",
    )


def parser():
    p = argparse.ArgumentParser(
        prog="agent-search",
        description="Budgeted retrieval through available native, API and host routes",
    )
    sub = p.add_subparsers(dest="command", required=True)
    for cmd in ("capabilities", "doctor"):
        a = sub.add_parser(cmd)
        options(a)
        if cmd == "doctor":
            a.add_argument("--live", action="store_true")
    a = sub.add_parser("query")
    a.add_argument("terms", nargs="?")
    options(a)
    a.add_argument("--state")
    a.add_argument("--inspect", action="store_true")
    for name in ("show-defaults", "save-defaults", "reset-defaults"):
        a.add_argument("--" + name, action="store_true")
    a.add_argument("--scope", choices=("user", "repo"), default="user")
    a = sub.add_parser("plan")
    a.add_argument("--request", required=True)
    options(a)
    a = sub.add_parser("run")
    a.add_argument("--plan")
    a.add_argument("--request")
    a.add_argument("--state")
    options(a)
    for cmd in ("continue", "assess", "report", "extend", "select", "candidates"):
        a = sub.add_parser(cmd)
        a.add_argument("--state", required=True)
        if cmd == "select":
            a.add_argument("--selection", required=True)
        if cmd == "candidates":
            a.add_argument("--offset", type=int, default=0)
            a.add_argument("--limit", type=int, default=30)
        if cmd == "continue":
            a.add_argument("--host-results", required=True)
        if cmd == "assess":
            a.add_argument("--assessment", required=True)
        if cmd == "extend":
            a.add_argument("--request", required=True)
    return p


def selections(args):
    values = {
        k: getattr(args, k) for k in c.CHOICES if getattr(args, k, None) is not None
    }
    for k in ("area", "source", "exclude_source", "require_source"):
        if k in values:
            values[k] = values[k].split(",")
    return c.choices(values)


def read_input(path):
    return (
        json.load(sys.stdin, object_pairs_hook=io.unique_pairs)
        if path == "-"
        else io.read(path)
    )


def execute(args):
    save_notices = []
    if args.command == "run" and args.plan:
        if args.request:
            raise c.Invalid("Choose --plan or --request")
        if selections(args) or args.capabilities or args.allow_paid or args.no_defaults:
            raise c.Invalid(
                "Set execution options when creating the plan; run --plan accepts only --state and --json"
            )
        return run(planning.validate_plan(read_input(args.plan)), args.state)
    if args.command in (
        "continue",
        "assess",
        "report",
        "extend",
        "select",
        "candidates",
    ):
        if args.command in ("report", "candidates"):
            s = engine.validate_state(io.read(args.state))
            if args.command == "report":
                return engine.report(s)
            c.integer(args.offset, "offset")
            c.integer(args.limit, "limit", 1)
            if args.limit > 100:
                raise c.Invalid("Candidate pages are limited to 100")
            rows = selection.candidates(s)
            return {
                "schema_version": 1,
                "run_id": s["run_id"],
                "total": len(rows),
                "offset": args.offset,
                "candidates": rows[args.offset : args.offset + args.limit],
            }
        with io.lock(args.state):
            s = engine.validate_state(io.read(args.state))
            if args.command == "extend":
                engine.extend(s, read_input(args.request))
                engine.checkpoint(s, args.state)
                return engine.drive(s, args.state)
            if args.command == "continue":
                s = engine.host_results(s, read_input(args.host_results))
                engine.checkpoint(s, args.state)
                return engine.drive(s, args.state)
            if args.command == "select":
                selection.apply(s, read_input(args.selection))
            else:
                engine.assess(s, read_input(args.assessment))
            engine.checkpoint(s, args.state)
            return engine.report(s)
    manifest = (
        io.read(args.capabilities)
        if args.capabilities
        else {"schema_version": 1, "capabilities": []}
    )
    c.host_manifest(manifest)
    paid = args.allow_paid.split(",") if args.allow_paid else []
    for provider in paid:
        registry.validate_provider(provider)
    choice = selections(args)
    if args.command in ("capabilities", "doctor") and not getattr(args, "live", False):
        rows = registry.capabilities(manifest, paid)
        if args.provider:
            registry.validate_provider(args.provider)
            rows = [r for r in rows if r["id"] == args.provider]
        return {"schema_version": 1, "providers": rows, "source_requests": 0}
    if args.command == "query":
        if args.inspect and (args.save_defaults or args.reset_defaults):
            raise c.Invalid("--inspect cannot save/reset defaults")
        if sum((args.show_defaults, args.save_defaults, args.reset_defaults)) > 1:
            raise c.Invalid("Choose one defaults operation")
        if args.show_defaults:
            return {
                "schema_version": 1,
                "scope": args.scope,
                "choices": planning.load_preferences(args.scope),
            }
        if args.reset_defaults:
            planning.save_preferences(args.scope, {}, reset=True)
            return {"schema_version": 1, "scope": args.scope, "choices": {}}
        if args.save_defaults:
            if not choice:
                raise c.Invalid("Select choices to save")
            # Resolve constraints before mutating persistent configuration.
            planning.resolve({"choices": choice}, saved=not args.no_defaults)
            save_notices = planning.save_preferences(args.scope, choice)
            if not args.terms:
                return {
                    "schema_version": 1,
                    "scope": args.scope,
                    "choices": planning.load_preferences(args.scope),
                    "notices": save_notices,
                }
        req = {
            "schema_version": 1,
            "terms": args.terms,
            "choices": choice,
            "authorized_paid": paid,
        }
    elif args.command == "doctor":
        if not args.provider:
            raise c.Invalid(
                "doctor --live requires --provider; probes are opt-in and budgeted"
            )
        p = registry.REGISTRY[registry.validate_provider(args.provider)]
        source = p["sources"][0]
        operation = next(
            (op for op in p["operations"] if op.endswith(".discover")), None
        )
        if not operation:
            raise c.Invalid("Use an explicit request for this non-discovery provider")
        req = {
            "schema_version": 1,
            "terms": "Python documentation",
            "facets": [
                {
                    "id": "canary",
                    "area": c.SOURCES[source][0],
                    "source": source,
                    "operation": operation,
                }
            ],
            "choices": {**choice, "max_calls": 1, "limit": 1},
            "authorized_paid": paid,
        }
    else:
        if not getattr(args, "request", None):
            raise c.Invalid("--request or --plan required")
        req = c.request(read_input(args.request))
        if any(
            k in req.get("choices", {}) and req["choices"][k] != v
            for k, v in choice.items()
        ):
            raise c.Invalid(
                "Request and command-line choices conflict at the explicit level"
            )
        req["choices"] = {**req.get("choices", {}), **choice}
        if paid:
            req["authorized_paid"] = paid
    plan = planning.plan(req, manifest, saved=not args.no_defaults)
    if args.command == "plan" or getattr(args, "inspect", False):
        return plan
    result = run(plan, getattr(args, "state", None))
    result["notices"] = save_notices + result["notices"]
    return result


def run(plan, state_path):
    if diagnostics.redact(plan) != plan:
        raise c.Invalid(
            "Request contains credential-like data; remove it before searching"
        )
    s = engine.new_state(plan)
    state_path = state_path or diagnostics.default_path(s["run_id"])
    with io.lock(state_path):
        if Path(state_path).exists():
            raise c.Invalid("State already exists; use continue/report or a new path")
        engine.checkpoint(s, state_path)
        return engine.drive(s, state_path)


def main(argv=None):
    argv = list(sys.argv[1:] if argv is None else argv)
    argv = [a for a in argv if a != "--json"]
    try:
        seen = {}
        for index, arg in enumerate(argv):
            flag, _, value = arg.partition("=")
            key = flag.removeprefix("--").replace("-", "_")
            if flag.startswith("--") and key in c.CHOICES:
                if "=" not in arg:
                    if key == "free_only":
                        value = True
                    elif index + 1 < len(argv):
                        value = argv[index + 1]
                    else:
                        value = None
                if key in seen and seen[key] != value:
                    raise c.Invalid(f"Conflicting explicit choice: {flag}")
                seen[key] = value
        value = execute(parser().parse_args(argv))
        print(json.dumps(value, indent=2, allow_nan=False))
        return 0
    except (c.Invalid, OSError, ValueError) as exc:
        print(json.dumps({"schema_version": 1, "error": str(exc)}), file=sys.stderr)
        return 2
