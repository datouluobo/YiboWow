local Addon, Core = _G.YiboCurrency, _G.YiboCore
local Integration = {}; Addon.CoreIntegration = Integration
local PAGE_ID = "currency"
local ICON = "Interface\\AddOns\\YiboCurrency\\Media\\YiboCurrencyIcon"

function Integration:Initialize()
    if self.initialized then return true end
    local upgrade = Addon:UpgradeMessage()
    if not (Core and type(Core.CheckAPIVersion) == "function" and Core:CheckAPIVersion(13)
        and type(Core.HasCapability) == "function" and type(Core.IsInitialized) == "function" and Core:IsInitialized()) then
        return nil, upgrade
    end
    local required = { ["localization"] = 1, ["character-name-format"] = 1, ["character-identity"] = 1,
        ["account-view"] = 2, ["account-entry"] = 2, ["account-dynamic-fields"] = 1,
        ["account-preview-field-groups"] = 1, ["account-surface-budget"] = 2,
        ["account-character-admission"] = 1, ["business-services"] = 1,
        ["character-archive-providers"] = 1, ["character-cleanup"] = 2, ["business-providers"] = 1, ["data-domains"] = 1, ["events"] = 1,
        ["basic-input"] = 1, ["item-resolver"] = 1, ["item-picker"] = 1 }
    for name, version in pairs(required) do
        if not Core:HasCapability(name, version) then return nil, Addon:T("UI.MISSING_CAPABILITY", upgrade, name, version) end
    end
    local methods = {
        { Core, "RegisterAddon", "CreateItemPicker", "GetVersion" },
        { Core.Locale, "Get", "Register", "GetLanguage" },
        { Core.Characters, "Get", "GetCurrent", "GetAll", "GetAliases", "ResolveLegacyKey", "FormatName" },
        { Core.Contracts, "Resolve", "Call", "Register", "NotifyChanged" },
        { Core.AccountView, "RegisterPage", "GetFieldDefinitions", "GetFieldVisible", "SetFieldVisible", "NotifyPageChanged", "Toggle", "GetScrollSurfaceWidth", "GetColumnPage", "GetColumnPageByWidth", "FitRepeatedColumnWidth", "UpdateColumnPager" },
        { Core.Entry, "RegisterBusinessEntry" }, { Core.CharacterCleanup, "RegisterOwner", "IsLegacyImportBlocked" },
        { Core.DataDomains, "Get", "GetDefinitions" }, { Core.Events, "Register" },
        { Core.LevelFilter, "Validate" }, { Core.ItemConfirmation, "Show" },
        { Core.UITheme, "CreateInput", "CreateCheckbox", "CreateButton", "CreateText", "BindTooltip", "GetDataRowColor", "MeasureText", "SetCharacterHeader", "GetCharacterMatrixColumnWidth", "GetCharacterRowHeaderWidth" },
        { Core.Defaults, "Copy" },
    }
    if not Core.ItemResolver then return nil, upgrade end
    for _, group in ipairs(methods) do
        for index = 2, #group do
            if type(group[1]) ~= "table" or type(group[1][group[index]]) ~= "function" then return nil, upgrade end
        end
    end
    local handedOff, handoffError = Addon.Migration:CheckCoreHandoff()
    if not handedOff then return nil, handoffError end
    local addon, err = Core:RegisterAddon(Addon.NAME, { version = Addon.VERSION, requiredAPI = 13 })
    if not addon then return nil, err end
    local stored, storeError = Addon.Store:Initialize()
    if not stored then return nil, storeError end
    local lifecycle, lifecycleError = Addon.Store:RegisterLifecycle()
    if not lifecycle then return nil, lifecycleError end
    local imported, _, importError = Addon.Migration:ImportAll()
    if imported == nil then return nil, importError end
    local archived, archiveError = Addon.ArchiveProvider:Initialize()
    if not archived then return nil, archiveError end
    local page, pageError = Core.AccountView:RegisterPage(Addon.NAME, {
        id = PAGE_ID, title = Addon:T("CURRENCY.CURRENCY_OVERVIEW_370A71"), icon = ICON, order = 50, previewEnabled = true, defaultEnabled = true, autoFitWidth = true, scope = { mode = "realms", allTitle = Addon:T("CURRENCY.ALL_REALMS_A166AB") },
        GetFieldDefinitions = function() return Addon:GetFieldDefinitions() end,
        GetPreviewFields = function() return Core.Defaults:Copy(Addon:GetSettings().previewColumns) end,
        SetPreviewFieldVisible = function(id, visible)
            return Addon:SetCurrencyDisplay(id, "hover", visible)
        end,
        characterFilter = {
            defaultExpression = "",
            GetExpression = function() return Addon:GetSettings().levelExpr or "" end,
            SetExpression = function(expression)
                local valid, normalized, badToken = Core.LevelFilter:Validate(expression)
                if not valid then return false, Addon:T("CURRENCY.INVALID_LEVEL_RULE_2824C2") .. tostring(badToken) end
                Addon:GetSettings().levelExpr = normalized; Addon:NotifyChanged(); return true
            end,
        },
        HasCharacterSnapshot = function(character) return Addon:HasCurrencySnapshot(character.id) end,
        GetEligibleCharacters = function(characters) return Addon:GetEligibleCurrencyCharacters(characters) end,
        settings = { title = Addon:T("CURRENCY.CURRENCY_OVERVIEW_370A71"), description = Addon:T("CURRENCY.MANAGE_CUSTOM_ITEM_TOKENS_HERE_SELECT_MAIN_VIEW_AND_HOV_749939"), CreateSettingsPanel = function(parent, context) return Addon:CreateSettingsPanel(parent, context) end },
        Create = function(parent) Addon:CreateCurrencyPage(parent) end, Refresh = function(parent, context) Addon:RefreshCurrencyPage(parent, context) end,
        GetSurfaceMetrics = function(context) return Addon:GetCurrencySurfaceMetrics(context) end,
        GetHoverMetrics = function(context)
            local metrics = Addon:GetCurrencySurfaceMetrics(context)
            local shell = Core.UITheme.Geometry.shellBorder * 2
            return {
                minWidth = metrics.minContentWidth + shell,
                preferredWidth = metrics.naturalContentWidth + shell,
                -- Header, its gap and at least one readable row must always
                -- be inside the hover shell, even with no monitored entries.
                minHeight = metrics.minContentHeight + Core.UITheme.Geometry.titleBar + shell,
                preferredHeight = metrics.naturalContentHeight + Core.UITheme.Geometry.titleBar + shell,
                scrollContentHeight = metrics.scrollContentHeight, scrollFixedHeight = metrics.scrollFixedHeight,
                horizontalOverflow = "paginate", verticalOverflow = "content",
            }
        end,
        GetSummary = function(characters) local monitored = 0; for _, entry in ipairs(Addon:GetCatalog()) do if Addon:IsMonitored(entry) then monitored = monitored + 1 end end; return string.format(Addon:T("CURRENCY.D_CHARACTERS_D_HOVER_CURRENCIES_60CF76"), #characters, monitored) end,
    })
    if not page then return nil, pageError end
    local entry, entryError = Core.Entry:RegisterBusinessEntry(Addon.NAME, { id = "ycu", brokerName = "YiboCurrency", pageID = PAGE_ID, text = Addon:T("CURRENCY.YIBO_CURRENCY_OVERVIEW_F45A33"), icon = ICON, defaultChannels = { minimap = false, broker = false, builtinBar = false } })
    if not entry then return nil, entryError end
    Core.Events:Register("ACCOUNT_VIEW_CHARACTERS_CHANGED", Addon, function() Addon:NotifyChanged() end)
    Core.Events:Register("CHARACTER_DISPLAY_UPDATED", Addon, function() Addon:NotifyChanged() end)
    for _, event in ipairs({ "BUSINESS_CONTRACT_REGISTERED", "BUSINESS_CONTRACT_UNREGISTERED", "BUSINESS_CONTRACT_CHANGED" }) do
        Core.Events:Register(event, Addon, function(_, descriptor)
            if descriptor.name == "vault.items" then Addon:NotifyChanged() end
        end)
    end
    if Addon.GoalTargets then Addon.GoalTargets:Initialize() end
    self.initialized = true
    Addon.Scanner:Initialize()
    return true
end
function Addon:NotifyChanged() if self.GoalTargets and self.GoalTargets.ref then local db = self:EnsureDB(); db.goalRevision = (db.goalRevision or 0) + 1; Core.Contracts:NotifyChanged(self.NAME, self.GoalTargets.ref, { reason = "currency-changed" }) end; if Core and Core.AccountView then Core.AccountView:NotifyPageChanged(PAGE_ID) end end
function Addon:OpenAccountPage()
    if not Integration.initialized then Addon:Print(Addon:UpgradeMessage()); return end
    Core.AccountView:Toggle(PAGE_ID)
end
