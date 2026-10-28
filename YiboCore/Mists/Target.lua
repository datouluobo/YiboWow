local Core = _G.YiboCore

Core._private.target = {
    id = "Mists",
    savedVariable = "YiboCoreDB",
    requireGUID = false,
    legacyImports = true,
    supported = type(WOW_PROJECT_MISTS_CLASSIC) == "number" and WOW_PROJECT_ID == WOW_PROJECT_MISTS_CLASSIC,
    projectID = WOW_PROJECT_ID,
    rulesetState = "unknown",
    events = { "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_LEVEL_UP", "PLAYER_GUILD_UPDATE",
        "BAG_UPDATE_DELAYED", "BANKFRAME_OPENED", "PLAYERBANKSLOTS_CHANGED", "SKILL_LINES_CHANGED",
        "PLAYER_EQUIPMENT_CHANGED", "PLAYER_SPECIALIZATION_CHANGED", "ZONE_CHANGED_NEW_AREA",
        "PLAYER_REGEN_ENABLED", "DISPLAY_SIZE_CHANGED", "UI_SCALE_CHANGED" },
}
