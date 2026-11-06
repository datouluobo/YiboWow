"""Review the bounded dragon silhouette and turquoise palette at 32px."""
from pathlib import Path
import importlib.util

ROOT = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('icon_preview', ROOT.parent / 'Simplified32-v1' / 'Preview.py')
preview = importlib.util.module_from_spec(spec)
spec.loader.exec_module(preview)
preview.ROOT = ROOT
preview.SOURCE = Path('C:/Users/Administrator/.codex/generated_images/01a13542-984b-75d1-a79b-41af5db0dd60/exec-878c337f-e0ff-4aad-89c3-21f10c16186a.png')
if __name__ == '__main__':
    preview.main()
