#!/usr/bin/env python3
"""Fill the merchant research queue with normalized, reviewable source paths.

This is deliberately an authoring helper, not a runtime dependency.  It keeps
the candidate status intact: the data is now useful to players and reviewers,
but target-client evidence is still required before a record becomes verified.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path


def labels(value):
    return {"enUS": value, "zhCN": value}


# npcID: (faction / reputation requirement, location, default price).  Prices
# which vary within a vendor's stock are handled by PRICE below.
NPC = {
    4885: ("暴风城", "艾尔文森林 > 东谷伐木场", "10金币（声望折扣）"),
    43694: ("暴风城", "暴风城", "10金币（声望折扣）"),
    3362: ("奥格瑞玛", "杜隆塔尔 > 奥格瑞玛", "10金币（声望折扣）"),
    1261: ("铁炉堡", "丹莫罗 > 铁炉堡", "10金币（声望折扣）"),
    4730: ("达纳苏斯", "泰达希尔 > 多兰纳尔", "10金币（声望折扣）"),
    7952: ("暗矛巨魔", "杜隆塔尔 > 森金村", "10金币（声望折扣）"),
    7955: ("诺莫瑞根", "丹莫罗 > 卡拉诺斯", "10金币（声望折扣）"),
    6749: ("暴风城", "艾尔文森林 > 东谷伐木场", "10金币（声望折扣）"),
    4731: ("幽暗城", "提瑞斯法林地 > 布瑞尔", "10金币（声望折扣）"),
    3685: ("雷霆崖", "莫高雷 > 血蹄村", "10金币（声望折扣）"),
    12783: ("联盟", "暴风城 > 勇士大厅", "2,000荣誉点数"),
    12796: ("部落", "奥格瑞玛 > 传说大厅", "2,000荣誉点数"),
    13218: ("霜狼氏族（崇拜）", "奥特兰克山谷", "2,000荣誉点数"),
    13216: ("雷矛卫队（崇拜）", "奥特兰克山谷", "2,000荣誉点数"),
    43768: ("联盟", "影月谷 > 蛮锤要塞", "50金币"),
    44918: ("部落", "影月谷 > 影月村", "50金币"),
    16264: ("银月城", "永歌森林 > 银月城", "10金币（声望折扣）"),
    17584: ("埃索达", "秘蓝岛 > 埃索达", "10金币（声望折扣）"),
    21485: ("玛格汉（崇拜）", "纳格兰 > 加拉达尔", "100金币（声望折扣）"),
    20241: ("库雷尼（崇拜）", "纳格兰 > 塔拉", "100金币（声望折扣）"),
    23367: ("沙塔尔天空卫队（崇拜）", "泰罗卡森林 > 斯克提斯", "200金币"),
    23489: ("灵翼之龙（崇拜）", "影月谷 > 灵翼浮岛", "200金币"),
    24510: ("美酒节", "美酒节营地", "200枚美酒节奖币"),
    17904: ("塞纳里奥远征队（崇拜）", "赞加沼泽 > 塞纳里奥庇护所", "2,000金币"),
    29587: ("黑锋骑士团（崇拜）", "冰冠冰川 > 暗影拱顶", "2,000金币"),
    32533: ("龙眠联军（崇拜）", "龙骨荒野 > 龙眠神殿", "2,000金币"),
    32294: ("联盟", "达拉然 > 银色领地", "2,000金币"),
    32296: ("部落", "达拉然 > 夺日者圣殿", "2,000金币"),
    32216: ("无", "达拉然 > 坐骑商人", "10,000金币"),
    32540: ("无", "达拉然 > 坐骑商人", "10,000金币"),
    31910: ("神谕者（崇敬）", "索拉查盆地 > 雨声树屋", "未成熟的毒囊"),
    33307: ("暴风城勇士", "冰冠冰川 > 银色锦标赛", "5枚冠军的徽记"),
    33554: ("暗矛巨魔勇士", "冰冠冰川 > 银色锦标赛", "5枚冠军的徽记"),
    33310: ("铁炉堡勇士", "冰冠冰川 > 银色锦标赛", "5枚冠军的徽记"),
    33653: ("达纳苏斯勇士", "冰冠冰川 > 银色锦标赛", "5枚冠军的徽记"),
    33650: ("诺莫瑞根勇士", "冰冠冰川 > 银色锦标赛", "5枚冠军的徽记"),
    33657: ("埃索达勇士", "冰冠冰川 > 银色锦标赛", "5枚冠军的徽记"),
    33553: ("奥格瑞玛勇士", "冰冠冰川 > 银色锦标赛", "5枚冠军的徽记"),
    33556: ("雷霆崖勇士", "冰冠冰川 > 银色锦标赛", "5枚冠军的徽记"),
    33557: ("银月城勇士", "冰冠冰川 > 银色锦标赛", "5枚冠军的徽记"),
    33555: ("幽暗城勇士", "冰冠冰川 > 银色锦标赛", "5枚冠军的徽记"),
    257969: ("旧集换式卡牌游戏兑换", "藏宝海湾 > 藏宝海湾港口", "已绝版"),
    34885: ("银色北伐军（崇拜）", "冰冠冰川 > 银色锦标赛", "100枚冠军的徽记"),
    48510: ("锈水财阀（崇拜）", "奥格瑞玛", "100金币（声望折扣）"),
    48617: ("无", "奥丹姆 > 拉穆卡恒", "80金币"),
    50409: ("无", "奥丹姆", "骆驼雕像事件奖励"),
    14846: ("暗月马戏团", "暗月岛", "180张暗月奖券"),
    32837: ("复活节", "复活节商人", "500个复活节巧克力"),
    37674: ("情人节", "暴风城 / 奥格瑞玛", "270个爱情信物"),
    55285: ("无", "吉尔尼斯 > 格雷迈恩庄园", "10,000金币"),
    63721: ("卡鲁亚克（崇拜）", "卡鲁亚克 > 霜火岭渔点", "5,000金币"),
    66022: ("熊猫人（直接购买）", "奥格瑞玛 > 荣誉谷 / 暴风城", "1金币"),
    64518: ("无", "昆莱山 > 野牛人前线", "3,000金币"),
    248108: ("至尊天神（崇拜）", "锦绣谷 > 至尊天神庭院", "2,500金币"),
    64599: ("卡拉克西（崇拜）", "恐惧废土 > 卡拉克西维斯", "2,000金币"),
    73306: ("云端翔龙骑士团（崇拜）", "翡翠林 > 百木园", "3,000金币"),
    59908: ("金莲教（崇拜）", "锦绣谷 > 双月殿 / 七星殿", "2,500金币"),
    64595: ("影踪派（崇拜）", "螳螂高原 > 影踪卫戍营", "2,500金币"),
    58706: ("阡陌客（崇拜）", "四风谷 > 半山", "2,000金币"),
    64605: ("游学者周卓（崇拜）", "锦绣谷 > 魔古山宫殿", "600金币"),
    69161: ("无", "巨兽岛", "乌达斯塔掉落"),
    258121: ("无", "巨兽岛", "9,999根巨兽骨头"),
    73190: ("挑战模式", "潘达利亚挑战模式商人", "挑战模式：黄金"),
    73151: ("挑战模式", "潘达利亚挑战模式商人", "挑战模式：黄金"),
    73307: ("皇帝少昊（崇拜）", "永恒岛 > 天神庭院", "2,000枚永恒铸币"),
    267317: ("至尊天神（崇拜）", "锦绣谷 > 至尊天神庭院", "2,500金币"),
}

PRICE = {
    # Fast racial mounts and their tournament counterparts use a different
    # price than the basic stock in their otherwise shared vendor group.
    **{spell: "100金币（声望折扣）" for spell in (23219,23221,23338,23227,23228,23229,23238,23239,23240,23241,23242,23243,23246,23247,23248,23249,23250,23251,23252)},
    **{spell: "100枚冠军的徽记" for spell in (63232,63635,63636,63637,63638,63639,63640,63641,63642,63643,65637,65638,65639,65640,65641,65642,65643,65644,65645,65646)},
    61425: "20,000金币", 61447: "20,000金币", 61469: "10,000金币", 61470: "10,000金币",
    122708: "120,000金币", 127220: "3,000金币", 127216: "3,000金币",
    **{spell: "10金币" for spell in (120822, 127293, 127295, 127302, 127308, 127310)},
}

SPECIAL = {
    62048: ("无", "旧版本商城", "黑色龙鹰坐骑：已绝版"),
    63844: ("银色北伐军（崇拜）", "冰冠冰川 > 银色锦标赛", "150枚冠军的徽记"),
    74856: ("旧版本商城", "游戏商城", "炽焰角鹰兽：已绝版"),
    90621: ("联盟", "暴风城", "100金币（声望折扣）"),
    93644: ("部落", "奥格瑞玛", "100金币（声望折扣）"),
    124408: ("云端翔龙骑士团（崇拜）", "翡翠林 > 百木园", "3,000金币"),
    129918: ("金莲教（崇拜）", "锦绣谷 > 双月殿 / 七星殿", "2,500金币"),
    142910: ("旧版本商城", "游戏商城", "钢铁战马：已绝版"),
    435115: ("旧版本商城", "游戏商城", "护卫魁麟：已绝版"),
}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--catalog", type=Path, required=True)
    args = parser.parse_args()
    catalog = json.loads(args.catalog.read_text(encoding="utf-8"))
    changed = 0
    missing = []
    for mount in catalog["mounts"]:
        if mount.get("status") != "candidate":
            continue
        source = next((s for s in mount.get("sources", []) if s.get("type") == "vendor"), None)
        if not source:
            continue
        spell_id = mount["ids"]["spellIDs"][0]
        npc = next((node for node in source.get("path", []) if node.get("kind") == "npc"), None)
        if npc and npc.get("refID") in NPC:
            faction, location, default_price = NPC[npc["refID"]]
            if npc["refID"] == 66022:
                source["path"] = [
                    {"kind": "faction", "refID": None, "labels": labels("熊猫人：直接购买；其他种族：火金派或土水派（崇拜）")},
                    {"kind": "zone", "refID": None, "labels": labels(location)},
                    {"kind": "custom", "refID": None, "labels": labels("乌龟大师吴玳（部落）/ 老白鼻（联盟）")},
                ]
                source["requirements"]["notes"] = {"enUS": "Six standard and six great dragon turtles; mount spells, not inventory items.", "zhCN": "普通龙龟 6 只、巨型龙龟 6 只；均为召唤法术，非背包物品。"}
            else:
                npc["kind"] = "npc"
                source["path"] = (
                    ([] if faction == "无" else [{"kind": "faction", "refID": None, "labels": labels(faction)}])
                    + [{"kind": "zone", "refID": None, "labels": labels(location)}, npc]
                )
            price = PRICE.get(spell_id, default_price)
        elif spell_id in SPECIAL:
            faction, location, price = SPECIAL[spell_id]
            name = mount["identity"]["names"]["zhCN"]
            source["path"] = (
                ([] if faction == "无" else [{"kind": "faction", "refID": None, "labels": labels(faction)}])
                + [{"kind": "zone", "refID": None, "labels": labels(location)},
                {"kind": "custom", "refID": None, "labels": labels(name)},
            ]
            )
        else:
            # A prior verified pass may already have converted the NPC node to a
            # named node without a database refID.  It is complete, so leave it
            # intact rather than treating it as an unresolved record.
            if any(node.get("kind") == "npc" and node.get("labels", {}).get("zhCN") for node in source.get("path", [])):
                continue
            missing.append(spell_id)
            continue
        source["requirements"]["price"] = {"enUS": price, "zhCN": price}
        if not (npc and npc.get("refID") == 66022):
            source["requirements"]["notes"] = {"enUS": None, "zhCN": None}
        changed += 1
    if missing:
        raise ValueError(f"merchant records without metadata: {missing}")
    args.catalog.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(f"completed {changed} candidate vendor paths")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
