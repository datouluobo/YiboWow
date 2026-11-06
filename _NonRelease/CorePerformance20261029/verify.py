"""Run focused checks and keep source-bound evidence, without touching game data."""
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
tests = [
    ['lua', '_NonRelease/CorePerformance20261029/DomainPipelineSpec.lua'],
    ['lua', 'YiboCore/_NonRelease/Tests/CharacterCleanupV2Spec.lua'],
    ['lua', '_NonRelease/EntryBar/EntryBarSpec.lua'],
]
tests += [['pwsh', '-NoProfile', '-File', 'Tools/Build-ReleasePackages.ps1',
           '-Addon', 'YiboCore', '-Target', target, '-ValidateOnly']
          for target in ['Mists', 'Retail', 'Forever']]
results = []
for command in tests:
    result = subprocess.run(command, cwd=ROOT, capture_output=True, encoding='utf-8', errors='replace')
    results.append(dict(command=command, code=result.returncode, output=result.stdout + result.stderr))
    print(('PASS ' if result.returncode == 0 else 'FAIL ') + ' '.join(command))
    if result.returncode != 0:
        print(results[-1]['output'])
sources = ['YiboCore/Data/DomainStore.lua', 'YiboCore/Data/Profile.lua', 'YiboCore/Runtime/DataDomains.lua']
report = dict(tests=results, source_sha256={p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in sources})
(OUT / 'verification.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
raise SystemExit(any(r['code'] != 0 for r in results))
