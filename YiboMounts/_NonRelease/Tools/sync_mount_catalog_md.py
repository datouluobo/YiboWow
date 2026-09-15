#!/usr/bin/env python3
"""Synchronize the human-editable mount source Markdown with mounts.json."""
from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path


TYPES = {"boss_drop", "rare_drop", "achievement", "reputation_vendor", "vendor", "quest", "class_reward", "event", "promotion", "store", "auction_house", "crafted", "container", "research"}
AVAILABILITY = {"obtainable", "limited_time", "rotation", "unavailable", "unknown"}
HEADER = ["序号", "spellID", "坐骑名称", "来源类型", "商人阵营/声望", "商人位置", "来源路径（使用 > 分隔）", "价格", "状态", "可用性", "备注"]
TYPE_LABELS = {"boss_drop": "首领掉落", "rare_drop": "稀有掉落", "achievement": "成就", "reputation_vendor": "声望商人", "vendor": "商人", "quest": "任务", "class_reward": "职业奖励", "event": "活动", "promotion": "推广", "store": "商城", "auction_house": "拍卖行", "crafted": "制造", "container": "宝袋", "research": "待核实"}
STATUS_LABELS = {"candidate": "候选", "verified": "已核实", "rejected": "已排除"}
AVAILABILITY_LABELS = {"obtainable": "可获取", "limited_time": "限时", "rotation": "轮换", "unavailable": "已绝版", "unknown": "待确认"}


def state_path(document_path):
    return document_path.with_name(document_path.stem + ".sync-state.json")


def document_sha256(document_path):
    return hashlib.sha256(document_path.read_bytes()).hexdigest()


def read_state(document_path):
    path = state_path(document_path)
    if not path.exists():
        return None
    return json.loads(path.read_text(encoding="utf-8"))


def write_state(document_path, accepted_by):
    state_path(document_path).write_text(
        json.dumps({"schemaVersion": 1, "documentSha256": document_sha256(document_path), "acceptedBy": accepted_by}, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
        newline="\n",
    )


def check_document(document_path):
    if not document_path.exists():
        return "missing"
    state = read_state(document_path)
    if not state or not state.get("documentSha256"):
        return "untracked"
    return "clean" if state["documentSha256"] == document_sha256(document_path) else "modified"


def require_safe_export(document_path):
    status = check_document(document_path)
    if status == "missing":
        return
    if status == "clean":
        return
    if status == "untracked":
        raise RuntimeError(f"refusing to overwrite untracked maintenance document: {document_path}; run import first to accept its current contents")
    raise RuntimeError(f"refusing to overwrite manually modified maintenance document: {document_path}; inspect it, then run import before export")


def display(value, labels):
    return labels.get(value, value or "")


def internal(value, labels):
    reverse = {label: key for key, label in labels.items()}
    return reverse.get(value, value)


def source_of(mount):
    return next((source for source in mount.get("sources", []) if source.get("sourceID") == mount.get("primarySourceID")), None)


def source_cells(mount):
    source = source_of(mount) if mount else None
    nodes = list((source or {}).get("path", []))
    source_type = (source or {}).get("type")
    merchant_faction = ""
    merchant_location = ""
    faction_nodes = [node for node in nodes if node.get("kind") == "faction"]
    merchant_faction = " > ".join(label(node) for node in faction_nodes)
    nodes = [node for node in nodes if node.get("kind") != "faction"]
    if source_type in {"vendor", "reputation_vendor"}:
        if len(nodes) > 1:
            merchant_location = " > ".join(label(node) for node in nodes[:-1])
            nodes = nodes[-1:]
    else:
        zone_nodes = [node for node in nodes if node.get("kind") == "zone"]
        merchant_location = " > ".join(label(node) for node in zone_nodes)
        nodes = [node for node in nodes if node.get("kind") != "zone"]
    path = " > ".join(label(node) for node in nodes)
    requirements = (source or {}).get("requirements", {})
    note = (requirements.get("notes") or {}).get("zhCN") or ""
    price = (requirements.get("price") or {}).get("zhCN") or ""
    return [display(source_type, TYPE_LABELS), merchant_faction, merchant_location, path, price, display((mount or {}).get("status"), STATUS_LABELS), display((source or {}).get("availability"), AVAILABILITY_LABELS), note]


def label(node):
    labels = node.get("labels", {})
    return labels.get("zhCN") or labels.get("enUS") or ""


def ordered_active_sources(mount):
    sources = [source for source in mount.get("sources", []) if source.get("active", True)]
    primary_id = mount.get("primarySourceID")
    primary = next((source for source in sources if source.get("sourceID") == primary_id), None)
    alternatives = sorted(
        (source for source in sources if source is not primary),
        key=lambda source: (-int(source.get("priority") or 0), str(source.get("sourceID") or "")),
    )
    return ([primary] if primary else []) + alternatives


def tooltip_preview(source):
    nodes = list(source.get("path", []))
    source_type = source.get("type")
    if source_type in {"boss_drop", "rare_drop"} and len(nodes) >= 3:
        nodes = nodes[1:]
    if source_type == "vendor":
        nodes = [node for node in nodes if node.get("kind") != "faction"]
    path = " › ".join(label(node) for node in nodes if label(node))
    return display(source_type, TYPE_LABELS) + "｜" + path


def esc(value):
    return str(value or "").replace("|", "\\|").replace("\n", " ").strip()


def split_row(line):
    cells, current, escaped = [], [], False
    for char in line.strip().strip("|"):
        if escaped:
            current.append(char)
            escaped = False
        elif char == "\\":
            escaped = True
        elif char == "|":
            cells.append("".join(current).strip())
            current = []
        else:
            current.append(char)
    cells.append("".join(current).strip())
    return cells


def document_sort_key(record, mount):
    """Keep the maintainers' racial-mount audit blocks together."""
    source_type, merchant_faction, merchant_location, path, price, status, availability, note = source_cells(mount)
    source = source_of(mount) if mount else None
    labels = " > ".join(label(node) for node in (source or {}).get("path", []))
    racial_groups = (
        ("人类", "暴风城"), ("矮人", "铁炉堡"), ("暗夜精灵", "达纳苏斯"),
        ("侏儒", "诺莫瑞根"), ("德莱尼", "埃索达"), ("兽人", "奥格瑞玛"),
        ("巨魔", "暗矛"), ("牛头人", "雷霆崖"), ("血精灵", "银月城"),
        ("亡灵", "幽暗城"), ("熊猫人", "火金派/土水派"),
    )
    # Racial paladin summons are spell-based mounts; keep them beside their
    # race's vendor mounts even though they are not vendor items.
    if "血精灵圣骑士" in labels:
        group = next(index for index, (race, _) in enumerate(racial_groups) if race == "血精灵")
    elif "德莱尼圣骑士" in labels:
        group = next(index for index, (race, _) in enumerate(racial_groups) if race == "德莱尼")
    elif "牛头人圣骑士" in labels:
        group = next(index for index, (race, _) in enumerate(racial_groups) if race == "牛头人")
    elif "乌龟大师吴玳" in labels or "老白鼻" in labels:
        group = next(index for index, (race, _) in enumerate(racial_groups) if race == "熊猫人")
    else:
        # A city appearing only as a physical PvP/vendor location does not make
        # the mount a racial mount.  Group only explicit city faction labels.
        group = next((index for index, (_, city) in enumerate(racial_groups)
                      if merchant_faction == city or merchant_faction == city + "勇士"), None)
    if group is not None:
        return (0, group, record["spellID"], record.get("name", ""))
    return (1, record["spellID"], record.get("name", ""), source_type, merchant_faction, merchant_location, path, price, status, availability, note)


def export(catalog_path, inventory_path, document_path):
    require_safe_export(document_path)
    catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
    inventory = json.loads(inventory_path.read_text(encoding="utf-8"))
    by_spell = {mount["ids"]["spellIDs"][0]: mount for mount in catalog["mounts"]}
    primary_sources = [next((source for source in mount.get("sources", []) if source.get("sourceID") == mount.get("primarySourceID")), None) for mount in catalog["mounts"]]
    unavailable_count = sum(source is not None and source.get("availability") == "unavailable" for source in primary_sources)
    limited_count = sum(source is not None and source.get("availability") == "limited_time" for source in primary_sources)
    unavailable_research = sum(source is not None and source.get("availability") == "unavailable" and source.get("type") == "research" for source in primary_sources)
    multi_source_lines = [
        "### 多渠道来源人工核验",
        "",
        "多渠道坐骑在 `mounts.json` 中维护多个 `sources[]`；本表主体行继续维护主要来源，下面单列其它有效渠道。人工验收时每个渠道必须各占一条来源主行。",
        "",
        "| spellID | 坐骑名称 | 顺序 | 来源类型 | 来源路径 | Tooltip 预期 |",
        "| --- | --- | --- | --- | --- | --- |",
    ]
    for mount in sorted(catalog["mounts"], key=lambda item: item["ids"]["spellIDs"][0]):
        sources = ordered_active_sources(mount)
        if len(sources) < 2:
            continue
        spell_id = mount["ids"]["spellIDs"][0]
        name = (mount.get("identity", {}).get("names", {}).get("zhCN")
                or mount.get("identity", {}).get("names", {}).get("enUS") or "")
        for order, source in enumerate(sources, start=1):
            source_path = " > ".join(label(node) for node in source.get("path", []) if label(node))
            row = [spell_id, name, order, display(source.get("type"), TYPE_LABELS), source_path, tooltip_preview(source)]
            multi_source_lines.append("| " + " | ".join(esc(value) for value in row) + " |")
    multi_source_lines.append("")
    lines = [
        "# Yibo Mounts 手工维护目录",
        "",
        "此表覆盖目标客户端 API 的全部 526 个坐骑 spellID。十一组种族坐骑优先按种族分组：人类（暴风城）、矮人（铁炉堡）、暗夜精灵（达纳苏斯）、侏儒（诺莫瑞根）、德莱尼（埃索达）、兽人（奥格瑞玛）、巨魔（暗矛）、牛头人（雷霆崖）、血精灵（银月城）、亡灵（幽暗城）、熊猫人（火金派/土水派）。熊猫人组包含乌龟大师吴玳（部落奥格瑞玛）与老白鼻（联盟暴风城）出售的 12 款龙龟坐骑：普通龙龟 6 只（1 金币）与巨型龙龟 6 只（10 金币）；熊猫人可直接购买，其他种族需火金派或土水派崇拜。均为召唤法术，非背包物品。每组内按 spellID 排列，包含普通、迅捷、银色锦标赛与适用的职业召唤变体。其余记录按 spellID 排列。只编辑数据行的“来源类型 / 商人阵营或声望 / 商人位置 / 来源路径 / 价格 / 状态 / 可用性 / 备注”；来源路径用 ` > ` 分隔。普通商人的阵营归属只用于维护与筛选，不重复进入 Tooltip；声望商人的声望阵营仍属于获取路径。联盟/部落拥有不同 spellID 时必须各建一行、各自写明来源；同 spellID 的双阵营来源在备注中标明另一阵营，待多来源字段启用后再拆分。",
        "",
        "## Tooltip 人工验收",
        "",
        "Tooltip 只回答“去哪里、找谁、需要什么”。表格中的“备注”是核验资料，**永不直接显示给玩家**；如确有无法结构化的必要条件，应在 JSON 的 `requirements.tooltipNote` 中单独维护不超过 24 个字符的短说明。`待核实` 类型不进入 Tooltip。",
        "",
        "人工抽查时统一验证：第一行使用“来源类型｜地点 › 目标”的路径层级；第二行仅使用“ · ”连接难度、声望、价格、短说明和可用性；普通商人不重复显示阵营归属或“坐骑商人”等泛称；绝版、限时和轮换状态使用统一短文案；任意维护备注、证据说明、版本沿革和公告解释均不得出现。",
        "",
        "| 场景 | 预期第一行 | 预期第二行 |",
        "| --- | --- | --- |",
        "| 首领掉落 | 掉落｜副本 › 首领 | 仅在确有难度条件时显示 |",
        "| 普通商人 | 商人｜地点 › NPC | 价格；没有条件则不显示 |",
        "| 声望商人 | 声望｜阵营 › 地点 › NPC | 崇拜 · 价格 |",
        "| 活动/推广 | 活动或推广｜活动名称 | 限时获取 / 轮换开放 / 当前已无法获取 |",
        "| 待核实 | 不追加 YiboMounts 内容 | 不追加 YiboMounts 内容 |",
        "",
        *multi_source_lines,
        "",
        "## 职业坐骑审计",
        "",
        "当前客户端坐骑列表中的职业召唤法术共 11 条，均非背包物品：术士（所有种族）为地狱战马 5784、恐惧战马 23161；死亡骑士（所有种族）为阿彻鲁斯死亡战马 48778；人类/矮人圣骑士为军马 13819、战马 23214；血精灵圣骑士为奎尔萨拉斯战马 34767、奎尔萨拉斯军马 34769；德莱尼圣骑士为主教的雷象 73629、大主教的雷象 73630；牛头人圣骑士（烈日行者）为烈日行者科多兽 69820、巨型烈日行者科多兽 69826。德鲁伊形态等不进入此客户端的坐骑 spellID 清单，故不在本表计数。",
        "",
        "## 60–90 级声望坐骑审计",
        "",
        "已规范 67 条“崇拜”声望商人来源：60 级战场声望 2 条、外域 21 条、诺森德 9 条、大地的裂变 5 条、潘达利亚 30 条。每条均以“声望商人”显示，并记录崇拜阵营、购买 NPC、地图地点和价格。熊猫人龙龟另属种族坐骑：熊猫人可直接购买，其他种族才需要火金派或土水派崇拜，因此不计入此 67 条。",
        "",
        "## PVP 坐骑审计",
        "",
        "当前客户端目录中的 PVP 相关坐骑共 33 条：奥特兰克山谷声望商人 2 条、荣誉点数商人 9 条、评级战场成就 4 条、敌对阵营主城首领成就 2 条、竞技场角斗士赛季奖励 16 条。竞技场奖励均明确标注赛季限定；历史赛季条目保留来源供已收集角色查询。",
        "",
        "## 绝版与限时审计",
        "",
        f"已核实 {unavailable_count} 条当前不可新获取记录及 {limited_count} 条限时/轮换记录。当前不可获取条目的来源均已写明；其中“来源待核实”的绝版条目为 {unavailable_research} 条。目标版本外、技术/任务临时法术，以及仍可由商城、声望或任务渠道取得的坐骑不标为绝版；具体来源和结束原因见数据行备注。",
        "",
        "来源类型：首领掉落、稀有掉落、成就、声望商人、商人、任务、职业奖励、活动、推广、商城、拍卖行、制造、宝袋、待核实。状态：候选、已核实、已排除。可用性：可获取、限时、轮换、已绝版、待确认。待核实不进入 Tooltip；空来源表示尚未建立记录。每次写入前先运行 check；手工修改必须先 import，export 会拒绝覆盖未导入的修改。",
        "",
        "| " + " | ".join(HEADER) + " |",
        "| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |",
    ]
    records = sorted(inventory["mounts"], key=lambda record: document_sort_key(record, by_spell.get(record["spellID"])))
    for sequence, record in enumerate(records, start=1):
        spell_id = record["spellID"]
        mount = by_spell.get(spell_id)
        row = [sequence, spell_id, record.get("name", ""), *source_cells(mount)]
        lines.append("| " + " | ".join(esc(value) for value in row) + " |")
    document_path.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
    write_state(document_path, "export")
    print(f"exported {len(inventory['mounts'])} rows to {document_path}")


def new_mount(spell_id, inventory_by_spell):
    source = inventory_by_spell[spell_id]
    return {
        "mountKey": "manual-" + str(spell_id), "status": "candidate",
        "ids": {"spellIDs": [spell_id], "itemIDs": [], "mountJournalID": source.get("mountJournalID")},
        "identity": {"iconFileID": source.get("icon"), "names": {"enUS": "Mount " + str(spell_id), "zhCN": source.get("name", "Mount " + str(spell_id))}},
        "restrictions": {"factions": [], "classes": []}, "primarySourceID": "manual-source-" + str(spell_id), "sources": [],
    }


def import_document(catalog_path, inventory_path, document_path):
    catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
    inventory = json.loads(inventory_path.read_text(encoding="utf-8"))
    inventory_by_spell = {row["spellID"]: row for row in inventory["mounts"]}
    by_spell = {mount["ids"]["spellIDs"][0]: mount for mount in catalog["mounts"]}
    changed = 0
    changed_spell_ids = []
    for line in document_path.read_text(encoding="utf-8").splitlines():
        if not line.startswith("|") or line.startswith("| ---") or line.startswith("| 序号 | spellID |"):
            continue
        cells = split_row(line)
        if len(cells) != len(HEADER) or not cells[0].isdigit() or not cells[1].isdigit() or int(cells[1]) not in inventory_by_spell:
            continue
        spell_id = int(cells[1]); source_type, merchant_faction, merchant_location, path_text, price, status, availability, note = cells[3:]
        if not source_type and not path_text:
            continue
        if [source_type, merchant_faction, merchant_location, path_text, price, status, availability, note] == source_cells(by_spell.get(spell_id)):
            continue
        source_type = internal(source_type, TYPE_LABELS)
        status = internal(status, STATUS_LABELS)
        availability = internal(availability, AVAILABILITY_LABELS)
        if source_type not in TYPES:
            raise ValueError(f"spellID {spell_id}: unsupported source type {source_type!r}")
        if not path_text:
            raise ValueError(f"spellID {spell_id}: source path is required when source type is set")
        if status not in {"candidate", "verified", "rejected"}:
            raise ValueError(f"spellID {spell_id}: unsupported status {status!r}")
        if availability not in AVAILABILITY:
            raise ValueError(f"spellID {spell_id}: unsupported availability {availability!r}")
        mount = by_spell.setdefault(spell_id, new_mount(spell_id, inventory_by_spell))
        existing_source = source_of(mount)
        existing_tooltip_note = ((existing_source or {}).get("requirements") or {}).get("tooltipNote")
        alternative_sources = [source for source in mount.get("sources", []) if source.get("sourceID") != mount.get("primarySourceID")]
        parts = [part.strip() for part in path_text.split(">") if part.strip()]
        nodes = []
        nodes.extend({"kind": "faction", "refID": None, "labels": {"enUS": part.strip(), "zhCN": part.strip()}} for part in merchant_faction.split(">") if part.strip())
        nodes.extend({"kind": "zone", "refID": None, "labels": {"enUS": part.strip(), "zhCN": part.strip()}} for part in merchant_location.split(">") if part.strip())
        nodes.extend({"kind": "custom", "refID": None, "labels": {"enUS": part, "zhCN": part}} for part in parts)
        source_id = "manual-source-" + str(spell_id)
        mount["status"] = status
        mount["primarySourceID"] = source_id
        mount["sources"] = [{"sourceID": source_id, "type": source_type, "priority": 100, "active": True, "availability": availability, "path": nodes, "requirements": {"difficulties": [], "reputation": None, "costs": [], "price": {"enUS": price or None, "zhCN": price or None}, "questID": None, "achievementID": None, "eventKey": None, "tooltipNote": existing_tooltip_note, "notes": {"enUS": note or None, "zhCN": note or None}}}, *alternative_sources]
        changed += 1
        changed_spell_ids.append(str(spell_id))
    catalog["mounts"] = sorted(by_spell.values(), key=lambda mount: mount["ids"]["spellIDs"][0])
    catalog_path.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    write_state(document_path, "import")
    suffix = f" (spellIDs: {', '.join(changed_spell_ids)})" if changed_spell_ids else ""
    print(f"imported {changed} documented source rows into {catalog_path}{suffix}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=("check", "export", "import"))
    parser.add_argument("--catalog", type=Path, required=True)
    parser.add_argument("--inventory", type=Path, required=True)
    parser.add_argument("--document", type=Path, required=True)
    args = parser.parse_args()
    try:
        if args.mode == "check":
            print(f"maintenance document is {check_document(args.document)}: {args.document}")
        elif args.mode == "export":
            export(args.catalog, args.inventory, args.document)
        else:
            import_document(args.catalog, args.inventory, args.document)
    except RuntimeError as error:
        parser.exit(2, f"error: {error}\n")


if __name__ == "__main__": main()
