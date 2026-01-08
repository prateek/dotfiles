#!/usr/bin/env python3
from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import re
import shlex
import subprocess
import sys
import textwrap
import urllib.parse
import urllib.request
from dataclasses import dataclass, replace
from html.parser import HTMLParser
from pathlib import Path
from typing import Any, Iterable


class GenerateError(RuntimeError):
    pass


def _eprint(*args: object) -> None:
    print(*args, file=sys.stderr)


def _shutil_which(cmd: str) -> str | None:
    # Tiny shim (keeps script portable and dependency-free).
    paths = os.environ.get("PATH", "").split(os.pathsep)
    for p in paths:
        candidate = Path(p) / cmd
        if candidate.is_file() and os.access(candidate, os.X_OK):
            return str(candidate)
    return None


def _require_cmd(cmd: str) -> None:
    if not _shutil_which(cmd):
        raise GenerateError(f"missing required command: {cmd}")


def _run(
    cmd: list[str],
    *,
    cwd: Path | None = None,
    capture: bool = False,
    check: bool = True,
    input_text: str | None = None,
) -> subprocess.CompletedProcess[str]:
    try:
        return subprocess.run(
            cmd,
            cwd=str(cwd) if cwd else None,
            check=check,
            text=True,
            input=input_text,
            stdout=subprocess.PIPE if capture else None,
            stderr=subprocess.PIPE if capture else None,
        )
    except subprocess.CalledProcessError as exc:
        stderr = (exc.stderr or "").strip()
        stdout = (exc.stdout or "").strip()
        details = "\n".join([s for s in [stderr, stdout] if s])
        if details:
            raise GenerateError(f"command failed: {shlex.join(cmd)}\n{details}") from exc
        raise GenerateError(f"command failed: {shlex.join(cmd)}") from exc


def _now_iso() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat()


def _normalize_base_url(url: str) -> str:
    url = url.strip()
    if not url:
        raise GenerateError("empty url")
    if not re.match(r"^https?://", url):
        url = "https://" + url
    parsed = urllib.parse.urlsplit(url)
    if parsed.scheme not in ("http", "https") or not parsed.netloc:
        raise GenerateError(f"unsupported url: {url}")
    # Prefer a trailing slash for base URL joins.
    path = parsed.path or "/"
    if not path.endswith("/"):
        path += "/"
    return urllib.parse.urlunsplit((parsed.scheme, parsed.netloc, path, "", ""))


def _origin(url: str) -> str:
    p = urllib.parse.urlsplit(url)
    return urllib.parse.urlunsplit((p.scheme, p.netloc, "", "", ""))


def _slug_for_url(url: str) -> str:
    p = urllib.parse.urlsplit(url)
    host = p.netloc.lower()
    path = (p.path or "/").strip("/")
    if not path:
        slug = host
    else:
        safe = re.sub(r"[^a-zA-Z0-9]+", "-", path).strip("-").lower()
        slug = f"{host}-{safe}"
    return slug[:80]


def _url_without_query_fragment(url: str) -> str:
    url, _frag = urllib.parse.urldefrag(url)
    p = urllib.parse.urlsplit(url)
    return urllib.parse.urlunsplit((p.scheme, p.netloc, p.path, "", ""))


@dataclass(frozen=True)
class FetchResult:
    url: str
    status: int
    content_type: str | None
    data: bytes


def _fetch(url: str, *, timeout_s: int = 30, max_bytes: int = 2_000_000) -> FetchResult:
    req = urllib.request.Request(
        url,
        headers={
            "User-Agent": "llms-txt-from-website/0.1",
            "Accept": "text/plain,text/markdown,text/html,*/*",
        },
        method="GET",
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout_s) as resp:
            status = int(getattr(resp, "status", 200))
            content_type = resp.headers.get("content-type")
            data = resp.read(max_bytes)
            return FetchResult(url=url, status=status, content_type=content_type, data=data)
    except urllib.error.HTTPError as exc:
        data = exc.read(max_bytes) if hasattr(exc, "read") else b""
        return FetchResult(url=url, status=int(getattr(exc, "code", 0) or 0), content_type=None, data=data)
    except Exception:
        return FetchResult(url=url, status=0, content_type=None, data=b"")


def _url_exists(url: str) -> bool:
    res = _fetch(url, max_bytes=1_000)
    return 200 <= res.status < 400


class _HtmlExtract(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.links: list[str] = []
        self._in_title = False
        self.title: str | None = None
        self.meta_description: str | None = None

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        attrs_dict = {k.lower(): (v or "") for k, v in attrs}
        if tag.lower() in ("a", "link"):
            href = attrs_dict.get("href")
            if href:
                self.links.append(href)
        if tag.lower() == "meta":
            name = (attrs_dict.get("name") or "").lower()
            prop = (attrs_dict.get("property") or "").lower()
            if name in ("description",) or prop in ("og:description",):
                content = attrs_dict.get("content")
                if content and not self.meta_description:
                    self.meta_description = content.strip()
        if tag.lower() == "title":
            self._in_title = True

    def handle_endtag(self, tag: str) -> None:
        if tag.lower() == "title":
            self._in_title = False

    def handle_data(self, data: str) -> None:
        if self._in_title:
            s = data.strip()
            if s:
                self.title = (self.title or "") + s


_GITHUB_REPO_RE = re.compile(r"https?://(?:www\.)?github\.com/(?P<owner>[^/]+)/(?P<repo>[^/#?]+)")


@dataclass(frozen=True)
class RepoRef:
    owner: str
    repo: str
    url: str


def _extract_github_repos_from_text(text: str) -> list[RepoRef]:
    repos: dict[tuple[str, str], int] = {}
    for m in _GITHUB_REPO_RE.finditer(text):
        owner = m.group("owner")
        repo = m.group("repo")
        repo = repo.removesuffix(".git")
        if owner and repo:
            repos[(owner, repo)] = repos.get((owner, repo), 0) + 1

    scored: list[tuple[int, RepoRef]] = []
    for (owner, repo), count in repos.items():
        score = count
        if "doc" in repo.lower() or "docs" in repo.lower() or "documentation" in repo.lower():
            score += 3
        if "website" in repo.lower() or "site" in repo.lower():
            score += 2
        scored.append((score, RepoRef(owner=owner, repo=repo, url=f"https://github.com/{owner}/{repo}")))
    scored.sort(key=lambda t: (-t[0], t[1].url))
    return [r for _s, r in scored]


def _discover_repo_from_site(base_url: str) -> RepoRef | None:
    # Try base URL and origin (some sites link repo only from root/home).
    for candidate in [base_url, _origin(base_url) + "/"]:
        res = _fetch(candidate, max_bytes=2_000_000)
        if not (200 <= res.status < 400) or not res.data:
            continue
        try:
            html = res.data.decode("utf-8", errors="replace")
        except Exception:
            continue
        parser = _HtmlExtract()
        parser.feed(html)
        all_text = "\n".join([html] + parser.links)
        repos = _extract_github_repos_from_text(all_text)
        if repos:
            return repos[0]
    return None


def _git_default_branch(repo_dir: Path) -> str:
    proc = _run(["git", "-C", str(repo_dir), "rev-parse", "--abbrev-ref", "HEAD"], capture=True)
    branch = proc.stdout.strip() or "main"
    return branch


def _clone_repo(repo: RepoRef, dest: Path) -> Path:
    _require_cmd("git")
    dest.parent.mkdir(parents=True, exist_ok=True)
    if dest.exists():
        if (dest / ".git").is_dir():
            return dest
        raise GenerateError(f"destination already exists and is not a git repo: {dest}")
    _run(["git", "clone", "--depth", "1", f"{repo.url}.git", str(dest)], capture=True)
    return dest


def _read_text(path: Path, *, max_bytes: int = 200_000) -> str:
    data = path.read_bytes()[:max_bytes]
    return data.decode("utf-8", errors="replace")


def _parse_mkdocs_docs_dir(repo_dir: Path) -> Path | None:
    for name in ("mkdocs.yml", "mkdocs.yaml"):
        cfg = repo_dir / name
        if not cfg.is_file():
            continue
        txt = _read_text(cfg)
        m = re.search(r"(?m)^[ \t]*docs_dir:[ \t]*([^\n#]+)", txt)
        if not m:
            continue
        raw = m.group(1).strip().strip('"').strip("'")
        if raw:
            p = (repo_dir / raw).resolve()
            if p.is_dir():
                return p
    return None


_SKIP_DIR_NAMES = {
    ".git",
    "node_modules",
    "dist",
    "build",
    "_build",
    ".venv",
    "venv",
    ".tox",
    ".mypy_cache",
    ".pytest_cache",
    ".ruff_cache",
    "__pycache__",
    ".next",
    ".turbo",
    ".cache",
}


def _count_docs_files(root: Path) -> int:
    count = 0
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in _SKIP_DIR_NAMES]
        for fn in filenames:
            if fn.lower().endswith((".md", ".mdx", ".rst")):
                count += 1
    return count


def _find_docs_root(repo_dir: Path, *, base_url: str) -> Path | None:
    base_path = urllib.parse.urlsplit(base_url).path.strip("/")
    base_parts = [p for p in base_path.split("/") if p]

    # If the site is hosted under a subpath (e.g. /api), strongly prefer a matching
    # repo directory when it contains docs-like files.
    if base_parts:
        rel_candidates: list[str] = []
        rel_candidates.append("/".join(base_parts))
        for k in range(1, min(3, len(base_parts)) + 1):
            rel_candidates.append("/".join(base_parts[-k:]))

        seen_rel: set[str] = set()
        for rel in rel_candidates:
            if rel in seen_rel:
                continue
            seen_rel.add(rel)
            p = (repo_dir / rel).resolve()
            if not p.is_dir():
                continue
            if _count_docs_files(p) >= 3:
                return p

    mkdocs_docs = _parse_mkdocs_docs_dir(repo_dir)
    if mkdocs_docs:
        return mkdocs_docs

    preferred = [repo_dir / p for p in ("docs", "doc", "documentation", "website", "site", "content")]
    candidates: list[Path] = [p for p in preferred if p.is_dir()]

    # Also look for nested "docs" dirs (mono-repos).
    max_depth = 4
    for dirpath, dirnames, _filenames in os.walk(repo_dir):
        rel = Path(dirpath).relative_to(repo_dir)
        if len(rel.parts) > max_depth:
            dirnames[:] = []
            continue
        dirnames[:] = [d for d in dirnames if d not in _SKIP_DIR_NAMES]
        for d in list(dirnames):
            if d.lower() in ("docs", "doc", "documentation"):
                candidates.append(Path(dirpath) / d)

    seen: set[Path] = set()
    uniq: list[Path] = []
    for c in candidates:
        c = c.resolve()
        if c in seen:
            continue
        seen.add(c)
        uniq.append(c)

    if not uniq:
        return None

    scored = [(c, _count_docs_files(c)) for c in uniq]
    scored.sort(key=lambda t: (-t[1], len(t[0].parts)))
    best, best_count = scored[0]
    if best_count == 0:
        return None
    return best


def _iter_docs_files(docs_root: Path) -> list[Path]:
    files: list[Path] = []
    for dirpath, dirnames, filenames in os.walk(docs_root):
        dirnames[:] = [d for d in dirnames if d not in _SKIP_DIR_NAMES]
        for fn in filenames:
            if fn.lower().endswith((".md", ".mdx", ".rst")):
                files.append(Path(dirpath) / fn)
    files.sort()
    return files


def _title_from_md(md_path: Path) -> str:
    try:
        txt = _read_text(md_path, max_bytes=80_000)
    except Exception:
        txt = ""
    lines = txt.splitlines()

    # Skip frontmatter blocks (common in many docs repos).
    i = 0
    if lines and lines[0].strip() in ("---", "+++"):
        delim = lines[0].strip()
        i = 1
        while i < len(lines) and lines[i].strip() != delim:
            i += 1
        if i < len(lines):
            i += 1

    for line in lines[i:]:
        m = re.match(r"^#\s+(.+?)\s*$", line)
        if m:
            return m.group(1).strip()
    stem = md_path.stem.replace("-", " ").replace("_", " ")
    return " ".join([w.capitalize() for w in stem.split()]) or md_path.name


def _title_from_url(url: str) -> str:
    res = _fetch(url, max_bytes=300_000)
    if not (200 <= res.status < 400) or not res.data:
        return _fallback_title_from_url(url)
    try:
        html = res.data.decode("utf-8", errors="replace")
    except Exception:
        return _fallback_title_from_url(url)
    parser = _HtmlExtract()
    parser.feed(html)
    if parser.title:
        return re.sub(r"\s+", " ", parser.title).strip()
    return _fallback_title_from_url(url)


def _fallback_title_from_url(url: str) -> str:
    p = urllib.parse.urlsplit(url)
    path = p.path.rstrip("/")
    if not path or path == "":
        return p.netloc
    last = path.split("/")[-1]
    last = last.replace("-", " ").replace("_", " ")
    return " ".join([w.capitalize() for w in last.split()]) or last


def _score_doc_like(name: str) -> int:
    n = name.lower()
    score = 0
    for kw, s in [
        ("get-started", 55),
        ("get started", 55),
        ("getting started", 50),
        ("quickstart", 50),
        ("installation", 40),
        ("install", 35),
        ("introduction", 35),
        ("overview", 35),
        ("your first", 40),
        ("tutorial", 30),
        ("guide", 25),
        ("how to", 25),
        ("api", 30),
        ("reference", 28),
        ("configuration", 20),
        ("cli", 18),
        ("examples", 18),
        ("faq", 15),
        ("troubleshooting", 15),
        ("changelog", 8),
        ("release", 8),
        ("migration", 8),
    ]:
        if kw in n:
            score += s
    return score


def _category_for_title_and_path(title: str, rel_path: str) -> str:
    t = (title + " " + rel_path).lower()
    if any(k in t for k in ("reference", "references", "sdk", "cli", "configuration", "config", "schema")):
        return "Reference"
    if any(k in t for k in ("tutorial", "guide", "how-to", "how to", "cookbook")):
        return "Guides"
    if any(k in t for k in ("example", "examples", "sample")):
        return "Examples"
    if any(k in t for k in ("faq", "troubleshooting", "troubleshoot", "errors")):
        return "FAQ"
    if any(k in t for k in ("changelog", "release", "migration")):
        return "Optional"
    return "Docs"


@dataclass(frozen=True)
class LinkItem:
    title: str
    url: str
    category: str
    source_path: str | None = None
    source_url: str | None = None
    site_url: str | None = None


def _md_path_to_site_url(base_url: str, docs_root: Path, md_path: Path) -> str:
    rel = md_path.relative_to(docs_root).as_posix()
    # Normalize to URL-ish paths.
    rel = re.sub(r"\.(md|mdx|rst)$", "", rel, flags=re.IGNORECASE)
    rel = rel.replace("README", "index").replace("readme", "index")
    if rel.endswith("/index"):
        rel = rel[: -len("/index")]
    if rel == "index" or rel == "":
        rel = ""
    # Keep a trailing slash (usually safe for docs).
    return urllib.parse.urljoin(base_url, rel + ("/" if rel else ""))


def _github_blob_url(repo: RepoRef, branch: str, rel_path: str) -> str:
    return f"https://github.com/{repo.owner}/{repo.repo}/blob/{branch}/{rel_path}"


def _select_top_links(items: list[LinkItem], *, max_links: int) -> list[LinkItem]:
    def depth(it: LinkItem) -> int:
        if it.source_path:
            return len([p for p in Path(it.source_path).parts if p])
        p = urllib.parse.urlsplit(it.url)
        return len([x for x in p.path.split("/") if x])

    scored: list[tuple[int, LinkItem]] = []
    for it in items:
        s = _score_doc_like(f"{it.title} {it.source_path or ''}")
        s += max(0, 10 - depth(it))  # prefer shallow
        if it.title.lower() in ("index", "home") or it.url.rstrip("/").endswith(("/docs", "/documentation")):
            s += 10
        scored.append((s, it))
    scored.sort(key=lambda t: (-t[0], t[1].category, t[1].title.lower()))

    out: list[LinkItem] = []
    seen_urls: set[str] = set()
    for _s, it in scored:
        if it.url in seen_urls:
            continue
        seen_urls.add(it.url)
        out.append(it)
        if len(out) >= max_links:
            break
    return out


def _render_llms_txt(
    title: str,
    summary: str,
    items: list[LinkItem],
    *,
    full_url_hint: str | None,
    include_source_links: bool,
) -> str:
    by_cat: dict[str, list[LinkItem]] = {}
    for it in items:
        by_cat.setdefault(it.category, []).append(it)

    # Stable section order.
    section_order = ["Docs", "Guides", "Reference", "Examples", "FAQ", "Optional"]

    def fmt_link(it: LinkItem) -> str:
        extra = ""
        if include_source_links and it.source_url and it.source_url != it.url:
            extra = f" (source: {it.source_url})"
        return f"- [{it.title}]({it.url}){extra}"

    lines: list[str] = []
    lines.append(f"# {title}")
    lines.append(f"> {summary}")
    lines.append("")
    if full_url_hint:
        lines.append(f"Full text bundle: {full_url_hint}")
        lines.append("")
    lines.append(
        "Use the links below as the canonical entry points. Prefer docs pages over blog/marketing pages."
    )
    lines.append("")
    for cat in section_order:
        section = by_cat.get(cat)
        if not section:
            continue
        lines.append(f"## {cat}")
        for it in sorted(section, key=lambda x: x.title.lower()):
            lines.append(fmt_link(it))
        lines.append("")
    return "\n".join(lines).rstrip() + "\n"


def _write_file(path: Path, data: str | bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if isinstance(data, str):
        path.write_text(data, encoding="utf-8")
    else:
        path.write_bytes(data)


def _extract_md_links(md_text: str, *, base_url: str) -> list[str]:
    # Conservative: Markdown links [x](url) and bare URLs on their own line.
    raw_links: list[str] = []
    raw_links.extend(re.findall(r"\[[^\]]+\]\(([^)\s]+)\)", md_text))
    raw_links.extend(re.findall(r"(?m)^(https?://\\S+)$", md_text))

    out: list[str] = []
    seen: set[str] = set()
    for raw in raw_links:
        raw = raw.strip()
        if not raw:
            continue
        # Resolve relative links against the llms.txt origin.
        if not re.match(r"^https?://", raw):
            raw = urllib.parse.urljoin(base_url, raw)
        u = _url_without_query_fragment(raw)
        if not u or u in seen:
            continue
        seen.add(u)
        out.append(u)
    return out


def _find_sitemaps(base_url: str) -> list[str]:
    origin = _origin(base_url)
    candidates = [
        urllib.parse.urljoin(base_url, "sitemap.xml"),
        urllib.parse.urljoin(origin + "/", "sitemap.xml"),
    ]

    # robots.txt may point at additional sitemap URLs.
    robots = _fetch(urllib.parse.urljoin(origin + "/", "robots.txt"), max_bytes=200_000)
    if 200 <= robots.status < 400 and robots.data:
        txt = robots.data.decode("utf-8", errors="replace")
        for line in txt.splitlines():
            if line.lower().startswith("sitemap:"):
                u = line.split(":", 1)[1].strip()
                if u.startswith("http"):
                    candidates.append(u)

    uniq: list[str] = []
    seen: set[str] = set()
    for u in candidates:
        u = _url_without_query_fragment(u)
        if u in seen:
            continue
        seen.add(u)
        uniq.append(u)
    return uniq


def _parse_sitemap_xml(xml_bytes: bytes) -> list[str]:
    try:
        txt = xml_bytes.decode("utf-8", errors="replace")
    except Exception:
        return []
    locs = re.findall(r"<loc>\\s*([^<\\s]+)\\s*</loc>", txt)
    out: list[str] = []
    seen: set[str] = set()
    for u in locs:
        u = _url_without_query_fragment(u)
        if not u or u in seen:
            continue
        seen.add(u)
        out.append(u)
    return out


def _crawl_internal(base_url: str, *, max_pages: int, max_depth: int) -> list[str]:
    origin = _origin(base_url)
    base_path = urllib.parse.urlsplit(base_url).path
    base_prefix = base_path if base_path.endswith("/") else base_path + "/"

    def allow(u: str) -> bool:
        p = urllib.parse.urlsplit(u)
        if p.scheme not in ("http", "https"):
            return False
        if urllib.parse.urlunsplit((p.scheme, p.netloc, "", "", "")) != origin:
            return False
        if not p.path.startswith(base_prefix):
            return False
        if re.search(r"\\.(png|jpg|jpeg|gif|svg|css|js|pdf|zip|gz|tgz)(?:$|\\?)", u, re.I):
            return False
        return True

    start = _url_without_query_fragment(base_url)
    q: list[tuple[str, int]] = [(start, 0)]
    seen: set[str] = set()
    out: list[str] = []

    while q and len(out) < max_pages:
        url, depth = q.pop(0)
        canon = _url_without_query_fragment(url).rstrip("/")
        if canon in seen:
            continue
        seen.add(canon)
        res = _fetch(url, max_bytes=600_000)
        if not (200 <= res.status < 400):
            continue
        ct = (res.content_type or "").lower()
        if "text/html" not in ct and ct:
            continue
        out.append(url)
        if depth >= max_depth:
            continue
        try:
            html = res.data.decode("utf-8", errors="replace")
        except Exception:
            continue
        parser = _HtmlExtract()
        parser.feed(html)
        for href in parser.links:
            abs_u = urllib.parse.urljoin(url, href)
            abs_u = _url_without_query_fragment(abs_u)
            if not allow(abs_u):
                continue
            q.append((abs_u, depth + 1))

    return out


def _rank_urls_for_llms(urls: list[str], base_url: str) -> list[str]:
    # Keep internal + prefer docs-ish paths.
    origin = _origin(base_url)
    base_path = urllib.parse.urlsplit(base_url).path
    base_prefix = base_path if base_path.endswith("/") else base_path + "/"

    def allow(u: str) -> bool:
        p = urllib.parse.urlsplit(u)
        if urllib.parse.urlunsplit((p.scheme, p.netloc, "", "", "")) != origin:
            return False
        return p.path.startswith(base_prefix)

    filtered = [u for u in urls if allow(u)]

    def score(u: str) -> int:
        p = urllib.parse.urlsplit(u)
        path = p.path.lower()
        s = 0
        for kw, pts in [
            ("/getting-started", 50),
            ("/quickstart", 50),
            ("/install", 40),
            ("/tutorial", 35),
            ("/guide", 30),
            ("/docs", 20),
            ("/reference", 30),
            ("/api", 30),
            ("/examples", 18),
            ("/faq", 15),
            ("/troubleshooting", 15),
            ("/changelog", 8),
        ]:
            if kw in path:
                s += pts
        depth = len([x for x in p.path.split("/") if x])
        s += max(0, 12 - depth)
        return s

    scored = sorted(filtered, key=lambda u: (-score(u), u))
    uniq: list[str] = []
    seen: set[str] = set()
    for u in scored:
        canon = u.rstrip("/")
        if canon in seen:
            continue
        seen.add(canon)
        uniq.append(u)
    return uniq


def _convert_url_to_markdown(url: str) -> str:
    url = _url_without_query_fragment(url)

    # If the URL already looks like raw text, fetch it directly.
    path = urllib.parse.urlsplit(url).path.lower()
    if path.endswith((".md", ".markdown", ".rst", ".txt")):
        res = _fetch(url, max_bytes=2_000_000)
        if 200 <= res.status < 400 and res.data:
            return res.data.decode("utf-8", errors="replace")

    # Prefer a ".md" endpoint if it exists (common llms.txt convention).
    p = urllib.parse.urlsplit(url)
    if p.path not in ("", "/"):
        md_url = urllib.parse.urlunsplit((p.scheme, p.netloc, p.path.rstrip("/") + ".md", "", ""))
        if _url_exists(md_url):
            res = _fetch(md_url, max_bytes=2_000_000)
            if 200 <= res.status < 400 and res.data:
                return res.data.decode("utf-8", errors="replace")

    # Use markitdown (via uvx) as a robust HTML -> markdown converter.
    _require_cmd("uvx")
    proc = _run(["uvx", "markitdown", url], capture=True, check=False)
    if proc.returncode == 0 and proc.stdout.strip():
        return proc.stdout

    # Last resort: raw HTML (still better than nothing).
    res = _fetch(url, max_bytes=2_000_000)
    if 200 <= res.status < 400 and res.data:
        return res.data.decode("utf-8", errors="replace")
    return ""


def _build_llms_full_from_urls(urls: list[LinkItem], out_path: Path) -> None:
    parts: list[str] = []
    for it in urls:
        md = _convert_url_to_markdown(it.url)
        if not md.strip():
            continue
        parts.append(f"# {it.title}\n\nSource: {it.url}\n\n{md.strip()}\n")
        parts.append("\n---\n")
    data = "\n".join(parts).rstrip() + "\n"
    _write_file(out_path, data)


def _repomix_files(file_paths: list[Path], out_path: Path, *, header: str | None) -> None:
    _require_cmd("repomix")
    args = [
        "repomix",
        "--stdin",
        "--style",
        "plain",
        "--quiet",
        "-o",
        str(out_path),
    ]
    if header:
        args.extend(["--header-text", header])
    stdin = "\n".join([str(p) for p in file_paths]) + "\n"
    _run(args, capture=True, check=True, input_text=stdin)


def _build_llms_full_from_repo(
    repo_dir: Path,
    repo: RepoRef,
    docs_root: Path,
    out_path: Path,
    *,
    full_scope: str,
    max_full_bytes: int,
    force_full: bool,
    curated: list[Path],
) -> dict[str, Any]:
    all_docs = _iter_docs_files(docs_root)
    chosen: list[Path]

    if full_scope == "selected":
        chosen = curated
    else:
        chosen = all_docs

    total_bytes = sum(p.stat().st_size for p in chosen if p.is_file())
    scope_used = full_scope
    if total_bytes > max_full_bytes and not force_full:
        scope_used = "selected"
        chosen = curated
        total_bytes = sum(p.stat().st_size for p in chosen if p.is_file())

    try:
        docs_root_display = docs_root.relative_to(repo_dir).as_posix()
    except Exception:
        docs_root_display = str(docs_root)

    header = textwrap.dedent(
        f"""\
        llms-full.txt
        Source repo: {repo.url}
        Docs root: {docs_root_display}
        Generated: {_now_iso()}
        """
    ).strip()
    _repomix_files([p.resolve() for p in chosen], out_path, header=header)
    return {"scope_used": scope_used, "docs_files": len(chosen), "estimated_bytes": total_bytes}


def _generate_from_repo(
    base_url: str,
    out_dir: Path,
    *,
    max_links: int,
    full_scope: str,
    max_full_bytes: int,
    force_full: bool,
    include_source_links: bool,
) -> dict[str, Any] | None:
    repo = _discover_repo_from_site(base_url)
    if not repo:
        return None

    sources_dir = out_dir / "sources"
    repo_dir = sources_dir / f"repo-{repo.owner}-{repo.repo}"
    _clone_repo(repo, repo_dir)
    branch = _git_default_branch(repo_dir)

    docs_root = _find_docs_root(repo_dir, base_url=base_url)
    if not docs_root:
        raise GenerateError(f"cloned repo but could not find docs root: {repo.url}")

    docs_files = _iter_docs_files(docs_root)
    if not docs_files:
        raise GenerateError(f"no docs files found under: {docs_root}")

    # Curate links for llms.txt.
    items: list[LinkItem] = []
    curated_paths: list[Path] = []
    for md_path in docs_files:
        rel_path = md_path.relative_to(repo_dir).as_posix()
        title = _title_from_md(md_path)
        site_url = _md_path_to_site_url(base_url, docs_root, md_path)
        blob_url = _github_blob_url(repo, branch, rel_path)
        category = _category_for_title_and_path(title, rel_path)
        # Default to GitHub source; validate site URLs only for the curated subset (keeps generation fast).
        items.append(
            LinkItem(
                title=title,
                url=blob_url,
                category=category,
                source_path=rel_path,
                source_url=blob_url,
                site_url=site_url,
            )
        )
        curated_paths.append(md_path)

    curated = _select_top_links(items, max_links=max_links)
    curated_final: list[LinkItem] = []
    for it in curated:
        if it.site_url and _url_exists(it.site_url):
            curated_final.append(replace(it, url=it.site_url))
        else:
            curated_final.append(it)

    curated_set = {it.source_path for it in curated_final if it.source_path}
    curated_files = [p for p in curated_paths if p.relative_to(repo_dir).as_posix() in curated_set]

    # Title + summary from site, else from host.
    site_title = _title_from_url(base_url)
    summary = f"Documentation extracted from {base_url}"
    llms_txt = _render_llms_txt(
        site_title,
        summary,
        curated_final,
        full_url_hint=None,
        include_source_links=include_source_links,
    )
    _write_file(out_dir / "llms.txt", llms_txt)

    full_meta = _build_llms_full_from_repo(
        repo_dir,
        repo,
        docs_root,
        out_dir / "llms-full.txt",
        full_scope=full_scope,
        max_full_bytes=max_full_bytes,
        force_full=force_full,
        curated=curated_files,
    )

    return {
        "method": "repo",
        "repo": repo.url,
        "branch": branch,
        "docs_root": str(docs_root),
        "llms_links": len(curated_final),
        "full": full_meta,
    }


def _generate_from_existing_llms(base_url: str, out_dir: Path, *, max_pages: int) -> dict[str, Any] | None:
    origin = _origin(base_url)
    candidates = []
    for root in [base_url, origin + "/"]:
        candidates.append(urllib.parse.urljoin(root, "llms.txt"))
        candidates.append(urllib.parse.urljoin(root, "llms-full.txt"))
    # Preserve order, unique.
    uniq: list[str] = []
    seen: set[str] = set()
    for u in candidates:
        if u in seen:
            continue
        seen.add(u)
        uniq.append(u)

    llms_txt_url = None
    llms_full_url = None
    llms_txt_bytes: bytes | None = None
    llms_full_bytes: bytes | None = None

    for u in uniq:
        if u.endswith("/llms.txt"):
            res = _fetch(u, max_bytes=2_000_000)
            if 200 <= res.status < 400 and res.data:
                llms_txt_url = u
                llms_txt_bytes = res.data
                break

    for u in uniq:
        if u.endswith("/llms-full.txt"):
            res = _fetch(u, max_bytes=10_000_000)
            if 200 <= res.status < 400 and res.data:
                llms_full_url = u
                llms_full_bytes = res.data
                break

    if not llms_txt_bytes:
        return None

    _write_file(out_dir / "llms.txt", llms_txt_bytes)

    llms_txt_text = llms_txt_bytes.decode("utf-8", errors="replace")
    links = _extract_md_links(llms_txt_text, base_url=llms_txt_url or base_url)

    if llms_full_bytes:
        _write_file(out_dir / "llms-full.txt", llms_full_bytes)
        return {
            "method": "existing_llms",
            "llms_txt_url": llms_txt_url,
            "llms_full_url": llms_full_url,
            "llms_links": len(links),
            "full": {"source": "downloaded"},
        }

    # Generate llms-full by converting linked pages (cap pages).
    items: list[LinkItem] = []
    for u in links[:max_pages]:
        items.append(LinkItem(title=_title_from_url(u), url=u, category="Docs"))
    _build_llms_full_from_urls(items, out_dir / "llms-full.txt")
    return {
        "method": "existing_llms",
        "llms_txt_url": llms_txt_url,
        "llms_full_url": None,
        "llms_links": len(links),
        "full": {"source": "generated_from_links", "converted_pages": len(items)},
    }


def _generate_from_sitemap_or_crawl(
    base_url: str,
    out_dir: Path,
    *,
    max_pages: int,
    max_depth: int,
    max_links: int,
) -> dict[str, Any]:
    urls: list[str] = []

    # 1) sitemap(s)
    for sm in _find_sitemaps(base_url):
        res = _fetch(sm, max_bytes=2_000_000)
        if not (200 <= res.status < 400) or not res.data:
            continue
        urls = _parse_sitemap_xml(res.data)
        if urls:
            break

    method = "sitemap" if urls else "crawl"
    if not urls:
        urls = _crawl_internal(base_url, max_pages=max_pages, max_depth=max_depth)

    ranked = _rank_urls_for_llms(urls, base_url)
    selected_urls = ranked[:max_links]

    items: list[LinkItem] = []
    for u in selected_urls:
        title = _title_from_url(u)
        category = _category_for_title_and_path(title, urllib.parse.urlsplit(u).path)
        items.append(LinkItem(title=title, url=u, category=category))

    site_title = _title_from_url(base_url)
    summary = f"Documentation extracted from {base_url}"
    llms_txt = _render_llms_txt(
        site_title,
        summary,
        items,
        full_url_hint=None,
        include_source_links=False,
    )
    _write_file(out_dir / "llms.txt", llms_txt)

    _build_llms_full_from_urls(items, out_dir / "llms-full.txt")

    return {
        "method": method,
        "discovered_urls": len(urls),
        "llms_links": len(items),
        "full": {"source": "markitdown", "converted_pages": len(items)},
    }


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description="Generate llms.txt and llms-full.txt from a website URL.")
    ap.add_argument("--url", required=True, help="Base website/docs URL (e.g. https://docs.example.com/)")
    ap.add_argument("--out", default="./llms-out", help="Output directory (default: ./llms-out)")
    ap.add_argument("--max-pages", type=int, default=60, help="Max pages to crawl/convert (default: 60)")
    ap.add_argument("--max-depth", type=int, default=3, help="Max crawl depth (default: 3)")
    ap.add_argument("--max-links", type=int, default=30, help="Max links to include in llms.txt (default: 30)")
    ap.add_argument(
        "--full-scope",
        choices=["all", "selected"],
        default="all",
        help="When using a repo, include all docs sources or only curated subset (default: all)",
    )
    ap.add_argument(
        "--max-full-bytes",
        type=int,
        default=12_000_000,
        help="Safety cap for repo-based llms-full before falling back to selected (default: 12MB)",
    )
    ap.add_argument(
        "--force-full",
        action="store_true",
        help="Ignore --max-full-bytes and always include the requested --full-scope",
    )
    ap.add_argument("--no-crawl", action="store_true", help="Do not crawl if repo discovery fails")
    ap.add_argument(
        "--include-source-links",
        action="store_true",
        help="Include an additional absolute source URL (e.g. GitHub blob) next to each link in llms.txt",
    )
    ap.add_argument("--json", action="store_true", help="Print metadata JSON to stdout")
    args = ap.parse_args(argv)

    base_url = _normalize_base_url(args.url)
    out_base = Path(args.out).expanduser().resolve()
    out_dir = out_base / _slug_for_url(base_url)
    out_dir.mkdir(parents=True, exist_ok=True)

    meta: dict[str, Any] = {
        "base_url": base_url,
        "generated_at": _now_iso(),
        "generator": "llms-txt-from-website",
    }

    try:
        existing = _generate_from_existing_llms(base_url, out_dir, max_pages=args.max_pages)
        if existing:
            meta.update(existing)
        else:
            repo_meta = _generate_from_repo(
                base_url,
                out_dir,
                max_links=args.max_links,
                full_scope=args.full_scope,
                max_full_bytes=args.max_full_bytes,
                force_full=args.force_full,
                include_source_links=args.include_source_links,
            )
            if repo_meta:
                meta.update(repo_meta)
            elif args.no_crawl:
                raise GenerateError("no existing llms.txt and no repo discovered; --no-crawl set")
            else:
                meta.update(
                    _generate_from_sitemap_or_crawl(
                        base_url,
                        out_dir,
                        max_pages=args.max_pages,
                        max_depth=args.max_depth,
                        max_links=args.max_links,
                    )
                )
    except GenerateError as exc:
        _eprint(f"error: {exc}")
        meta["error"] = str(exc)
        _write_file(out_dir / "metadata.json", json.dumps(meta, indent=2, sort_keys=True) + "\n")
        return 2

    _write_file(out_dir / "metadata.json", json.dumps(meta, indent=2, sort_keys=True) + "\n")
    if args.json:
        print(json.dumps(meta, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
