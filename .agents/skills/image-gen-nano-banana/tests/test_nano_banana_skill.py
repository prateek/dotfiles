from __future__ import annotations

from .conftest import make_test_image


class TestGetApiKey:
    def test_explicit_key_returned(self, skill_module):
        assert skill_module.get_api_key({}, "my-key") == "my-key"

    def test_env_var_fallback(self, skill_module):
        assert skill_module.get_api_key({"GEMINI_API_KEY": "env-key"}, None) == "env-key"

    def test_google_api_key_fallback(self, skill_module):
        assert skill_module.get_api_key({"GOOGLE_API_KEY": "google-key"}, None) == "google-key"


class TestAutoDetectResolution:
    def test_user_override_respected(self, skill_module, tmp_path):
        image_path = tmp_path / "large.png"
        make_test_image(4000, 3000).save(image_path)
        resolution, note = skill_module.detect_auto_resolution(
            [image_path],
            requested_resolution="2K",
            model="flash",
        )
        assert resolution == "2K"
        assert note is None

    def test_large_input_maps_to_4k(self, skill_module, tmp_path):
        image_path = tmp_path / "large.png"
        make_test_image(4000, 3000).save(image_path)
        resolution, note = skill_module.detect_auto_resolution(
            [image_path],
            requested_resolution="1K",
            model="flash",
        )
        assert resolution == "4K"
        assert "4K" in note

    def test_medium_input_maps_to_2k(self, skill_module, tmp_path):
        image_path = tmp_path / "medium.png"
        make_test_image(1600, 900).save(image_path)
        resolution, note = skill_module.detect_auto_resolution(
            [image_path],
            requested_resolution="1K",
            model="flash",
        )
        assert resolution == "2K"
        assert "2K" in note

    def test_small_flash_input_maps_to_512(self, skill_module, tmp_path):
        image_path = tmp_path / "small.png"
        make_test_image(400, 300).save(image_path)
        resolution, note = skill_module.detect_auto_resolution(
            [image_path],
            requested_resolution="1K",
            model="flash",
        )
        assert resolution == "512"
        assert "512" in note

    def test_small_pro_input_stays_1k(self, skill_module, tmp_path):
        image_path = tmp_path / "small.png"
        make_test_image(400, 300).save(image_path)
        resolution, note = skill_module.detect_auto_resolution(
            [image_path],
            requested_resolution="1K",
            model="pro",
        )
        assert resolution == "1K"
        assert "1K" in note


class TestValidateArgs:
    def test_valid_flash_args_pass(self, skill_module):
        assert skill_module.validate_args(
            model="flash",
            resolution="1K",
            aspect_ratio="16:9",
            num_input_images=2,
        ) == []

    def test_pro_rejects_512(self, skill_module):
        errors = skill_module.validate_args(
            model="pro",
            resolution="512",
            aspect_ratio=None,
            num_input_images=0,
        )
        assert any("512" in error for error in errors)

    def test_pro_rejects_aspect_ratio(self, skill_module):
        errors = skill_module.validate_args(
            model="pro",
            resolution="1K",
            aspect_ratio="16:9",
            num_input_images=0,
        )
        assert any("Aspect ratio" in error for error in errors)

    def test_pro_rejects_multiple_inputs(self, skill_module):
        errors = skill_module.validate_args(
            model="pro",
            resolution="1K",
            aspect_ratio=None,
            num_input_images=2,
        )
        assert any("at most 1" in error for error in errors)

    def test_flash_rejects_too_many_inputs(self, skill_module):
        errors = skill_module.validate_args(
            model="flash",
            resolution="1K",
            aspect_ratio=None,
            num_input_images=15,
        )
        assert any("at most 14" in error for error in errors)


class TestNormalizeOutputPath:
    def test_adds_png_suffix_when_missing(self, skill_module, tmp_path):
        normalized = skill_module.normalize_output_path(tmp_path / "image")
        assert normalized.name == "image.png"

    def test_rejects_unsupported_suffix(self, skill_module, tmp_path):
        path = tmp_path / "image.gif"
        try:
            skill_module.normalize_output_path(path)
        except RuntimeError as exc:
            assert "Unsupported output extension" in str(exc)
        else:
            raise AssertionError("Expected normalize_output_path to reject .gif")


class TestMainResolutionSelection:
    def test_explicit_1k_is_not_auto_upgraded(self, skill_module, monkeypatch, tmp_path):
        ref = tmp_path / "ref.png"
        make_test_image(1600, 900).save(ref)
        out = tmp_path / "out.png"
        captured: dict[str, str] = {}

        def fake_run_generation(**kwargs):
            captured["resolution"] = kwargs["resolution"]
            return {
                "model": "gemini-3.1-flash-image-preview",
                "model_alias": "flash",
                "original_prompt": kwargs["prompt"],
                "resolution": kwargs["resolution"],
                "aspect_ratio": kwargs["aspect_ratio"],
                "references": [str(path) for path in kwargs["reference_images"]],
                "output_paths": [str(out)],
                "model_text": [],
            }

        monkeypatch.setattr(skill_module, "run_generation", fake_run_generation)
        monkeypatch.setattr(
            "sys.argv",
            [
                "nano_banana_skill.py",
                "--model",
                "flash",
                "--input-image",
                str(ref),
                "--resolution",
                "1K",
                "--prompt",
                "Turn this into a glossy product-style orb on a clean studio background.",
                "--output",
                str(out),
            ],
        )
        skill_module.main()
        assert captured["resolution"] == "1K"
