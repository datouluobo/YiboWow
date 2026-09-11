#!/usr/bin/env python3
"""Complete the faction-specific 50-attempt Trial of the Grand Crusader mounts."""
import argparse
import json
from pathlib import Path


def labels(text):
    return {"enUS": text, "zhCN": text}


DATA = {
    68187: ("ALLIANCE", 4156, "十字军的白色战马"),
    68188: ("HORDE", 4079, "十字军的黑色战马"),
}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--catalog", type=Path, required=True)
    args = parser.parse_args()
    catalog = json.loads(args.catalog.read_text(encoding="utf-8"))
    changed = 0
    for mount in catalog["mounts"]:
        spell_id = mount["ids"]["spellIDs"][0]
        if spell_id not in DATA:
            continue
        faction, achievement_id, name = DATA[spell_id]
        source = {
            "sourceID": f"trial-tribute-source-{spell_id}",
            "type": "achievement",
            "priority": 100,
            "active": False,
            "availability": "unavailable",
            "path": [
                {"kind": "zone", "refID": None, "labels": labels("冰冠冰川")},
                {"kind": "instance", "refID": None, "labels": labels("大十字军的试炼25H（50箱、全程无人死亡）")},
                {"kind": "achievement", "refID": achievement_id, "labels": labels("对不朽的嘉奖")},
            ],
            "requirements": {
                "difficulties": ["TWENTY_FIVE", "HEROIC"],
                "difficultyInPath": True,
                "reputation": None, "costs": [],
                "price": {"enUS": None, "zhCN": None},
                "questID": None, "achievementID": achievement_id,
                "eventKey": None,
                "notes": labels("巫妖王之怒阶段限定；奖励来自银色北伐军的嘉奖宝箱。"),
            },
        }
        mount["restrictions"]["factions"] = [faction]
        mount["sources"] = [source]
        mount["primarySourceID"] = source["sourceID"]
        mount["status"] = "verified"
        changed += 1
    args.catalog.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(f"completed {changed} Trial tribute mount sources")


if __name__ == "__main__":
    main()
