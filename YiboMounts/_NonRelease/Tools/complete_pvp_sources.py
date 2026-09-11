#!/usr/bin/env python3
"""Fill every PvP-related mount source represented by the target client."""
from __future__ import annotations
import argparse, json
from pathlib import Path

ARENA = {
    37015: "第 1 赛季", 44317: "第 2 赛季", 44744: "第 2 赛季",
    49193: "第 3 赛季", 58615: "第 4 赛季", 64927: "第 5 赛季",
    65439: "第 6 赛季", 67336: "第 7 赛季", 71810: "第 8 赛季",
    101282: "第 9 赛季", 101821: "第 9 赛季", 124550: "第 11 赛季",
    139407: "第 12 赛季", 148618: "第 13 赛季",
    148619: "第 14 赛季", 148620: "第 15 赛季",
}
BATTLEGROUND = {
    68056: "评级战场成就：对疯狂的嘉奖（10 人）",
    68057: "评级战场成就：对疯狂的嘉奖（10 人）",
    100332: "评级战场成就：联盟精兵",
    100333: "评级战场成就：部落精兵",
}
AV = {23509, 23510}
HONOR_VENDOR = {*range(22717, 22725), 48027}
CITY_LEADER = {60118: "为了联盟！", 60119: "为了部落！"}

def labels(text): return {"enUS": text, "zhCN": text}
def node(kind, text): return {"kind": kind, "refID": None, "labels": labels(text)}
def requirements(note): return {"difficulties": [], "reputation": None, "costs": [], "price": {"enUS": None, "zhCN": None}, "questID": None, "achievementID": None, "eventKey": None, "notes": labels(note)}

def main():
    p=argparse.ArgumentParser(); p.add_argument('--catalog', type=Path, required=True); a=p.parse_args()
    root=json.loads(a.catalog.read_text(encoding='utf-8')); changed=0
    for mount in root['mounts']:
        sid=mount['ids']['spellIDs'][0]
        if sid in ARENA:
            season=ARENA[sid]
            source={"sourceID":f"pvp-arena-{sid}","type":"achievement","priority":100,"active":True,"availability":"limited_time","path":[node("pvp","竞技场 3v3"),node("season",season),node("custom","角斗士赛季奖励")],"requirements":requirements(f"PVP 竞技场 {season}角斗士奖励；赛季限定，非背包物品。")}
        elif sid in BATTLEGROUND:
            source={"sourceID":f"pvp-battleground-{sid}","type":"achievement","priority":100,"active":True,"availability":"obtainable","path":[node("pvp","评级战场"),node("achievement",BATTLEGROUND[sid])],"requirements":requirements(f"PVP {BATTLEGROUND[sid]}奖励，非背包物品。")}
        elif sid in AV or sid in HONOR_VENDOR:
            source=next(s for s in mount['sources'] if s['sourceID']==mount['primarySourceID'])
            note=source['requirements'].get('notes') or labels('')
            category = '奥特兰克山谷战场声望坐骑。' if sid in AV else 'PVP 荣誉点数商人坐骑。'
            note['zhCN'] = (note.get('zhCN') or '') + ' ' + category
            note['enUS'] = note['zhCN']
            source['requirements']['notes']=note
            changed += 1; continue
        elif sid in CITY_LEADER:
            source={"sourceID":f"pvp-city-leader-{sid}","type":"achievement","priority":100,"active":True,"availability":"obtainable","path":[node("pvp","敌对阵营主城首领"),node("achievement",CITY_LEADER[sid])],"requirements":requirements(f"PVP 阵营领袖击杀成就“{CITY_LEADER[sid]}”奖励，非背包物品。")}
        else: continue
        mount['status']='candidate'; mount['sources']=[source]; mount['primarySourceID']=source['sourceID']; changed+=1
    a.catalog.write_text(json.dumps(root,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
    print(f'completed {changed} PvP mount sources')
if __name__=='__main__': main()
