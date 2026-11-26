local Core = _G.YiboCore
local YQB = _G.YQB
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
    if not YQB.CoreCompatible then return nil end
    local addon, addonError = Core:RegisterAddon("YiboQuestBlocker", { version = YQB.Target.version, requiredAPI = YQB.REQUIRED_CORE_API })
    if not addon then return nil, addonError end
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
        id = PAGE_ID, columnPager = true, title = YQB.T("PAGE.TITLE"), icon = "Interface\\AddOns\\YiboQuestBlocker\\Media\\YiboQuestBlockerIcon", order = 40, previewEnabled = true,
        fields = {
            { id = "global", title = YQB.T("PAGE.GLOBAL_FIELD"), defaultVisible = true },
            { id = "characters", title = YQB.T("PAGE.CHARACTER_FIELD"), defaultVisible = true },
        },
        scope = YQB.Target.realmScope and { mode = "realms", allTitle = YQB.T("PAGE.ALL_REALMS") } or nil,
        characterFilter = {
            defaultExpression = YQB.Target.defaultLevel,
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
        text = YQB.T("PAGE.ENTRY"), icon = "Interface\\AddOns\\YiboQuestBlocker\\Media\\YiboQuestBlockerIcon",
    })
    if not entry then return nil, entryError end
    self.initialized = true
    return true
end

local pageNotification
function YQB.NotifyCorePageChanged(coalesce)
    if coalesce and C_Timer and C_Timer.After then
        if pageNotification then return end
        local ticket = {}
        pageNotification = ticket
        C_Timer.After(0, function()
            if pageNotification ~= ticket then return end
            pageNotification = nil
            if Core.AccountView then Core.AccountView:NotifyPageChanged(PAGE_ID) end
        end)
        return
    end
    pageNotification = nil
    if Core.AccountView then Core.AccountView:NotifyPageChanged(PAGE_ID) end
end

function YQB.OpenAccountPage()
    if Core.AccountView then Core.AccountView:Toggle(PAGE_ID) end
end
