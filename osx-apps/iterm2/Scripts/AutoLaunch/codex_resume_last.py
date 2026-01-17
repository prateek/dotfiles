#!/usr/bin/env python3

import re
import shlex
from pathlib import Path
from typing import Optional, Sequence

import iterm2

_UUID_RE = re.compile(
    r"codex\s+resume\s+"
    r"(?P<uuid>"
    r"[0-9a-fA-F]{8}-"
    r"[0-9a-fA-F]{4}-"
    r"[0-9a-fA-F]{4}-"
    r"[0-9a-fA-F]{4}-"
    r"[0-9a-fA-F]{12}"
    r")",
    re.IGNORECASE,
)

_KNOWN_CODEX_SUBCOMMANDS = {
    "exec",
    "resume",
    # Keep this list short; it's only used to find where global flags end.
}

_ENV_ASSIGNMENT_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=.+$")


def _command_argv_index(tokens: Sequence[str]) -> Optional[int]:
    i = 0
    while i < len(tokens) and _ENV_ASSIGNMENT_RE.match(tokens[i]):
        i += 1
    if i < len(tokens) and tokens[i] == "command":
        i += 1
    return i if i < len(tokens) else None


def _looks_like_codex_invocation(command: str) -> bool:
    try:
        tokens = shlex.split(command)
    except ValueError:
        return False
    if not tokens:
        return False

    cmd_index = _command_argv_index(tokens)
    if cmd_index is None:
        return False

    cmd0 = Path(tokens[cmd_index]).name
    return cmd0 in {"codex", "yolo"}


def _extract_command_from_zhistory_line(line: str) -> Optional[str]:
    # zsh EXTENDED_HISTORY format:
    #   : <start time>:<elapsed seconds>;<command>
    # Example:
    #   : 1700000000:0;yolo exec "do things"
    if not line.startswith(": "):
        return None
    sep = line.find(";")
    if sep == -1:
        return None
    cmd = line[sep + 1 :].strip()
    return cmd or None


def _get_last_codex_invocation_from_zhistory() -> Optional[str]:
    candidates = [
        Path.home() / ".zhistory",  # this repo's zsh config
        Path.home() / ".zsh_history",  # zsh default
    ]

    lines = None
    for histfile in candidates:
        try:
            lines = histfile.read_text(errors="ignore").splitlines()
            break
        except FileNotFoundError:
            continue
    if lines is None:
        return None

    for line in reversed(lines):
        cmd = _extract_command_from_zhistory_line(line)
        if not cmd:
            continue
        if _looks_like_codex_invocation(cmd):
            return cmd
    return None


async def _get_last_codex_invocation_from_iterm(session: iterm2.Session) -> Optional[str]:
    try:
        last_command = await session.async_get_variable("lastCommand")
    except Exception:
        return None
    if not isinstance(last_command, str):
        return None
    last_command = last_command.strip()
    return last_command if _looks_like_codex_invocation(last_command) else None


async def _get_last_resume_uuid_from_selection(session: iterm2.Session) -> Optional[str]:
    try:
        selection = await session.async_get_variable("selection")
    except Exception:
        return None
    if not isinstance(selection, str) or not selection:
        return None
    match = _UUID_RE.search(selection)
    return match.group("uuid") if match else None


async def _get_last_resume_uuid_from_scrollback(
    session: iterm2.Session, *, max_lines: int = 8000
) -> Optional[str]:
    line_info = await session.async_get_line_info()
    first_line_number = line_info.overflow
    last_line_number = (
        line_info.overflow
        + line_info.scrollback_buffer_height
        + line_info.mutable_area_height
        - 1
    )
    if last_line_number < first_line_number:
        return None

    start = max(first_line_number, last_line_number - max_lines + 1)
    lines = await session.async_get_contents(start, last_line_number - start + 1)
    text = "\n".join(line.string for line in lines)
    matches = list(_UUID_RE.finditer(text))
    return matches[-1].group("uuid") if matches else None


def _build_resume_command(base_command: Optional[str], uuid: str) -> str:
    if not base_command:
        return f"codex resume {uuid}"

    try:
        tokens = shlex.split(base_command)
    except ValueError:
        return f"codex resume {uuid}"
    if not tokens:
        return f"codex resume {uuid}"

    cmd_index = _command_argv_index(tokens)
    if cmd_index is None:
        return f"codex resume {uuid}"

    subcommand_index = None
    for i in range(cmd_index + 1, len(tokens)):
        if tokens[i] in _KNOWN_CODEX_SUBCOMMANDS:
            subcommand_index = i
            break

    if subcommand_index is None:
        for i in range(cmd_index + 1, len(tokens)):
            if not tokens[i].startswith("-"):
                subcommand_index = i
                break

    if subcommand_index is None:
        subcommand_index = len(tokens)

    prefix = tokens[:subcommand_index]
    resume_tokens = prefix + ["resume", uuid]
    return " ".join(shlex.quote(tok) for tok in resume_tokens)


async def _alert(connection: iterm2.Connection, title: str, subtitle: str) -> None:
    alert = iterm2.Alert(title=title, subtitle=subtitle)
    alert.add_button("OK")
    await alert.async_run(connection)


async def _resume_in_session(
    connection: iterm2.Connection,
    app: iterm2.App,
    *,
    session_id: str,
    execute: bool,
) -> None:
    session = app.get_session_by_id(session_id)
    if not session:
        await _alert(connection, "Codex resume", "Could not find the target session.")
        return

    uuid = await _get_last_resume_uuid_from_selection(session)
    if not uuid:
        uuid = await _get_last_resume_uuid_from_scrollback(session)
    if not uuid:
        await _alert(connection, "Codex resume", "No `codex resume <uuid>` found in this session.")
        return

    base = await _get_last_codex_invocation_from_iterm(session)
    if not base:
        base = _get_last_codex_invocation_from_zhistory()

    command = _build_resume_command(base, uuid)

    # Clear the current input line (Ctrl+U) and type the resume command.
    await session.async_send_text("\x15")
    await session.async_send_text(command)
    if execute:
        await session.async_send_text("\n")


async def main(connection: iterm2.Connection) -> None:
    app = await iterm2.async_get_app(connection)

    @iterm2.RPC
    async def codex_resume_last_paste(session_id=iterm2.Reference("id")) -> None:
        await _resume_in_session(connection, app, session_id=session_id, execute=False)

    @iterm2.RPC
    async def codex_resume_last_run(session_id=iterm2.Reference("id")) -> None:
        await _resume_in_session(connection, app, session_id=session_id, execute=True)

    await codex_resume_last_paste.async_register(connection)
    await codex_resume_last_run.async_register(connection)


iterm2.run_forever(main)
