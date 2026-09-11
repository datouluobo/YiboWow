#!/usr/bin/env python3
"""Record China Classic reprint and distribution sources for legacy models."""
import argparse, json
from pathlib import Path

def labels(en, zh=None): return {"enUS":en,"zhCN":zh or en}

def source(spell_id, title, event, note, availability="limited_time"):
 return {"sourceID":f"china-classic-distribution-{spell_id}","type":"event","priority":100,"active":True,"availability":availability,"path":[{"kind":"event","refID":None,"labels":labels(title)},{"kind":"custom","refID":None,"labels":labels(event)}],"requirements":{"difficulties":[],"reputation":None,"costs":[],"price":{"enUS":None,"zhCN":None},"questID":None,"achievementID":None,"eventKey":event,"notes":labels(note)}}

CLASSIC = {
 42776: source(42776, "国服怀旧服限时活动", "2026 兰德鲁金色礼盒", "2026 兰德鲁金色礼盒可投递至熊猫人之谜怀旧服；限时活动，当前是否开放以国服公告为准。"),
 42777: source(42777, "国服怀旧服限时礼包", "2022 虎年特别礼包", "国服燃烧的远征怀旧服曾以虎年特别礼包投放迅捷幽灵虎；限时礼包已结束。"),
 46197: source(46197, "国服怀旧服限时活动", "2026 兰德鲁金色礼盒", "2026 兰德鲁金色礼盒可投递至熊猫人之谜怀旧服；限时活动，当前是否开放以国服公告为准。"),
 46199: source(46199, "国服怀旧服限时活动", "2026 兰德鲁金色礼盒", "2026 兰德鲁金色礼盒可投递至熊猫人之谜怀旧服；限时活动，当前是否开放以国服公告为准。"),
 51412: source(51412, "国服怀旧服限时活动", "2024 国庆小程序签到", "2024-10-01 至 2024-10-14，官方微信小程序累计签到 7 天领取；奖励适用于国服怀旧服，活动已结束。", "unavailable"),
}

PENDING = {
 101573: "历史国服曾以战网积分兑换迅捷海滨陆行鸟；尚未核实其曾投放至熊猫人之谜怀旧服。",
}

def pending_classic_source(spell_id, historical_origin):
 return {"sourceID":f"classic-channel-pending-{spell_id}","type":"research","priority":100,"active":True,"availability":"unknown","path":[{"kind":"research","refID":None,"labels":labels("Classic distribution pending verification", "怀旧服投放待核实")}],"requirements":{"difficulties":[],"reputation":None,"costs":[],"price":{"enUS":None,"zhCN":None},"questID":None,"achievementID":None,"eventKey":historical_origin,"notes":labels("Original TCG codes cannot be redeemed in Classic; verify a China Classic reprint channel before exposing a player-facing source.", "原版 TCG 实体卡兑换码无法在怀旧服兑换；仅在核实国服怀旧服官方复刻渠道后才显示玩家来源。")}}

PENDING_CLASSIC_TCG = {
 136505: ("Ghastly Charger", "幽灵军马", "TCG_LOOT_CARD"),
 96503: ("Amani Dragonhawk", "阿曼尼龙鹰", "TCG_TWILIGHT_OF_THE_DRAGONS"),
 97581: ("Savage Raptor", "野蛮迅猛龙", "TCG_WAR_OF_THE_ELEMENTS"),
 101573: ("Swift Shorestrider", "迅捷海滨陆行鸟", "TCG_THRONE_OF_THE_TIDES"),
 102514: ("Corrupted Hippogryph", "堕落角鹰兽", "TCG_CROWN_OF_THE_HEAVENS"),
 113120: ("Feldrake", "邪能幼龙", "TCG_TIMEWALKERS_WAR_OF_THE_ANCIENTS"),
 387320: ("Blazing Hippogryph", "炽焰角鹰兽", "TCG_WRATHGATE"),
}

CLASSIC_REPRINTS = {
  387323: source(387323, "2026 兰德鲁金色礼盒", "X-51虚空火箭", "国服怀旧服官方复刻投放；该期活动结束后不可再获取。", "unavailable"),
}

def main():
 p=argparse.ArgumentParser();p.add_argument('--catalog',type=Path,required=True);a=p.parse_args();d=json.loads(a.catalog.read_text(encoding='utf-8'));n=0
 completed=pending=0
 for m in d['mounts']:
  sid=m['ids']['spellIDs'][0]
  if sid in PENDING_CLASSIC_TCG:
   en, zh, origin = PENDING_CLASSIC_TCG[sid]
   s=pending_classic_source(sid, origin);m['sources']=[s];m['primarySourceID']=s['sourceID'];m['status']='candidate';m['identity']['names']={'enUS':en,'zhCN':zh};pending+=1
  elif sid in CLASSIC_REPRINTS:
   s=CLASSIC_REPRINTS[sid];m['sources']=[s];m['primarySourceID']=s['sourceID'];m['status']='verified';completed+=1
  elif sid in CLASSIC:
   s=CLASSIC[sid];m['sources']=[s];m['primarySourceID']=s['sourceID'];m['status']='verified';completed+=1
  elif sid in PENDING:
   s=source(sid,"国服历史兑换渠道待核实","战网积分兑换（历史记录）",PENDING[sid],"unknown")
   s['type']='research';s['path'][0]={"kind":"research","refID":None,"labels":labels("怀旧服投放待核实")}
   m['sources']=[s];m['primarySourceID']=s['sourceID'];m['status']='candidate';pending+=1
 a.catalog.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n');print(f'recorded {completed} China Classic distributions; retained {pending} pending Classic checks')
if __name__=='__main__':main()
