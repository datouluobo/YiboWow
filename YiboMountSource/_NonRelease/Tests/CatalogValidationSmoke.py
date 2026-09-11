from __future__ import annotations

import copy
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
GENERATOR_PATH = ROOT / "_NonRelease" / "Tools" / "generate_mount_catalog.py"
SPEC = importlib.util.spec_from_file_location("generate_mount_catalog", GENERATOR_PATH)
GENERATOR = importlib.util.module_from_spec(SPEC)
assert SPEC and SPEC.loader
SPEC.loader.exec_module(GENERATOR)


class CatalogValidationSmoke(unittest.TestCase):
    def setUp(self) -> None:
        self.catalog = json.loads((ROOT / "_NonRelease" / "Data" / "mounts.json").read_text(encoding="utf-8"))

    def test_alpha_catalog_is_valid(self) -> None:
        warnings = GENERATOR.validate_catalog(self.catalog, "alpha")
        self.assertTrue(warnings)

    def test_release_rejects_candidates(self) -> None:
        with self.assertRaises(GENERATOR.ValidationError):
            GENERATOR.validate_catalog(self.catalog, "release")

    def test_duplicate_spell_id_is_rejected(self) -> None:
        invalid = copy.deepcopy(self.catalog)
        invalid["mounts"][1]["ids"]["spellIDs"].append(invalid["mounts"][0]["ids"]["spellIDs"][0])
        with self.assertRaises(GENERATOR.ValidationError):
            GENERATOR.validate_catalog(invalid, "alpha")

    def test_generation_is_stable(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            output_a = Path(temporary_directory) / "a.lua"
            output_b = Path(temporary_directory) / "b.lua"
            GENERATOR.write_lua(self.catalog, output_a)
            GENERATOR.write_lua(self.catalog, output_b)
            self.assertEqual(output_a.read_bytes(), output_b.read_bytes())
            self.assertIn(b"[40192] = \"ashes-of-alar\"", output_a.read_bytes())


if __name__ == "__main__":
    unittest.main()
