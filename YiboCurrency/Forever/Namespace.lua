local Addon = { NAME = "YiboCurrency", VERSION = "0.1.1", PAGE_ID = "currency" }
_G.YiboCurrency = Addon
Addon.Frame = CreateFrame("Frame")
function Addon:T(key, ...) return _G.YiboCore.Locale:Get(self.NAME, key, ...) end
function Addon:Print(message)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff20e070[Yibo] YiboCurrency:|r " .. tostring(message)) end
end
function Addon:NotifyChanged()
    if self.Core then self.Core.AccountView:NotifyPageChanged(self.PAGE_ID) end
end
