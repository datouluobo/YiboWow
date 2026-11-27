local Addon = { NAME = "YiboReputation", VERSION = "0.3.0", PAGE_ID = "reputation" }
_G.YiboReputation = Addon
Addon.Frame = CreateFrame("Frame")
function Addon:T(key, ...) return _G.YiboCore.Locale:Get(self.NAME, key, ...) end
function Addon:Print(message)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff20e070[Yibo] YiboReputation:|r " .. tostring(message)) end
end
function Addon:NotifyChanged()
    self._matrixDataRevision = (self._matrixDataRevision or 0) + 1
    self._matrixSnapshotCache, self._matrixNodeCaches = nil, nil
    if self.Core then self.Core.AccountView:NotifyPageChanged(self.PAGE_ID) end
end
