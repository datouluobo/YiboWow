local Core = _G.YiboCore
Core._private.archiveFields = {
    ["character.identity"] = true, ["character.level"] = true, ["character.item-level"] = true,
    ["character.zone"] = true, ["character.profession-primary"] = true, ["character.profession-secondary"] = true,
    ["character.archaeology"] = true, ["character.fishing"] = true, ["character.cooking"] = true, ["character.first-aid"] = true,
}
Core._private.professionSlotIDs = { [3] = 794, [4] = 356, [5] = 185, [6] = 129 }
