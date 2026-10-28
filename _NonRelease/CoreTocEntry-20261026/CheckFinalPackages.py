from pathlib import Path
import json,zipfile,hashlib,subprocess
repo=Path.cwd(); plan=json.loads((repo/'_NonRelease/CoreTocEntry-20261026/FinalPackageBuild.json').read_text(encoding='utf-8-sig')); run=Path(plan['Run']); checks=0;results=[];cases=[]
def check(v,msg):
 global checks
 checks+=1
 assert v,msg
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def unpack(archive,dest):
 with zipfile.ZipFile(archive) as z:
  for n in z.namelist():check(not Path(n).is_absolute() and '..' not in Path(n).parts,'safe zip path')
  z.extractall(dest)
 return dest/'YiboCore'
def entries(toc):return [x.strip().replace('\\','/') for x in toc.read_text(encoding='utf-8-sig').splitlines() if x.strip() and not x.startswith('#')]
for target in ['Mists','Forever']:
 archive=Path(plan[target]['CurseForge']);dest=unpack(archive,run/('Clean-'+target)); manifest=json.loads((dest/'YiboReleaseManifest.json').read_text(encoding='utf-8-sig')); paths=entries(dest/'YiboCore.toc')
 check([x.name for x in dest.glob('*.toc')]==['YiboCore.toc'],'one install TOC')
 check(manifest['target']==target,'manifest target')
 check(not (dest/('Forever' if target=='Mists' else 'Mists')).exists(),'exclude other target directory')
 check(not (dest/'Common/TocHint.lua').exists(),'hint excluded')
 check(len(paths)==len(set(paths)),'no duplicate Lua')
 check(paths.index('Data/PackagedAddonVersions.lua')+1==paths.index('Runtime/AddonStatus.lua'),'generated index load position')
 source=repo/'YiboCore'/('YiboCore_'+target+'.toc'); expected=source.read_text(encoding='utf-8-sig').replace('Runtime\\AddonStatus.lua','Data\\PackagedAddonVersions.lua\nRuntime\\AddonStatus.lua')
 check((dest/'YiboCore.toc').read_text(encoding='utf-8-sig').replace('\r\n','\n')==expected.replace('\r\n','\n'),'TOC only generated-index insertion')
 for rel in paths:
  check((dest/rel).is_file(),'file exists '+rel)
  if rel!='Data/PackagedAddonVersions.lua':check(sha(dest/rel)==sha(repo/'YiboCore'/rel),'source runtime hash '+rel)
 for rel in ['Libs/Ace3-LICENSE.txt','Libs/LDB-LICENSE.txt','Libs/UPSTREAM.md']:check(sha(dest/rel)==sha(repo/'YiboCore'/rel),'third party notice')
 cases.append({'label':'Clean-'+target,'target':target,'root':str(dest)})
 results.append({'target':target,'archive':str(archive),'sha256':sha(archive),'loadedLua':len(paths),'fileCount':sum(p.is_file() for p in dest.rglob('*'))})
old=json.loads((repo/'_NonRelease/CoreTocEntry-20261026/OverlayReplay-Report.json').read_text(encoding='utf-8'))
for i,row in enumerate(old):
 check(sha(Path(row['archive']))==row['archiveSHA256'],'old archive identity')
 root=unpack(Path(row['archive']),run/('Overlay-Mists-'+str(i)))
 before={p.relative_to(root).as_posix():sha(p) for p in root.rglob('*') if p.is_file()}
 unpack(Path(plan['Mists']['CurseForge']),root.parent)
 current=Path(cases[0]['root']);new={p.relative_to(current).as_posix() for p in current.rglob('*') if p.is_file()}
 residual=sorted(set(before)-new)
 for rel in residual:check(sha(root/rel)==before[rel],'old residual retained')
 for rel in entries(root/'YiboCore.toc'):check(sha(root/rel)==sha(current/rel),'overlay loads new bytes')
 check(len(list(root.glob('*.toc')))==1,'old package no extra selectable TOC')
 cases.append({'label':'Overlay-Mists-'+str(i),'target':'Mists','root':str(root),'oldArchive':row['archive'],'retainedOldFiles':residual})
for first,second in [('Mists','Forever'),('Forever','Mists')]:
 root=unpack(Path(plan[first]['CurseForge']),run/('Cross-'+first+'-'+second));unpack(Path(plan[second]['CurseForge']),root.parent)
 check(len(list(root.glob('*.toc')))==1,'cross install has single selected default TOC')
 for rel in entries(root/'YiboCore.toc'):check(sha(root/rel)==sha(Path(next(c['root'] for c in cases if c['label']=='Clean-'+second))/rel),'cross install uses new target bytes')
 cases.append({'label':'Cross-'+first+'-'+second,'target':second,'root':str(root)})
gh=Path(plan['Mists']['GitHub'])
with zipfile.ZipFile(gh) as z:
 names=z.namelist();check(not any('/_NonRelease/' in x or '/Builds/' in x for x in names),'source archive excludes diagnostic outputs')
 for name in ['YiboCore.toc','YiboCore_Mists.toc','YiboCore_Forever.toc','Common/TocHint.lua']:check('YiboCore/'+name in names,'source archive retains '+name)
 check(json.loads(z.read('YiboCore/YiboReleaseManifest.json'))['purpose']=='all-target-source-and-public-documentation','source purpose')
# Reuse the existing simulation fixture for actual extracted package loading.
base=(repo/'_NonRelease/CoreTocEntry-20261026/Verify.lua').read_text(encoding='utf-8').split('for _,target in ipairs(')[0]
base=base.replace('local root = (arg and arg[1] or "_NonRelease/CoreTocEntry-20261026/Candidate/YiboCore/"):gsub("\\\\","/"):gsub("/*$", "/")','local root')
base=base.replace('return e,e.YiboCore,initializations,counts','return e,e.YiboCore,initializations,counts')
# Reject any mutation of preexisting stores in wrong-target checks using recursive table comparison.
base+='\nlocal function Pristine(t,label) Check(t.sentinel==label and next(t,"sentinel")==nil,"wrong target retains whole saved store") end\n'
for c in cases:
 literal=json.dumps(c['root'].replace('\\','/')+'/');forever='true' if c['target']=='Forever' else 'false';version='0.2.0' if c['target']=='Forever' else '1.12.9'
 for lang in ['enUS','zhCN']:
  base+=f'root={literal}\ndo local e,c,n,counts=Boot("YiboCore.toc",{forever},"{lang}"); Check(c:IsInitialized() and c.VERSION=="{version}","packaged target boots"); Check(n==1,"single successful initialization"); Check(c.PackagedAddonVersions~=nil,"packaged catalog loaded"); for _,n in pairs(counts) do Check(n==1,"single file load") end; Check(#e.TEST_MESSAGES==0,"no callback errors"); end\n'
# Cross-target package misinstallation, including old other-target residuals.
for c in [x for x in cases if x['label'].startswith(('Clean-','Cross-'))]:
 literal=json.dumps(c['root'].replace('\\','/')+'/');wrong='false' if c['target']=='Forever' else 'true'
 base+=f'root={literal}\ndo local e,c=Boot("YiboCore.toc",{wrong},"enUS"); Check(not c:IsInitialized(),"wrong-client install stops"); Pristine(e.YiboCoreDB,"mists"); Pristine(e.YiboCoreForeverDB,"forever"); end\n'
base+='print("Actual package simulations passed: "..checks.." checks")\n'
script=run/'ActualPackageSpec.lua';script.write_text(base,encoding='utf-8');proc=subprocess.run(['lua',str(script)],capture_output=True,text=True)
print(proc.stdout,proc.stderr);check(proc.returncode==0,'actual package simulation')
report={'staticChecks':checks,'packages':results,'sourceArchive':{'path':str(gh),'sha256':sha(gh)},'cases':cases,'luaOutput':proc.stdout.strip(),'limits':'Offline package simulation and filesystem overlay; no client deployment, real save restoration or updater acceptance.'}
(run/'PackageChecks.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8');print('PASS:',checks,'static archive, load graph and overlay checks;',run)
