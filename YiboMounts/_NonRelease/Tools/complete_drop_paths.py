#!/usr/bin/env python3
"""Complete the alpha boss/rare-drop queue from curated client and AtlasLoot references."""
from __future__ import annotations
import argparse, json
from pathlib import Path

EN = {"奥丹姆": "Uldum", "风神王座": "Throne of the Four Winds", "奥拉基尔": "Al'Akir"}
def node(kind, text): return {"kind": kind, "refID": None, "labels": {"enUS": EN.get(text, text), "zhCN": text}}
def labels(text): return {"enUS": text, "zhCN": text}

# spellID: (region, instance, boss, difficulties).  Empty instance denotes an
# outdoor rare; empty difficulties means that the content has no mode gate.
DROP = {
17481:("东瘟疫之地","斯坦索姆","瑞文戴尔男爵",()),23161:("菲拉斯","厄运之槌","伊莫塔尔",()),23214:("西瘟疫之地","通灵学院","黑暗院长加丁",()),
25953:("希利苏斯","安其拉","无疤者奥斯里安",()),26054:("希利苏斯","安其拉","无疤者奥斯里安",()),26055:("希利苏斯","安其拉","无疤者奥斯里安",()),26056:("希利苏斯","安其拉","无疤者奥斯里安",()),
36702:("逆风小径","卡拉赞","猎手阿图门",()),40192:("虚空风暴","风暴要塞","凯尔萨斯·逐日者",()),41252:("泰罗卡森林","塞泰克大厅","安苏",("HEROIC",)),43688:("幽魂之地","祖阿曼","限时宝箱奖励",()),46628:("奎尔丹纳斯岛","魔导师平台","凯尔萨斯·逐日者",("HEROIC",)),
59567:("北风苔原","永恒之眼","玛里苟斯",()),59568:("北风苔原","永恒之眼","玛里苟斯",()),59569:("塔纳利斯","净化斯坦索姆","永恒腐蚀者",("HEROIC",)),59571:("龙骨荒野","黑曜石圣殿","萨塔里奥",()),59650:("龙骨荒野","黑曜石圣殿","萨塔里奥",()),59996:("风暴峭壁","乌特加德之巅","残忍的斯卡迪",("HEROIC",)),
61465:("冬拥湖","阿尔卡冯的宝库","阿尔卡冯",()),61467:("冬拥湖","阿尔卡冯的宝库","阿尔卡冯",()),63796:("风暴峭壁","奥杜尔","尤格-萨隆",("TWENTY_FIVE",)),69395:("尘泥沼泽","奥妮克希亚的巢穴","奥妮克希亚",()),72286:("冰冠冰川","冰冠堡垒","巫妖王",("TWENTY_FIVE","HEROIC")),
88742:("奥丹姆","旋云之巅","阿尔泰鲁斯",("HEROIC",)),88744:("奥丹姆","风神王座","奥拉基尔",()),88746:("深岩之洲","石岩之心","岩皮",("HEROIC",)),96491:("荆棘谷","祖尔格拉布","血领主曼多基尔",("HEROIC",)),96499:("荆棘谷","祖尔格拉布","高阶祭司基尔娜拉",("HEROIC",)),97493:("海加尔山","火焰之地","拉格纳罗斯",("HEROIC",)),97560:("海加尔山","火焰之地","拉格纳罗斯",()),98204:("幽魂之地","祖阿曼","达卡拉",("HEROIC",)),101542:("海加尔山","火焰之地","奥利瑟拉佐尔",()),
107842:("时光之穴","巨龙之魂","死亡之翼的疯狂",()),107844:("时光之穴","巨龙之魂","死亡之翼的疯狂",("HEROIC",)),107845:("时光之穴","巨龙之魂","死亡之翼的疯狂",()),110039:("时光之穴","巨龙之魂","奥卓克希昂",()),
127158:("昆莱山","怒之煞","怒之煞",()),127170:("昆莱山","魔古山宝库","伊拉贡",()),130965:("四风谷","炮舰","炮舰",()),132036:("锦绣谷","阿拉尼","阿拉尼",()),136400:("雷神岛","雷电王座","季鹍",()),136471:("雷神岛","雷电王座","赫利东",()),
138641:("巨兽岛","赞达拉战争使者","赞达拉战争使者",()),138642:("巨兽岛","赞达拉战争使者","赞达拉战争使者",()),138643:("巨兽岛","赞达拉战争使者","赞达拉战争使者",()),139442:("雷神岛","纳拉克","纳拉克",()),
148392:("锦绣谷","决战奥格瑞玛","加尔鲁什·地狱咆哮",()),148396:("锦绣谷","决战奥格瑞玛","加尔鲁什·地狱咆哮",()),148417:("锦绣谷","决战奥格瑞玛","加尔鲁什·地狱咆哮",("HEROIC",)),148476:("锦绣谷","决战奥格瑞玛","加尔鲁什·地狱咆哮",()),
24242:("荆棘谷","祖尔格拉布","血领主曼多基尔",()),24252:("荆棘谷","祖尔格拉布","高阶祭司塞卡尔",()),43900:("黑石山","黑石深渊","科林·烈酒",()),49378:("黑石山","黑石深渊","科林·烈酒",()),49379:("黑石山","黑石深渊","科林·烈酒",()),71342:("银松森林","影牙城堡","药剂师汉摩尔",()),88718:("深岩之洲","","奥艾娜克斯",()),98718:("瓦丝琪尔","","波赛冬斯",()),102488:("奥丹姆","","多姆斯·驼贮",()),
}

# Keep the player-facing instance label self-contained: raid size and required
# difficulty appear immediately after the instance name.  Encounter-specific
# rules (for example, Yogg-Saron 0 Keepers) remain in notes instead.
INSTANCE_LABEL = {
 24242:"祖尔格拉布20人",24252:"祖尔格拉布20人",
 25953:"安其拉废墟20人",26054:"安其拉废墟20人",26055:"安其拉废墟20人",26056:"安其拉废墟20人",
 36702:"卡拉赞10人",40192:"风暴要塞",41252:"塞泰克大厅H",43688:"祖阿曼10人",46628:"魔导师平台H",
 59567:"永恒之眼25人",59568:"永恒之眼10人",59569:"净化斯坦索姆H",59571:"黑曜石圣殿25人",59650:"黑曜石圣殿10人",59996:"乌特加德之巅H",
 61465:"阿尔卡冯的宝库10/25人",61467:"阿尔卡冯的宝库10/25人",63796:"奥杜尔25人",69395:"奥妮克希亚的巢穴10/25人",72286:"冰冠堡垒25H",
 88742:"旋云之巅H",88744:"风神王座10/25人",88746:"石岩之心H",96491:"祖尔格拉布H",96499:"祖尔格拉布H",97493:"火焰之地10/25H",97560:"火焰之地10/25人",98204:"祖阿曼H",101542:"火焰之地10/25人",
 107842:"巨龙之魂10/25人",107844:"巨龙之魂10/25H",107845:"巨龙之魂10/25人",110039:"巨龙之魂10/25人",127170:"魔古山宝库10/25人",136400:"雷电王座10/25人",136471:"雷电王座10/25人",148417:"决战奥格瑞玛25H",
}

# Only four encounter gates exist in the whole drop set (five mount rows).
# They are therefore part of the compact instance qualification, rather than a
# sparse, separate condition field.
ENCOUNTER_GATE = {
 59571:"保留3条暮光幼龙",59650:"保留3条暮光幼龙",63796:"0守护者",98204:"限时挑战",
}

CORRECTIONS = {
 # These were source-type errors, not raid drops.
 148392:("achievement", "锦绣谷", "决战奥格瑞玛", "团队的荣耀：决战奥格瑞玛", 8454, "完成团队成就，不是加尔鲁什掉落。"),
 148396:("achievement", "锦绣谷", "决战奥格瑞玛", "千钧一发：加尔鲁什·地狱咆哮", 8398, "10人普通或更高难度、版本阶段限定；不是首领掉落。"),
 148476:("rare_drop", "永恒岛", "", "火龙", None, "世界稀有精英掉落，不是加尔鲁什掉落。"),
}

def main():
 p=argparse.ArgumentParser();p.add_argument('--catalog',type=Path,required=True);a=p.parse_args()
 root=json.loads(a.catalog.read_text(encoding='utf-8')); changed=0; missing=[]
 for mount in root['mounts']:
  spell=mount['ids']['spellIDs'][0]; detail=DROP.get(spell)
  if spell in CORRECTIONS:
   kind,region,instance,reward,achievement,note=CORRECTIONS[spell]
   source=mount['sources'][0]
   source['sourceID']=f"corrected-source-{spell}";source['type']=kind;source['priority']=100
   source['path']=[node('zone',region)]+([node('instance',instance)] if instance else [])+[node('achievement' if kind=='achievement' else 'rare',reward)]
   source['requirements']['difficulties']=[];source['requirements']['achievementID']=achievement;source['requirements']['notes']=labels(note)
   if kind=='achievement': source['availability']='unavailable' if spell==148396 else 'obtainable'
   mount['primarySourceID']=source['sourceID'];changed+=1;continue
  source=next((s for s in mount.get('sources',[]) if s.get('type') in ('boss_drop','rare_drop') and mount.get('status')=='candidate'),None)
  if not source: continue
  if not detail: missing.append(spell); continue
  region,instance,boss,difficulties=detail
  instance=INSTANCE_LABEL.get(spell,instance)
  if spell in ENCOUNTER_GATE:
   instance=f"{instance}（{ENCOUNTER_GATE[spell]}）"
  source['path']=[node('zone',region)]+([node('instance',instance)] if instance else [])+[node('rare' if source['type']=='rare_drop' else 'boss',boss)]
  source['requirements']['difficulties']=list(difficulties)
  source['requirements']['difficultyInPath']=spell in INSTANCE_LABEL
  if spell in ENCOUNTER_GATE: source['requirements']['notes']=None
  changed+=1
 if missing: raise ValueError(f'missing drop metadata: {missing}')
 a.catalog.write_text(json.dumps(root,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
 print(f'completed {changed} boss/rare-drop paths')
if __name__=='__main__': main()
