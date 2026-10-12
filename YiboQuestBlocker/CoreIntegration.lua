local Core = _G.YiboCore
local YQB = _G.YQB
if not (YQB and YQB.CoreCompatible) then return end
local Integration = {}
YQB.CoreIntegration = Integration

local PAGE_ID = "quest-blocker"

local function HasCharacterSnapshot(character)
    local db = YQB.GetDatabase()
    return type(character) == "table" and type(db.characterData and db.characterData[character.id]) == "table"
end

local function GetEligibleCharacters(characters, context)
    local result = {}
    for _, character in ipairs(characters or {}) do
        if HasCharacterSnapshot(character) then
            result[#result + 1] = character
        end
    end
    return result
end

local function PreviewFields()
    local db = YQB.GetDatabase()
    db.settings = db.settings or {}
    db.settings.previewColumns = db.settings.previewColumns or { global = true, characters = true }
    return db.settings.previewColumns
end

local function SetPreviewField(fieldID, visible)
    PreviewFields()[fieldID] = not not visible
    YQB.PersistDB()
    YQB.NotifyCorePageChanged()
end

local function GetSummary(characters)
    local db, roles = YQB.GetDatabase(), 0
    for _, character in ipairs(characters or {}) do
        if HasCharacterSnapshot(character) then roles = roles + 1 end
    end
    local globalCount = 0
    for _ in pairs(db.globalBlocked or {}) do globalCount = globalCount + 1 end
    return YQB.T("PAGE.CURRENT_SUMMARY", globalCount, roles)
end

function Integration:Initialize()
    if self.initialized then return true end
    if not (Core and Core.CheckAPIVersion and Core.AccountView and Core.Entry and Core.Characters) then
        return nil, YQB.T("CORE.UNAVAILABLE")
    end
    local compatible = Core:CheckAPIVersion(13)
    if not compatible then return nil, YQB.T("CORE.UPGRADE") end
    if not (Core.HasCapability and Core:HasCapability("localization", 1)
        and Core:HasCapability("character-name-format", 1)
        and Core:HasCapability("basic-input", 1)
        and Core:HasCapability("account-view", 2)
        and Core:HasCapability("account-entry", 2)
        and Core.RegisterAddon and Core.AccountView.RegisterPage
        and Core.Entry.RegisterBusinessEntry and Core.Characters.FormatName
        and Core.UITheme.CreateInput) then
        return nil, YQB.T("CORE.UPGRADE")
    end

    local addon, addonError = Core:RegisterAddon("YiboQuestBlocker", { version = "3.1.0", requiredAPI = 13 })
    if not addon then return nil, addonError end
    local database = YQB.GetDatabase()
    database.filters = database.filters or {}
    if database.filters.levelExpr == nil or database.filters.levelExpr == "" then
        database.filters.levelExpr = "90"
        YQB.PersistDB()
    end
    if Core.CharacterCleanup then
        local cleanupRegistered, cleanupError = Core.CharacterCleanup:RegisterOwner("YiboQuestBlocker", {
        Inspect = function(character)
            local data = YQB.GetDatabase().characterData[character.id]
            local blockedCount = 0
            for _ in pairs(data and data.blocked or {}) do blockedCount = blockedCount + 1 end
            return {
                hasData = type(data) == "table",
                label = YQB.T("PAGE.CLEANUP_LABEL"),
                detail = type(data) == "table" and YQB.T("PAGE.CLEANUP_DETAIL", blockedCount) or YQB.T("PAGE.NO_CHARACTER_CACHE"),
            }
        end,
        Delete = function(character)
            local db = YQB.GetDatabase()
            db.characterData[character.id] = nil
            YQB.PersistDB()
            if YQB.NotifyCorePageChanged then YQB.NotifyCorePageChanged() end
            return true
        end,
        })
        if not cleanupRegistered then return nil, cleanupError end
    end
    local page, pageError = Core.AccountView:RegisterPage("YiboQuestBlocker", {
        id = PAGE_ID, title = YQB.T("PAGE.TITLE"), icon = "Interface\\AddOns\\YiboQuestBlocker\\Media\\YQB_MinimapIcon", order = 40, previewEnabled = true,
        fields = {
            { id = "global", title = YQB.T("PAGE.GLOBAL_FIELD"), defaultVisible = true },
            { id = "characters", title = YQB.T("PAGE.CHARACTER_FIELD"), defaultVisible = true },
        },
        scope = { mode = "realms", allTitle = YQB.T("PAGE.ALL_REALMS") },
        characterFilter = {
            defaultExpression = "90",
            GetExpression = function() return YQB.GetLevelFilterExpr() end,
            SetExpression = function(expression) return YQB.SetLevelFilterExpr(expression) end,
        },
        HasCharacterSnapshot = HasCharacterSnapshot,
        GetEligibleCharacters = GetEligibleCharacters,
        GetPreviewFields = PreviewFields,
        SetPreviewFieldVisible = SetPreviewField,
        defaultEnabled = true,
        settings = {
            title = YQB.T("PAGE.TITLE"), description = YQB.T("PAGE.DESCRIPTION"),
            CreateSettingsPanel = function(parent, context) return YQB.CreateSettingsPanel(parent, context) end,
        },
        Create = YQB.AccountPage.Create,
        Refresh = YQB.AccountPage.Refresh,
        GetSurfaceMetrics = YQB.AccountPage.GetSurfaceMetrics,
        GetHoverMetrics = YQB.AccountPage.GetHoverMetrics,
        GetMeasuredHeight = YQB.AccountPage.GetMeasuredHeight,
        GetSummary = GetSummary,
        GetActions = function() return {} end,
    })
    if not page then return nil, pageError end
    local entry, entryError = Core.Entry:RegisterBusinessEntry("YiboQuestBlocker", {
        id = "yqb", legacyIDs = { "YiboQuestBlocker" }, brokerName = "YiboQuestBlocker", pageID = PAGE_ID,
        defaultChannels = { broker = false, minimap = false, builtinBar = false },
        text = YQB.T("PAGE.ENTRY"), icon = "Interface\\AddOns\\YiboQuestBlocker\\Media\\YQB_MinimapIcon",
    })
    if not entry then return nil, entryError end
    self.initialized = true
    return true
end

function YQB.NotifyCorePageChanged()
    if Core.AccountView then Core.AccountView:NotifyPageChanged(PAGE_ID) end
end

function YQB.OpenAccountPage()
    if Core.AccountView then Core.AccountView:Toggle(PAGE_ID) end
end

local initialized, initializeError = Integration:Initialize()
if not initialized and Core and Core.Print then
    Core:Print(YQB.T("CORE.INTEGRATION_FAILED", tostring(initializeError)))
end

SLASH_YQB1 = "/yqb"
SlashCmdList["YQB"] = function()
    YQB.OpenAccountPage()
end
