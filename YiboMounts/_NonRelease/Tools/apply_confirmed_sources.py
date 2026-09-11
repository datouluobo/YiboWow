#!/usr/bin/env python3
"""Apply maintainer-confirmed mount sources without numeric placeholders."""
from __future__ import annotations
import argparse,json
from pathlib import Path

def labels(text): return {"enUS": text, "zhCN": text}
def node(kind,text): return {"kind":kind,"refID":None,"labels":labels(text)}
def req(note=None): return {"difficulties":[],"reputation":None,"costs":[],"price":{"enUS":None,"zhCN":None},"questID":None,"achievementID":None,"eventKey":None,"notes":{"enUS":note,"zhCN":note}}

CONFIRMED={
 5784:{"type":"class_reward","path":[node("class","术士"),node("custom","20级职业训练师"),node("custom","召唤地狱战马")],"availability":"obtainable","classes":["WARLOCK"],"factions":[],"note":"术士专属召唤法术；20级由职业训练师教授，非背包物品。"},
 13819:{"type":"class_reward","path":[node("class","人类/矮人圣骑士"),node("custom","20级职业训练师"),node("custom","召唤军马")],"availability":"obtainable","classes":["PALADIN"],"factions":["ALLIANCE"],"note":"仅限人类或矮人圣骑士的召唤法术；20级由职业训练师教授，非背包物品。"},
 23161:{"type":"class_reward","path":[node("class","术士"),node("custom","40级职业训练师"),node("custom","召唤恐惧战马")],"availability":"obtainable","classes":["WARLOCK"],"factions":[],"note":"术士专属召唤法术；40级由职业训练师教授，非背包物品。"},
 23214:{"type":"class_reward","path":[node("class","人类/矮人圣骑士"),node("custom","40级职业训练师"),node("custom","召唤战马")],"availability":"obtainable","classes":["PALADIN"],"factions":["ALLIANCE"],"note":"仅限人类或矮人圣骑士的召唤法术；40级由职业训练师教授，非背包物品。"},
 73629:{"type":"class_reward","path":[node("class","德莱尼圣骑士"),node("custom","20级职业训练师"),node("custom","召唤主教的雷象")],"availability":"obtainable","classes":["PALADIN"],"factions":["ALLIANCE"],"note":"德莱尼圣骑士专属召唤法术；20级由职业训练师教授，非背包物品。"},
 73630:{"type":"class_reward","path":[node("class","德莱尼圣骑士"),node("custom","40级职业训练师"),node("custom","召唤大主教的雷象")],"availability":"obtainable","classes":["PALADIN"],"factions":["ALLIANCE"],"note":"德莱尼圣骑士专属召唤法术；40级由职业训练师教授，非背包物品。"},
 48778:{"type":"class_reward","path":[node("class","死亡骑士"),node("zone","东瘟疫之地 > 黑锋要塞"),node("quest","初始任务：踏入暗影界")],"availability":"obtainable","classes":["DEATHKNIGHT"],"factions":[],"note":"死亡骑士专属召唤法术；完成黑锋要塞初始任务获得，非背包物品。"},
 69820:{"type":"class_reward","path":[node("class","牛头人圣骑士（烈日行者）"),node("custom","20级职业训练师"),node("custom","召唤烈日行者科多兽")],"availability":"obtainable","classes":["PALADIN"],"factions":["HORDE"],"note":"仅限牛头人圣骑士的召唤法术；20级由职业训练师教授，非背包物品。"},
 69826:{"type":"class_reward","path":[node("class","牛头人圣骑士（烈日行者）"),node("custom","40级职业训练师"),node("custom","召唤巨型烈日行者科多兽")],"availability":"obtainable","classes":["PALADIN"],"factions":["HORDE"],"note":"仅限牛头人圣骑士的召唤法术；40级由职业训练师教授，非背包物品。"},
 155741:{"type":"promotion","path":[node("promotion","《德拉诺之王》数字豪华版/典藏版奖励")],"availability":"unavailable","classes":[],"factions":[],"note":"恐惧渡鸦为《德拉诺之王》数字豪华版或典藏版奖励；目标客户端当前不可新获取。"},
 34767:{"type":"class_reward","path":[node("class","血精灵圣骑士"),node("custom","30级职业训练师"),node("custom","召唤奎尔萨拉斯战马")],"availability":"obtainable","classes":["PALADIN"],"factions":["HORDE"],"note":"血精灵圣骑士专属召唤法术；学习专家骑术后由职业训练师教授，非背包物品。"},
34769:{"type":"class_reward","path":[node("class","血精灵圣骑士"),node("custom","60级职业训练师"),node("custom","召唤奎尔萨拉斯军马")],"availability":"obtainable","classes":["PALADIN"],"factions":["HORDE"],"note":"血精灵圣骑士专属召唤法术；学习高级骑术后由职业训练师教授，非背包物品。"},
 394209:{"type":"event","path":[node("event","网易运营活动")],"availability":"limited_time","classes":[],"factions":[],"note":"网易运营活动赠送。"},
 416158:{"type":"event","path":[node("event","网易运营活动")],"availability":"limited_time","classes":[],"factions":[],"note":"网易运营活动赠送。"},
  446902:{"type":"event","path":[node("event","网易运营活动")],"availability":"limited_time","classes":[],"factions":[],"note":"网易运营活动赠送。"},
 459:{"type":"vendor","path":[node("faction","奥格瑞玛"),node("zone","杜隆塔尔 > 奥格瑞玛"),node("npc","奥古纳罗")],"availability":"obtainable","classes":[],"factions":["HORDE"],"note":"10金币（声望折扣）。"},
 468:{"type":"vendor","path":[node("faction","暴风城"),node("zone","暴风城"),node("npc","凯蒂·斯托克斯")],"availability":"obtainable","classes":[],"factions":["ALLIANCE"],"note":"10金币（声望折扣）。"},
 578:{"type":"vendor","path":[node("faction","奥格瑞玛"),node("zone","杜隆塔尔 > 奥格瑞玛"),node("npc","奥古纳罗")],"availability":"obtainable","classes":[],"factions":["HORDE"],"note":"10金币（声望折扣）。"},
 579:{"type":"vendor","path":[node("faction","奥格瑞玛"),node("zone","杜隆塔尔 > 奥格瑞玛"),node("npc","奥古纳罗")],"availability":"obtainable","classes":[],"factions":["HORDE"],"note":"10金币（声望折扣）。"},
 581:{"type":"vendor","path":[node("faction","奥格瑞玛"),node("zone","杜隆塔尔 > 奥格瑞玛"),node("npc","奥古纳罗")],"availability":"obtainable","classes":[],"factions":["HORDE"],"note":"10金币（声望折扣）。"},
 6896:{"type":"vendor","path":[node("faction","铁炉堡"),node("zone","丹莫罗 > 铁炉堡"),node("npc","维隆·冻石")],"availability":"obtainable","classes":[],"factions":["ALLIANCE"],"note":"10金币（声望折扣）。"},
 8980:{"type":"vendor","path":[node("faction","幽暗城"),node("zone","提瑞斯法林地 > 布瑞尔"),node("npc","撒迦利亚·普斯特")],"availability":"obtainable","classes":[],"factions":["HORDE"],"note":"10金币（声望折扣）。"},
 10790:{"type":"vendor","path":[node("faction","达纳苏斯"),node("zone","泰达希尔 > 多兰纳尔"),node("npc","莱兰奈")],"availability":"obtainable","classes":[],"factions":["ALLIANCE"],"note":"10金币（声望折扣）。"},
 10795:{"type":"vendor","path":[node("faction","暗矛巨魔"),node("zone","杜隆塔尔 > 森金村"),node("npc","祖尼尔")],"availability":"obtainable","classes":[],"factions":["HORDE"],"note":"10金币（声望折扣）。"},
 15780:{"type":"vendor","path":[node("faction","诺莫瑞根"),node("zone","丹莫罗 > 卡拉诺斯"),node("npc","米利·羽哨")],"availability":"obtainable","classes":[],"factions":["ALLIANCE"],"note":"10金币（声望折扣）。"},
 33630:{"type":"vendor","path":[node("faction","诺莫瑞根"),node("zone","丹莫罗 > 卡拉诺斯"),node("npc","米利·羽哨")],"availability":"obtainable","classes":[],"factions":["ALLIANCE"],"note":"10金币（声望折扣）。"},
}
def main():
 p=argparse.ArgumentParser();p.add_argument('--catalog',type=Path,required=True);a=p.parse_args();root=json.loads(a.catalog.read_text(encoding='utf-8'));changed=0
 for m in root['mounts']:
  sid=m['ids']['spellIDs'][0]; data=CONFIRMED.get(sid)
  if not data:continue
  m['status']='candidate';m['restrictions']={'factions':data['factions'],'classes':data['classes']};source={"sourceID":"confirmed-source-"+str(sid),"type":data['type'],"priority":100,"active":True,"availability":data['availability'],"path":data['path'],"requirements":req(data['note'])};m['sources']=[source];m['primarySourceID']=source['sourceID'];changed+=1
 a.catalog.write_text(json.dumps(root,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n');print(f'applied {changed} confirmed sources')
if __name__=='__main__':main()
