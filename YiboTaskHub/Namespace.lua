local ADDON_NAME, Addon = ...

_G.YiboTaskHub = Addon
Addon.NAME = ADDON_NAME
Addon.VERSION = "0.6.3"

function Addon:T(key, ...)
    local Core = self.Core or _G.YiboCore
    return Core.Locale:Get("YiboTaskHub", key, ...)
end

Addon.DISPLAY_NAME = Addon:T("TEXT.ACTION_HUB.19B860")
Addon.REQUIRED_CORE_API = 13
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
