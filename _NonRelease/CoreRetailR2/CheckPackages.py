"""Inspect actual local output ZIPs and replay the extracted Retail player TOC."""
import hashlib
import json
from pathlib import Path, PurePosixPath
import subprocess
import uuid
import zipfile

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = Path(__file__).resolve().parent
plan = json.loads((OUTPUT / "Package-Build.json").read_text(encoding="utf-8-sig"))
checks = 0


def check(value, label):
    global checks
    checks += 1
    if not value:
        raise AssertionError(label)


artifacts = {}
source_check = subprocess.run(["pwsh", "-NoProfile", "-File", "_NonRelease/CoreRetailR2/VerifySourceSnapshot.ps1",
                               "-ExpectedSHA256", plan["SourceSHA256"]], cwd=ROOT, capture_output=True,
                              text=True, encoding="utf-8", errors="replace", timeout=120)
check(source_check.returncode == 0, source_check.stdout + source_check.stderr)
extraction = OUTPUT / "PackageReplay" / uuid.uuid4().hex[:12]
for channel in ("CurseForge", "GitHub"):
    path = Path(plan[channel])
    with zipfile.ZipFile(path) as archive:
        names = archive.namelist()
        check(len(names) == len(set(name.lower() for name in names)), "No duplicate case-insensitive ZIP names")
        check(all(name.startswith("YiboCore/") and ".." not in PurePosixPath(name).parts for name in names), "Single safe addon root")
        manifest = json.loads(archive.read("YiboCore/YiboReleaseManifest.json"))
        expected = {"YiboCore/" + name for name in manifest["files"]} | {"YiboCore/YiboReleaseManifest.json"}
        check(set(names) == expected, "Actual entries exactly match generated manifest")
        check(manifest["sourceSHA256"] == plan["SourceSHA256"], "Actual ZIP uses frozen unified source hash")
        states = {state["target"]: state for state in manifest["registeredTargets"]}
        check(set(states) == {"Retail", "Mists", "Forever"}, "Three actual source targets, no fourth alias product")
        check(states["Retail"]["developmentToc"] == "YiboCore_Mainline.toc", "Native development name retained in metadata")
        if channel == "CurseForge":
            check([name for name in names if name.endswith(".toc")] == ["YiboCore/YiboCore.toc"], "Player package has one default TOC")
            check(not any("/Mists/" in name or "/Forever/" in name or "/_NonRelease/" in name for name in names), "Player package excludes other targets and probes")
            check("YiboCore/Common/TocHint.lua" not in names, "Player package excludes source Hint")
            toc = archive.read("YiboCore/YiboCore.toc").decode("utf-8")
            check("## Interface: 120105" in toc and "SavedVariables: YiboCoreRetailDB" in toc, "Player default TOC matches Retail")
            check(toc.count("Data\\PackagedAddonVersions.lua") == 1, "Generated target version index loaded once")
            check('YiboBeastPaths' in archive.read("YiboCore/Data/PackagedAddonVersions.lua").decode("utf-8"), "Declared bundle source version included")
            for line in toc.splitlines():
                if line.endswith(".lua"):
                    check("YiboCore/" + line.replace(chr(92), "/") in names, "Every actual runtime reference exists")
            for name in names:
                destination = extraction / name
                destination.parent.mkdir(parents=True, exist_ok=True)
                destination.write_bytes(archive.read(name))
        else:
            for toc in ("YiboCore.toc", "YiboCore_Mists.toc", "YiboCore_Forever.toc", "YiboCore_Retail.toc", "YiboCore_Mainline.toc"):
                check("YiboCore/" + toc in names, "Full source archive retains standard manifests and native alias")
            check(archive.read("YiboCore/YiboCore_Retail.toc") == archive.read("YiboCore/YiboCore_Mainline.toc"), "Actual source ZIP alias bytes match")
        artifacts[channel] = dict(path=str(path), sha256=hashlib.sha256(path.read_bytes()).hexdigest(), fileCount=len(names))
replay = subprocess.run(["lua", "_NonRelease/CoreRetailR2/PackageSpec.lua", str(extraction / "YiboCore")],
                        cwd=ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=120)
check(replay.returncode == 0, replay.stdout + replay.stderr)
record = dict(date="2026-10-27", status="local ZIP inspection and extracted default-TOC replay passed; not client install acceptance",
              sourceSHA256=plan["SourceSHA256"], checks=checks, artifacts=artifacts, archivedPriorSourceCount=plan["Archived"],
              extraction=str(extraction), packageReplay=dict(exitCode=replay.returncode, output=(replay.stdout + replay.stderr).strip()),
              publication="none", pending="final-package clean/retained-file client installation and WTF recovery")
(OUTPUT / "Package-Checks.json").write_text(json.dumps(record, ensure_ascii=False, indent=2), encoding="utf-8")
print(f"CoreRetailR2 PackageChecks passed: {checks} ZIP checks; {replay.stdout.strip()}")
