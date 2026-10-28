local Core = _G.YiboCore
Core.VERSION = "0.1.0"
Core._private.target = {
    id = "Retail", savedVariable = "YiboCoreRetailDB",
    requireGUID = true, legacyImports = false, requireStampedStore = true,
    directoryIdentityOnly = true,
    supported = type(WOW_PROJECT_MAINLINE) == "number" and WOW_PROJECT_ID == WOW_PROJECT_MAINLINE,
    projectID = WOW_PROJECT_ID, rulesetState = "unknown",
    identityEvents = { PLAYER_LOGIN = true, PLAYER_ENTERING_WORLD = true, PLAYER_LEVEL_UP = true },
    characterEvents = { PLAYER_LEVEL_UP = true },
    events = { "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_LEVEL_UP",
        "PLAYER_REGEN_ENABLED", "DISPLAY_SIZE_CHANGED", "UI_SCALE_CHANGED" },
}
