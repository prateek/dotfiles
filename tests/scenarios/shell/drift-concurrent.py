import os
from pathlib import Path
import subprocess
import time

fixture = Path(os.environ["FIXTURE"])
with subprocess.Popen([os.environ["REFRESH"], "--if-stale"]) as first:
    try:
        deadline = time.monotonic() + 3
        while not (fixture / "status.started").exists():
            if first.poll() is not None or time.monotonic() > deadline:
                raise AssertionError("first refresh did not enter status")
            time.sleep(0.01)
        subprocess.run([os.environ["REFRESH"], "--if-stale"], check=True, timeout=2)
        assert first.poll() is None, "first refresh finished before release"
    finally:
        (fixture / "status.release").touch()
        try:
            first.wait(timeout=5)
        except subprocess.TimeoutExpired:
            first.kill()
            first.wait(timeout=2)
    assert first.returncode == 0, first.returncode
