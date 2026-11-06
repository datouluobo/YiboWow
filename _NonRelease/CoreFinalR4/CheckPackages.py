"""Validate actual packages and exact retained-file overlays. No client deployment."""
from pathlib import Path, PurePosixPath
import hashlib
import json
import subprocess
import zipfile
import uuid

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
RUN = OUT / "Scenarios" / uuid.uuid4().hex[:10]
plans = json.loads((OUT / "Package-Builds.json").read_text(encoding="utf-8-sig"))
checks, cases, artifacts = 0, [], []


def check(value, label):
    global checks
    checks += 1
    assert value, label


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def files(root):
    return {p.relative_to(root).as_posix(): sha(p) for p in root.rglob("*") if p.is_file()}


def unpack(path, directory):
    with zipfile.ZipFile(path) as z:
        for name in z.namelist():
            check(name.startswith("YiboCore/") and ".." not in PurePosixPath(name).parts and not PurePosixPath(name).is_absolute(), "safe package path")
        z.extractall(directory)
    return directory / "YiboCore"


def graph(root):
    return [line.strip().replace(chr(92), "/") for line in (root / "YiboCore.toc").read_text(encoding="utf-8-sig").splitlines()
            if line.strip() and not line.startswith("#")]


def replay(target, root):
    p = subprocess.run(["lua", "_NonRelease/CoreFinalR4/PackageSpec.lua", target, str(root)], cwd=ROOT, capture_output=True,
                       text=True, encoding="utf-8", errors="replace", timeout=120)
    check(p.returncode == 0, p.stdout + p.stderr)
    return p.stdout.strip()


check(len({p["SourceSHA256"] for p in plans}) == 1, "all actual packages share frozen source/config input")
for plan in plans:
    target, archive = plan["Target"], Path(plan["CurseForge"])
    with zipfile.ZipFile(archive) as z:
        names = z.namelist()
        manifest = json.loads(z.read("YiboCore/YiboReleaseManifest.json"))
        check(len(names) == len(set(n.lower() for n in names)), "no duplicate case-insensitive entries")
        check(set(names) == {"YiboCore/" + name for name in manifest["files"]} | {"YiboCore/YiboReleaseManifest.json"}, "actual payload equals manifest")
        check([n for n in names if n.endswith(".toc")] == ["YiboCore/YiboCore.toc"], "one default player TOC")
        check(manifest["target"] == target and manifest["sourceSHA256"] == plan["SourceSHA256"], "manifest identity")
        check(not any("/_NonRelease/" in n or "/CoreFinalR4/" in n for n in names), "no probes in player package")
        for other in {"Mists","Forever","Retail"} - {target}:
            check(not any(n.startswith("YiboCore/" + other + "/") for n in names), "other target excluded")
        check("YiboCore/Common/TocHint.lua" not in names, "source Hint excluded")
    root = unpack(archive, RUN / ("Clean-" + target))
    entries = graph(root)
    check(len(entries) == len(set(entries)), "single load of every referenced file")
    check(entries.count("Data/PackagedAddonVersions.lua") == 1, "generated index loaded exactly once")
    for entry in entries:
        check((root / entry).is_file(), "runtime reference exists")
        if entry != "Data/PackagedAddonVersions.lua":
            check(sha(root / entry) == sha(ROOT / "YiboCore" / entry), "actual runtime equals current source")
    cases.append(dict(label="Clean-"+target, target=target, root=str(root), files=files(root), luaOutput=replay(target,root)))
    artifacts.append(dict(target=target,path=str(archive),sha256=sha(archive),files=len(files(root)),runtimeReferences=len(entries)))

old = json.loads((ROOT / "_NonRelease/CoreTocEntry-20261026/OverlayReplay-Report.json").read_text(encoding="utf-8"))
upgrades = [("Mists-1.12.9", "Mists", Path(old[0]["archive"])), ("Mists-1.12.7", "Mists", Path(old[1]["archive"])),
            ("Retail-R2", "Retail", ROOT / "Builds/YiboCore-retail-v0.1.0-api13-curseforge.zip"),
            ("Forever-Dev", "Forever", ROOT / "_NonRelease/CoreFinalPackages-20261026/Run-67f2ed2d/Artifacts/YiboCore-forever-v0.2.0-api13-curseforge.zip")]
for i, expected in enumerate(old):
    check(sha(Path(expected["archive"])) == expected["archiveSHA256"], "Mists representative old package SHA frozen")
for label, target, archive in upgrades:
    root = unpack(archive, RUN / ("Overlay-" + label))
    before = files(root)
    clean = Path(next(c["root"] for c in cases if c["label"] == "Clean-" + target))
    package = Path(next(p["CurseForge"] for p in plans if p["Target"] == target))
    unpack(package, root.parent)
    after, clean_files = files(root), files(clean)
    residual = {name: digest for name, digest in before.items() if name not in clean_files}
    for name, digest in residual.items():
        check(after.get(name) == digest, "old residual preserved byte-for-byte")
    for name, digest in clean_files.items():
        check(after.get(name) == digest, "overlay file equals new actual package")
    check(sorted(p.name for p in root.glob("*.toc")) == ["YiboCore.toc"], "no stale selectable target TOC")
    for name in graph(root):
        check(after[name] == clean_files[name], "overlay runtime wholly from new package")
    cases.append(dict(label="Overlay-"+label,target=target,root=str(root),oldArchive=str(archive),oldArchiveSHA256=sha(archive),
                      retainedFiles=residual,files=after,luaOutput=replay(target,root)))
source = Path(plans[0]["GitHub"])
with zipfile.ZipFile(source) as z:
    names = z.namelist()
    check(not any("/_NonRelease/" in n for n in names), "source ZIP excludes non-release tests")
    check(z.read("YiboCore/YiboCore_Retail.toc") == z.read("YiboCore/YiboCore_Mainline.toc"), "actual source alias bytes identical")
    check(len([n for n in names if n.endswith(".toc")]) == 5, "source contains five manifests for three products")
record = dict(date="2026-10-27", checks=checks, sourceSHA256=plans[0]["SourceSHA256"],artifacts=artifacts,
              sourceArchive=dict(path=str(source),sha256=sha(source)), cases=cases,
              status="actual ZIP and filesystem overlay plus simulated package/probe recovery passed; client acceptance pending",
              pending="client clean/overlay loading, reload/full exit persistence, and original environment restoration")
(OUT / "Package-Checks.json").write_text(json.dumps(record,ensure_ascii=False,indent=2),encoding="utf-8")
print(f"R4 actual ZIP/overlay checks passed: {checks}; {len(cases)} package scenarios")
for case in cases:
    print(case["label"]+": "+case["luaOutput"])
