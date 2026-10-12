"""Exercise the real PTY adapter with a socket-gated external chezmoi check."""

import os
from pathlib import Path
import pty
import select
import shlex
import signal
import socket
import subprocess
import sys
import tempfile
import time


TIMEOUT = 5


def fake_chezmoi():
    if "managed" in sys.argv:
        print("one\ntwo\nthree")
    elif os.environ.get("BANNER_BLOCK_CHECK"):
        with socket.socket(socket.AF_UNIX) as channel:
            channel.settimeout(TIMEOUT * 3)
            channel.connect(os.environ["BANNER_CHECK_SOCKET"])
            channel.sendall(b"started\n")
            assert channel.recv(32) == b"release\n", "check was not released"
            print("M one")
            channel.sendall(b"finished\n")
    else:
        print("M one\nM two")


def until(predicate, description):
    deadline = time.monotonic() + TIMEOUT
    while not predicate():
        if time.monotonic() >= deadline:
            raise AssertionError(f"timed out waiting for {description}")
        select.select([], [], [], 0.01)


def exercise():
    root = Path(os.environ["BANNER_ROOT"])
    fixture = Path(os.environ["FIXTURE"])
    env = os.environ.copy()
    check = fixture / "bin/chezmoi-check"
    check.write_text(
        f"#!/bin/sh\nexec {shlex.quote(sys.executable)} "
        f"{shlex.quote(__file__)} fake-chezmoi \"$@\"\n"
    )
    check.chmod(0o755)
    renderer = fixture / "bin/fastfetch"
    renderer.write_text('#!/bin/sh\nexec "$BANNER_ROOT/bin/module" chezmoi\n')
    renderer.chmod(0o755)
    env.update(DOTFILES_BANNER_CHEZMOI_BIN=str(check),
               DOTFILES_BANNER_FASTFETCH_BIN=str(renderer))
    subprocess.run([str(root / "bin/refresh")], env=env, check=True, timeout=TIMEOUT)
    # Invalidate the seeded cache through public configuration, without editing it.
    env.update(DOTFILES_BANNER_CHEZMOI_REFRESH_TTL_SECONDS="0", BANNER_BLOCK_CHECK="1")

    # Keep the Unix socket path short even when Bats' fixture path is long.
    with tempfile.TemporaryDirectory(prefix="banner-") as socket_dir:
        env["BANNER_CHECK_SOCKET"] = str(Path(socket_dir) / "check")
        with socket.socket(socket.AF_UNIX) as listener:
            listener.bind(env["BANNER_CHECK_SOCKET"])
            listener.listen(1)
            listener.settimeout(TIMEOUT)
            master, slave = pty.openpty()
            shell = subprocess.Popen(
                [os.environ["TEST_ZSH"], "-fic",
                 'source "$LOADER"; print -r -- __BANNER_STARTUP_RETURNED__; read -r acknowledgment'],
                stdin=slave, stdout=slave, stderr=slave, env=env, start_new_session=True,
            )
            os.close(slave)
            channel = None
            transcript = b""
            try:
                deadline = time.monotonic() + TIMEOUT
                while b"__BANNER_STARTUP_RETURNED__\r\n" not in transcript:
                    remaining = deadline - time.monotonic()
                    assert remaining > 0, "shell startup waited for the blocked refresh"
                    readable, _, _ = select.select([master], [], [], remaining)
                    assert readable, "shell startup waited for the blocked refresh"
                    transcript += os.read(master, 65536)
                assert b"2 / 3 drifted" in transcript, transcript
                assert b"1 / 3 drifted" not in transcript, transcript
                channel, _ = listener.accept()
                channel.settimeout(TIMEOUT)
                assert channel.recv(32) == b"started\n", "refresh never started"
                assert not select.select([channel], [], [], 0)[0], "check finished before release"
                assert "2 / 3 drifted" in subprocess.check_output(
                    [str(root / "bin/module"), "chezmoi"], env=env, text=True, timeout=TIMEOUT
                )
                channel.sendall(b"release\n")
                assert channel.recv(32) == b"finished\n", "check did not finish after release"

                def new_row_visible():
                    return "1 / 3 drifted" in subprocess.check_output(
                        [str(root / "bin/module"), "chezmoi"], env=env, text=True, timeout=TIMEOUT
                    )

                until(new_row_visible, "the refreshed public module row")
                lock = Path(env["DOTFILES_BANNER_STATE_DIR"]) / "sources/chezmoi/refresh.lock"
                until(lambda: not lock.exists(), "refresh completion")
                os.write(master, b"acknowledged\n")
                assert shell.wait(timeout=TIMEOUT) == 0
            finally:
                (fixture / "startup.pty").write_bytes(transcript)
                try:
                    # Release even after assertion failure so no detached checker is stranded.
                    if channel is None:
                        try:
                            channel, _ = listener.accept()
                        except TimeoutError:
                            pass
                    if channel is not None:
                        try:
                            channel.sendall(b"release\n")
                            channel.settimeout(TIMEOUT)
                            while channel.recv(32):
                                pass
                        except (OSError, TimeoutError):
                            pass
                        channel.close()
                        lock = Path(env["DOTFILES_BANNER_STATE_DIR"]) / "sources/chezmoi/refresh.lock"
                        until(lambda: not lock.exists(), "released refresh cleanup")
                finally:
                    if shell.poll() is None:
                        os.killpg(shell.pid, signal.SIGKILL)
                        shell.wait(timeout=TIMEOUT)
                    os.close(master)
    print("OK shell banner background refresh")


if __name__ == "__main__":
    if sys.argv[1:] and sys.argv[1] == "fake-chezmoi":
        fake_chezmoi()
    else:
        exercise()
