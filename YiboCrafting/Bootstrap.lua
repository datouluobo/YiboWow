local Addon = _G.YiboCrafting
local Core = _G.YiboCore
local function L(key, ...)
    local fullKey = "UI." .. key
    return Core.Locale:Get("YiboCrafting", fullKey, ...)
end

function Addon:Initialize()
    if self.initialized then return true end
    if not (Core and Core.CheckAPIVersion and Core:CheckAPIVersion(13) and Core.HasCapability and Core.Locale) then
        return nil, self.STARTUP_REQUIREMENTS
    end
    for name, version in pairs({ ["localization"] = 1, ["basic-input"] = 1, ["item-resolver"] = 1,
        ["character-name-format"] = 1, ["character-identity"] = 1, ["account-view"] = 2,
        ["account-entry"] = 2, ["account-surface-budget"] = 2, ["character-cleanup"] = 1,
        ["characters"] = 1, ["data-domains"] = 1, ["events"] = 1, ["fields"] = 1,
        ["business-services"] = 1, ["business-providers"] = 1, ["business-item-actions"] = 2 }) do
        if not Core:HasCapability(name, version) then return nil, L("UPGRADE") .. " (" .. name .. ":" .. version .. ")" end
    end
    if not (Core.IsInitialized and Core:IsInitialized()) then return nil, L("CORE_NOT_READY") end
    if not (Core.Characters and Core.DataDomains and Core.Contracts and Core.ItemResolver and Core.AccountView and Core.UITheme
        and Core.CharacterCleanup and Core.Events and Core.Entry and Core.BusinessItemActions
        and type(Core.UITheme.CreateInput) == "function"
        and type(Core.Characters.FormatName) == "function"
        and type(Core.UITheme.CreateMatrixHeader) == "function"
        and type(Core.UITheme.SetCharacterHeader) == "function"
        and type(Core.AccountView.GetScrollSurfaceWidth) == "function") then return nil, L("UPGRADE") end
    local db, errorMessage = self.Store:Initialize()
    if not db then return nil, errorMessage end
    local registered, registerError = Core:RegisterAddon(self.NAME, { version = self.VERSION, requiredAPI = 13 })
    if not registered then return nil, registerError end
    if Core.CharacterCleanup then
        local cleanup, cleanupError = Core.CharacterCleanup:RegisterOwner(self.NAME, {
            Inspect = function(character)
                local record = db.characters[character.id]
                return {
                    hasData = record ~= nil,
                    label = L("CACHE_LABEL"),
                    detail = record and L("CACHE_PRESENT") or L("CACHE_EMPTY"),
                }
            end,
            Delete = function(character)
                db.characters[character.id] = nil
                if self.GoalTargets then self.GoalTargets:RecipeStatesChanged(character.id) end
                self:NotifyPageChanged()
                return true
            end,
        })
        if not cleanup then return nil, cleanupError end
    end
    if Core.Events then
        Core.Events:Register("CHARACTER_ID_CHANGED", self, function(_, oldID, newID)
            self.Store:MoveCharacterID(oldID, newID)
            if self.GoalTargets then self.GoalTargets:RecipeStatesChanged(newID) end
            self:NotifyPageChanged()
        end)
    end
    Core.Events:Register("DATA_DOMAIN_UPDATED", self, function(_, change)
        if change.domainID == "professions" then self:NotifyPageChanged() end
    end)
    local page, pageError = self.AccountPage:Register()
    if not page then return nil, pageError end
    if self.GoalTargets then self.GoalTargets:Initialize() end
    self.initialized = true
    return true
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("TRADE_SKILL_SHOW")
frame:RegisterEvent("TRADE_SKILL_UPDATE")
frame:RegisterEvent("NEW_RECIPE_LEARNED")
frame:RegisterEvent("SPELLS_CHANGED")
-- Some client builds expose this event while others do not.  The stage-0
-- probe treats it as optional, so registration must not prevent addon startup.
pcall(frame.RegisterEvent, frame, "TRADE_SKILL_LIST_UPDATE")

local scanSequence = 0
local pendingStateReason
local function ScheduleRecipeScan(reason, delay)
    if reason == "PLAYER_LOGIN" or reason == "TRADE_SKILL_SHOW"
        or reason == "NEW_RECIPE_LEARNED" or reason == "SPELLS_CHANGED" then
        pendingStateReason = reason
    end
    scanSequence = scanSequence + 1
    local scheduledSequence = scanSequence
    local function Run()
        if scheduledSequence ~= scanSequence or not Addon.initialized then return end
        Addon.Collector:Scan(reason)
        local stateReason = pendingStateReason or reason
        pendingStateReason = nil
        if Addon.RecipeStateScanner then Addon.RecipeStateScanner:Start(stateReason) end
    end
    if C_Timer and C_Timer.After then C_Timer.After(delay, Run) else Run() end
end

frame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        local initialized, message = Addon:Initialize()
        if not initialized and message then
            if Core and type(Core.Print) == "function" then Core:Print(message)
            elseif DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("[YiboCrafting] " .. message) end
        end
        if initialized then ScheduleRecipeScan("PLAYER_LOGIN", 2) end
        return
    end
    if not Addon.initialized then return end
    -- TRADE_SKILL_SHOW fires before the legacy recipe list is populated.  Wait
    -- for the window/list events to settle, coalescing the burst into one scan.
    ScheduleRecipeScan(event, (event == "TRADE_SKILL_SHOW" or event == "SPELLS_CHANGED") and 0.5 or 0.2)
end)

if Core and Core.Events then
    Core.Events:Register("CORE_READY", Addon, function()
        if not Addon.initialized then
            local ok = Addon:Initialize()
            if ok then ScheduleRecipeScan("PLAYER_LOGIN", 2) end
        end
    end)
end
