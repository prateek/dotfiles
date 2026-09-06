import json
import os
from pathlib import Path
import sys
import time

fixture = Path(os.environ["FIXTURE"])
with open(os.environ["DRIFT_STUB_LOG"], "a") as log:
    log.write(json.dumps(sys.argv[1:]) + "\n")
mask = os.umask(0o022)
os.umask(mask)
(fixture / "status.umask").write_text(f"{mask:03o}\n")
(fixture / "status.started").touch()
try:
    if os.environ.get("DRIFT_STUB_BLOCK") == "1":
        deadline = time.monotonic() + 4
        while not (fixture / "status.release").exists():
            if time.monotonic() > deadline:
                raise SystemExit("status release deadline exceeded")
            time.sleep(0.01)
    if warning := os.environ.get("DRIFT_STUB_STDERR"):
        print(warning, file=sys.stderr)
    if os.environ.get("DRIFT_STUB_FAIL") == "1":
        print("stub failure", file=sys.stderr)
        raise SystemExit(42)
    if os.environ.get("DRIFT_STUB_CLEAN") != "1":
        print("M dot_zshrc\n M dot_gitconfig")
finally:
    (fixture / "status.finished").touch()
