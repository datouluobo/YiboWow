local Addon = _G.YiboAutoOpen or {}
_G.YiboAutoOpen = Addon
Addon.NAME, Addon.VERSION = "YiboAutoOpen", "1.2.7"
Addon.runtime = { initialized = false, loggedIn = false, startupScansStarted = false, worldLoading = false, recoveryUntil = nil, queueState = "IDLE", pauseReason = nil, generation = 0, pending = nil, scanQueued = false, candidateQueue = {}, candidateSet = {}, deferredScanGeneration = 0, worldScanGeneration = 0, quarantined = {}, quarantineReasons = {}, quarantineTokens = {}, failures = {}, warned = {}, sensitiveFrames = {}, pandariaDarkSoilLoot = nil, confirmLootSourceKey = nil, recentConfirmObjects = {}, recentConfirmObjectOrder = {} }

function Addon:Print(message, level)
    if level == "verbose" and self.db and self.db.notificationMode ~= "verbose" then return end
    if level == "issue" and self.db and self.db.notificationMode == "silent" then return end
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage(Addon:T("PRINT.PREFIX") .. tostring(message)) end
end
function Addon:NotifyIssue(key, message)
    if self.runtime.warned[key] then return end
    self.runtime.warned[key] = true; self:Print(message, "issue")
end
function Addon:ResetItemRuntimeState(itemID)
    itemID = tonumber(itemID)
    if not itemID then return end
    self.runtime.failures[itemID] = nil
    if self.runtime.candidateSet then self.runtime.candidateSet[itemID] = nil end
    self.runtime.quarantined[itemID] = nil
    self.runtime.quarantineReasons[itemID] = nil
    self.runtime.quarantineTokens[itemID] = (self.runtime.quarantineTokens[itemID] or 0) + 1
    self.runtime.warned["quarantine:" .. itemID] = nil
end
function Addon:ResetAllItemRuntimeState()
    self.runtime.failures = {}
    self.runtime.candidateQueue = {}
    self.runtime.candidateSet = {}
    self.runtime.quarantined = {}
    self.runtime.quarantineReasons = {}
    self.runtime.quarantineTokens = {}
    for key in pairs(self.runtime.warned) do
        if type(key) == "string" and key:match("^quarantine:") then self.runtime.warned[key] = nil end
    end
end
function Addon:Initialize()
    if self.runtime.initialized and self.Database and self.Database.db then
        return true
    end
    if self.Target and not self.Target.supported then self:NotifyIssue("wrong-target", self:T("TARGET.WRONG")); return false end
    if self.Target and self.Target.requireCore then
        local core = _G.YiboCore
        if not (core and core.IsInitialized and core:IsInitialized() and core.CheckAPIVersion and core:CheckAPIVersion(13)
            and core.HasCapability and core:HasCapability("localization", 1) and core:HasCapability("basic-input", 1) and core:HasCapability("item-resolver", 1) and core.Locale and core.Locale.Get
            and core.Locale.Register and core.ItemResolver and core.ItemResolver.Parse and core.ItemResolver.GetInfo and core.ItemResolver.Request
            and core.UITheme and core.UITheme.CreateInput and core.RegisterSettingsPanel and core.RegisterAddon and core.UITheme) then
            self:NotifyIssue("core-required", self:T("CORE.RUNTIME_REQUIRED"))
            return false
        end
    end
    if self.Target and self.Target.requireCore then self.Core = _G.YiboCore; self:RegisterLocales() end
    self.runtime.initializing = true
    self.Database:Initialize(); self.runtime.initializing = nil; self.runtime.initialized = true
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

function Addon:StatusText(state, reason)
    return self:T("STATE." .. tostring(state)) .. (reason and (" · " .. self:T("REASON." .. reason)) or "")
end
