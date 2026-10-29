local Addon = _G.YiboMail
Addon.VERSION = "0.1.0-api1"
Addon.Target = { id = "Forever", savedVariable = "YiboMailForeverDB" }
Addon.CLIENT_SUPPORTED = type(WOW_PROJECT_CAMELOT) == "number" and WOW_PROJECT_ID == WOW_PROJECT_CAMELOT
Addon.FEATURES = { account = true, settings = true, send = false, sendAssist = false }
Addon.CAPABILITIES = { ["mail-items.query"] = 1, ["mail-items.state"] = 1, ["mail-items.events"] = 1 }
