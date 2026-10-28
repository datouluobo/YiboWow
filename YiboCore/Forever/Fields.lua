local Core = _G.YiboCore
Core._private.archiveFields = {
    ["character.identity"] = true, ["character.level"] = true, ["character.zone"] = true,
    ["character.profession-primary"] = true, ["character.profession-secondary"] = true,
    ["character.archaeology"] = true, ["character.fishing"] = true, ["character.cooking"] = true, ["character.first-aid"] = true,
}
-- This target's professions use authoritative skillLineID, not historical slot meanings.
Core._private.professionSlotIDs = {}
