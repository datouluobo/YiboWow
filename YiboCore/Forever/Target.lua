local Core = _G.YiboCore

-- Loaded only by the Forever manifest. Shared code consumes policy, not product IDs.
Core.VERSION = "0.2.0"
Core._private.target = {
    id = "Forever",
    savedVariable = "YiboCoreForeverDB",
    requireGUID = true,
    legacyImports = false,
    supported = type(WOW_PROJECT_CAMELOT) == "number" and WOW_PROJECT_ID == WOW_PROJECT_CAMELOT,
    projectID = WOW_PROJECT_ID,
    rulesetState = "unknown",
    events = { "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_LEVEL_UP", "PLAYER_GUILD_UPDATE",
        "BAG_UPDATE_DELAYED", "SKILL_LINES_CHANGED", "ZONE_CHANGED_NEW_AREA",
        "PLAYER_REGEN_ENABLED", "DISPLAY_SIZE_CHANGED", "UI_SCALE_CHANGED" },
}
