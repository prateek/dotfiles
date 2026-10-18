"""Native search and enrichment. Domain-specific query policy stays with callers."""

import json
import math
import re
import time
from urllib.parse import quote
from .web import spec
from .. import io
from ..contracts import Invalid


def cli(id, tool, operations, **kwargs):
    return spec(
        id,
        upstream="github" if tool == "gh" else "unknown",
        method="native",
        tool=tool,
        rate_group="github" if tool == "gh" else id,
        sources=["github"],
        operations=operations,
        filters=("repo", "path", "language"),
        **kwargs,
    )


SPECS = [
    cli("github-code", "gh", ("code.discover",)),
    cli("github-repos", "gh", ("repo.discover",)),
    cli("github-issues", "gh", ("issue.discover",)),
    cli(
        "github-meta",
        "gh",
        ("repo.inspect", "repo.commits", "quota.diagnose", "tool.diagnose"),
    ),
    cli("gh-skill", "gh", ("code.discover",)),
    cli("sourcegraph", "src", ("code.discover", "tool.diagnose")),
    {
        **cli("skills-cli", "npx", ("code.discover", "tool.diagnose")),
        "sources": ["skills"],
    },
    {
        **cli("openserp", "openserp", ("page.discover",)),
        "sources": ["web"],
        "filters": (),
        "upstream": "google",
    },
]


def query(p, f):
    if "native_query" in f:
        return f["native_query"]["text"]
    terms = f.get("terms", "")
    filters = f.get("filters", {})
    for key, prefix in (("repo", "repo"), ("path", "path"), ("language", "language")):
        if filters.get(key):
            terms += f" {prefix}:{filters[key]}"
    if p["id"] == "sourcegraph":
        terms += f" count:{f['limit']} select:file"
    return terms.strip()


def argv(p, f, page=1):
    id, op, q, limit = p["id"], f["operation"], query(p, f), f["limit"]
    if op == "tool.diagnose":
        return {
            "gh": ["gh", "version"],
            "src": ["src", "version"],
            "npx": ["npx", "--yes", "skills", "--help"],
        }[p["tool"]]
    if op == "quota.diagnose":
        return ["gh", "api", "rate_limit"]
    if op in ("repo.inspect", "repo.commits"):
        repo = f.get("filters", {}).get("repo")
        if not repo or not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", repo):
            raise Invalid("Expected owner/repo")
        args = ["gh", "api", f"repos/{repo}"]
        if op == "repo.commits":
            args = [
                "gh",
                "api",
                "-i",
                "--method",
                "GET",
                f"repos/{repo}/commits",
                "-f",
                "per_page=1",
            ]
            if f.get("filters", {}).get("path"):
                args += ["-f", "path=" + f["filters"]["path"]]
        return args
    if id == "gh-skill":
        return [
            "gh",
            "skill",
            "search",
            q,
            "--limit",
            str(limit),
            "--json",
            "repo,path,skillName,namespace,description,stars",
        ]
    if id == "sourcegraph":
        return ["src", "search", "-json", q]
    if id == "skills-cli":
        return ["npx", "--yes", "skills", "find", q]
    if id == "openserp":
        return [
            "openserp",
            "search",
            "google",
            q,
            "--limit",
            str(min(limit, 100)),
            "--search-timeout",
            "30",
        ]
    endpoint = {
        "github-code": "code",
        "github-repos": "repositories",
        "github-issues": "issues",
    }[id]
    return [
        "gh",
        "api",
        "--method",
        "GET",
        f"/search/{endpoint}",
        "-f",
        f"q={q}",
        "-f",
        f"per_page={min(limit, 100)}",
        "-f",
        f"page={page}",
    ]


def json_data(text):
    try:
        return json.loads(text)
    except ValueError:
        raise io.Failure("schema_error", "Expected JSON from native CLI") from None


def rows(p, f, output):
    id, op = p["id"], f["operation"]
    if op == "tool.diagnose":
        return [{"url": "https://github.com", "fields": {"diagnostic": output[:500]}}]
    if op == "quota.diagnose":
        return [
            {"url": "https://api.github.com/rate_limit", "fields": json_data(output)}
        ]
    if op in ("repo.inspect", "repo.commits"):
        fields = {"repo": f["filters"]["repo"]}
        if op == "repo.inspect":
            fields["stars"] = json_data(output).get("stargazers_count")
        else:
            normalized = output.replace("\r\n", "\n")
            headers, _, body = normalized.partition("\n\n")
            match = re.search(
                r'(?im)^link:\s*.*?[?&]page=([0-9]+)[^,\n]*;\s*rel="last"', headers
            )
            fields["commits"] = (
                int(match[1]) if match else len(json_data(body or normalized))
            )
        return [
            {
                "kind": "repo",
                "url": "https://github.com/" + fields["repo"],
                "fields": fields,
            }
        ]
    if id == "skills-cli":
        output = re.sub(r"\x1b\[[0-?]*[ -/]*[@-~]", "", output)
        found = []
        for match in re.finditer(
            r"([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)@([A-Za-z0-9_.-]+)\s+([0-9][0-9,.]*[KkMm]?)\s+installs",
            output,
        ):
            repo, name, installs = match.groups()
            multiplier = {"k": 1000, "m": 1000000}.get(installs[-1:].lower(), 1)
            count = int(float(installs.rstrip("KkMm").replace(",", "")) * multiplier)
            found.append(
                {
                    "url": f"https://skills.sh/{repo}/{name}",
                    "fields": {"repo": repo, "name": name, "installs": count},
                }
            )
        return found[: f["limit"]]
    data = json_data(output)
    if id == "sourcegraph":
        items = data.get("Results") if isinstance(data, dict) else None
    elif id == "gh-skill":
        items = data
    else:
        items = (
            data.get("results" if id == "openserp" else "items")
            if isinstance(data, dict)
            else None
        )
    if not isinstance(items, list):
        raise io.Failure("schema_error", "Missing native result list")
    result = []
    for item in items:
        if not isinstance(item, dict):
            result.append(item)
            continue
        if id == "sourcegraph":
            if item.get("__typename") == "Repository":
                continue
            repository, info = item.get("repository"), item.get("file")
            if not isinstance(repository, dict) or not isinstance(info, dict):
                result.append(None)
                continue
            name = repository.get("name", "")
            if not isinstance(name, str):
                result.append(None)
                continue
            if not name.startswith("github.com/"):
                continue
            repo = name.removeprefix("github.com/")
            commit = info.get("commit") or {}
            fields = {
                "repo": repo,
                "path": info.get("path"),
                "revision": commit.get("oid") if isinstance(commit, dict) else None,
                "content": info.get("content"),
                "matches": item.get("lineMatches", []),
            }
        elif id == "gh-skill":
            repo = item.get("repo") or item.get("repository")
            if isinstance(repo, dict):
                repo = repo.get("nameWithOwner") or repo.get("full_name")
            fields = {
                **item,
                "repo": str(repo or "")
                .removeprefix("https://github.com/")
                .removeprefix("github.com/"),
            }
        elif id == "github-code":
            fields = {
                "repo": item.get("repository", {}).get("full_name"),
                "path": item.get("path"),
                "matches": item.get("text_matches", []),
            }
        elif id == "github-repos":
            fields = {
                "repo": item.get("full_name"),
                "stars": item.get("stargazers_count"),
                "description": item.get("description"),
            }
        elif id == "github-issues":
            fields = {
                "repo": item.get("repository_url", "").removeprefix(
                    "https://api.github.com/repos/"
                ),
                "item_id": item.get("number"),
            }
        else:
            if item.get("type") != "organic":
                continue
            fields = {}
        url = item.get("html_url") or item.get("url")
        if id in ("gh-skill", "sourcegraph"):
            if not fields.get("repo") or not fields.get("path"):
                continue
            url = f"https://github.com/{fields['repo']}/blob/{fields.get('revision') or 'HEAD'}/{quote(fields['path'])}"
        kind = {
            "github-repos": "repo",
            "github-issues": "issue",
            "openserp": "page",
        }.get(id, "code")
        result.append(
            {
                "kind": kind,
                "url": url,
                "title": item.get("title") or fields.get("repo", ""),
                "excerpt": item.get("snippet") or item.get("description") or "",
                "fields": fields,
            }
        )
    return result[: f["limit"]]


def max_calls(p, f):
    return (
        math.ceil(f["limit"] / 100)
        if p["id"] in ("github-code", "github-repos", "github-issues")
        and not f.get("raw")
        else 1
    )


def execute(p, f, timeout):
    result, count, deadline = [], 0, time.monotonic() + timeout
    for page in range(1, max_calls(p, f) + 1):
        try:
            args = argv(p, f, page)
            count += 1
            output = io.command(args, max(0.01, deadline - time.monotonic()))
            if f.get("raw"):
                return {
                    "status": "success"
                    if output["rc"] == 0
                    else io.classify(output["stderr"]),
                    "results": [],
                    "raw": output,
                    "calls": count,
                }
            if output["rc"]:
                status = io.classify(output["stderr"] + output["stdout"], output["rc"])
                detail = f"{p['id']} command failed"
                if status == "rate_limited" and p.get("rate_group") == "github":
                    detail = "GitHub rate limit reached; inspect `gh api rate_limit` for reset time, or use other sources while quota recovers"
                raise io.Failure(
                    status,
                    detail,
                )
            result.extend(rows(p, f, output["stdout"]))
            if p["id"] not in ("github-code", "github-repos", "github-issues"):
                break
            data = json_data(output["stdout"])
            if len(result) >= data.get("total_count", 0) or len(data["items"]) < min(
                f["limit"], 100
            ):
                break
        except io.Failure as exc:
            return {
                "status": exc.status,
                "detail": exc.detail,
                "results": result,
                "calls": max(count, 1),
            }
    return {
        "status": "success" if result else "empty",
        "results": result[: f["limit"]],
        "calls": count,
    }
