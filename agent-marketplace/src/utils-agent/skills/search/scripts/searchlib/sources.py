"""Data-only source scopes shared by planning, query translation and filtering."""

from dataclasses import dataclass
import re
import unicodedata
from urllib.parse import quote, unquote, urlsplit


class Invalid(ValueError):
    pass


SOURCES = {
    "web": ("web", None),
    "github": ("code", "github.com"),
    "hn": ("social", "news.ycombinator.com"),
    "reddit": ("social", "reddit.com"),
    "x": ("social", "x.com"),
    "youtube": ("social", "youtube.com"),
    "google-shopping": ("shopping", None),
    "amazon": ("shopping", "amazon.com"),
    "alibaba": ("shopping", "alibaba.com"),
    "marketplace": ("shopping", "facebook.com/marketplace"),
    "ubereats": ("shopping", "ubereats.com"),
    "instacart": ("shopping", "instacart.com"),
    "skills": ("code", "skills.sh"),
}
HOST_ALIASES = {"twitter.com": "x.com", "youtu.be": "youtube.com"}


def hostname(value, strict=True):
    try:
        if not strict:
            value = unquote(value, errors="strict")
        # IDNA2003 folds these into different browser hosts; require explicit A-labels.
        if any(c in "ßẞς\u200c\u200d" for c in unicodedata.normalize("NFKC", value)):
            raise Invalid(
                "Ambiguous Unicode hostname; use its explicit ASCII punycode hostname"
            )
        host = value.rstrip(".").encode("idna").decode("ascii").lower()
    except (UnicodeError, AttributeError, TypeError) as exc:
        raise Invalid("Invalid site hostname") from exc
    labels = host.split(".")
    if not host or any(c.isspace() or c in "%/\\:@?#[]" or ord(c) < 32 for c in host):
        raise Invalid("Invalid destination hostname")
    if strict and (
        len(host) > 253
        or len(labels) < 2
        or labels[-1].isdigit()
        or labels[-1] in {"localhost", "local", "internal"}
        or any(
            not re.fullmatch(r"[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?", x) for x in labels
        )
    ):
        raise Invalid(
            "Site scopes require a public DNS hostname without port or credentials"
        )
    for alias, canonical in HOST_ALIASES.items():
        if host == alias or host.endswith("." + alias):
            return host[: -len(alias)] + canonical
    return host


def path_prefix(value, strict=True):
    if (
        re.search(r"%(?![0-9a-fA-F]{2})|%2f", value, re.IGNORECASE)
        or (strict and "%25" in value.lower())
        or "\\" in value
        or any(ord(c) < 32 for c in value)
    ):
        raise Invalid("Invalid site path scope")
    try:
        path = unquote(value, errors="strict").rstrip("/")
    except UnicodeError as exc:
        raise Invalid("Invalid UTF-8 site path") from exc
    if (
        "\\" in path
        or re.search(r"%[0-9a-fA-F]{2}", path)
        or any(ord(c) < 32 or ord(c) == 127 for c in path)
    ):
        raise Invalid("Invalid encoded site path")
    if any(p in {".", ".."} for p in path.split("/")) or "//" in path:
        raise Invalid("Site path scope cannot contain dot or empty segments")
    return quote(path, safe="/:@-._~!$&'()*+,;=")


@dataclass(frozen=True)
class Scope:
    host: str | None
    path: str = ""
    name: str = ""

    @property
    def domain(self):
        return self.host + self.path if self.host else None


def resolve(reference):
    if not isinstance(reference, str):
        raise Invalid("Source must be an alias or site:hostname[/path] string")
    if reference in SOURCES:
        domain = SOURCES[reference][1]
        if domain is None:
            return Scope(None, name=reference)
    elif reference.startswith("site:"):
        domain = reference[5:]
    else:
        raise Invalid(
            f"Unknown source {reference!r}; use a known alias or site:hostname[/path]"
        )
    if (
        not domain
        or len(domain) > 2304
        or any(c.isspace() for c in domain)
        or any(c in domain for c in "?#@\\")
    ):
        raise Invalid("Invalid site scope; use hostname[/path] without URL syntax")
    host, sep, path = domain.partition("/")
    return Scope(hostname(host), path_prefix("/" + path) if sep else "")


def contains(outer, inner):
    a, b = resolve(outer), resolve(inner)
    if a.host is None or b.host is None:
        return a == b
    return (b.host == a.host or b.host.endswith("." + a.host)) and (
        not a.path or b.path == a.path or b.path.startswith(a.path + "/")
    )


def matches(url, reference, ambiguous_path_matches=False):
    scope = resolve(reference)
    try:
        p = urlsplit(url)
        if p.scheme not in {"https", "http"} or p.username or p.password:
            return False
        # p.hostname lowercases some Greek capitals into the ambiguous final sigma.
        host = hostname(p.netloc.partition(":")[0], strict=False)
    except (Invalid, ValueError, UnicodeError):
        return False
    if scope.host is None:
        return True
    if host != scope.host and not host.endswith("." + scope.host):
        return False
    if not scope.path:
        return True
    try:
        path = path_prefix(p.path, strict=False)
    except Invalid:
        return ambiguous_path_matches
    return path == scope.path or path.startswith(scope.path + "/")


def domains(facet):
    source = facet["source"]
    scope = resolve(source)
    filters = ["site:" + d for d in facet.get("filters", {}).get("domains", [])]
    if not filters:
        return [scope.domain] if scope.domain else []
    result = []
    for f in filters:
        current = resolve(f)
        if scope.host is None:
            result.append(current.domain)
            continue
        if current.host == scope.host or current.host.endswith("." + scope.host):
            host = current.host
        elif scope.host.endswith("." + current.host):
            host = scope.host
        else:
            continue
        if (
            not scope.path
            or current.path == scope.path
            or current.path.startswith(scope.path + "/")
        ):
            path = current.path
        elif not current.path or scope.path.startswith(current.path + "/"):
            path = scope.path
        else:
            continue
        result.append(host + path)
    if not result:
        raise Invalid("Source and domain filters have an empty scope intersection")
    return list(dict.fromkeys(result))


def excluded(reference, exclusions):
    return any(contains(item, reference) for item in exclusions)


def destination_allowed(url, facet, exclusions=()):
    return (
        matches(url, facet["source"])
        and (
            not facet.get("filters", {}).get("domains")
            or any(matches(url, "site:" + d) for d in facet["filters"]["domains"])
        )
        and not destination_excluded(url, facet["source"], exclusions)
    )


def destination_excluded(url, source, exclusions):
    return any(
        matches(url, item, ambiguous_path_matches=True)
        if resolve(item).host
        else item == source
        for item in exclusions
    )


def provider_supports(provider, reference):
    scope = resolve(reference)
    if provider.get("source_scope") == "public-web":
        return True
    return any(resolve(s) == scope for s in provider["sources"])


def platform(url):
    for name, (_, domain) in SOURCES.items():
        if domain and name != "amazon" and matches(url, name):
            return name
    host = (urlsplit(url).hostname or "").lower().removeprefix("www.")
    if re.fullmatch(
        r"amazon\.(com|ca|com\.mx|com\.br|co\.uk|de|fr|it|es|nl|se|pl|com\.be|co\.jp|in|com\.au|sg|ae|sa|com\.tr)",
        host,
    ):
        return "amazon"
    return None
