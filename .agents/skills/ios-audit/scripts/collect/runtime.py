"""Runtime Quality collector.

Captures:
- os_log / Logger / print usage inventory
- Retry / backoff / timeout patterns
- Cache-related call sites (URLCache, ImageCache, Nuke, NSCache)
- Network resilience patterns (NetworkMonitor, URLSession timeout config)
- Silent catch blocks / silent try? inventory
- Persistence touchpoints (UserDefaults, Keychain, FileManager writes)

Output: <output_dir>/runtime.json
"""

from __future__ import annotations

from pathlib import Path
from typing import Any

from common import RepoInfo, safe_grep, write_json

LOG_PATTERNS = [
    r"\bos_log\s*\(",
    r"\bLogger\s*\(",
    r"\bos\.Logger\b",
    r"\bprint\s*\(",
    r"\bdebugPrint\s*\(",
    r"\bNSLog\s*\(",
]

RETRY_PATTERNS = [
    r"retryCount",
    r"retry(?:Task|Attempt|Version|Request)",
    r"maxRetries",
    r"exponentialBackoff|backoff",
    r"Task\.sleep",
    r"DispatchQueue\.main\.asyncAfter",
]

TIMEOUT_PATTERNS = [
    r"timeoutInterval\w*",
    r"URLSessionConfiguration\.\w+",
    r"\.timeoutIntervalForRequest",
    r"\.timeoutIntervalForResource",
]

CACHE_PATTERNS = [
    r"URLCache",
    r"NSCache",
    r"ImageCache",
    r"Nuke\.",
    r"Cache\b",
]

NETWORK_MONITOR_PATTERNS = [
    r"NWPathMonitor",
    r"NetworkMonitor",
    r"isConnected",
    r"reachability",
]

SILENT_ERROR_PATTERNS = [
    r"try\?",
    r"catch\s*\{[\s\n]*\}",                # empty catch
    r"catch\s*\{[\s\n]*//",                # catch with only comment
    r"//\s*silent",
]

PERSISTENCE_PATTERNS = [
    r"UserDefaults\.",
    r"KeychainHelper",
    r"Keychain\.",
    r"FileManager\.default",
    r"NSCoding",
    r"Codable.*\bwrite\b",
]

PLAYBACK_PATTERNS = [
    r"AVPlayer\b",
    r"AVPlayerItem\b",
    r"AVPlayerLayer\b",
    r"timeControlStatus",
    r"isPlaybackBufferEmpty",
    r"isPlaybackLikelyToKeepUp",
]


def collect(*, repo: RepoInfo, output_dir: Path) -> None:
    root = repo.root
    out: dict[str, Any] = {
        "logging": safe_grep(LOG_PATTERNS, root),
        "retry_patterns": safe_grep(RETRY_PATTERNS, root),
        "timeouts": safe_grep(TIMEOUT_PATTERNS, root),
        "cache_usage": safe_grep(CACHE_PATTERNS, root),
        "network_monitor": safe_grep(NETWORK_MONITOR_PATTERNS, root),
        "silent_errors": safe_grep(SILENT_ERROR_PATTERNS, root),
        "persistence": safe_grep(PERSISTENCE_PATTERNS, root),
        "playback_signals": safe_grep(PLAYBACK_PATTERNS, root),
    }
    out["summary"] = {
        "total_log_sites": len(out["logging"]),
        "print_sites": sum(1 for r in out["logging"] if "print" in r["pattern"]),
        "os_log_sites": sum(1 for r in out["logging"] if "os_log" in r["pattern"] or "Logger" in r["pattern"]),
        "retry_sites": len(out["retry_patterns"]),
        "timeout_sites": len(out["timeouts"]),
        "cache_sites": len(out["cache_usage"]),
        "silent_error_sites": len(out["silent_errors"]),
    }
    write_json(output_dir / "runtime.json", out)
