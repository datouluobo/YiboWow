local Addon = _G.YiboAutoOpen
Addon.VERSION = "0.1.3"
Addon.REQUIRED_CORE_API = 13
Addon.Target = { id = "Forever", savedVariable = "YiboAutoOpenForeverDB", requireCore = true,
    supported = type(WOW_PROJECT_CAMELOT) == "number" and WOW_PROJECT_ID == WOW_PROJECT_CAMELOT,
    catalog = { version = 1, defaultOrder = {}, manualOnly = {}, excludedFromCatalog = {}, migrations = {} } }
