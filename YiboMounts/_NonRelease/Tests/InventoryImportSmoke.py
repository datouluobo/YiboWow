from __future__ import annotations

import importlib.util
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
TOOL_PATH = ROOT / "_NonRelease" / "Tools" / "import_mount_inventory.py"
SPEC = importlib.util.spec_from_file_location("import_mount_inventory", TOOL_PATH)
TOOL = importlib.util.module_from_spec(SPEC)
assert SPEC and SPEC.loader
SPEC.loader.exec_module(TOOL)


class InventoryImportSmoke(unittest.TestCase):
    def test_keeps_client_source_fields(self) -> None:
        contents = '''YiboMountsDiagnostics = {
            ["mountInventory"] = {
                ["mounts"] = {
                    {
                        ["mountJournalID"] = 123,
                        ["spellID"] = 456,
                        ["icon"] = 789,
                        ["name"] = "测试坐骑",
                        ["sourceType"] = 3,
                        ["sourceText"] = "出售者：测试商人",
                        ["description"] = "测试描述",
                        ["isCollected"] = true,
                    },
                },
            },
        }'''
        records = TOOL.parse_snapshot(contents)
        self.assertEqual(records, [{
            "mountJournalID": 123,
            "spellID": 456,
            "icon": 789,
            "name": "测试坐骑",
            "isCollected": True,
            "sourceType": 3,
            "sourceText": "出售者：测试商人",
            "description": "测试描述",
        }])


if __name__ == "__main__":
    unittest.main()
