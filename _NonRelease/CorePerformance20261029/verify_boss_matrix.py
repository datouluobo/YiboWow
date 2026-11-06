"""Matrix allocation hotspot and catalog/goal compatibility, without game writes."""
import json
from pathlib import Path
import runpy
import subprocess

here = Path(__file__).resolve().parent
root = here.parents[1]
output = here / 'BossMatrix'
output.mkdir(exist_ok=True)
command = ['pwsh', '-NoProfile', '-File', 'Tools/Build-ReleasePackages.ps1',
           '-Addon', 'YiboAltoBoss', '-Target', 'Mists', '-ValidateOnly']
result = subprocess.run(command, cwd=root, capture_output=True, encoding='utf-8', errors='replace')
(output / 'alto-boss-build.json').write_text(json.dumps(dict(command=command, code=result.returncode,
    output=result.stdout + result.stderr), ensure_ascii=False, indent=2), encoding='utf-8')
print(('PASS' if result.returncode == 0 else 'FAIL') + ' AltoBoss Mists build validation', flush=True)
if result.returncode:
    print(result.stdout + result.stderr)
    raise SystemExit(result.returncode)
runpy.run_path(str(here / 'verify_ui.py'), init_globals={
    'VERIFICATION_OUTPUT': output,
    'EXTRA_TESTS': [
        '_NonRelease/CorePerformance20261029/DeferredWorkSpec.lua',
        '_NonRelease/CoreSurfaceR1/Spec.lua',
        'YiboCurrency/_NonRelease/Tests/CoreItemControlsSpec.lua',
        '_NonRelease/TaskGoalIntegration/ItemActionSettingsSpec.lua',
        '_NonRelease/CorePerformance20261029/SettingsIdentitySpec.lua',
        '_NonRelease/CorePerformance20261029/NormalizationSpec.lua',
        '_NonRelease/CorePerformance20261029/DropdownWorkSpec.lua',
        '_NonRelease/CorePerformance20261029/PageSwitchSpec.lua',
        '_NonRelease/CorePerformance20261029/PageLifetimeSpec.lua',
        '_NonRelease/CorePerformance20261029/BossMatrixAllocationSpec.lua',
        '_NonRelease/TaskGoalIntegration/BossGoalsSpec.lua',
        '_NonRelease/TaskGoalIntegration/CustomBossGoalsSpec.lua',
        '_NonRelease/TaskGoalIntegration/BossSearchIdentitySpec.lua',
        '_NonRelease/TaskGoalIntegration/BossGoalEditorSpec.lua',
        '_NonRelease/TaskGoalIntegration/RaidProgressSpec.lua',
    ],
})
