"""Build an isolated Core TOC candidate; never modify the source checkout."""
from pathlib import Path
import hashlib
import json
import shutil

workspace = Path(__file__).resolve().parents[2]
source = workspace / "YiboCore"
run = Path(__file__).resolve().parent
candidate = run / "Candidate" / "YiboCore"
assert not candidate.exists(), "Candidate already exists; inspect it before rebuilding"
candidate.mkdir(parents=True)
manifests = {}
for name in ("YiboCore.toc", "YiboCore_Mists.toc", "YiboCore_Forever.toc"):
    text = (source / name).read_text(encoding="utf-8-sig")
    manifests[name] = text
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        relative = Path(line.replace("\\", "/"))
        path = (source / relative).resolve()
        assert path.is_relative_to(source.resolve()) and path.is_file()
        assert path.suffix == ".lua", "Review indirect loading explicitly"
        destination = candidate / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, destination)
shutil.copytree(source / "Media", candidate / "Media")
for name, text in manifests.items():
    (candidate / name).write_text(text, encoding="utf-8")
def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()
files = sorted(p for p in candidate.rglob("*") if p.is_file())
unchanged = []
for path in files:
    relative = path.relative_to(candidate)
    original = source / relative
    if original.is_file() and path.suffix == ".lua" and relative.as_posix() != "Common/TocHint.lua":
        assert digest(path) == digest(original)
        unchanged.append(relative.as_posix())
manifest = {
    "purpose": "Non-release formal Core three-TOC entry candidate; not a release artifact",
    "source": str(source), "candidate": str(candidate),
    "unchangedRuntimeLua": unchanged,
    "originalManifests": {name: digest(source / name) for name in manifests},
    "files": [{"path": p.relative_to(candidate).as_posix(), "sha256": digest(p)} for p in files],
}
(run / "Candidate-Manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
print(f"Candidate: {len(files)} files; {len(unchanged)} existing runtime Lua files unchanged")
