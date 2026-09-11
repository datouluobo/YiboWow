#!/usr/bin/env python3
"""Correct first-wave retired classifications and document their actual sources."""
import argparse
import json
from pathlib import Path


def labels(text): return {"enUS": text, "zhCN": text}
def node(kind, text, ref=None): return {"kind": kind, "refID": ref, "labels": labels(text)}

def req(note=None, *, reputation=None, price=None, achievement=None):
    return {"difficulties": [], "reputation": reputation, "costs": [],
            "price": {"enUS": price, "zhCN": price}, "questID": None,
            "achievementID": achievement, "eventKey": None,
            "notes": labels(note) if note else None}

def source(sid, kind, availability, path, requirements, active=True):
    return {"sourceID": f"retired-audit-source-{sid}", "type": kind,
            "priority": 100, "active": active, "availability": availability,
            "path": path, "requirements": requirements}

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--catalog", type=Path, required=True)
    args = parser.parse_args()
    root = json.loads(args.catalog.read_text(encoding="utf-8"))
    updates = {
        25863: source(25863, "event", "unavailable", [node("zone", "希利苏斯"), node("event", "安其拉开门事件 > 敲响甲虫之锣")], req("甲虫之王任务线和服务器开门窗口限定；窗口结束后不可新获得。"), False),
        26655: source(26655, "event", "unavailable", [node("zone", "希利苏斯"), node("event", "安其拉开门事件 > 敲响甲虫之锣")], req("甲虫之王任务线和服务器开门窗口限定；窗口结束后不可新获得。"), False),
        26656: source(26656, "event", "unavailable", [node("zone", "希利苏斯"), node("event", "安其拉开门事件 > 敲响甲虫之锣")], req("黑色其拉作战坦克的另一召唤法术变体；甲虫之王任务线和服务器开门窗口限定。"), False),
        28828: source(28828, "reputation_vendor", "obtainable", [node("faction", "灵翼之龙（崇拜）"), node("zone", "影月谷 > 灵翼浮岛"), node("npc", "灵翼幼龙管理员")], req("灵翼之龙崇拜后选择奖励；并非绝版。", reputation={"faction": "灵翼之龙", "standing": "EXALTED"})),
        60002: source(60002, "achievement", "obtainable", [node("achievement", "千奇百怪的漫长旅行")], req("完成节日元成就获得；并非绝版。", achievement=2144)),
        60136: source(60136, "vendor", "obtainable", [node("zone", "达拉然"), node("npc", "梅·弗朗西斯")], req("20,000金币；并非绝版。", price="20,000金币")),
        60140: source(60140, "vendor", "obtainable", [node("zone", "达拉然"), node("npc", "梅·弗朗西斯")], req("20,000金币；并非绝版。", price="20,000金币")),
        65917: source(65917, "store", "limited_time", [node("store", "国服怀旧服商城"), node("custom", "魔法公鸡")], req("2022 年巫妖王之怒怀旧服国服商城限时上架；当前是否返场以商城公告为准。", price="¥298")),
        66122: source(66122, "store", "limited_time", [node("store", "国服怀旧服商城"), node("custom", "魔法公鸡")], req("2022 年巫妖王之怒怀旧服国服商城限时上架；当前是否返场以商城公告为准。", price="¥298")),
        66123: source(66123, "store", "limited_time", [node("store", "国服怀旧服商城"), node("custom", "魔法公鸡")], req("2022 年巫妖王之怒怀旧服国服商城限时上架；当前是否返场以商城公告为准。", price="¥298")),
        66124: source(66124, "store", "limited_time", [node("store", "国服怀旧服商城"), node("custom", "魔法公鸡")], req("2022 年巫妖王之怒怀旧服国服商城限时上架；当前是否返场以商城公告为准。", price="¥298")),
        74918: source(74918, "store", "limited_time", [node("store", "国服怀旧服商城"), node("custom", "白毛犀牛")], req("2022 年巫妖王之怒怀旧服国服商城限时上架；当前是否返场以商城公告为准。", price="¥218")),
        129552: source(129552, "research", "unknown", [node("research", "国服怀旧服投放待核实")], req("现有旧兑换路径不作为怀旧服玩家可见来源；待核实实际国服怀旧服投放渠道。")),
        132117: source(132117, "research", "unknown", [node("research", "国服怀旧服投放待核实")], req("现有旧兑换路径不作为怀旧服玩家可见来源；待核实实际国服怀旧服投放渠道。")),
        132118: source(132118, "research", "unknown", [node("research", "国服怀旧服投放待核实")], req("现有旧兑换路径不作为怀旧服玩家可见来源；待核实实际国服怀旧服投放渠道。")),
        132119: source(132119, "research", "unknown", [node("research", "国服怀旧服投放待核实")], req("现有旧兑换路径不作为怀旧服玩家可见来源；待核实实际国服怀旧服投放渠道。")),
        1298512: source(1298512, "research", "unknown", [node("research", "国服怀旧服投放待核实")], req("现有旧兑换路径不作为怀旧服玩家可见来源；待核实实际国服怀旧服投放渠道。")),
        1298516: source(1298516, "research", "unknown", [node("research", "国服怀旧服投放待核实")], req("现有旧兑换路径不作为怀旧服玩家可见来源；待核实实际国服怀旧服投放渠道。")),
        1302506: source(1302506, "research", "unknown", [node("research", "国服怀旧服投放待核实")], req("现有旧兑换路径不作为怀旧服玩家可见来源；待核实实际国服怀旧服投放渠道。")),
        136164: source(136164, "quest", "obtainable", [node("faction", "统御先锋军（崇拜）"), node("zone", "卡桑琅丛林"), node("quest", "最黑暗的阴影之息")], req("部落专属；统御先锋军战役最终任务奖励，并非绝版。", reputation={"faction": "统御先锋军", "standing": "EXALTED"})),
        423869: source(423869, "store", "unavailable", [node("store", "大灾变怀旧服"), node("custom", "炽炎英雄版组合包")], req("2023 年大灾变怀旧服组合包奖励；该历史组合包已结束。"), False),
        440915: source(440915, "event", "unavailable", [node("event", "2024 国服游戏时间优惠"), node("custom", "购买 90 天游戏时间")], req("2024 年国服《巫妖王之怒》游戏时间优惠奖励；限时投放已结束。"), False),
        457485: source(457485, "event", "unavailable", [node("event", "2026 猩红之潮秘宝")], req("2026 年怀旧服/时光服限时活动奖励；活动已结束。"), False),
        459486: source(459486, "event", "unavailable", [node("event", "2025 兰德鲁的豪华礼物盒")], req("2025 年国服限时礼物盒活动奖励；活动已结束。"), False),
        466948: source(466948, "store", "unavailable", [node("store", "魔兽系列 30 周年纪念坐骑礼包"), node("custom", "经典怀旧服：混沌异生恐翼蝙蝠")], req("礼包销售截止于 2025-01-07。"), False),
        466977: source(466977, "store", "unavailable", [node("store", "魔兽系列 30 周年纪念坐骑礼包"), node("custom", "经典怀旧服：混沌异生驭风者")], req("礼包销售截止于 2025-01-07。"), False),
        466980: source(466980, "store", "unavailable", [node("store", "魔兽系列 30 周年纪念坐骑礼包"), node("custom", "经典怀旧服：混沌异生角鹰兽")], req("礼包销售截止于 2025-01-07。"), False),
        466983: source(466983, "store", "unavailable", [node("store", "魔兽系列 30 周年纪念坐骑礼包"), node("custom", "经典怀旧服：混沌异生狮鹫")], req("礼包销售截止于 2025-01-07。"), False),
        1217476: source(1217476, "event", "unavailable", [node("event", "2025 新春狂欢季 > 藏宝工坊")], req("中国刺绣馆联名坐骑；2025 年限时抽奖活动已结束。"), False),
        1229670: source(1229670, "research", "unavailable", [node("research", "目标版本外")], req("此商品不适用于经典怀旧服，因此不作为怀旧服坐骑来源。"), False),
        1229672: source(1229672, "research", "unavailable", [node("research", "目标版本外")], req("此商品不适用于经典怀旧服，因此不作为怀旧服坐骑来源。"), False),
        1238816: source(1238816, "research", "unavailable", [node("research", "目标版本外")], req("此商品不适用于经典怀旧服，因此不作为怀旧服坐骑来源。"), False),
        1239204: source(1239204, "event", "unavailable", [node("event", "2025 国服抖音直播活动"), node("custom", "暴风城巡天战机返场")], req("联盟专属；2025-05-15 限时直播购买返场，活动已结束。"), False),
        1239240: source(1239240, "event", "unavailable", [node("event", "2025 国服抖音直播活动"), node("custom", "奥格瑞玛哨戒飞艇返场")], req("部落专属；2025-05-15 限时直播购买返场，活动已结束。"), False),
        1239372: source(1239372, "store", "unknown", [node("store", "经典怀旧服商城"), node("custom", "星骓")], req("巫妖王之怒怀旧服商城曾投放；当前是否在售需以商城实时列表为准。")),
        55164: source(55164, "quest", "unavailable", [node("zone", "龙骨荒野"), node("quest", "冬卫要塞防御者飞行任务")], req("任务临时载具法术，不是可永久收藏的坐骑；因此不属于绝版坐骑。"), False),
        473478: source(473478, "store", "obtainable", [node("store", "熊猫人之谜怀旧服升级礼包"), node("custom", "宿煞英雄/史诗礼包 > 染煞骑乘虎")], req("可在熊猫人之谜怀旧服与泰坦重铸服务器「时光」使用；并非绝版。")),
        473487: source(473487, "store", "obtainable", [node("store", "熊猫人之谜怀旧服升级礼包"), node("custom", "宿煞英雄/史诗礼包 > 染煞云端翔龙")], req("可在熊猫人之谜怀旧服与泰坦重铸服务器「时光」使用；并非绝版。")),
        1257516: source(1257516, "store", "obtainable", [node("store", "经典怀旧服商城"), node("custom", "兰娜瑟尔的喋血瀑流")], req("怀旧服主线服务器角色可用；商城售价以实时列表为准。")),
        1280068: source(1280068, "store", "obtainable", [node("store", "经典怀旧服商城"), node("custom", "炽燃烈驹")], req("怀旧服商城坐骑；并非绝版。")),
        1283471: source(1283471, "event", "unavailable", [node("event", "2026 兰德鲁金色礼盒")], req("2026 新春限时礼盒奖励；活动结束后绝版。"), False),
        1285724: source(1285724, "event", "unavailable", [node("event", "2026 兰德鲁金色礼盒")], req("2026 新春限时礼盒奖励；活动结束后绝版。"), False),
        1298515: source(1298515, "promotion", "unavailable", [node("promotion", "复活卷轴活动"), node("custom", "唤醒长期未登录玩家")], req("2012-03 至 2014-02 的复活卷轴奖励；活动已结束。"), False),
        1309841: source(1309841, "event", "limited_time", [node("event", "碧蓝林海秘宝")], req("2026-08-14 至 2026-09-11 限时活动奖励；提供主城传送功能。")),
    }
    changed = 0
    for mount in root["mounts"]:
        spell_id = mount["ids"]["spellIDs"][0]
        value = updates.get(spell_id)
        if not value:
            continue
        mount["sources"] = [value]
        mount["primarySourceID"] = value["sourceID"]
        mount["status"] = "candidate" if value["type"] == "research" else "verified"
        if spell_id == 136164:
            mount["restrictions"]["factions"] = ["HORDE"]
        elif spell_id == 1239204:
            mount["restrictions"]["factions"] = ["ALLIANCE"]
        elif spell_id == 1239240:
            mount["restrictions"]["factions"] = ["HORDE"]
        changed += 1
    args.catalog.write_text(json.dumps(root, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(f"audited {changed} retired/source records")


if __name__ == "__main__": main()
