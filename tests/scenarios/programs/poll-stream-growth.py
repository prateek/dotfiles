import os
from pathlib import Path
import signal
import subprocess
import sys
import time

fixture = Path(os.environ["FIXTURE"])
with (fixture / "out").open("wb") as out, (fixture / "err").open("wb") as err:
    started = time.monotonic()
    with subprocess.Popen(
        [sys.argv[1], str(fixture / "log"), str(fixture / "offset"), "3"],
        stdout=out, stderr=err, start_new_session=True,
    ) as poll:
        try:
            while not (fixture / "ready").exists():
                if poll.poll() is not None or time.monotonic() - started > 2:
                    raise AssertionError("poll did not enter its wait before the readiness deadline")
                time.sleep(0.01)
            (fixture / "log").write_bytes(b"grew")
            status = poll.wait(timeout=5)
            elapsed = time.monotonic() - started
            assert status == 0, f"growth poll exited {status}: {(fixture / 'err').read_text()}"
            assert elapsed < 3, f"growth must wake before timeout, took {elapsed:.3f}s"
        finally:
            if poll.poll() is None:
                os.killpg(poll.pid, signal.SIGTERM)
                try:
                    poll.wait(timeout=2)
                except subprocess.TimeoutExpired:
                    os.killpg(poll.pid, signal.SIGKILL)
                    poll.wait(timeout=2)
