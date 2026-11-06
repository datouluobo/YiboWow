from pathlib import Path
import hashlib,json,re
from urllib.parse import unquote
ROOT=Path(__file__).resolve().parents[2];OUT=Path(__file__).resolve().parent
docs=[
 'Docs/Core-R5-文档与验收台账收尾.md','YiboCore/Docs/R5-文档与台账收尾验收.md','YiboCore/README.md',
 'YiboCore/Docs/Retail-共享底座适配实施与验收方案.md','YiboCore/Docs/Retail-R0-三目标能力矩阵.md',
 'YiboCore/Docs/Retail-R0-共享模块审查与改造清单.md','YiboCore/Docs/Core-公共能力迁移台账.md',
 'YiboCore/Docs/API-v13-YBP离线兽栏公共支持契约.md','YiboCore/Docs/R4-最终包安装覆盖与存档恢复验收.md',
 'YiboBeastPaths/Docs/离线兽栏与拥有状态-版本任务清单.md','Docs/多版本目标与发行标识规范.md',
 'Docs/无限服适配与发布验收台账.md','Docs/后续开发任务清单.md','Docs/仓库当前状态总览.md','Docs/文档维护索引.md',
 '_NonRelease/Recovery-20261027/README.md']
count=0;broken=[]
for relative in docs:
 path=ROOT/relative
 for link in re.findall(r'\]\(([^)]+)\)',path.read_text(encoding='utf-8-sig')):
  if '://' in link or link.startswith('#'):continue
  target=unquote(link.split('#',1)[0].strip('<>'))
  if not (path.parent/target).exists():broken.append(dict(document=relative,target=link))
  count+=1
base=json.loads((ROOT/'_NonRelease/CoreFinalR4/Regression.json').read_text(encoding='utf-8'))['runtimeHashes']
for relative,digest in base.items():
 assert hashlib.sha256((ROOT/'YiboCore'/relative).read_bytes()).hexdigest()==digest,relative
frozen=json.loads((ROOT/'_NonRelease/CoreFinalR4/Package-Checks.json').read_text(encoding='utf-8'))
for row in frozen['artifacts']+[frozen['sourceArchive']]:
 assert hashlib.sha256(Path(row['path']).read_bytes()).hexdigest()==row['sha256'],row['path']
plans=json.loads((OUT/'Build-Plans.json').read_text(encoding='utf-8-sig'))
record=dict(date='2026-10-27',stage='R5',documentation='complete' if not broken else 'link repair pending',
 documents=docs,localLinksChecked=count,brokenLinks=broken,coreRuntimeFilesUnchanged=87,frozenR4PackagesUnchanged=True,
 currentSourceSHA256=plans[0]['SourceSHA256'],frozenR4SourceSHA256=frozen['sourceSHA256'],
 overallR4Complete=False,foreverClientAcceptance='pending server availability',releaseReady=False,publication='none',
 recoveryEvidence='../Recovery-20261027/Validation.json',git='main; no stage, commit, reset or push')
(OUT/'Review.json').write_text(json.dumps(record,ensure_ascii=False,indent=2),encoding='utf-8')
print('R5 link review:',count,'links;',len(broken),'broken; Core runtime and old R4 ZIPs unchanged.')
for item in broken:print(item)
assert not broken,broken
