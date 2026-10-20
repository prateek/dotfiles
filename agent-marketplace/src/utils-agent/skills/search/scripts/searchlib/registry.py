import os
import shutil
from .adapters import web, native, host
from .contracts import Invalid, string

REGISTRY = {p["id"]: p for p in web.SPECS + native.SPECS + host.SPECS}
ENGINE_VERSION = "1.16.1"
FEATURES = [
    "site-scopes",
    "cross-area-sources",
    "source-decisions",
    "context",
    "query-language",
    "identity-v2",
]
PROBES = {
    **{
        p["id"]: {
            "source": "web",
            "area": "web",
            "operation": "page.discover",
            "terms": "Python documentation",
        }
        for p in web.SPECS + host.SPECS
        if p.get("source_scope") == "public-web" and "page.discover" in p["operations"]
    },
    "hn": {
        "source": "hn",
        "area": "social",
        "operation": "post.discover",
        "terms": "Python",
    },
    **{
        name: {
            "source": "github",
            "area": "code",
            "operation": operation,
            "terms": "python",
        }
        for name, operation in [
            ("github-code", "code.discover"),
            ("github-repos", "repo.discover"),
            ("github-issues", "issue.discover"),
            ("sourcegraph", "code.discover"),
            ("grep-app", "code.discover"),
            ("gh-skill", "code.discover"),
        ]
    },
    "skills-cli": {
        "source": "skills",
        "area": "code",
        "operation": "code.discover",
        "terms": "python",
    },
    "openserp": {
        "source": "web",
        "area": "web",
        "operation": "page.discover",
        "terms": "Python documentation",
    },
}


def capabilities(manifest, authorized=()):
    bindings = {c["id"]: c for c in manifest["capabilities"]}
    rows = []
    for p in REGISTRY.values():
        readiness, detail = "configured_unverified", ""
        binding = bindings.get(p.get("host"))
        if p.get("host") and not binding:
            readiness, detail = "requires_host", p["host"]
        elif p.get("tool") and not shutil.which(p["tool"]):
            readiness, detail = "missing_tool", p["tool"]
        elif p.get("credential") and not os.environ.get(p["credential"]):
            readiness, detail = "missing_credential", p["credential"]
        elif p.get("endpoint_env") and not os.environ.get(p["endpoint_env"]):
            readiness, detail = "missing_endpoint", p["endpoint_env"]
        cost = binding.get("cost", "unknown") if binding else p["cost"]
        if (
            readiness == "configured_unverified"
            and cost != "free"
            and p["id"] not in authorized
        ):
            readiness, detail = (
                "requires_authorization",
                "Existing paid authorization and account limit/prepaid allowance required",
            )
        rows.append(
            {
                **p,
                "source_scope": p.get("source_scope", "named"),
                "scope_filter": p.get("scope_filter", "native"),
                "probe": PROBES.get(p["id"]),
                "readiness": readiness,
                "detail": detail,
                "cost": cost,
                "host_binding": binding,
                "observation": None,
            }
        )
    return rows


def validate_provider(value):
    string(value, "provider")
    if value not in REGISTRY:
        raise Invalid(f"Unknown provider: {value}")
    return value


def execute(p, f, timeout):
    return (
        native.execute(p, f, timeout)
        if p["method"] == "native"
        else web.execute(p, f, timeout)
    )
