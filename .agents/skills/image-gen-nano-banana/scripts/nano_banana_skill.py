#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.12"
# dependencies = [
#   "google-genai>=1.65.0",
#   "pillow>=12.1.1",
# ]
# ///

from __future__ import annotations

import argparse
import base64
import json
import os
import sys
from io import BytesIO
from pathlib import Path

from PIL import Image as PILImage


MODEL_NAMES = {
    "flash": "gemini-3.1-flash-image-preview",
    "pro": "gemini-3-pro-image-preview",
}
MODEL_RESOLUTIONS = {
    "flash": {"512", "1K", "2K", "4K"},
    "pro": {"1K", "2K", "4K"},
}
MODEL_MAX_INPUT_IMAGES = {
    "flash": 14,
    "pro": 1,
}
MODEL_ASPECT_RATIOS = {
    "flash": {
        "1:1",
        "1:4",
        "1:8",
        "2:3",
        "3:2",
        "3:4",
        "4:1",
        "4:3",
        "4:5",
        "5:4",
        "8:1",
        "9:16",
        "16:9",
        "21:9",
    },
    "pro": set(),
}
SUPPORTED_RESOLUTION_INPUTS = {"512", "512px", "1K", "2K", "4K"}
CANONICAL_RESOLUTION_MAP = {
    "512": "512",
    "512px": "512",
    "1K": "1K",
    "2K": "2K",
    "4K": "4K",
}

FILE_PATH = Path(__file__).resolve()
SKILL_ROOT = FILE_PATH.parents[1]
EXPERIMENT_ROOT = FILE_PATH.parents[3]


def load_dotenv_into(env: dict[str, str]) -> None:
    for dotenv_path in (EXPERIMENT_ROOT / ".env", SKILL_ROOT / ".env"):
        if not dotenv_path.exists():
            continue
        for line in dotenv_path.read_text().splitlines():
            stripped = line.strip()
            if not stripped or stripped.startswith("#") or "=" not in stripped:
                continue
            key, value = stripped.split("=", 1)
            key = key.strip()
            if key.startswith("export "):
                key = key.removeprefix("export ").strip()
            env.setdefault(key, value.strip().strip("\"'"))


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Direct image generation/editing with Nano Banana Flash or Pro")
    parser.add_argument("--prompt", "-p", required=True, help="Image prompt or editing instructions")
    parser.add_argument(
        "--output",
        "--filename",
        "-o",
        "-f",
        dest="output",
        required=True,
        help="Primary output image path.",
    )
    parser.add_argument(
        "--model",
        "-m",
        choices=["flash", "pro"],
        default="flash",
        help="Image model: flash for speed, pro for higher fidelity.",
    )
    parser.add_argument(
        "--input-image",
        "-i",
        action="append",
        default=[],
        help="Reference or source image path. Repeat for multiple images.",
    )
    parser.add_argument(
        "--resolution",
        "-r",
        default=None,
        choices=sorted(SUPPORTED_RESOLUTION_INPUTS),
        help="Output resolution. Defaults to 1K when omitted.",
    )
    parser.add_argument(
        "--aspect-ratio",
        "-a",
        choices=sorted(MODEL_ASPECT_RATIOS["flash"]),
        help="Output aspect ratio (flash only).",
    )
    parser.add_argument("--api-key", "-k", help="Gemini API key (overrides environment)")
    parser.add_argument("--json", action="store_true", help="Emit JSON output")
    return parser


def normalize_resolution(value: str) -> str:
    try:
        return CANONICAL_RESOLUTION_MAP[value]
    except KeyError as exc:
        raise RuntimeError(f"Unsupported resolution: {value}") from exc


def get_api_key(env: dict[str, str], provided_key: str | None) -> str:
    if provided_key:
        return provided_key
    for name in ("GEMINI_API_KEY", "GOOGLE_API_KEY"):
        value = env.get(name)
        if value:
            return value
    raise RuntimeError("Missing GEMINI_API_KEY / GOOGLE_API_KEY")


def load_reference_images(paths: list[str]) -> list[Path]:
    resolved: list[Path] = []
    for raw in paths:
        path = Path(raw).expanduser().resolve()
        if not path.exists():
            raise RuntimeError(f"Missing reference image: {path}")
        resolved.append(path)
    return resolved


def detect_auto_resolution(reference_images: list[Path], *, requested_resolution: str, model: str) -> tuple[str, str | None]:
    if requested_resolution != "1K" or not reference_images:
        return requested_resolution, None

    max_dim = 0
    for path in reference_images:
        with PILImage.open(path) as image:
            max_dim = max(max_dim, max(image.size))

    if max_dim >= 3000:
        return "4K", f"auto_resolution=4K_from_input:{max_dim}px"
    if max_dim >= 1500:
        return "2K", f"auto_resolution=2K_from_input:{max_dim}px"
    if model == "flash" and max_dim <= 640:
        return "512", f"auto_resolution=512_from_input:{max_dim}px"
    return "1K", f"auto_resolution=1K_from_input:{max_dim}px"


def validate_args(*, model: str, resolution: str, aspect_ratio: str | None, num_input_images: int) -> list[str]:
    errors: list[str] = []
    if resolution not in MODEL_RESOLUTIONS[model]:
        allowed = ", ".join(sorted(MODEL_RESOLUTIONS[model]))
        errors.append(f"Resolution {resolution} is not supported for model {model}. Allowed: {allowed}")

    if aspect_ratio is not None:
        allowed_ratios = MODEL_ASPECT_RATIOS[model]
        if not allowed_ratios:
            errors.append(f"Aspect ratio is not supported for model {model}.")
        elif aspect_ratio not in allowed_ratios:
            allowed = ", ".join(sorted(allowed_ratios))
            errors.append(f"Aspect ratio {aspect_ratio} is not supported for model {model}. Allowed: {allowed}")

    max_inputs = MODEL_MAX_INPUT_IMAGES[model]
    if num_input_images > max_inputs:
        errors.append(f"Too many input images ({num_input_images}). {model} supports at most {max_inputs}.")

    return errors


def normalize_output_path(output_path: Path) -> Path:
    suffix = output_path.suffix.lower()
    if not suffix:
        return output_path.with_suffix(".png")
    if suffix in {".png", ".jpg", ".jpeg"}:
        return output_path
    raise RuntimeError("Unsupported output extension. Use .png, .jpg, .jpeg, or omit the extension.")


def save_image(image: PILImage.Image, output_path: Path) -> Path:
    output_path = normalize_output_path(output_path)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    suffix = output_path.suffix.lower()
    if suffix in {".jpg", ".jpeg"}:
        image.convert("RGB").save(output_path, "JPEG", quality=95)
        return output_path
    image.save(output_path, "PNG")
    return output_path


def decode_image_bytes(part) -> bytes:
    image_data = part.inline_data.data
    if isinstance(image_data, str):
        return base64.b64decode(image_data)
    return image_data


def run_generation(
    *,
    prompt: str,
    output_path: Path,
    reference_images: list[Path],
    resolution: str,
    model: str,
    aspect_ratio: str | None,
    api_key_override: str | None,
) -> dict:
    from google import genai
    from google.genai import types

    env = os.environ.copy()
    load_dotenv_into(env)
    api_key = get_api_key(env, api_key_override)

    client = genai.Client(api_key=api_key)
    image_config_kwargs: dict[str, str] = {"image_size": resolution}
    if aspect_ratio:
        image_config_kwargs["aspect_ratio"] = aspect_ratio

    contents: list[object] = [prompt]
    for reference_image in reference_images:
        contents.append(PILImage.open(reference_image))

    response = client.models.generate_content(
        model=MODEL_NAMES[model],
        contents=contents,
        config=types.GenerateContentConfig(
            response_modalities=["TEXT", "IMAGE"],
            image_config=types.ImageConfig(**image_config_kwargs),
        ),
    )

    saved_paths: list[str] = []
    model_text: list[str] = []
    image_count = 0
    parts = response.parts or []
    for part in parts:
        if part.text is not None:
            model_text.append(part.text)
            continue
        if part.inline_data is None:
            continue

        image_count += 1
        image = PILImage.open(BytesIO(decode_image_bytes(part)))
        current_output = (
            output_path
            if image_count == 1
            else output_path.with_name(f"{output_path.stem}-{image_count}{output_path.suffix}")
        )
        saved_path = save_image(image, current_output)
        saved_paths.append(str(saved_path))

    if not saved_paths:
        raise RuntimeError("Gemini returned no image output")

    metadata = {
        "model": MODEL_NAMES[model],
        "model_alias": model,
        "original_prompt": prompt,
        "resolution": resolution,
        "aspect_ratio": aspect_ratio,
        "references": [str(path) for path in reference_images],
        "output_paths": saved_paths,
        "model_text": model_text,
    }
    output_path.with_suffix(".json").write_text(json.dumps(metadata, indent=2) + "\n")
    return metadata


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()

    requested_resolution_input = args.resolution or "1K"
    requested_resolution = normalize_resolution(requested_resolution_input)
    reference_images = load_reference_images(args.input_image)

    validation_errors = validate_args(
        model=args.model,
        resolution=requested_resolution,
        aspect_ratio=args.aspect_ratio,
        num_input_images=len(reference_images),
    )
    if validation_errors:
        raise SystemExit("\n".join(validation_errors))

    if args.resolution is None:
        resolution, auto_resolution_note = detect_auto_resolution(
            reference_images,
            requested_resolution=requested_resolution,
            model=args.model,
        )
    else:
        resolution, auto_resolution_note = requested_resolution, None

    output_path = normalize_output_path(Path(args.output).expanduser().resolve())
    metadata = run_generation(
        prompt=args.prompt,
        output_path=output_path,
        reference_images=reference_images,
        resolution=resolution,
        model=args.model,
        aspect_ratio=args.aspect_ratio,
        api_key_override=args.api_key,
    )
    if auto_resolution_note:
        metadata["notes"] = [auto_resolution_note]
        output_path.with_suffix(".json").write_text(json.dumps(metadata, indent=2) + "\n")

    if args.json:
        print(json.dumps(metadata, indent=2))
        return
    print(f"saved: {metadata['output_paths'][0]}")
    if len(metadata["output_paths"]) > 1:
        print(f"additional_outputs: {len(metadata['output_paths']) - 1}")
    print(f"model: {args.model}")
    print(f"resolution: {resolution}")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:  # noqa: BLE001
        print(f"error: {exc}", file=sys.stderr)
        raise SystemExit(1)
