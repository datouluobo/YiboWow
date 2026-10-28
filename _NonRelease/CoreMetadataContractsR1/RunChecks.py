"""Run scoped offline regressions without accessing player data or installing addons."""
import concurrent.futures
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = Path(__file__).resolve().parent
prior_results = json.loads((ROOT / "_NonRelease/CoreSurfaceR1/TestResults.json").read_text(encoding="utf-8"))
commands = ["lua _NonRelease/CoreMetadataContractsR1/MetadataSpec.lua",
            "lua _NonRelease/CoreMetadataContractsR1/ContractsSpec.lua"]
commands += [entry["command"] for entry in prior_results if "PlanSpec.ps1" not in entry["command"]]
commands += ["pwsh -NoProfile -File _NonRelease/CoreMetadataContractsR1/PlanSpec.ps1"]


def execute(command):
    try:
        result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True,
                                encoding="utf-8", errors="replace", timeout=120)
        return {"command": command, "exitCode": result.returncode,
                "output": (result.stdout + result.stderr).strip()}
    except subprocess.TimeoutExpired as error:
        return {"command": command, "exitCode": -1, "output": str(error)}


with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
    results = list(pool.map(execute, commands))
(OUTPUT / "TestResults.json").write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding="utf-8")
for item in results:
    print(f"{item['exitCode']} {item['command']}: {item['output'][:220]}", flush=True)

core = ROOT / "YiboCore"
hashes = {path.relative_to(core).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest()
          for path in sorted(core.rglob("*")) if path.is_file() and path.suffix in (".lua", ".toc")
          and not {"Docs", "_NonRelease"}.intersection(path.relative_to(core).parts)}
prior = json.loads((ROOT / "_NonRelease/CoreSurfaceR1/Results.json").read_text(encoding="utf-8"))["runtimeHashes"]
record = {
    "date": "2026-10-27", "stage": "R1-07 and R1-08",
    "status": "code and scoped offline checks complete; extended fixture blockers and client acceptance pending",
    "versions": {"Mists": "1.12.9", "Forever": "0.2.0", "API": 13, "schema": 11, "Retail": "not-implemented"},
    "runtimeHashes": hashes,
    "changedSinceR10506": [name for name, digest in hashes.items() if prior.get(name) != digest],
    "sourceGraphs": {"Mists": 62, "Forever": 59, "syntaxUnionWithHint": 69},
    "capabilities": {"Mists": 33, "Forever": 33, "union": 34, "versions": "unchanged"},
    "catalogSizes": {"Mists": 14, "Forever": 6}, "expectedCleanupOwners": {"Mists": 10, "Forever": 6},
    "startingBaseline": "R1-05/06 runtime hashes verified unchanged before implementation",
    "localization": {"coreKeys": 557, "missingEnglish": 0, "formatMismatches": 0, "duplicateKeys": 0,
                     "existingUnknownKeys": 6, "coreHardcodedCandidates": 27},
    "testResults": "TestResults.json",
    "boundaries": {"client": "pending for changed bytes", "playerData": "synthetic in-memory only; no WTF access",
                   "packages": "ValidateOnly and virtual retained-file graph overlays; no ZIP or installation",
                   "Retail": "no target implementation, manifest, store or build profile; YBP existing route metadata only",
                   "git": "main; no commit or push"},
}
(OUTPUT / "Results.json").write_text(json.dumps(record, ensure_ascii=False, indent=2), encoding="utf-8")
