"""TOC/XML inventory and scoped regressions; does not change game or source data."""
from pathlib import Path
import concurrent.futures, hashlib, json, re, subprocess, time

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
EXCLUDED = {'YiboCore', 'YiboMail', 'YiboTodo', 'YiboAltoBoss'}
addons = sorted(p for p in ROOT.glob('Yibo*') if p.is_dir() and ' ' not in p.name and p.name not in EXCLUDED)
loaded, inventory = set(), []
def visit(path, seen):
    path = path.resolve()
    if path in seen: return
    seen.add(path)
    if not path.exists(): return
    suffix = path.suffix.lower()
    if suffix not in {'.toc', '.xml'}: return
    content = path.read_text(encoding='utf-8-sig')
    names = ([s.strip() for s in content.splitlines() if s.strip() and not s.lstrip().startswith('#')]
             if suffix == '.toc' else re.findall(r'<(?:Include|Script)\b[^>]*\bfile=[\"\']([^\"\']+)', content, re.I))
    for name in names: visit(path.parent/name.replace('\\','/'), seen)
for addon in addons:
    variants = []
    for toc in sorted(addon.glob('*.toc')):
        seen=set(); visit(toc,seen)
        lua={p for p in seen if p.suffix.lower()=='.lua' and p.exists()}; loaded.update(lua)
        variants.append({'toc':toc.relative_to(ROOT).as_posix(),'lua':len(lua), 'missing':[str(p) for p in seen if not p.exists()]})
    inventory.append({'addon':addon.name,'variants':variants})

tests = [
 'YiboAutoOpen/_NonRelease/Tests/TestRunner.lua',
 'YiboBuilds/_NonRelease/Tests/GemCandidatesSpec.lua',
 'YiboBuilds/_NonRelease/Tests/SocketOrderSpec.lua',
 'YiboBuilds/_NonRelease/Tests/EquipmentAugmentSpec.lua',
 'YiboBuilds/_NonRelease/Tests/MistsTargetGuardSpec.lua',
 'YiboBuilds/_NonRelease/Tests/Core13Spec.lua',
 'YiboCrafting/Tests/SearchPerformance.lua',
 'YiboCrafting/Tests/RecipeScanScheduling.lua',
 'YiboCrafting/Tests/RecipeStateScanner.lua',
 'YiboCrafting/Tests/GoalTargets.lua',
 'YiboCrafting/Tests/RealmGoals.lua',
 'YiboCrafting/Tests/EnchantGoals.lua',
 '_NonRelease/CurrencyMigration/Spec.lua',
 '_NonRelease/CurrencyMigration/RetentionSpec.lua',
 '_NonRelease/ReputationMigration/Spec.lua',
 '_NonRelease/ReputationMigration/RetentionSpec.lua',
 '_NonRelease/ReputationMigration/HoverSpec.lua',
 '_NonRelease/TaskChainPerformance/PerformanceSpec.lua',
 '_NonRelease/TaskGoalIntegration/GoalsSpec.lua',
 '_NonRelease/TaskGoalIntegration/GoalSourcesSpec.lua',
 '_NonRelease/TaskHubVisibility/VisibilitySpec.lua',
 '_NonRelease/PerformanceAudit20261029/HistoryRetentionSpec.lua',
 '_NonRelease/PerformanceAudit20261029/RouteRotationSpec.lua',
 '_NonRelease/OtherPluginsPerformance20261030/Hotpaths.lua',
 '_NonRelease/BuildsForever/Smoke.lua',
 '_NonRelease/CraftingForever/Smoke.lua',
 '_NonRelease/CurrencyForever/Smoke.lua',
 '_NonRelease/ReputationForever/Smoke.lua',
 '_NonRelease/VaultForever/Smoke.lua',
]
tests += [p.relative_to(ROOT).as_posix() for name in ['YiboBeastPaths','YiboTaskHub','YiboVault']
          for p in sorted((ROOT/name/'_NonRelease/Tests').glob('*.lua')) if p.name!='Fixture.lua']
jobs=[(p,[]) for p in tests]
jobs += [('YiboMounts/_NonRelease/Tests/RunLuaSmokeTests.lua',['YiboMounts'])]
jobs += [('_NonRelease/PerformanceAudit20261028/MinimapPoolSpec.lua',[target]) for target in ['Mists','Retail']]
def run(job):
    path,args=job; started=time.perf_counter()
    try:
        r=subprocess.run(['lua',path,*args],cwd=ROOT,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=60)
        return dict(test=path,args=args,code=r.returncode,seconds=round(time.perf_counter()-started,3),output=r.stdout+r.stderr)
    except subprocess.TimeoutExpired: return dict(test=path,args=args,code='timeout')
def syntax(path):
    r=subprocess.run(['luac','-p',str(path)],capture_output=True,text=True,encoding='utf-8',errors='replace')
    return dict(file=path.relative_to(ROOT).as_posix(),code=r.returncode,output=r.stderr)
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
    syntax_results=list(pool.map(syntax,sorted(loaded)))
    results=list(pool.map(run,jobs))
data=dict(inventory=inventory,excluded=sorted(EXCLUDED),syntax=syntax_results,tests=results,
          source_sha256={p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(loaded)})
(OUT/'results.json').write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(dict(addons=len(addons),loaded_lua=len(loaded),syntax_failed=sum(r['code']!=0 for r in syntax_results),
    missing=sum(len(v['missing']) for a in inventory for v in a['variants']),tests=len(results),passed=sum(r['code']==0 for r in results))))
for r in results:
    if r['code']!=0: print('FAIL',r['test'],r.get('output','timeout')[-1600:])
print(next(r['output'] for r in results if r['test'].endswith('/Hotpaths.lua')))
