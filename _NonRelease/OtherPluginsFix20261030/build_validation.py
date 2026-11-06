from pathlib import Path
import concurrent.futures,json,subprocess,time
out=Path('_NonRelease/OtherPluginsFix20261030'); jobs=['YiboLegendary','YiboVault','YiboBeastPaths','YiboMounts','YiboBuilds','YiboCrafting','YiboTaskHub','YiboQuestBlocker','YiboReputation']
def check(addon):
 cmd=['pwsh','-NoProfile','-File','Tools/Build-ReleasePackages.ps1','-Addon',addon,'-ValidateOnly']
 if addon!='YiboBeastPaths':cmd+=['-Target','Mists']
 started=time.time();r=subprocess.run(cmd,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=180)
 (out/f'Build-{addon}.log').write_text(r.stdout+r.stderr,encoding='utf-8')
 return {'addon':addon,'target':'Universal' if addon=='YiboBeastPaths' else 'Mists','code':r.returncode,'seconds':round(time.time()-started,2)}
with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
 rows=list(pool.map(check,jobs))
(out/'build-results.json').write_text(json.dumps(rows,indent=2),encoding='utf-8');print(json.dumps(rows));raise SystemExit(any(r['code'] for r in rows))
