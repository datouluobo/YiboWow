"""R3 evidence: preserve earlier R1/R2 reports and replay current scoped regressions."""
import concurrent.futures
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
BASE = ROOT / "_NonRelease/CoreRetailR2"


def hashes():
    core = ROOT / "YiboCore"
    return {p.relative_to(core).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(core.rglob("*")) if p.is_file() and p.suffix in (".lua", ".toc")
            and not {"Docs", "_NonRelease"}.intersection(p.relative_to(core).parts)}


before = hashes()
baseline = json.loads((BASE / "Results.json").read_text(encoding="utf-8"))
commands = ["lua _NonRelease/CoreConsumerR3/Spec.lua",
            "pwsh -NoProfile -File _NonRelease/CoreConsumerR3/PlanSpec.ps1"]
previous = json.loads((BASE / "TestResults.json").read_text(encoding="utf-8"))
commands += [r["command"] for r in previous if r["command"] not in (
    "pwsh -NoProfile -File _NonRelease/CoreRetailR2/PlanSpec.ps1",
    "python _NonRelease/CoreRetailR2/CheckPackages.py")]


def run(command):
    try:
        result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True,
                                encoding="utf-8", errors="replace", timeout=180)
        return dict(command=command, exitCode=result.returncode, output=(result.stdout + result.stderr).strip())
    except subprocess.TimeoutExpired as error:
        return dict(command=command, exitCode=-1, output=str(error))


with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
    results = list(pool.map(run, commands))
(OUT / "TestResults.json").write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding="utf-8")
for row in results:
    print(f"{row['exitCode']} {row['command']}: {row['output'][:170]}", flush=True)
after = hashes()
assert before == after == baseline["runtimeHashes"], "R3 must not silently change the R2 production runtime"
previous_codes = {r["command"]: r["exitCode"] for r in previous}
regressions = [r["command"] for r in results if r["exitCode"] and previous_codes.get(r["command"], 0) == 0]
record = dict(date="2026-10-27", stage="R3", productionRuntimeChanged=False, runtimeHashes=after,
              baseline="../CoreRetailR2/Results.json", versions=baseline["versions"],
              capabilityVersions=baseline["capabilityVersions"],
              totalCommands=len(results), passedCommands=sum(r["exitCode"] == 0 for r in results),
              failedCommands=[r["command"] for r in results if r["exitCode"]], newFailures=regressions,
              boundaries=dict(consumer="synthetic offline fixture; not YBP integration", nativeEvidence="R2 unchanged runtime only; R3 visual/recovery not client-tested",
                              playerData="no player stores or client links touched", publication="none", git="main; no commit or push"))
(OUT / "Results.json").write_text(json.dumps(record, ensure_ascii=False, indent=2), encoding="utf-8")
assert not regressions, regressions
