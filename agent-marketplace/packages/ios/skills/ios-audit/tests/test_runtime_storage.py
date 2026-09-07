import sys
import unittest
from pathlib import Path


SKILL_ROOT = Path(__file__).resolve().parents[1]
SCRIPTS_ROOT = SKILL_ROOT / "scripts"
sys.path.insert(0, str(SCRIPTS_ROOT))

from collect.runtime import summarize_storage_policy  # noqa: E402


class RuntimeStorageTests(unittest.TestCase):
    def test_classifies_storage_buckets_and_controls(self) -> None:
        touchpoints = [
            {"context": "FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)"},
            {"context": "FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)"},
            {"context": "FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)"},
            {"context": "FileManager.default.temporaryDirectory"},
            {"context": "KeychainHelper.saveToken(token)"},
            {"context": "UserDefaults.standard.set(value, forKey: key)"},
        ]
        backup_exclusions = [{"context": "values.isExcludedFromBackup = true"}]
        cleanup_controls = [{"context": "try FileManager.default.removeItem(at: url)"}]

        summary = summarize_storage_policy(touchpoints, backup_exclusions, cleanup_controls)

        self.assertEqual(summary["bucket_counts"]["documents"], 1)
        self.assertEqual(summary["bucket_counts"]["application_support"], 1)
        self.assertEqual(summary["bucket_counts"]["caches"], 1)
        self.assertEqual(summary["bucket_counts"]["temporary"], 1)
        self.assertEqual(summary["bucket_counts"]["keychain"], 1)
        self.assertEqual(summary["bucket_counts"]["user_defaults"], 1)
        self.assertTrue(summary["has_backup_exclusion"])
        self.assertTrue(summary["has_cleanup_controls"])


if __name__ == "__main__":
    unittest.main()
