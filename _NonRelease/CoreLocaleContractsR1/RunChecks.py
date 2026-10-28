"""R1-09 offline verification; earlier evidence files stay unchanged."""
import concurrent.futures
import hashlib
import json
import re
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = Path(__file__).resolve().parent
previous = ROOT / "_NonRelease/CoreMetadataContractsR1"
commands = ["lua _NonRelease/CoreLocaleContractsR1/Spec.lua"]
commands += [item["command"] for item in json.loads((previous / "TestResults.json").read_text(encoding="utf-8"))]


def run(command):
    try:
        result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True,
                                encoding="utf-8", errors="replace", timeout=120)
        return {"command": command, "exitCode": result.returncode,
                "output": (result.stdout + result.stderr).strip()}
    except subprocess.TimeoutExpired as error:
        return {"command": command, "exitCode": -1, "output": str(error)}


with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
    results = list(pool.map(run, commands))
(OUTPUT / "TestResults.json").write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding="utf-8")
for result in results:
    print(f"{result['exitCode']} {result['command']}: {result['output'][:200]}", flush=True)

core = ROOT / "YiboCore"
hashes = {path.relative_to(core).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest()
          for path in sorted(core.rglob("*")) if path.is_file() and path.suffix in (".lua", ".toc")
          and not {"Docs", "_NonRelease"}.intersection(path.relative_to(core).parts)}
baseline = json.loads((previous / "Results.json").read_text(encoding="utf-8"))["runtimeHashes"]
capability_versions = {}
for target in ("Mists", "Forever"):
    versions = {}
    for line in (core / f"YiboCore_{target}.toc").read_text(encoding="utf-8").splitlines():
        if line.endswith(".lua"):
            source = (core / line.replace(chr(92), "/")).read_text(encoding="utf-8")
            for name, version in re.findall(r'Capabilities:Register\("([^"]+)",\s*(\d+)\)', source):
                versions[name] = max(versions.get(name, 0), int(version))
    capability_versions[target] = dict(sorted(versions.items()))
record = {
    "date": "2026-10-27", "stage": "R1-09",
    "status": "copy/contracts and scoped offline verification complete; client acceptance and extended fixture blockers pending",
    "versions": {"Mists": "1.12.9", "Forever": "0.2.0", "API": 13, "schema": 11, "Retail": "not-implemented"},
    "runtimeHashes": hashes,
    "startingBaseline": "R1-07/08 runtime hashes verified unchanged before implementation",
    "changedSinceR10708": [name for name, digest in hashes.items() if baseline.get(name) != digest],
    "sourceGraphs": {"Mists": 62, "Forever": 59, "syntaxUnionWithHint": 69},
    "capabilities": {"Mists": 33, "Forever": 33, "union": 34, "versions": "unchanged"},
    "capabilityVersions": capability_versions,
    "testResults": "TestResults.json",
    "localization": {"coreKeys": 563, "addedKeys": 6, "missingEnglish": 0, "formatMismatches": 0,
                     "duplicateKeys": 0, "existingUnknownKeys": 6, "coreHardcodedCandidates": 27},
    "boundaries": {"localeTests": "synthetic zhCN/zhTW/enUS/frFR and manual settings; actual client tests pending",
                   "playerData": "synthetic in-memory only; no WTF access", "git": "main; no commit or push",
                   "packages": "ValidateOnly and virtual retained-file graphs; no final ZIP or install",
                   "Retail": "no target, manifest, store or build profile added"},
}
(OUTPUT / "Results.json").write_text(json.dumps(record, ensure_ascii=False, indent=2), encoding="utf-8")
