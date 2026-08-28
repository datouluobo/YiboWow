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
    return string.format("%d 个全局拒绝任务 · %d 名角色", globalCount, roles)
end

function Integration:Initialize()
    if self.initialized then return true end
    if not (Core and Core.CheckAPIVersion and Core.AccountView and Core.Entry and Core.Characters) then
        return nil, "YiboCore 不可用。"
    end
    local compatible = Core:CheckAPIVersion(5)
    if not compatible then return nil, "需要 YiboCore API v5。" end

    local addon, addonError = Core:RegisterAddon("YiboQuestBlocker", { version = "2.1", requiredAPI = 5 })
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
                label = "任务屏蔽个人设置",
                detail = type(data) == "table" and (tostring(blockedCount) .. " 个个人拒绝任务") or "无角色缓存",
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
        id = PAGE_ID, title = "任务屏蔽", order = 40, previewEnabled = true,
        fields = {
            { id = "global", title = "全局屏蔽", defaultVisible = true },
            { id = "characters", title = "角色屏蔽", defaultVisible = true },
        },
        scope = { mode = "realms", allTitle = "所有服务器" },
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
        settings = { title = "任务屏蔽", description = "角色身份与服务器范围由 Core 管理；任务屏蔽快照由 QuestBlocker 保存。" },
        Create = YQB.AccountPage.Create,
        Refresh = YQB.AccountPage.Refresh,
        GetSurfaceMetrics = YQB.AccountPage.GetSurfaceMetrics,
        GetMeasuredHeight = YQB.AccountPage.GetMeasuredHeight,
        GetSummary = GetSummary,
        GetActions = function() return {} end,
    })
    if not page then return nil, pageError end
    local entry, entryError = Core.Entry:RegisterBusinessEntry("YiboQuestBlocker", {
        id = "yqb", legacyIDs = { "YiboQuestBlocker" }, brokerName = "YiboQuestBlocker", pageID = PAGE_ID,
        text = "[Yibo] 任务屏蔽", icon = "Interface\\AddOns\\YiboQuestBlocker\\Media\\YQB_MinimapIcon",
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
    Core:Print("QuestBlocker Core 集成失败：" .. tostring(initializeError))
end

SLASH_YQB1 = "/yqb"
SlashCmdList["YQB"] = function()
    YQB.OpenAccountPage()
end
