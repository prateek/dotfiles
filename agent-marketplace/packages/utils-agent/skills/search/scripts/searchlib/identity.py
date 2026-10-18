"""Resource grouping preserves observations, including conflicting values."""

from copy import deepcopy
import json
import re
from urllib.parse import urlsplit, parse_qs, urlencode, urlunsplit, unquote
from .contracts import web_url, Invalid
from . import sources


def identity(row, version=1):
    fields, kind, source = row.get("fields", {}), row.get("kind", "page"), row["source"]
    p = urlsplit(row["url"])
    host = (p.hostname or "").lower().removeprefix("www.")
    parts = p.path.strip("/").split("/")
    q = parse_qs(p.query)
    fields = dict(fields)
    platform = sources.platform(row["url"]) if version >= 2 else source
    if version >= 2:
        source = platform or ""
    if host == "github.com" and len(parts) >= 2:
        fields.setdefault("repo", "/".join(parts[:2]))
        if len(parts) >= 5 and parts[2] == "blob":
            fields.setdefault("path", unquote("/".join(parts[4:])))
            # A branch/ref is not an immutable revision.
            fields.setdefault(
                "revision",
                parts[3] if re.fullmatch(r"[0-9a-f]{40}", parts[3]) else None,
            )
            kind = "code"
        elif len(parts) >= 4 and parts[2] in ("issues", "pull"):
            fields.setdefault("item_id", parts[3])
            kind = "issue"
            if p.fragment.startswith(("issuecomment-", "discussion_r")):
                fields.setdefault("comment_id", p.fragment)
                kind = "comment"
    if source == "reddit" and "comments" in parts:
        index = parts.index("comments")
        if len(parts) > index + 1:
            post_id = parts[index + 1]
            comment_id = parts[index + 3] if len(parts) > index + 3 else None
            return ["comment" if comment_id else "post", "reddit", post_id, comment_id]
    if source == "x" and "status" in parts and len(parts) > parts.index("status") + 1:
        return ["post", "x", parts[parts.index("status") + 1]]
    if source == "amazon":
        index = None
        if "dp" in parts:
            index = parts.index("dp") + 1
        elif "product" in parts:
            index = parts.index("product") + 1
        if index is not None and len(parts) > index:
            fields["item_id"] = parts[index]
            kind = "product" if kind != "offer" else kind
    if (
        source == "marketplace"
        and "item" in parts
        and len(parts) > parts.index("item") + 1
    ):
        fields["item_id"] = parts[parts.index("item") + 1]
        kind = "product" if kind != "offer" else kind
    if kind == "repo" and fields.get("repo") and (version == 1 or platform == "github"):
        return ["repo", host, fields["repo"].lower()]
    if (
        kind == "code"
        and fields.get("repo")
        and fields.get("path")
        and (version == 1 or platform == "github")
    ):
        return [
            "code",
            host,
            fields["repo"].lower(),
            fields["path"],
            fields.get("revision"),
        ]
    if (
        kind in ("issue", "comment")
        and fields.get("item_id")
        and (version == 1 or platform)
    ):
        return [
            kind,
            source,
            fields.get("repo"),
            str(fields["item_id"]),
            fields.get("comment_id"),
        ]
    if source == "youtube":
        native = (q.get("v") or [None])[0] or fields.get("item_id")
        if host == "youtu.be":
            native = parts[0]
        if len(parts) > 1 and parts[0] in ("shorts", "live"):
            native = parts[1]
        if native:
            return ["video", "youtube", native]
    if source == "hn" and (fields.get("item_id") or q.get("id")):
        return ["post", "hn", str((q.get("id") or [None])[0] or fields.get("item_id"))]
    if (
        kind in ("post", "video", "product", "offer")
        and fields.get("item_id")
        and (version == 1 or platform)
    ):
        key = [kind, source, str(fields["item_id"])]
        if version >= 2 and source == "amazon":
            key.insert(2, host)
        if kind in ("product", "offer"):
            key += [fields.get("variant")]
        if kind == "offer":
            key += [fields.get(k) for k in ("seller", "condition", "location")] + [
                row["observed_at"]
            ]
        return key
    # Strip only known tracking keys. Identity-bearing and unknown query parameters survive.
    pairs = [
        (k, v)
        for k, vs in q.items()
        if not k.startswith("utm_") and k not in ("gclid", "fbclid")
        for v in vs
    ]
    return [
        "page",
        urlunsplit(
            (p.scheme, p.netloc.lower(), p.path, urlencode(sorted(pairs)), p.fragment)
        ),
    ]


def normalize(rows, facet, provider, observed_at, rank_start=1, identity_version=1):
    result = []
    for rank, r in enumerate(rows, rank_start):
        if not isinstance(r, dict):
            raise Invalid("result must be an object")
        web_url(r.get("url"))
        fields = r.get("fields", {})
        if not isinstance(fields, dict):
            raise Invalid("result fields must be an object")
        kind = r.get("kind", facet["operation"].split(".")[0])
        kind = {
            "comments": "comment",
            "item": "post",
            "quota": "page",
            "tool": "page",
        }.get(kind, kind)
        if kind not in (
            "page",
            "repo",
            "code",
            "issue",
            "comment",
            "post",
            "video",
            "product",
            "offer",
            "transcript",
        ):
            raise Invalid("Unknown result kind")
        row = {
            "kind": kind,
            "source": facet["source"],
            "url": r["url"],
            "title": str(r.get("title", "")),
            "excerpt": str(r.get("excerpt", "")),
            "fields": fields,
            "observed_at": observed_at,
            "evidence_level": "candidate",
        }
        row["identity"] = identity(row, identity_version)
        row["observations"] = [
            {
                "provider": provider["id"],
                "upstream": provider["upstream"],
                "method": provider["method"],
                "facet_id": facet["id"],
                "operation": facet["operation"],
                "source": facet["source"],
                "title": row["title"],
                "rank": rank,
                "observed_at": observed_at,
                "url": row["url"],
                "fields": deepcopy(fields),
                "excerpt": row["excerpt"],
            }
        ]
        result.append(row)
    return result


def merge(rows):
    grouped = {}
    for row in rows:
        key = json.dumps(row["identity"], sort_keys=True)
        if key in grouped:
            grouped[key]["observations"].extend(deepcopy(row["observations"]))
        else:
            grouped[key] = deepcopy(row)
    return list(grouped.values())
