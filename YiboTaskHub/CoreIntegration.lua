local Addon = _G.YiboTaskHub
local Integration = {}
Addon.CoreIntegration = Integration
local ICON = "Interface\\AddOns\\YiboTaskHub\\Media\\YiboTaskHubIcon-v1"

function Integration:Initialize()
    if self.initialized then return true end
    local core = _G.YiboCore
    local apiReady = core and core.CheckAPIVersion and core:CheckAPIVersion(Addon.REQUIRED_CORE_API)
    local localeReady = core and core.HasCapability and core:HasCapability("localization", 1)
        and core.Locale and type(core.Locale.Get) == "function" and type(core.Locale.Register) == "function"
    local coreReady = core and type(core.IsInitialized) == "function" and core:IsInitialized()
    if not (apiReady and localeReady and coreReady
        and core:HasCapability("business-item-actions", 1) and core:HasCapability("business-providers", 1) and core:HasCapability("account-view", 2)
        and core:HasCapability("character-identity", 1) and core:HasCapability("character-name-format", 1) and core.Contracts and core.Contracts.List
        and core:HasCapability("account-character-admission", 1)
        and core:HasCapability("account-surface-budget", 1)
        and core:HasCapability("account-entry", 2)
        and core:HasCapability("builtin-entry-bar", 1)
        and core:HasCapability("item-resolver", 1) and core.ItemResolver
        and type(core.ItemResolver.GetInfo) == "function" and type(core.ItemResolver.Request) == "function"
        and core.Characters and core.Characters.FormatName and core.UITheme and core.UITheme.ShowTooltip
        and type(core.UITheme.CreateMatrixHeader) == "function" and type(core.UITheme.SetCharacterHeader) == "function"
        and type(core.UITheme.GetDataRowColor) == "function"
        and type(core.UITheme.CreateMultiSelectDropdown) == "function"
        and core.UITheme.CreateCheckbox and core.Entry and core.AccountView and core.AccountView.GetVisibleCharacters
        and type(core.AccountView.SetPageScope) == "function") then
        local message = "Upgrade YiboCore to 1.12.0 / API 13."
        if core and type(core.Text) == "function" then
            local ok, text = pcall(core.Text, core, "CORE.API_UPGRADE_REQUIRED", "1.12.0", 13)
            if ok and type(text) == "string" and text:sub(1, 1) ~= "[" then message = text end
        end
        return nil, message
    end
    Addon.Core = core
    local registered, err = core:RegisterAddon(Addon.NAME, { version = Addon.VERSION, requiredAPI = Addon.REQUIRED_CORE_API })
    if not registered then return nil, err end
    if not Addon.Goals:Initialize() then return nil, Addon:T("ERROR.GOAL_SERVICE") end
    Addon.Contracts:Initialize()
    if Addon.BossTargets then
        if not (core:HasCapability("business-services", 1) and core.Contracts.Resolve and core.Contracts.Call
            and core:HasCapability("basic-input", 1) and core.UITheme.CreateInput
            and core.UITheme.CreateBusinessTabs and core.UITheme.CreateDropdown) then
            Addon.Contracts:Shutdown(); Addon.Goals:Shutdown(); return nil, Addon:T("CORE.BOSS_CAPABILITY_REQUIRED")
        end
        local ok, targetErr = Addon.BossTargets:Initialize()
        if not ok then Addon.Contracts:Shutdown(); Addon.Goals:Shutdown(); return nil, targetErr or Addon:T("ERROR.BOSS_TARGET_SERVICE") end
    end
    local page, pageErr = core.AccountView:RegisterPage(Addon.NAME, {
        id = Addon.PAGE_ID, title = Addon:T("PAGE.TITLE"), icon = ICON, defaultEnabled = true, previewEnabled = true,
        fields = Addon.Presentation.fields,
        GetPreviewFields = function() return core.Defaults:Copy(Addon.db.settings.previewColumns) end,
        SetPreviewFieldVisible = function(id, visible) return Addon.Settings:SetPreviewField(id, visible) end,
        settings = { title = Addon:T("PAGE.TITLE"), description = Addon:T("PAGE.SETTINGS_DESCRIPTION"),
            CreateSettingsPanel = function(parent, context) return Addon.Settings:CreatePanel(parent, context) end },
        scope = { mode = "realms", allTitle = Addon:T("SCOPE.ALL_REALMS") },
        Create = Addon.AccountPage.Create, Refresh = Addon.AccountPage.Refresh,
        GetSurfaceMetrics = Addon.AccountPage.GetSurfaceMetrics,
        GetEligibleCharacters = function(characters, context)
            -- Keep the requested directory scope so unobserved coverage is not
            -- lost when there are zero tasks. Only actual task rows are drawn.
            if not (context and context.preview) then return characters end
            local value, eligible, shown = Addon.Snapshot:Build(characters), {}, {}
            for _, pair in ipairs(Addon.AccountPage:Filter(value)) do shown[pair.row.character.id] = true end
            for _, character in ipairs(characters) do if shown[character.id] then eligible[#eligible + 1] = character end end
            return eligible
        end,
        HasCharacterSnapshot = function(character) return Addon.Snapshot:Build({ character }).byCharacter[character.id] ~= nil end,
        GetSummary = function(characters)
            local count = Addon.AccountPage:Stats(Addon.AccountPage:Filter(Addon.Snapshot:Build(characters)))
            return Addon:T("SUMMARY.SOURCE_WORK", count)
        end,
    })
    if not page then if Addon.BossTargets then Addon.BossTargets:Shutdown() end; Addon.Contracts:Shutdown(); Addon.Goals:Shutdown(); return nil, pageErr end
    self.page = page
    local entry, entryErr = core.Entry:RegisterBusinessEntry(Addon.NAME,
        { id = "yth", brokerName = "YiboTaskHub", pageID = Addon.PAGE_ID, text = Addon:T("ENTRY.TEXT"), icon = ICON,
            defaultChannels = { minimap = false, broker = false, builtinBar = false } })
    if not entry then if Addon.BossTargets then Addon.BossTargets:Shutdown() end; Addon.Contracts:Shutdown(); Addon.Goals:Shutdown(); return nil, entryErr end
    for _, event in ipairs({ "CHARACTER_ID_CHANGED", "CHARACTER_UPDATED", "CHARACTER_CACHE_DELETED" }) do
        core.Events:Register(event, self, function() Addon.Contracts:Invalidate() end)
    end
    self.initialized = true
    return true
end
