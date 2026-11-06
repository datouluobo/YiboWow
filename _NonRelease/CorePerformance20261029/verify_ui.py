"""UI performance integration evidence for the current working tree."""
import json
from pathlib import Path
import runpy
import subprocess

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(globals().get('VERIFICATION_OUTPUT', Path(__file__).resolve().parent / 'UI'))
OUT.mkdir(exist_ok=True)
runpy.run_path(str(ROOT / '_NonRelease/PerformanceAudit20261028/audit.py'), init_globals={
    'AUDIT_OUTPUT': OUT,
    'ADDITIONAL_TESTS': [
        '_NonRelease/PerformanceAudit20261029/HistoryRetentionSpec.lua',
        '_NonRelease/PerformanceAudit20261029/MailDeadlinesSpec.lua',
        '_NonRelease/PerformanceAudit20261029/MailCacheStampsSpec.lua',
        '_NonRelease/PerformanceAudit20261029/RouteRotationSpec.lua',
        'YiboMail/_NonRelease/Tests/RuleSendSpec.lua',
        'YiboMail/_NonRelease/Tests/RuleSendUISpec.lua',
        '_NonRelease/MailForever/Smoke.lua',
        '_NonRelease/VaultForever/Smoke.lua',
        '_NonRelease/CorePerformance20261029/UIPoolSpec.lua',
        '_NonRelease/CorePerformance20261029/DomainPipelineSpec.lua',
        '_NonRelease/Localization/LayoutSpec.lua',
        '_NonRelease/CurrencyMigration/CoreSpec.lua',
        'YiboCore/_NonRelease/Tests/CharacterCleanupV2Spec.lua',
    ] + globals().get('EXTRA_TESTS', []),
})
builds = []
for target in ['Mists', 'Retail', 'Forever']:
    command = ['pwsh', '-NoProfile', '-File', 'Tools/Build-ReleasePackages.ps1',
               '-Addon', 'YiboCore', '-Target', target, '-ValidateOnly']
    result = subprocess.run(command, cwd=ROOT, capture_output=True, encoding='utf-8', errors='replace')
    builds.append(dict(target=target, code=result.returncode, output=result.stdout + result.stderr))
    print(('PASS ' if result.returncode == 0 else 'FAIL ') + target + ' build validation')
(OUT / 'build-validation.json').write_text(json.dumps(builds, ensure_ascii=False, indent=2), encoding='utf-8')
report = json.loads((OUT / 'results.json').read_text(encoding='utf-8'))
raise SystemExit(any(r['code'] != 0 for r in report['tests'] + report['syntax'] + builds))
