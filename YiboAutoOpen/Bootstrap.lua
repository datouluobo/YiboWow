local Addon = _G.YiboAutoOpen or {}
_G.YiboAutoOpen = Addon
Addon.NAME, Addon.VERSION = "YiboAutoOpen", "1.2.0"
Addon.runtime = { initialized = false, loggedIn = false, startupScansStarted = false, queueState = "IDLE", pauseReason = nil, generation = 0, pending = nil, scanQueued = false, deferredScanGeneration = 0, quarantined = {}, failures = {}, warned = {}, sensitiveFrames = {}, pandariaDarkSoilLoot = nil, confirmLootSourceKey = nil, recentConfirmObjects = {}, recentConfirmObjectOrder = {} }

function Addon:Print(message, level)
    if level == "verbose" and self.db and self.db.notificationMode ~= "verbose" then return end
    if level == "issue" and self.db and self.db.notificationMode == "silent" then return end
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff20e070[Yibo]|r 自动开包：" .. tostring(message)) end
end
function Addon:NotifyIssue(key, message)
    if self.runtime.warned[key] then return end
    self.runtime.warned[key] = true; self:Print(message, "issue")
end
function Addon:ResetItemRuntimeState(itemID)
    itemID = tonumber(itemID)
    if not itemID then return end
    self.runtime.failures[itemID] = nil
    self.runtime.quarantined[itemID] = nil
    self.runtime.warned["quarantine:" .. itemID] = nil
end
function Addon:ResetAllItemRuntimeState()
    self.runtime.failures = {}
    self.runtime.quarantined = {}
    for key in pairs(self.runtime.warned) do
        if type(key) == "string" and key:match("^quarantine:") then self.runtime.warned[key] = nil end
    end
end
function Addon:Initialize()
    if self.runtime.initialized and self.Database and self.Database.db then
        return true
    end
    self.Database:Initialize(); self.runtime.initialized = true
    if IsLoggedIn and IsLoggedIn() then self:StartPostLogin() end
    return true
end
function Addon:StartPostLogin()
    local firstStart = not self.runtime.loggedIn
    self.runtime.loggedIn = true
    if not firstStart then return false end
    if self.CoreIntegration then self.CoreIntegration:Initialize() end
    if self.db and self.db.scanExistingOnLogin then self:Refresh() end
    return true
end
function Addon:Refresh()
    if self.Queue then self.Queue:RequestScan() end
end
