local ADDON_NAME, Addon = ...

_G.YiboTaskHub = Addon
Addon.NAME = ADDON_NAME
Addon.VERSION = "0.7.0"
-- This package is Mists-only. The actual client identity is checked before
-- YiboTaskHubDB is touched or anything is registered with Core.
Addon.MatchesTarget = type(WOW_PROJECT_MISTS_CLASSIC) == "number" and WOW_PROJECT_ID == WOW_PROJECT_MISTS_CLASSIC
-- Static bilingual startup text: on a wrong client the Core language service
-- may be missing or uninitialized, so this message must not depend on it.
local STARTUP_TEXT = {
    en = { WRONG_MISTS = "Install the YiboTaskHub package for Mists. Action Hub stopped without changing saved data." },
    zh = { WRONG_MISTS = "请安装 YiboTaskHub 熊猫人之谜版本。行动中心已停止，未改动存档。" },
}
function Addon:GetStartupText(key)
    local locale = GetLocale and GetLocale()
    local language = (locale == "zhCN" or locale == "zhTW") and "zh" or "en"
    return STARTUP_TEXT[language][key] or STARTUP_TEXT.en[key] or tostring(key)
end
function Addon:PrintStartupMessage(key)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff20e070[Yibo]|r " .. self:GetStartupText(key)) end
end

function Addon:T(key, ...)
    local Core = self.Core or _G.YiboCore
    return Core.Locale:Get("YiboTaskHub", key, ...)
end

Addon.DISPLAY_NAME = Addon:T("TEXT.ACTION_HUB.19B860")
Addon.REQUIRED_CORE_API = 14
Addon.PAGE_ID = "taskhub"

function Addon:Now() return (GetServerTime and GetServerTime()) or time() end
function Addon:Print(message)
    if DEFAULT_CHAT_FRAME then
        local prefix = "Action Hub: "
        local core = self.Core or _G.YiboCore
        if core and core.Locale and type(core.Locale.Get) == "function" then prefix = self:T("CHAT.PREFIX") end
        DEFAULT_CHAT_FRAME:AddMessage("|cff20e070[Yibo]|r " .. prefix .. tostring(message))
    end
end
