"""R2 regression snapshots. Previous R0/R1 evidence remains unchanged."""
import concurrent.futures
import hashlib
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = Path(__file__).resolve().parent
previous = ROOT / "_NonRelease/CoreLocaleContractsR1"
commands = ["lua _NonRelease/CoreRetailR2/Spec.lua",
            "pwsh -NoProfile -File _NonRelease/CoreRetailR2/AliasSpec.ps1",
            "pwsh -NoProfile -File _NonRelease/CoreRetailR2/VersionIndexSpec.ps1",
            "pwsh -NoProfile -File _NonRelease/CoreRetailR2/PlanSpec.ps1"]
commands += [row["command"] for row in json.loads((previous / "TestResults.json").read_text(encoding="utf-8"))]


def run(command):
    try:
        result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True,
                                encoding="utf-8", errors="replace", timeout=120)
        return dict(command=command, exitCode=result.returncode, output=(result.stdout + result.stderr).strip())
    except subprocess.TimeoutExpired as error:
        return dict(command=command, exitCode=-1, output=str(error))


with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
    results = list(pool.map(run, commands))
(OUTPUT / "TestResults.json").write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding="utf-8")
for row in results:
    print(f"{row['exitCode']} {row['command']}: {row['output'][:210]}", flush=True)
core = ROOT / "YiboCore"
hashes = {path.relative_to(core).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest()
          for path in sorted(core.rglob("*")) if path.is_file() and path.suffix in (".lua", ".toc")
          and not {"Docs", "_NonRelease"}.intersection(path.relative_to(core).parts)}
baseline = json.loads((previous / "Results.json").read_text(encoding="utf-8"))["runtimeHashes"]
versions = {}
counts = {}
for target in ("Mists", "Forever", "Retail"):
    caps, count = {}, 0
    for line in (core / f"YiboCore_{target}.toc").read_text(encoding="utf-8").splitlines():
        if line.endswith(".lua"):
            count += 1
            text = (core / line.replace(chr(92), "/")).read_text(encoding="utf-8")
            for name, version in re.findall(r'Capabilities:Register\("([^"]+)",\s*(\d+)\)', text):
                caps[name] = max(caps.get(name, 0), int(version))
    versions[target], counts[target] = dict(sorted(caps.items())), count
record = dict(date="2026-10-27", stage="R2-01 and R2-02",
              status="implementation and scoped offline verification complete; current client/package evidence recorded separately",
              versions=dict(Mists="1.12.9", Forever="0.2.0", Retail="0.1.0", API=13, schema=11),
              runtimeHashes=hashes, changedSinceR109=[name for name, digest in hashes.items() if baseline.get(name) != digest],
              sourceGraphs=counts, capabilityVersions=versions, testResults="TestResults.json",
              toolingHashes={name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest()
                             for name in ("Tools/Release.Common.ps1", "Tools/ReleaseProfiles.psd1", "Tools/Build-ReleasePackages.ps1")},
              boundaries=dict(playerData="offline tests use synthetic in-memory stores; client Core link has separate presence/backup record",
                              publication="none", git="main; no commit or push", install="source junction and local package checks; final package client overlay/recovery acceptance separate"))
(OUTPUT / "Results.json").write_text(json.dumps(record, ensure_ascii=False, indent=2), encoding="utf-8")
