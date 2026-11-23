local Addon = _G.YiboMail
Addon.VERSION = "0.4.0-api1"
Addon.Target = { id = "Forever", savedVariable = "YiboMailForeverDB", storageScope = "current-character" }
Addon.INBOX_QUERY_SCOPE = "account"
Addon.STABLE_INBOX_LIMIT = false
Addon.CLIENT_SUPPORTED = type(WOW_PROJECT_CAMELOT) == "number" and WOW_PROJECT_ID == WOW_PROJECT_CAMELOT
Addon.FEATURES = { account = true, settings = true, send = true, sendAssist = false, collect = true, contacts = true, rules = true }
Addon.FEATURES.currencyAttachments = true
Addon.Target.nativeMoneyConfirmation = true
Addon.Target.manualGMMail = true
Addon.Target.mailNamesHaveSpaces = true
Addon.Target.lastSendBag = Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag == 5 and 5 or nil
Addon.Target.transferTrackingStartedAt = 1795006800
Addon.Target.manualScan = true
Addon.Target.events = { "PLAYER_ENTERING_WORLD", "PLAYER_LEAVING_WORLD", "PLAYER_LOGOUT", "MAIL_SHOW", "MAIL_CLOSED", "MAIL_INBOX_UPDATE",
    "MAIL_SUCCESS", "MAIL_FAILED", "BAG_UPDATE_DELAYED", "GET_ITEM_INFO_RECEIVED", "UI_ERROR_MESSAGE", "ADDON_ACTION_BLOCKED", "PLAYER_REGEN_ENABLED",
    "PLAYER_LOGIN", "FRIENDLIST_UPDATE", "GUILD_ROSTER_UPDATE", "MAIL_SEND_SUCCESS", "MAIL_SEND_INFO_UPDATE", "UPDATE_PENDING_MAIL" }
Addon.CAPABILITIES = { ["mail-items.query"] = 1, ["mail-items.state"] = 1, ["mail-items.events"] = 1, ["mail-items.transfers"] = 1 }
