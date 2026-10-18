"""Cooperative host jobs; the browser skill owns controllers and sessions."""

import re
from html.parser import HTMLParser
from urllib.parse import urlencode, urljoin, urlsplit, parse_qs
from .web import spec, keywords
from .. import io

SPECS = [
    spec("host-web", host="web.search", method="host", upstream="unknown"),
    spec(
        "host-fetch",
        host="web.fetch",
        method="host",
        operations=("page.inspect",),
        filters=("url",),
    ),
    spec(
        "grep-app",
        host="mcp:grep.app",
        method="host",
        sources=["github"],
        operations=("code.discover",),
        filters=("repo", "path", "language"),
    ),
    spec(
        "startpage",
        host="browser",
        method="browser",
        upstream="google",
        filters=("domains",),
    ),
    spec(
        "ddg", host="browser", method="browser", upstream="bing", filters=("domains",)
    ),
    spec(
        "native-page",
        host="browser",
        method="browser",
        operations=(
            "page.inspect",
            "offer.inspect",
            "comments.read",
            "transcript.read",
        ),
        filters=("url", "location"),
    ),
]


def work(p, f, binding):
    payload = {
        "tool": binding["tool"],
        "provider": p["id"],
        "source": f["source"],
        "query": keywords(f),
        "limit": f["limit"],
        "filters": f.get("filters", {}),
        "identity": binding.get("identity", "unknown"),
        "runtime": binding.get("runtime"),
    }
    if p["method"] == "browser":
        q = keywords(f)
        payload["url"] = {
            "startpage": "https://www.startpage.com/sp/search?"
            + urlencode({"query": q}),
            "ddg": "https://duckduckgo.com/?" + urlencode({"q": q}),
        }.get(p["id"], f.get("filters", {}).get("url"))
        payload["instruction"] = (
            "Use the browser skill. Wait for recognized results or an explicit empty/block state before returning links or HTML; stop on challenge/login. Inspect requested evidence and clean up owned resources."
        )
    return payload


class Serp(HTMLParser):
    def __init__(self, provider):
        super().__init__()
        self.provider = provider
        self.rows = []
        self.current = None
        self.text = []

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if tag == "a":
            classes = a.get("class", "") + " " + a.get("data-testid", "")
            wanted = (
                ("result__a", "result-link", "result-title-a")
                if self.provider == "ddg"
                else ("w-gl__result-title", "result-title", "result-link")
            )
            if any(x in classes for x in wanted):
                self.current = [a.get("href", ""), []]

    def handle_data(self, data):
        self.text.append(data)
        if self.current:
            self.current[1].append(data)

    def handle_endtag(self, tag):
        if tag == "a" and self.current:
            href, title = self.current
            self.current = None
            if self.provider == "ddg":
                href = urljoin("https://duckduckgo.com", href)
                href = parse_qs(urlsplit(href).query).get("uddg", [href])[0]
            if href.startswith(("https://", "http://")):
                self.rows.append({"url": href, "title": "".join(title).strip()})


def parse(provider, html):
    parser = Serp(provider)
    parser.feed(html)
    rows = [
        r
        for r in parser.rows
        if not any(
            (urlsplit(r["url"]).hostname or "") == d
            or (urlsplit(r["url"]).hostname or "").endswith("." + d)
            for d in ("duckduckgo.com", "startpage.com")
        )
    ]
    if rows:
        return {"status": "success", "results": rows}
    text = " ".join(" ".join(parser.text).lower().split())
    status = io.classify(text)
    if status in ("challenge", "auth_failed", "rate_limited"):
        return {"status": status, "results": []}
    if re.fullmatch(
        r"no (?:search )?results(?: found)?[.!]?|no results (?:found )?for .+|your search .+ did not match any documents[.!]?",
        text,
    ):
        return {"status": "empty", "results": []}
    return {
        "status": "schema_error",
        "results": [],
        "detail": "No recognized results or explicit empty state",
    }
