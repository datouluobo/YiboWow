"""In-memory fixtures for the shipped-file localization audit."""
import importlib.util
from pathlib import Path, PurePosixPath
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('localization_checker', Path(__file__).resolve().parents[2] / 'Tools/Check-Localization.py')
checker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(checker)


class File:
    def __init__(self, path, content=''):
        self.path, self.content = path, content
        self.name, self.stem = PurePosixPath(path).name, PurePosixPath(path).stem

    def read_text(self, **_): return self.content
    def exists(self): return True
    def relative_to(self, _): return PurePosixPath(self.path)


class Root:
    def __init__(self, files): self.files = files
    def __truediv__(self, path): return self.files.get(path, File(path))


class CheckerSpec(unittest.TestCase):
    def test_owner_resources_missing_keys_formats_and_comments(self):
        files = {
            'YiboCore/Locales/zhCN.lua': File('YiboCore/Locales/zhCN.lua', '["CORE.ONE"] = "数量：%d",'),
            'YiboCore/Locales/enUS.lua': File('YiboCore/Locales/enUS.lua', '["CORE.ONE"] = "Count: %d",'),
            'YiboCore/Runtime/Example.lua': File('YiboCore/Runtime/Example.lua', '-- "注释不统计"\nCore:Text("CORE.ONE", 3)\n'),
            'YiboExample/Locales.lua': File('YiboExample/Locales.lua', '''
Core.Locale:Register("YiboExample", "zh", { ["OK"] = "数量：%d", ["MISSING"] = "缺英文" })
Core.Locale:Register("YiboExample", "en", { ["OK"] = "Count: %s }" })
'''),
            'YiboExample/Page.lua': File('YiboExample/Page.lua', '''
-- Core.Locale:Get("YiboExample", "COMMENT")
Core.Locale:Get("YiboExample", "OK", 3)
Core.Locale:Get("YiboExample", "UNKNOWN")
local text = "旧中文"
'''),
        }
        with patch.object(checker, 'ROOT', Root(files)), patch.object(checker, 'shipped', side_effect=lambda addon: [f for key, f in files.items() if key.startswith(addon.name + '/')]):
            result = checker.audit(['YiboCore', 'YiboExample'])
        self.assertEqual(result['missingEnglish'], ['YiboExample:MISSING'])
        self.assertEqual(result['formatMismatch'], ['YiboExample:OK'])
        self.assertEqual([x['key'] for x in result['unknownKeys']], ['YiboExample:UNKNOWN'])
        self.assertEqual(result['addons']['YiboCore']['hardcodedCandidates'], 0)
        self.assertEqual(result['addons']['YiboExample']['hardcodedCandidates'], 1)
        self.assertEqual(result['addons']['YiboExample']['localizedReferences'], 2)


if __name__ == '__main__': unittest.main()
