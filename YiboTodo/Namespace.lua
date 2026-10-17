local ADDON_NAME = ...

local Addon = _G.YiboTodo or {}
_G.YiboTodo = Addon
Addon.NAME = ADDON_NAME or "YiboTodo"
Addon.VERSION = "1.2.2"
Addon.REQUIRED_CORE_API = 13
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
        DEFAULT_CHAT_FRAME:AddMessage(self:T("CHAT.PREFIX") .. tostring(message))
    end
end

function Addon:T(key, ...)
    local core = self.Core or _G.YiboCore
    if core and core.Locale and type(core.Locale.Get) == "function" then
        return core.Locale:Get(self.NAME, key, ...)
    end
    -- This fallback is limited to the bootstrap failure path: the older Core
    -- being reported cannot provide the required localization service.
    if key == "ERROR.CORE_REQUIRED" then
        return "YiboTodo requires YiboCore API v13 with localization:1, character-identity:1, character-name-format:1, and account-entry:2. Please update YiboCore."
    elseif key == "ERROR.INTEGRATION" then
        return string.format("Core integration failed: %s", tostring((...)))
    elseif key == "CHAT.PREFIX" then
        return "|cff20e070[Yibo]|r Account Tasks: "
    end
    return "[" .. self.NAME .. ":" .. tostring(key) .. "]"
end

-- Prefer the game's current-client name for entities with stable IDs. Catalog
-- labels remain the fallback when data is unavailable, so localized clients
-- keep their existing text even while quest/item data is loading.
function Addon:GetLocalizedGameName(kind, id, fallback)
    id = tonumber(id)
    if not id then return fallback end
    local ok, name
    if kind == "spell" then
        if C_Spell and type(C_Spell.GetSpellInfo) == "function" then
            ok, name = pcall(C_Spell.GetSpellInfo, id)
            if ok and type(name) == "table" then name = name.name end
        end
        if (not ok or type(name) ~= "string" or name == "") and type(GetSpellInfo) == "function" then
            ok, name = pcall(GetSpellInfo, id)
        end
    elseif kind == "item" then
        if C_Item and type(C_Item.GetItemNameByID) == "function" then
            ok, name = pcall(C_Item.GetItemNameByID, id)
        end
        if (not ok or type(name) ~= "string" or name == "") and type(GetItemInfo) == "function" then
            ok, name = pcall(GetItemInfo, id)
        end
    elseif kind == "quest" then
        if C_QuestLog and type(C_QuestLog.GetTitleForQuestID) == "function" then
            ok, name = pcall(C_QuestLog.GetTitleForQuestID, id)
        end
        if (not ok or type(name) ~= "string" or name == "") and C_QuestLog and type(C_QuestLog.GetQuestInfo) == "function" then
            ok, name = pcall(C_QuestLog.GetQuestInfo, id)
        end
    end
    if ok and type(name) == "string" and name ~= "" then return name end
    return fallback
end

function Addon:GetCooldownGroupLabel(group)
    if type(group) ~= "table" then return nil end
    local fallback = group.label or group.id
    -- Shared-cooldown labels describe the group, not one member recipe.
    -- For a single-output group the result item is the stable display identity.
    if group.aggregation ~= "single-recipe" then return fallback end
    for _, recipe in pairs(self.Catalog and self.Catalog.recipes or {}) do
        if recipe.cooldownGroupID == group.id and recipe.resultItemID then
            return self:GetLocalizedGameName("item", recipe.resultItemID, fallback)
        end
    end
    return fallback
end

function Addon:NotifyChanged(immediate, refreshTarget)
    if self.Snapshot then self.Snapshot:Invalidate() end
    if self.ActionContracts then self.ActionContracts:Changed() end
    -- A completed direct craft affects exactly one visible icon.  Update that
    -- control in place instead of rebuilding the whole account matrix.
    if refreshTarget and self.AccountPage and self.AccountPage.RefreshProjectIcon
        and self.AccountPage:RefreshProjectIcon(refreshTarget) then
        return
    end
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
