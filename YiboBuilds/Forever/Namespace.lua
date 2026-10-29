local Addon = { NAME = "YiboBuilds", VERSION = "0.1.0", PAGE_ID = "builds" }
_G.YiboBuilds = Addon
Addon.Frame = CreateFrame("Frame")
function Addon:T(key, ...) return _G.YiboCore.Locale:Get(self.NAME, key, ...) end
function Addon:Print(message)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff20e070[Yibo] YiboBuilds:|r " .. tostring(message)) end
end
function Addon:NotifyChanged()
    if self.Core then self.Core.AccountView:NotifyPageChanged(self.PAGE_ID) end
end
