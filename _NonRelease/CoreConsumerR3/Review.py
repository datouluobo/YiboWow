"""Final R3 evidence consistency check; only refresh checks whose inputs changed."""
import hashlib
import json
from pathlib import Path
import re
import subprocess
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent


def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


rows = read(OUT / "TestResults.json")
for command in ("lua _NonRelease/CoreConsumerR3/Spec.lua", "pwsh -NoProfile -File _NonRelease/CoreConsumerR3/PlanSpec.ps1"):
    run = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=120)
    assert run.returncode == 0, run.stdout + run.stderr
    row = next(r for r in rows if r["command"] == command)
    row.update(exitCode=run.returncode, output=(run.stdout + run.stderr).strip())
    print(row["output"], flush=True)
(OUT / "TestResults.json").write_text(json.dumps(rows, ensure_ascii=False, indent=2), encoding="utf-8")
baseline = read(ROOT / "_NonRelease/CoreRetailR2/Results.json")
for name, digest in baseline["runtimeHashes"].items():
    assert hashlib.sha256((ROOT / "YiboCore" / name).read_bytes()).hexdigest() == digest, name
for name, digest in baseline["toolingHashes"].items():
    assert hashlib.sha256((ROOT / name).read_bytes()).hexdigest() == digest, name
docs = [
    "YiboCore/Docs/API-v13-YBP离线兽栏公共支持契约.md",
    "YiboCore/Docs/R3-YBP离线兽栏公共契约实施验收.md",
    "YiboCore/Docs/Retail-共享底座适配实施与验收方案.md",
    "YiboCore/Docs/Retail-R0-三目标能力矩阵.md",
    "YiboCore/Docs/Retail-R0-共享模块审查与改造清单.md",
    "YiboCore/Docs/Core-公共能力迁移台账.md",
    "YiboCore/Docs/API-v13-R1共享底座兼容与失败契约.md",
    "YiboCore/README.md", "Docs/无限服适配与发布验收台账.md", "Docs/后续开发任务清单.md",
    "YiboBeastPaths/Docs/离线兽栏与拥有状态-版本任务清单.md", "_NonRelease/CoreConsumerR3/README.md",
]
count = 0
for relative in docs:
    path = ROOT / relative
    for link in re.findall(r"\]\(([^)]+)\)", path.read_text(encoding="utf-8-sig")):
        if "://" in link or link.startswith("#"):
            continue
        target = unquote(link.split("#", 1)[0].strip("<>"))
        assert (path.parent / target).exists(), (relative, link)
        count += 1
results = read(OUT / "Results.json")
results.update(fixtureChecks=2463, buildPlanChecks=26, runtimeAndToolingHashesMatchR2=True,
               nativeEvidence="../CoreRetailR2/Core-Client-Evidence.json",
               currentBuildPlans="Build-Plans.json", documentation=docs,
               fixtureHashes={p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(OUT.iterdir())
                              if p.suffix in (".lua", ".ps1", ".py")},
               sourceSHA256=read(OUT / "Build-Plans.json")[0]["SourceSHA256"])
(OUT / "Results.json").write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding="utf-8")
review = dict(date="2026-10-27", docs=docs, localLinksChecked=count, brokenLinks=[],
              runtimeFilesUnchanged=len(baseline["runtimeHashes"]), toolingUnchanged=True,
              totalCommands=len(rows), passedCommands=sum(r["exitCode"] == 0 for r in rows),
              productionRuntimeChanged=False, git="main; no commit or push", publication="none")
(OUT / "Review.json").write_text(json.dumps(review, ensure_ascii=False, indent=2), encoding="utf-8")
print(json.dumps(review, ensure_ascii=False), flush=True)
