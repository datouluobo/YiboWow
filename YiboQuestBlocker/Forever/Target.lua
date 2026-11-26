local _, addon = ...
_G.YQB = addon or {}
_G.YQB.Target = {
    version = "0.2.0",
    supported = type(WOW_PROJECT_CAMELOT) == "number" and WOW_PROJECT_ID == WOW_PROJECT_CAMELOT,
    savedVariable = "YiboQuestBlockerForeverDB",
    schemaVersion = 1,
    defaultLevel = "",
    defaultMode = "notify",
    modeHelp = "SETTINGS.FOREVER_MODE_HELP",
    blockedGroup = "FOREVER.BLOCKED_GROUP",
}
