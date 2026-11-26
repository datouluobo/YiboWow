local _, addon = ...
_G.YQB = addon or {}
_G.YQB.Target = {
    version = "3.3.0",
    supported = type(WOW_PROJECT_MISTS_CLASSIC) == "number" and WOW_PROJECT_ID == WOW_PROJECT_MISTS_CLASSIC,
    savedVariable = "YiboQuestBlockerDB",
    realmScope = true,
    defaultLevel = "90",
    defaultMode = "direct",
    legacyDirectAbandons = true,
}
