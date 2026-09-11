#!/usr/bin/env python3
"""Remove placeholder-only records from player-facing source data.

Resolvable MoP-era records get an actionable path first.  Remaining numeric
facts stay as non-runtime research records rather than leaking item/NPC IDs to
the catalogue or tooltip.  Empty technical and post-target records are kept
for auditability, but explicitly rejected for the 5.5.4 runtime catalogue.
"""
from __future__ import annotations
import argparse,json,re
from pathlib import Path

def labels(text): return {"enUS": text, "zhCN": text}
def n(kind,text): return {"kind":kind,"refID":None,"labels":labels(text)}

RESOLVED={
 48778:("quest",[n("zone","东瘟疫之地 > 黑锋要塞"),n("quest","死亡骑士初始任务线")],"obtainable"),
 49378:("rare_drop",[n("zone","黑石山 > 黑石深渊"),n("rare","科林·烈酒")],"limited_time"),
 54753:("quest",[n("zone","风暴峭壁 > 布伦希尔达村"),n("quest","女人村日常任务奖励")],"obtainable"),
 59572:("quest",[n("zone","风暴峭壁 > 布伦希尔达村"),n("quest","女人村日常任务奖励")],"obtainable"),
 64659:("quest",[n("zone","安戈洛环形山"),n("quest","毒皮暴掠龙任务线")],"obtainable"),
 73313:("quest",[n("zone","冰冠堡垒"),n("quest","影之哀伤任务线奖励")],"obtainable"),
 75207:("quest",[n("zone","瓦丝琪尔"),n("quest","深海任务线")],"obtainable"),
 97501:("achievement",[n("zone","海加尔山 > 火焰之地"),n("achievement","火焰之地团队成就")],"obtainable"),
 102488:("rare_drop",[n("zone","奥丹姆"),n("rare","多姆斯·驼贮")],"obtainable"),
 136164:("quest",[n("zone","卡桑琅丛林"),n("quest","阵营战役任务奖励")],"unavailable"),
}

PLACEHOLDER=re.compile(r"#\d+")
def requirements(availability):
 return {"difficulties":[],"reputation":None,"costs":[],"price":{"enUS":None,"zhCN":None},"questID":None,"achievementID":None,"eventKey":None,"notes":{"enUS":None,"zhCN":None}}

def main():
 p=argparse.ArgumentParser();p.add_argument('--catalog',type=Path,required=True);p.add_argument('--inventory',type=Path,required=True);a=p.parse_args()
 root=json.loads(a.catalog.read_text(encoding='utf-8')); numbered=blank=resolved=0
 for mount in root['mounts']:
  source=next((s for s in mount.get('sources',[]) if s.get('sourceID')==mount.get('primarySourceID')),None)
  spell=mount['ids']['spellIDs'][0]
  is_blank=not source or not source.get('path')
  text=' '.join(node.get('labels',{}).get('zhCN','') for node in (source or {}).get('path',[]))
  is_numbered=bool(PLACEHOLDER.search(text))
  if spell in RESOLVED:
   kind,path,availability=RESOLVED[spell]
   source={"sourceID":"clean-source-"+str(spell),"type":kind,"priority":100,"active":True,"availability":availability,"path":path,"requirements":requirements(availability)}
   mount['sources']=[source];mount['primarySourceID']=source['sourceID'];resolved+=1;continue
  if is_blank:
   # Future-client journal records and technical duplicate spell entries must
   # remain auditable but are not valid MoP Classic collection targets.
   mount['status']='rejected'
   source={"sourceID":"excluded-source-"+str(spell),"type":"research","priority":0,"active":False,"availability":"unavailable","path":[n("research","不属于目标客户端或为技术重复法术")],"requirements":requirements("unavailable")}
   mount['sources']=[source];mount['primarySourceID']=source['sourceID'];blank+=1;continue
  if is_numbered:
   source['type']='research';source['path']=[n("research","来源待进一步核实（已从游戏提示中隐藏）")]
   source['requirements']=requirements(source.get('availability','unknown')); numbered+=1
 known={m['ids']['spellIDs'][0] for m in root['mounts']}
 for row in json.loads(a.inventory.read_text(encoding='utf-8'))['mounts']:
  spell=row['spellID']
  if spell in known: continue
  source={"sourceID":"excluded-source-"+str(spell),"type":"research","priority":0,"active":False,"availability":"unavailable","path":[n("research","不属于目标客户端或为技术重复法术")],"requirements":requirements("unavailable")}
  root['mounts'].append({"mountKey":"excluded-"+str(spell),"status":"rejected","ids":{"spellIDs":[spell],"itemIDs":[],"mountJournalID":row.get('mountJournalID')},"identity":{"iconFileID":row.get('icon'),"names":{"enUS":"Mount "+str(spell),"zhCN":row.get('name','坐骑 '+str(spell))}},"restrictions":{"factions":[],"classes":[]},"primarySourceID":source['sourceID'],"sources":[source]})
  blank+=1
 root['mounts'].sort(key=lambda m:m['ids']['spellIDs'][0])
 a.catalog.write_text(json.dumps(root,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
 print(f'resolved {resolved}; cleared {numbered} numbered placeholders and {blank} blank records')
if __name__=='__main__':main()
