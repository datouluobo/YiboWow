local ADDON_NAME = ...

local Addon = _G.YiboTodo or {}
_G.YiboTodo = Addon
Addon.NAME = ADDON_NAME or "YiboTodo"
Addon.VERSION = "1.1"
Addon.REQUIRED_CORE_API = 5
Addon.CATALOG_VERSION = 16
Addon.RULESET_ID = "mop-classic-50504"
Addon.Catalog = Addon.Catalog or { activities = {}, groups = {}, recipes = {}, rulesets = {}, farmOperations = {}, dailyActivities = {}, specialActivities = {}, monitoringGroups = {} }
Addon.Catalog.farmOperations = Addon.Catalog.farmOperations or {}
Addon.Catalog.dailyActivities = Addon.Catalog.dailyActivities or {}
Addon.Catalog.specialActivities = Addon.Catalog.specialActivities or {}
Addon.Catalog.monitoringGroups = Addon.Catalog.monitoringGroups or {}
Addon.Model = Addon.Model or {}
Addon.Providers = Addon.Providers or {}
Addon.Database = Addon.Database or {}

function Addon:Now()
    return (GetServerTime and GetServerTime()) or time()
end

function Addon:Print(message)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff20e070[YiboTodo]|r " .. tostring(message))
    end
end

function Addon:NotifyChanged(immediate)
    if self.Snapshot then self.Snapshot:Invalidate() end
    local accountView = self.Core and self.Core.AccountView
    if not accountView then return end
    if immediate and self.previewRefreshToken then
        -- Cancel a previously queued hover refresh so the profession update
        -- is the single authoritative rebuild for the new button action.
        self.previewRefreshToken = self.previewRefreshToken + 1
    end
    -- A visible hover preview is a dense account matrix.  Quest and reward
    -- plugins can emit a burst of state changes while their native panels
    -- are opening, so refresh it once two seconds after that burst settles.
    -- The normal account page and a hidden preview remain immediate.
    local frame = accountView.frame
    if not immediate and frame and frame.preview and accountView.previewPageID == "todo" and C_Timer and C_Timer.After then
        self.previewRefreshToken = (self.previewRefreshToken or 0) + 1
        local token = self.previewRefreshToken
        C_Timer.After(2, function()
            if Addon.previewRefreshToken ~= token then return end
            Addon.previewRefreshToken = nil
            accountView:NotifyPageChanged("todo")
        end)
        return
    end
    accountView:NotifyPageChanged("todo")
end
