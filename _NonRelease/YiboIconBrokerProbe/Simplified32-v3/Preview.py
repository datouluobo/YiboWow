"""Review the Core network, bounded dragon, compass spacing and teal palette."""
from pathlib import Path
import importlib.util

ROOT = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('icon_preview', ROOT.parent / 'Simplified32-v1' / 'Preview.py')
preview = importlib.util.module_from_spec(spec)
spec.loader.exec_module(preview)
preview.ROOT = ROOT
preview.SOURCE = Path('C:/Users/Administrator/.codex/generated_images/01a13542-984b-75d1-a79b-41af5db0dd60/exec-fdab7350-b4f5-42d7-a913-9d1c674192b0.png')
preview.ITEMS.append(('YiboTaskHub',1254,860))
if __name__ == '__main__':
    preview.main()
