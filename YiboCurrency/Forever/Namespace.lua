local Addon = { NAME = "YiboCurrency", VERSION = "0.2.0", PAGE_ID = "currency" }
_G.YiboCurrency = Addon
Addon.Frame = CreateFrame("Frame")
function Addon:T(key, ...) return _G.YiboCore.Locale:Get(self.NAME, key, ...) end
function Addon:Print(message)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff20e070[Yibo] YiboCurrency:|r " .. tostring(message)) end
end
function Addon:NotifyChanged()
    if not self.Core then return end
    self.GoalTargets:NotifyChanged()
    self.Core.AccountView:NotifyPageChanged(self.PAGE_ID)
    if self.ArchiveProvider and self.ArchiveProvider.ref then
        self.Core.Contracts:NotifyChanged(self.NAME, self.ArchiveProvider.ref, {reason="currency-changed"})
    end
end
