#!/usr/bin/env python3
"""Import offline numeric fact hints as explicitly provisional test records."""
from __future__ import annotations
import argparse,json
from pathlib import Path

N={"instanceIDs":("Instance","副本"),"encounterIDs":("Boss","首领"),"npcIDs":("NPC","NPC"),"questIDs":("Quest","任务"),"achievementIDs":("Achievement","成就"),"professionIDs":("Profession","专业"),"itemIDs":("Item","物品")}
def node(k,v):
 e,z=N[k];return {"kind":"custom","refID":v,"labels":{"enUS":f"{e} #{v}","zhCN":f"{z} #{v}"}}
def choose(hs):
 for h in hs:
  if h.get("instanceIDs") and h.get("encounterIDs"): return "boss_drop",[node("instanceIDs",h["instanceIDs"][0]),node("encounterIDs",h["encounterIDs"][0])]
 for k,t in (("professionIDs","crafted"),("achievementIDs","achievement"),("questIDs","quest"),("npcIDs","vendor"),("itemIDs","research")):
  for h in hs:
   if h.get(k): return t,[node(k,h[k][0])]
def main():
 p=argparse.ArgumentParser();p.add_argument("--catalog",type=Path,required=True);p.add_argument("--inventory",type=Path,required=True);p.add_argument("--facts",type=Path,required=True);a=p.parse_args()
 c=json.loads(a.catalog.read_text(encoding="utf8")); inv={int(x["spellID"]):x for x in json.loads(a.inventory.read_text(encoding="utf8"))["mounts"]}; by_spell={s:r for r in c["mounts"] for s in r["ids"]["spellIDs"]}; add=[]; upgraded=0
 for f in json.loads(a.facts.read_text(encoding="utf8"))["mounts"]:
  spell=int(f["spellID"]); picked=choose(f["hints"])
  if not picked: continue
  typ,path=picked;m=inv[spell];sid=f"fact-source-{spell}"
  existing=by_spell.get(spell)
  if existing:
   if existing["mountKey"].startswith("provisional-"):
    existing["primarySourceID"]=sid;existing["sources"]=[{"sourceID":sid,"type":typ,"priority":1,"active":True,"availability":"unknown","path":path,"requirements":{"difficulties":[],"reputation":None,"costs":[],"questID":None,"achievementID":None,"eventKey":None,"notes":None}}];upgraded+=1
   continue
  add.append({"mountKey":f"fact-{spell}","status":"candidate","ids":{"spellIDs":[spell],"itemIDs":[],"mountJournalID":m["mountJournalID"]},"identity":{"iconFileID":m.get("icon"),"names":{"enUS":f"Mount {spell}","zhCN":m["name"]}},"restrictions":{"factions":[],"classes":[]},"primarySourceID":sid,"sources":[{"sourceID":sid,"type":typ,"priority":1,"active":True,"availability":"unknown","path":path,"requirements":{"difficulties":[],"reputation":None,"costs":[],"questID":None,"achievementID":None,"eventKey":None,"notes":None}}]})
 c["mounts"].extend(sorted(add,key=lambda r:r["ids"]["spellIDs"][0]));a.catalog.write_text(json.dumps(c,ensure_ascii=False,indent=2)+"\n",encoding="utf8",newline="\n");print(f"added {len(add)} numeric-fact candidates; upgraded {upgraded} provisional records")
if __name__=="__main__":main()
