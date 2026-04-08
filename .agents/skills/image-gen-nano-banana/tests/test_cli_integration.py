from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

from PIL import Image as PILImage


SCRIPT = str(Path(__file__).resolve().parent.parent / "scripts" / "nano_banana_skill.py")


def run_cli(*args: str, env: dict[str, str] | None = None) -> subprocess.CompletedProcess:
    merged_env = os.environ.copy()
    if env:
        merged_env.update(env)
    return subprocess.run(
        [sys.executable, SCRIPT, *args],
        capture_output=True,
        text=True,
        env=merged_env,
    )


class TestHelpOutput:
    def test_help_exits_zero(self):
        result = run_cli("--help")
        assert result.returncode == 0

    def test_help_mentions_models(self):
        result = run_cli("--help")
        assert "flash" in result.stdout
        assert "pro" in result.stdout


class TestValidation:
    def test_pro_rejects_multiple_inputs(self, tmp_path):
        ref1 = tmp_path / "a.png"
        ref2 = tmp_path / "b.png"
        PILImage.new("RGB", (100, 100), (10, 20, 30)).save(ref1)
        PILImage.new("RGB", (100, 100), (30, 20, 10)).save(ref2)
        result = run_cli(
            "--model",
            "pro",
            "--prompt",
            "Edit these reference images together.",
            "--output",
            str(tmp_path / "out.png"),
            "--input-image",
            str(ref1),
            "--input-image",
            str(ref2),
        )
        assert result.returncode != 0
        assert "at most 1" in result.stderr

    def test_pro_rejects_aspect_ratio(self):
        result = run_cli(
            "--model",
            "pro",
            "--aspect-ratio",
            "16:9",
            "--prompt",
            "A photoreal portrait.",
            "--output",
            "/tmp/out.png",
        )
        assert result.returncode != 0
        assert "Aspect ratio is not supported for model pro" in result.stderr

    def test_generate_rejects_bad_extension_before_api(self):
        result = run_cli(
            "--model",
            "flash",
            "--prompt",
            "Simple prompt.",
            "--output",
            "/tmp/bad-output.gif",
        )
        assert result.returncode != 0
        assert "Unsupported output extension" in result.stderr

    def test_filename_alias_works_in_parser_path(self):
        result = run_cli(
            "--help",
        )
        assert result.returncode == 0
        assert "--filename" in result.stdout
