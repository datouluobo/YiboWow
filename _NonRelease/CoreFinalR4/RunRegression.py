"""Current R4 regression evidence without overwriting R3 snapshots."""
from pathlib import Path
import concurrent.futures
import hashlib
import json
import subprocess

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
previous = json.loads((ROOT / "_NonRelease/CoreConsumerR3/TestResults.json").read_text(encoding="utf-8"))
commands = [row["command"] for row in previous if row["command"].startswith("lua ")]
commands += ["pwsh -NoProfile -File Tools/Test-LuaSyntax.ps1 -Addon YiboCore",
             "python Tools/Check-Localization.py --output _NonRelease/Localization/Workspace-Report.md"]


def run(command):
    result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True,
                            encoding="utf-8", errors="replace", timeout=180)
    return dict(command=command,exitCode=result.returncode,output=(result.stdout+result.stderr).strip())


with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
    rows = list(pool.map(run, commands))
(OUT / "TestResults.json").write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding="utf-8")
codes = {r["command"]:r["exitCode"] for r in previous}
new_failures = [r["command"] for r in rows if r["exitCode"] and codes.get(r["command"],0)==0]
baseline = json.loads((ROOT / "_NonRelease/CoreConsumerR3/Results.json").read_text(encoding="utf-8"))
for relative,digest in baseline["runtimeHashes"].items():
    assert hashlib.sha256((ROOT / "YiboCore" / relative).read_bytes()).hexdigest()==digest, relative
record = dict(date="2026-10-27",totalCommands=len(rows),passedCommands=sum(r["exitCode"]==0 for r in rows),
              failures=[r["command"] for r in rows if r["exitCode"]],newFailures=new_failures,
              runtimeUnchangedSinceR3=True,runtimeHashes=baseline["runtimeHashes"],publication="none")
(OUT / "Regression.json").write_text(json.dumps(record,ensure_ascii=False,indent=2),encoding="utf-8")
for r in rows: print(str(r["exitCode"])+" "+r["command"]+": "+r["output"][:130],flush=True)
assert not new_failures, new_failures
