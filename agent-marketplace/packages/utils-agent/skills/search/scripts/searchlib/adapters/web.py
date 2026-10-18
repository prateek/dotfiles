"""HTTP search adapters. Metadata lives beside the request/response translation."""

import datetime as dt
import os
from urllib.parse import urlencode, urlsplit
from .. import io
from ..contracts import SOURCES, Invalid, web_url

WEB_OPS = (
    "page.discover",
    "post.discover",
    "video.discover",
    "product.discover",
    "repo.discover",
    "issue.discover",
)
WEB_FILTERS = ("domains", "since", "until")


def spec(id, key=None, upstream="unknown", **extra):
    return {
        "id": id,
        "method": "api",
        "upstream": upstream,
        "operations": WEB_OPS,
        "sources": list(SOURCES),
        "filters": WEB_FILTERS,
        "credential": key,
        "cost": "chargeable" if key else "free",
        "retention": "standard",
        "version": 1,
        "qualification": "contract-tested; live health unverified",
        **extra,
    }


SPECS = [
    spec("serper", "SERPER_API_KEY", "google"),
    spec(
        "brave",
        "BRAVE_SEARCH_API_KEY",
        "brave",
        retention="derived-only",
        filters=("domains",),
    ),
    spec("exa", "EXA_API_KEY", "exa"),
    spec("parallel", "PARALLEL_API_KEY", filters=("domains",)),
    spec("tavily", "TAVILY_API_KEY", filters=("domains",)),
    spec("perplexity", "PERPLEXITY_API_KEY", filters=("domains",)),
    spec("kagi", "KAGI_API_KEY", filters=("domains",)),
    spec("octen", "OCTEN_API_KEY", filters=("domains",)),
    spec("searchapi", "SEARCHAPI_API_KEY", filters=()),
    spec("searxng", endpoint_env="SEARXNG_URL", filters=("domains",)),
    spec("degoog", endpoint_env="DEGOOG_URL", filters=("domains",)),
    spec(
        "hn",
        upstream="hacker-news",
        sources=["hn"],
        operations=("post.discover", "item.read"),
        filters=("since", "until", "item_id"),
    ),
]


def keywords(f):
    if "native_query" in f:
        return f["native_query"]["text"]
    q, filters = f.get("terms", ""), f.get("filters", {})
    domains = filters.get("domains", [])
    domain = SOURCES[f["source"]][1]
    if domain:
        domains = domains + [domain]
    if domains:
        q += " (" + " OR ".join("site:" + d for d in domains) + ")"
    for key, prefix in (("since", "after"), ("until", "before")):
        if key in filters:
            q += f" {prefix}:{filters[key]}"
    return q.strip()


def endpoint(env, suffix):
    url = os.environ[env].rstrip("/")
    web_url(url)
    if urlsplit(url).query or urlsplit(url).fragment:
        raise Invalid(f"{env} must be a base URL")
    return url + suffix


def request_for(p, f):
    id, limit = p["id"], min(f["limit"], 100)
    q = keywords(f)
    key = os.environ.get(p.get("credential") or "", "")
    auth = {"Authorization": "Bearer " + key} if key else {}
    if id == "serper":
        return (
            "https://google.serper.dev/search",
            {"X-API-KEY": key},
            {"q": q, "num": min(limit, 100)},
        )
    if id == "brave":
        return (
            "https://api.search.brave.com/res/v1/web/search?"
            + urlencode({"q": q, "count": min(limit, 20)}),
            {"X-Subscription-Token": key},
            None,
        )
    if id == "exa":
        body = {
            "query": f.get("terms", q),
            "type": "auto",
            "numResults": limit,
            "contents": {"highlights": True},
        }
        filters = f.get("filters", {})
        domains = filters.get("domains", []) + (
            [SOURCES[f["source"]][1]] if SOURCES[f["source"]][1] else []
        )
        if domains:
            body["includeDomains"] = domains
        for src, dest in (
            ("since", "startPublishedDate"),
            ("until", "endPublishedDate"),
        ):
            if src in filters:
                body[dest] = filters[src] + "T00:00:00Z"
        return "https://api.exa.ai/search", auth, body
    if id == "parallel":
        return (
            "https://api.parallel.ai/v1/search",
            {"x-api-key": key},
            {"objective": q, "search_queries": [q], "mode": "fast"},
        )
    if id == "tavily":
        return (
            "https://api.tavily.com/search",
            auth,
            {
                "query": q,
                "search_depth": "basic",
                "max_results": min(limit, 20),
                "include_answer": False,
            },
        )
    if id == "perplexity":
        return (
            "https://api.perplexity.ai/search",
            auth,
            {
                "query": q,
                "max_results": min(limit, 20),
                "search_context_size": "medium",
            },
        )
    if id == "octen":
        return (
            "https://api.octen.ai/search",
            {"x-api-key": key},
            {"query": q, "count": limit},
        )
    if id == "kagi":
        return (
            "https://kagi.com/api/v1/search",
            auth,
            {"query": q, "workflow": "search"},
        )
    if id == "searchapi":
        engine = {
            "youtube": "youtube",
            "amazon": "amazon_search",
            "google-shopping": "google_shopping",
        }.get(f["source"], "google")
        return (
            "https://www.searchapi.io/api/v1/search?"
            + urlencode(
                {"engine": engine, "q": q if engine == "google" else f.get("terms", q)}
            ),
            auth,
            None,
        )
    if id == "searxng":
        return (
            endpoint("SEARXNG_URL", "/search?")
            + urlencode({"q": q, "format": "json", "categories": "general"}),
            {},
            None,
        )
    if id == "degoog":
        return (
            endpoint("DEGOOG_URL", "/api/search?") + urlencode({"q": q, "type": "web"}),
            {},
            None,
        )
    if id == "hn":
        if f["operation"] == "item.read":
            item = f.get("filters", {}).get("item_id", "")
            if not str(item).isdigit():
                raise Invalid("HN item.read needs numeric item_id")
            return f"https://hacker-news.firebaseio.com/v0/item/{item}.json", {}, None
        params = {"query": f.get("terms", ""), "tags": "story", "hitsPerPage": limit}
        date_filters = []
        for name, op in (("since", ">="), ("until", "<")):
            if name in f.get("filters", {}):
                epoch = int(
                    dt.datetime.fromisoformat(f["filters"][name])
                    .replace(tzinfo=dt.timezone.utc)
                    .timestamp()
                )
                date_filters.append(f"created_at_i{op}{epoch}")
        if date_filters:
            params["numericFilters"] = ",".join(date_filters)
        return "https://hn.algolia.com/api/v1/search?" + urlencode(params), {}, None
    raise Invalid("unknown HTTP adapter")


def select(data, path):
    value = data
    for key in path.split("."):
        if not isinstance(value, dict) or key not in value:
            raise io.Failure("schema_error", f"Missing response field {path}")
        value = value[key]
    if not isinstance(value, list):
        raise io.Failure("schema_error", f"{path} is not a list")
    return value


def parse(p, f, data):
    id = p["id"]
    if not isinstance(data, dict):
        raise io.Failure("schema_error", "Expected response object")
    if data.get("error") or (data.get("errors") and id != "degoog"):
        raise io.Failure(
            io.classify(str(data.get("error") or data.get("errors"))),
            "Provider reported an error",
        )
    if id == "hn" and f["operation"] == "item.read":
        if not data.get("id"):
            raise io.Failure("schema_error", "Missing item id")
        items = [data]
    else:
        path = {
            "serper": "organic",
            "brave": "web.results",
            "kagi": "data.search",
            "octen": "data.results",
            "hn": "hits",
        }.get(id, "results")
        if id == "searchapi":
            path = {"youtube": "videos", "google-shopping": "shopping_results"}.get(
                f["source"], "organic_results"
            )
        if id == "octen" and data.get("code", 0) != 0:
            raise io.Failure("failed", "Octen error code")
        items = select(data, path)
    rows = []
    for item in items[: f["limit"]]:
        if not isinstance(item, dict):
            rows.append(item)
            continue
        fields = {
            k: item[k]
            for k in (
                "price",
                "currency",
                "seller",
                "rating",
                "reviews",
                "channel",
                "published_at",
                "views",
                "duration",
                "author",
                "score",
                "points",
                "num_comments",
                "created_at",
                "time",
                "by",
                "kids",
            )
            if k in item
        }
        if id == "hn":
            native = item.get("objectID") or item.get("id")
            fields.update(item_id=str(native), destination_url=item.get("url"))
            url = f"https://news.ycombinator.com/item?id={native}"
        else:
            url = item.get("url") or item.get("link")
            native_key = {
                "amazon": "asin",
                "youtube": "video_id",
                "google-shopping": "product_id",
            }.get(f["source"])
            native = item.get(native_key) if native_key else None
            if native:
                fields["item_id"] = native
            if "id" in item:
                fields["provider_id"] = item["id"]
        excerpt = next(
            (
                item[k]
                for k in (
                    "snippet",
                    "description",
                    "content",
                    "highlights",
                    "excerpts",
                    "highlight",
                    "text",
                )
                if item.get(k)
            ),
            "",
        )
        if isinstance(excerpt, list):
            excerpt = " ".join(str(s) for s in excerpt)
        rows.append(
            {
                "url": url,
                "title": item.get("title", ""),
                "excerpt": str(excerpt),
                "fields": fields,
            }
        )
    errors = (
        data.get("unresponsive_engines")
        or (data.get("errors") if id == "degoog" else None)
        or data.get("warnings")
    )
    return {
        "status": "partial" if errors else ("success" if rows else "empty"),
        "results": rows,
        "detail": "Some upstream engines failed" if errors else "",
    }


def execute(p, f, timeout):
    url, headers, body = request_for(p, f)
    return parse(p, f, io.http(url, timeout, headers, body))
