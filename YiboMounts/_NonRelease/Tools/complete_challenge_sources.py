#!/usr/bin/env python3
"""Normalize Mists of Pandaria Classic Challenge Mode mount sources."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


def labels(text: str) -> dict[str, str]:
    return {"enUS": text, "zhCN": text}


def node(kind: str, text: str) -> dict:
    return {"kind": kind, "refID": None, "labels": labels(text)}


def requirements(price: str | None = None, note: str | None = None) -> dict:
    return {
        "difficulties": [],
        "reputation": None,
        "costs": [],
        "price": labels(price) if price else {"enUS": None, "zhCN": None},
        "questID": None,
        "achievementID": None,
        "eventKey": None,
        "notes": labels(note) if note else {"enUS": None, "zhCN": None},
    }


def source(source_id: str, source_type: str, path: list[dict], price: str | None = None, note: str | None = None, availability: str = "obtainable") -> dict:
    return {
        "sourceID": source_id,
        "type": source_type,
        "priority": 100,
        "active": True,
        "availability": availability,
        "path": path,
        "requirements": requirements(price, note),
    }


VENDOR_PATH = [
    node("faction", "挑战模式"),
    node("zone", "七星殿上层（联盟）/ 双月殿上层（部落）"),
    node("npc", "贾洛夫·铁心（联盟）/ 维克多·费尔霍洛（部落）"),
]

COIN_MOUNTS = {
    1298512: ("300 白金币", "挑战模式第3赛季新增白金币兑换坐骑。"),
    1302506: ("300 白金币", "挑战模式第3赛季新增白金币兑换坐骑。"),
    107517: ("150 白金币", "旧复活卷轴坐骑在怀旧服挑战模式商店提供兑换渠道。"),
    387308: ("70 白金币", "经典怀旧服挑战模式白金币商人新增兑换渠道。"),
    387321: ("40 白金币", "经典怀旧服挑战模式白金币商人新增兑换渠道。"),
}

PHOENIXES = {129552, 132117, 132118, 132119}

SEASONAL_SOURCES = {
    1247596: ("挑战模式第2赛季排行榜（头衔「雾裔」）奖励", "unavailable", "S2 已结算，当前无法获取。"),
    1247597: ("挑战模式第3赛季：全部9本副本钻石评价（头衔「迷雾继承者」）奖励", "unknown", "S3 赛季奖励，赛季结算后绝版。"),
    1247598: ("挑战模式第1赛季排行榜极速线（头衔「迷雾行者」）奖励", "unavailable", "S1 已结算，当前无法获取。"),
    1298510: ("挑战模式第3赛季：全部9本副本钻石评价奖励", "unknown", "S3 赛季奖励，赛季结算后绝版。"),
}

NON_CHALLENGE_FALSE_POSITIVES = {
    146615: ("联盟 PvP 第14赛季", "暴风城 > 通灵领主赛普", "1 邪气鞍座"),
    146622: ("部落 PvP 第14赛季", "奥格瑞玛 > 亡灵卫兵奈萨里安", "1 邪气鞍座"),
}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--catalog", type=Path, required=True)
    args = parser.parse_args()
    catalog = json.loads(args.catalog.read_text(encoding="utf-8"))
    by_spell = {mount["ids"]["spellIDs"][0]: mount for mount in catalog["mounts"]}

    for spell_id in PHOENIXES:
        mount = by_spell[spell_id]
        mount["status"] = "verified"
        mount["sources"] = [
            source(
                f"challenge-silver-{spell_id}",
                "achievement",
                [node("achievement", "挑战征服者：白银（全部9个挑战模式副本达到白银）"), node("custom", "邮件收取先祖凤凰蛋后向凯·落羽选择颜色")],
                note="四种熊猫人凤凰四选一；同一角色通过白银成就获得一枚先祖凤凰蛋。",
            ),
            source(
                f"platinum-coin-vendor-{spell_id}",
                "vendor",
                VENDOR_PATH,
                price="50 白金币",
                note="已完成挑战征服者：白银后，也可由白金币商人兑换。",
            ),
        ]
        mount["primarySourceID"] = f"challenge-silver-{spell_id}"

    for spell_id, (price, note) in COIN_MOUNTS.items():
        mount = by_spell[spell_id]
        coin_source = source(f"platinum-coin-vendor-{spell_id}", "vendor", VENDOR_PATH, price=price, note=note)
        existing = [item for item in mount.get("sources", []) if item.get("sourceID") != coin_source["sourceID"]]
        mount["sources"] = [coin_source, *existing]
        mount["primarySourceID"] = coin_source["sourceID"]
        mount["status"] = "verified"

    for spell_id, (path_text, availability, note) in SEASONAL_SOURCES.items():
        mount = by_spell[spell_id]
        source_id = mount["primarySourceID"]
        seasonal_source = next(item for item in mount["sources"] if item["sourceID"] == source_id)
        seasonal_source["type"] = "achievement"
        seasonal_source["availability"] = availability
        seasonal_source["path"] = [node("achievement", path_text)]
        seasonal_source["requirements"] = requirements(note=note)

    for spell_id, (faction, location, price) in NON_CHALLENGE_FALSE_POSITIVES.items():
        mount = by_spell[spell_id]
        source_id = mount["primarySourceID"]
        pvp_source = next(item for item in mount["sources"] if item["sourceID"] == source_id)
        pvp_source["type"] = "vendor"
        pvp_source["path"] = [node("faction", faction), node("zone", location), node("npc", "邪气鞍座兑换商")]
        pvp_source["requirements"] = requirements(price=price, note="PvP 邪气鞍座兑换，不属于挑战模式坐骑。")

    args.catalog.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(f"completed {len(PHOENIXES) + len(COIN_MOUNTS)} Challenge Mode mount records")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
