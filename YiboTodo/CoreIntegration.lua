local Addon = _G.YiboTodo
local Integration = {}
Addon.CoreIntegration = Integration
local ICON = "Interface\\AddOns\\YiboTodo\\Media\\YiboTodoIcon-v6"

function Integration:Initialize()
    if self.initialized then return true end
    local Core = _G.YiboCore
    if not (Core and Core.CheckAPIVersion and Core:CheckAPIVersion(Addon.REQUIRED_CORE_API)
        and Core.HasCapability and Core:HasCapability("localization", 1)
        and Core:HasCapability("calendar-day-query", 1) and Core.Calendar and type(Core.Calendar.ReadDay) == "function"
        and Core:HasCapability("account-view", 2) and Core:HasCapability("character-identity", 1)
        and Core:HasCapability("character-name-format", 1) and Core:HasCapability("account-entry", 2)
        and Core.Locale and type(Core.Locale.Get) == "function" and Core.AccountView and Core.Entry and Core.Characters
        and type(Core.Characters.FormatName) == "function") then return nil, Addon:T("ERROR.CORE_REQUIRED") end
    Addon.Core = Core
    local function MoveCharacterData(oldID, newID)
        if Addon.Database:MoveCharacterData(oldID, newID) then Addon:NotifyChanged() end
    end
    -- This listener covers promotions that happen after this addon has
    -- initialized.  The reconciliation below covers the login-time promotion,
    -- which may have completed before YiboTodo receives PLAYER_LOGIN.
    if not self.characterIDListenerRegistered then
        Core.Events:Register("CHARACTER_ID_CHANGED", self, function(_, oldID, newID) MoveCharacterData(oldID, newID) end)
        self.characterIDListenerRegistered = true
    end
    local current = Core.Characters:GetCurrent()
    if current then
        local legacyID = "legacy:" .. tostring(current.realm or "Unknown") .. ":" .. tostring(current.name or "Unknown")
        MoveCharacterData(legacyID, current.id)
    end
    if not self.domainListenerRegistered then
        Core.Events:Register("DATA_DOMAIN_UPDATED", self, function(_, payload)
            if payload.domainID == "professions" then Addon:NotifyChanged() end
        end)
        self.domainListenerRegistered = true
    end
    local addon, err = Core:RegisterAddon(Addon.NAME, { version = Addon.VERSION, requiredAPI = Addon.REQUIRED_CORE_API })
    if not addon then return nil, err end
    if Core.CharacterCleanup then
        local ok, cleanupErr = Core.CharacterCleanup:RegisterOwner(Addon.NAME, {
            Inspect = function(character) local has = Addon.db.byCharacter[character.id] ~= nil; return { hasData = has, label = Addon:T("CLEANUP.LABEL"), detail = has and Addon:T("CLEANUP.HAS_DATA") or Addon:T("CLEANUP.NO_DATA") } end,
            Delete = function(character) Addon.Database:DeleteCharacter(character.id); Addon:NotifyChanged(); return true end,
        })
        if not ok then return nil, cleanupErr end
    end
    local page, pageErr = Core.AccountView:RegisterPage(Addon.NAME, {
        id = "todo", title = Addon:T("PAGE.TITLE"), icon = ICON, order = 35, defaultEnabled = true, previewEnabled = true, compactWidth = true, scope = { mode = "realms", allTitle = Addon:T("PAGE.ALL_REALMS") },
        firstUseTip = { title = Addon:T("PAGE.FIRST_USE_TITLE"), lines = { Addon:T("PAGE.FIRST_USE_BODY") } },
        characterFilter = {
            defaultExpression = "",
            GetExpression = function() return Addon.db.settings.levelExpr or "" end,
            SetExpression = function(expression)
                local valid, normalized, badToken = Core.LevelFilter:Validate(expression)
                if not valid then return false, Addon:T("FILTER.INVALID", tostring(badToken)) end
                Addon.db.settings.levelExpr = normalized; Addon:NotifyChanged(); return true
            end,
        },
        HasCharacterSnapshot = function(character) return Addon.Snapshot:GetCharacter(character.id) ~= nil end,
        GetEligibleCharacters = function(characters) local result = {}; for _, c in ipairs(characters or {}) do if Addon.Snapshot:GetCharacter(c.id) then result[#result + 1] = c end end; return result end,
        settings = { title = Addon:T("PAGE.TITLE"), description = Addon:T("PAGE.SETTINGS_DESCRIPTION"), CreateSettingsPanel = function(parent, context) return Addon.Settings:CreatePanel(parent, context) end },
        Create = Addon.AccountPage.Create, Refresh = Addon.AccountPage.Refresh,
        GetSurfaceMetrics = Addon.AccountPage.GetSurfaceMetrics,
        GetHoverMetrics = Addon.AccountPage.GetHoverMetrics,
        GetMeasuredHeight = Addon.AccountPage.GetMeasuredHeight,
        GetSummary = function(characters) return Addon:T("PAGE.SUMMARY", #(characters or {})) end,
        GetActions = function(characters) local actions = {}; for _, c in ipairs(characters or {}) do local s = Addon.Snapshot:GetCharacter(c.id).summary; if s.todo > 0 then actions[#actions + 1] = { priority = 2, title = c.name, text = table.concat(s.items, Addon:T("LIST.SEP")) } end end; return actions end,
    })
    if not page then return nil, pageErr end
    local entry, entryErr = Core.Entry:RegisterBusinessEntry(Addon.NAME, { id = "ytd", brokerName = "YiboTodo", pageID = "todo", text = Addon:T("PAGE.TITLE"), icon = ICON,
        defaultChannels = { minimap = false, broker = false, builtinBar = false } })
    if not entry then return nil, entryErr end
    if Addon.ActionContracts then
        local ok, actionErr = Addon.ActionContracts:Initialize()
        if not ok then Addon:Print(actionErr) end
    end
    self.initialized = true; return true
end

function Addon:OpenAccountPage() if self.Core and self.Core.AccountView then self.Core.AccountView:Toggle("todo") end end
