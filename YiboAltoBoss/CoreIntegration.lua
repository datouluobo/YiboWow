if _G.YAB and _G.YAB.CoreReady == false then return end
local Core = _G.YiboCore
local YAB = _G.YAB
local addonTitle = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.BOSS_TRACKER")
local addonDescription = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.BOSS_TRACKER_OWNS_BOSS_KILLS_PHASE_OBSERVATIONS_RESPAWN_SAMPLES_AND_CUST")
local characterRecordLabel = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.BOSS_TRACKER_CHARACTER_RECORDS")

-- AltoBoss 的账号视图、预览和可选入口均由 YiboCore 承载；此处只保留业务数据适配。
local Integration = {}
YAB.CoreIntegration = Integration

local PAGE_ID = "alto-boss"
local LOCKOUT_PAGE_ID = "alto-lockouts"

local function AddText(parent, template, color)
    local text = parent:CreateFontString(nil, "OVERLAY", template or "GameFontNormal")
    Core.UITheme:ApplyTextStyle(text, template == "GameFontNormalSmall" and Core.UITheme.Font.assist or Core.UITheme.Font.body)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    if color then
        text:SetTextColor(color[1], color[2], color[3])
    end
    return text
end

local function CreateButton(parent, label)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(152, 25)
    button:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    button:SetBackdropColor(0.16, 0.16, 0.18, 0.98)
    button:SetBackdropBorderColor(0.70, 0.50, 0.16, 0.92)
    button.label = AddText(button, "GameFontNormalSmall", { 0.95, 0.95, 0.95 })
    button.label:SetPoint("CENTER")
    button.label:SetText(label)
    button:SetScript("OnEnter", function(self) self:SetBackdropColor(0.28, 0.16, 0.06, 0.98) end)
    button:SetScript("OnLeave", function(self) self:SetBackdropColor(0.16, 0.16, 0.18, 0.98) end)
    return button
end

local function ImportKnownCharacters()
    if not (Core and Core.Characters and Core.Characters.ImportLegacyCharacter) then
        return
    end
    for legacyKey, info in pairs(YiboAltoBossDB.knownChars or {}) do
        local name = info.name or legacyKey:match("^(.-)-") or legacyKey
        local realm = info.realm or legacyKey:match("-(.+)$") or "Unknown"
        Core.Characters:ImportLegacyCharacter("YiboAltoBoss", legacyKey, {
            name = name,
            realm = realm,
            class = info.class,
            level = info.level,
            lastSeenAt = info.lastSeenAt,
            seenOrder = info.seenOrder,
        })
    end
end

local function GetCleanupLegacyKeys(character, aliases)
    local keys, seen = {}, {}
    for legacyKey in pairs(YiboAltoBossDB.knownChars or {}) do
        local resolvedID = Core.Characters:ResolveLegacyKey(legacyKey)
        if resolvedID == character.id or (aliases and aliases[legacyKey]) then
            seen[legacyKey] = true
            keys[#keys + 1] = legacyKey
        end
    end
    for legacyKey in pairs(YiboAltoBossDB.characters or {}) do
        local resolvedID = Core.Characters:ResolveLegacyKey(legacyKey)
        if not seen[legacyKey] and (resolvedID == character.id or (aliases and aliases[legacyKey])) then
            seen[legacyKey] = true
            keys[#keys + 1] = legacyKey
        end
    end
    return keys
end

local function RegisterCharacterCleanupOwner()
    if not Core.CharacterCleanup then return nil, _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.YIBOCORE_CHARACTER_CLEANUP_IS_UNAVAILABLE") end
    return Core.CharacterCleanup:RegisterOwner("YiboAltoBoss", {
        Inspect = function(character, aliases)
            local keys = GetCleanupLegacyKeys(character, aliases)
            return {
                hasData = #keys > 0,
                label = characterRecordLabel,
                detail = #keys > 0 and (tostring(#keys) .. _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.CHARACTER_CACHES")) or _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.NO_CHARACTER_CACHE"),
            }
        end,
        Delete = function(character, aliases)
            for _, legacyKey in ipairs(GetCleanupLegacyKeys(character, aliases)) do
                YiboAltoBossDB.knownChars[legacyKey] = nil
                YiboAltoBossDB.characters[legacyKey] = nil
            end
            YAB.PersistDB()
            if YAB.NotifyCorePageChanged then YAB.NotifyCorePageChanged() end
            if YAB.RefreshSettingsUI then YAB.RefreshSettingsUI() end
            return true
        end,
    })
end

local function GetLegacyKeyByCharacterID(characterID)
    for legacyKey in pairs(YiboAltoBossDB.knownChars or {}) do
        if Core.Characters:ResolveLegacyKey(legacyKey) == characterID then
            return legacyKey
        end
    end
end

local function HasEligibleSnapshot(legacyKey)
    return legacyKey
        -- A known character is a valid Boss row even before its first combat
        -- snapshot.  Rendering it as "未击杀" is more useful than silently
        -- dropping a role from the account comparison.
        and YiboAltoBossDB.knownChars[legacyKey] ~= nil
end

function YAB.GetAccountCharacterKeys(context)
    local result = {}
    for _, character in ipairs(context and context.characters or {}) do
        local legacyKey = GetLegacyKeyByCharacterID(character.id)
        if legacyKey then result[#result + 1] = legacyKey end
    end
    return result
end

local function GetEligibleCharacters(characters, context)
    local eligible = {}
    for _, character in ipairs(characters or {}) do
        local legacyKey = GetLegacyKeyByCharacterID(character.id)
        local hasSnapshot = HasEligibleSnapshot(legacyKey)
        if hasSnapshot then
            eligible[#eligible + 1] = character
        end
    end
    return eligible
end

local function GetSummary(characters)
    local killed, total = 0, 0
    for _, character in ipairs(characters or {}) do
        local legacyKey = GetLegacyKeyByCharacterID(character.id)
        if HasEligibleSnapshot(legacyKey) then
            for _, boss in ipairs(YAB.GetBossList({ characters = characters })) do
                total = total + 1
                local progress = YAB.PlannedTargets and YAB.PlannedTargets:GetBossProgress(legacyKey, boss.key)
                if (progress and progress.state == "completed") or (not progress and YAB.IsBossKilled(legacyKey, boss.key)) then killed = killed + 1 end
            end
        end
    end
    return string.format(_G.YiboCore.Locale:Get("YiboAltoBoss", "UI.BOSS_KILLS_D_D"), killed, total)
end

local function GetActions(characters)
    local actions = {}
    for _, character in ipairs(characters or {}) do
        local legacyKey = GetLegacyKeyByCharacterID(character.id)
        if HasEligibleSnapshot(legacyKey) then
            for _, boss in ipairs(YAB.GetBossList({ characters = characters })) do
                local status = YAB.GetBossKillStatus(legacyKey, boss.key)
                local progress = YAB.PlannedTargets and YAB.PlannedTargets:GetBossProgress(legacyKey, boss.key)
                if (progress and progress.state == "ready") or (not progress and status ~= "killed" and status ~= "loot_locked") then
                    actions[#actions + 1] = {
                        priority = 3,
                        title = Core.Characters:FormatName(character, { nameMode = "short", realmMode = "full" }),
                        text = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.AVAILABLE") .. tostring(boss.name),
                    }
                    break
                end
            end
        end
    end
    return actions
end

function Integration:GetPreviewFields()
    YAB.GetLockoutPreviewFieldDefinitions() -- Also imports legacy selections once.
    local settings = YiboAltoBossDB.settings or {}
    return Core.Defaults:Copy(settings.previewColumns or {})
end

function Integration:SetPreviewFieldVisible(fieldID, visible)
    if fieldID:sub(1, 9) == "instance:" then
        YAB.SetLockoutColumnEnabled(fieldID:sub(10), visible)
        return
    end
    YiboAltoBossDB.settings = YiboAltoBossDB.settings or {}
    YiboAltoBossDB.settings.previewColumns = YiboAltoBossDB.settings.previewColumns or {}
    YiboAltoBossDB.settings.previewColumns[fieldID] = not not visible
    YAB.PersistDB()
    YAB.NotifyCorePageChanged()
end

function Integration:Initialize()
    if self.initialized then
        return true
    end
    if not (Core and Core.CheckAPIVersion and Core.AccountView) then
        return nil, _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.YIBOCORE_IS_UNAVAILABLE")
    end
    local compatible = Core:CheckAPIVersion(13)
    if not compatible or not Core.HasCapability or not Core:HasCapability("localization", 1) or not Core:HasCapability("account-surface-budget", 2)
        or type(Core.AccountView.GetScrollSurfaceWidth) ~= "function" or not YAB.LockoutLocaleReady then
        return nil, _G.YiboCore.Locale:Get("YiboAltoBoss", "ERROR.CORE_API13_REQUIRED")
    end

    Core:RegisterAddon("YiboAltoBoss", { version = "2.8.4", requiredAPI = 13 })
    if Core.CharacterCleanup then
        local cleanupRegistered, cleanupError = RegisterCharacterCleanupOwner()
        if not cleanupRegistered then return nil, cleanupError end
    end
    ImportKnownCharacters()
    -- An unconfigured legacy Boss view now follows the shared max-level
    -- default, while an explicit prior expression remains untouched.
    YiboAltoBossDB.filters = YiboAltoBossDB.filters or {}
    if YiboAltoBossDB.filters.levelExpr == nil or YiboAltoBossDB.filters.levelExpr == "" then
        YiboAltoBossDB.filters.levelExpr = "90"
    end
    local page, errorMessage = Core.AccountView:RegisterPage("YiboAltoBoss", {
        id = PAGE_ID,
        title = addonTitle,
        icon = "Interface\\AddOns\\YiboAltoBoss\\Media\\YiboAltoBossIcon",
        order = 30,
        previewEnabled = true,
        fields = {
            { id = "kills", title = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.KILLS_3"), defaultVisible = true },
            { id = "action", title = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.ACTION_2"), defaultVisible = true },
            { id = "phase", title = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.PHASE_2"), defaultVisible = true },
        },
        viewModes = {
            { id = "character-rows", title = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.CHARACTERS_AS_ROWS") },
            { id = "character-columns", title = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.CHARACTERS_AS_COLUMNS") },
        },
        scope = { mode = "realms", allTitle = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.ALL_REALMS") },
        characterFilter = {
            defaultExpression = "90",
            GetExpression = function() return YAB.GetLevelFilterExpr() end,
            SetExpression = function(expression) return YAB.SetLevelFilterExpr(expression) end,
        },
        HasCharacterSnapshot = function(character)
            return HasEligibleSnapshot(GetLegacyKeyByCharacterID(character.id))
        end,
        GetEligibleCharacters = GetEligibleCharacters,
        GetPreviewFieldDefinitions = function() return YAB.GetLockoutPreviewFieldDefinitions() end,
        GetPreviewFields = function() return Integration:GetPreviewFields() end,
        SetPreviewFieldVisible = function(fieldID, visible) Integration:SetPreviewFieldVisible(fieldID, visible) end,
        defaultEnabled = true,
        settings = {
            title = addonTitle,
            description = addonDescription,
            CreateSettingsPanel = function(parent, context)
                if YAB.CreateCoreSettingsPanel then
                    return YAB.CreateCoreSettingsPanel(parent, context)
                end
                return 1
            end,
        },
        Create = YAB.CreateAccountPage,
        Refresh = YAB.RefreshAccountPage,
        -- The hosted page reports only its data surface.  Core adds its
        -- window or hover chrome in one place.
        GetSurfaceMetrics = YAB.GetAccountSurfaceMetrics,
        GetSummary = GetSummary,
        GetActions = GetActions,
    })
    if not page and errorMessage then
        return nil, errorMessage
    end
    local lockoutPage, lockoutError = Core.AccountView:RegisterPage("YiboAltoBoss", {
        id = LOCKOUT_PAGE_ID,
        title = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.INSTANCES"),
        icon = "Interface\\AddOns\\YiboAltoBoss\\Media\\YiboAltoBossIcon",
        order = 31,
        previewEnabled = true,
        hideFromSettings = true,
        internal = true,
        compactWidth = true,
        autoFitWidth = true,
        autoFitHeight = true,
        fields = { { id = "lockout", title = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.LOCKOUTS"), defaultVisible = true } },
        scope = { mode = "realms", allTitle = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.ALL_REALMS") },
        characterFilter = {
            defaultExpression = "90",
            GetExpression = function() return YAB.GetLevelFilterExpr() end,
            SetExpression = function(expression) return YAB.SetLevelFilterExpr(expression) end,
        },
        HasCharacterSnapshot = function(character)
            return HasEligibleSnapshot(GetLegacyKeyByCharacterID(character.id))
        end,
        GetEligibleCharacters = GetEligibleCharacters,
        GetPreviewFields = function() return { lockout = true } end,
        SetPreviewFieldVisible = function() end,
        defaultEnabled = true,
        Create = YAB.CreateLockoutsPage,
        Refresh = YAB.RefreshLockoutsPage,
        GetSurfaceMetrics = YAB.GetLockoutsSurfaceMetrics,
        GetMeasuredHeight = YAB.GetLockoutsMeasuredHeight,
        GetHoverMetrics = YAB.GetLockoutsHoverMetrics,
        GetSummary = YAB.GetLockoutsSummary,
        GetActions = YAB.GetLockoutsActions,
    })
    if not lockoutPage and lockoutError then return nil, lockoutError end
    local entry, entryError = Core.Entry:RegisterBusinessEntry("YiboAltoBoss", {
        id = "yab",
        legacyIDs = { "YiboAltoBoss" },
        brokerName = "YiboAltoBoss",
        pageID = PAGE_ID,
        resolvePageID = function()
            return YAB.GetAccountBusinessPageID and YAB.GetAccountBusinessPageID() or PAGE_ID
        end,
        text = "[Yibo] " .. addonTitle,
        icon = "Interface\\AddOns\\YiboAltoBoss\\Media\\YiboAltoBossIcon",
    })
    if not entry and entryError then return nil, entryError end
    if YAB.PlannedTargets then
        local linked, linkError = YAB.PlannedTargets:Initialize()
        if not linked and linkError ~= "core-version" and Core.Print then Core:Print(_G.YiboCore.Locale:Get("YiboAltoBoss", "UI.BOSS_TARGET_INTEGRATION_UNAVAILABLE") .. tostring(linkError)) end
    end
    self.initialized = true
    return true
end

function YAB.NotifyCorePageChanged()
    if YAB.PlannedTargets then YAB.PlannedTargets:ScheduleChange() end
    if Core and Core.AccountView then
        -- Refresh only the page currently being viewed.  The lockout page is
        -- an internal tab hosted by AltoBoss; notifying both pages in a row
        -- can let an external Core refresh race with the tab switch and
        -- restore the default Boss page.
        local frame = Core.AccountView.frame
        local visiblePageID = frame and frame.preview
            and Core.AccountView.previewPageID
            or Core.AccountView.activePageID
        Core.AccountView:NotifyPageChanged(visiblePageID == LOCKOUT_PAGE_ID and LOCKOUT_PAGE_ID or PAGE_ID)
    end
end

function YAB.RefreshCoreSettingsPage()
    if Core and Core.AccountView and Core.AccountView.activePageID == "settings"
        and Core.AccountView.settingsTargetPageID == PAGE_ID then
        Core.AccountView:RefreshPage()
    end
end
