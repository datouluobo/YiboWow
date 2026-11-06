"""Reproducible source inventory, syntax checks and offline regression results.

No game process, SavedVariables, installed addons or release packages are changed.
"""
import concurrent.futures
import hashlib
import json
from pathlib import Path
import re
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(globals().get('AUDIT_OUTPUT', Path(__file__).resolve().parent))
addons = sorted(p for p in ROOT.glob('Yibo*') if p.is_dir() and ' ' not in p.name)
loaded = set()
inventory = []

def references(path, seen):
    path = path.resolve()
    if path in seen:
        return
    seen.add(path)
    if not path.exists():
        return
    content = path.read_text(encoding='utf-8-sig')
    if path.suffix.lower() == '.toc':
        names = [s.strip() for s in content.splitlines() if s.strip() and not s.lstrip().startswith('#')]
    elif path.suffix.lower() == '.xml':
        names = re.findall(r'<(?:Include|Script)\b[^>]*\bfile=[\"\']([^\"\']+)', content, re.I)
    else:
        return
    for name in names:
        references(path.parent / name.replace('\\', '/'), seen)

for addon in addons:
    variants = []
    addon_lua = set()
    for toc in sorted(addon.glob('*.toc')):
        seen = set()
        references(toc, seen)
        lua = {p for p in seen if p.suffix.lower() == '.lua' and p.exists()}
        addon_lua.update(lua)
        variants.append({'toc': toc.relative_to(ROOT).as_posix(), 'lua': len(lua),
                         'missing': [p.relative_to(ROOT).as_posix() for p in seen if not p.exists()]})
    loaded.update(addon_lua)
    owned = sorted(p for p in addon_lua if 'Libs' not in p.parts)
    hotspots = []
    for p in owned:
        for n, line in enumerate(p.read_text(encoding='utf-8-sig').splitlines(), 1):
            if re.search(r'OnUpdate|C_Timer\.(?:After|NewTicker|NewTimer)|COMBAT_LOG_EVENT_UNFILTERED|collectgarbage', line):
                hotspots.append({'file': p.relative_to(ROOT).as_posix(), 'line': n, 'code': line.strip()})
    inventory.append({'addon': addon.name, 'variants': variants, 'owned_lua': len(owned),
                      'owned_source_kb': round(sum(p.stat().st_size for p in owned)/1024, 1),
                      'hotspots': hotspots,
                      'largest_sources': [{'file': p.relative_to(ROOT).as_posix(), 'kb': round(p.stat().st_size/1024,1)}
                                          for p in sorted(owned, key=lambda p: p.stat().st_size, reverse=True)[:4]]})

def syntax(path):
    result = subprocess.run(['luac', '-p', str(path)], capture_output=True, text=True, encoding='utf-8', errors='replace')
    return {'file': path.relative_to(ROOT).as_posix(), 'code': result.returncode, 'output': result.stderr}

tests = [
 'YiboCore/_NonRelease/Tests/RuntimePerformanceSpec.lua',
 'YiboCore/_NonRelease/Tests/ContractsSpec.lua',
 'YiboCore/_NonRelease/Tests/CharacterNamesSpec.lua',
 'YiboCore/_NonRelease/Tests/CalendarDaySpec.lua',
 '_NonRelease/TaskChainPerformance/PerformanceSpec.lua',
 '_NonRelease/CoreIdentityDomainsR1/Spec.lua',
 '_NonRelease/CoreStartupR1/Spec.lua',
 '_NonRelease/CoreRetailR2/Spec.lua',
 '_NonRelease/CoreForever/Smoke.lua',
 '_NonRelease/CurrencyMigration/Spec.lua',
 '_NonRelease/CurrencyMigration/RetentionSpec.lua',
 '_NonRelease/ReputationMigration/Spec.lua',
 '_NonRelease/ReputationMigration/RetentionSpec.lua',
 '_NonRelease/ReputationMigration/HoverSpec.lua',
 '_NonRelease/TaskGoalIntegration/GoalsSpec.lua',
 '_NonRelease/TaskGoalIntegration/GoalSourcesSpec.lua',
 '_NonRelease/TaskHubVisibility/VisibilitySpec.lua',
 'YiboMail/_NonRelease/Tests/IdentityPerformanceSpec.lua',
 'YiboMail/_NonRelease/Tests/TransfersPerformanceSpec.lua',
 'YiboMail/_NonRelease/Tests/MailRuntimeSpec.lua',
 'YiboMail/_NonRelease/Tests/NativeInboxSpec.lua',
 'YiboMail/_NonRelease/Tests/WorkspaceSpec.lua',
 'YiboVault/_NonRelease/Tests/RevisionEventsSpec.lua',
 'YiboVault/_NonRelease/Tests/PersonalCountsSpec.lua',
 'YiboVault/_NonRelease/Tests/MailProviderSpec.lua',
 'YiboAltoBoss/_NonRelease/Tests/InstanceKillsSpec.lua',
 'YiboAltoBoss/_NonRelease/Tests/LockoutProjectionSpec.lua',
 'YiboAltoBoss/_NonRelease/Tests/HolidayBossSpec.lua',
 'YiboAutoOpen/_NonRelease/Tests/TestRunner.lua',
 'YiboCrafting/Tests/SearchPerformance.lua',
 'YiboCrafting/Tests/RecipeScanScheduling.lua',
 'YiboCrafting/Tests/RecipeStateScanner.lua',
 'YiboBuilds/_NonRelease/Tests/GemCandidatesSpec.lua',
 'YiboBuilds/_NonRelease/Tests/SocketOrderSpec.lua',
 'YiboMounts/_NonRelease/Tests/RunLuaSmokeTests.lua',
]
# All existing isolated BeastPaths tests, plus this audit's actual-renderer regression.
tests += [p.relative_to(ROOT).as_posix() for p in (ROOT/'YiboBeastPaths/_NonRelease/Tests').glob('*.lua')]
jobs = [(p, ['YiboMounts'] if p.endswith('/RunLuaSmokeTests.lua') else [])
        for p in tests if (ROOT/p).exists()]
jobs += [('_NonRelease/PerformanceAudit20261028/MinimapPoolSpec.lua', [flavor]) for flavor in ['Mists','Retail']]
jobs += [('_NonRelease/PerformanceAudit20261028/'+name+'.lua', []) for name in
         ['CopyAndDispatchSpec','CombatCacheSpec','MinimapComputeSpec','TodoSnapshotSpec']]
jobs += [(path, []) for path in globals().get('ADDITIONAL_TESTS', [])]

def run_test(job):
    path, args = job
    started = time.perf_counter()
    try:
        result = subprocess.run(['lua', path, *args], cwd=ROOT, capture_output=True, text=True,
                                encoding='utf-8', errors='replace', timeout=45)
        return {'test':path, 'args':args, 'code':result.returncode,
                'seconds':round(time.perf_counter()-started,3), 'output':result.stdout+result.stderr}
    except subprocess.TimeoutExpired:
        return {'test':path, 'args':args, 'code':'timeout'}

with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
    syntax_results = list(pool.map(syntax, sorted(loaded)))
    results = list(pool.map(run_test, jobs))

output = {'inventory':inventory, 'syntax':syntax_results, 'tests':results,
          'missing_selected_tests':[p for p in tests if not (ROOT/p).exists()],
          'source_sha256':{p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(loaded)}}
(OUT/'results.json').write_text(json.dumps(output,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'addons':len(addons),'loaded_lua':len(loaded),
                  'syntax_failed':sum(r['code']!=0 for r in syntax_results),
                  'tests':len(results),'passed':sum(r['code']==0 for r in results),
                  'failed':sum(r['code']!=0 for r in results)},ensure_ascii=False))
for row in inventory:
    print(row['addon'], row['owned_lua'], row['owned_source_kb'], 'KB source',len(row['hotspots']),'hotspot lines')
for r in results:
    print('PASS' if r['code']==0 else 'FAIL',r['test'],*r['args'])
