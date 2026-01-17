#!/usr/bin/env python3

import shlex
from typing import Optional

import iterm2


async def _get_session_cwd(session: iterm2.Session) -> Optional[str]:
    # iTerm2 shell integration sets `path` to the current working directory.
    for var in ("path", "pwd", "currentDirectory"):
        try:
            value = await session.async_get_variable(var)
        except Exception:
            continue
        if isinstance(value, str) and value:
            return value

    try:
        home = await session.async_get_variable("homeDirectory")
    except Exception:
        return None
    return home if isinstance(home, str) and home else None


async def _split_pane_in_cwd(
    connection: iterm2.Connection,
    app: iterm2.App,
    *,
    session_id: str,
    vertical: bool,
) -> None:
    session = app.get_session_by_id(session_id)
    if not session:
        alert = iterm2.Alert(title="Split pane", subtitle="Could not find the target session.")
        alert.add_button("OK")
        await alert.async_run(connection)
        return

    cwd = await _get_session_cwd(session)
    new_session = await session.async_split_pane(vertical=vertical)
    if not new_session or not cwd:
        return

    await new_session.async_send_text(f"cd {shlex.quote(cwd)}\n")


async def main(connection: iterm2.Connection) -> None:
    app = await iterm2.async_get_app(connection)

    @iterm2.RPC
    async def split_pane_cwd_vertical(session_id=iterm2.Reference("id")) -> None:
        await _split_pane_in_cwd(connection, app, session_id=session_id, vertical=True)

    @iterm2.RPC
    async def split_pane_cwd_horizontal(session_id=iterm2.Reference("id")) -> None:
        await _split_pane_in_cwd(connection, app, session_id=session_id, vertical=False)

    await split_pane_cwd_vertical.async_register(connection)
    await split_pane_cwd_horizontal.async_register(connection)


iterm2.run_forever(main)

