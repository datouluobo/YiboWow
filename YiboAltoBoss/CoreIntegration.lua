local Core = _G.YiboCore
local YAB = _G.YAB

-- AltoBoss 的账号视图、预览和可选入口均由 YiboCore 承载；此处只保留业务数据适配。
local Integration = {}
YAB.CoreIntegration = Integration

local PAGE_ID = "alto-boss"

local function RealmScopeID(realm)
    return "realm:" .. tostring(realm or "Unknown")
end

local function BuildScopeDefinition()
    local currentRealm = YAB.GetCurrentRealm()
    local values = { { id = RealmScopeID(currentRealm), title = currentRealm } }
    for _, realm in ipairs(YAB.GetOtherRealmNames()) do
        values[#values + 1] = { id = RealmScopeID(realm), title = realm }
    end
    values[#values + 1] = { id = "all", title = "所有服务器" }
    return { default = RealmScopeID(currentRealm), values = values }
end

local function AddText(parent, template, color)
    local text = parent:CreateFontString(nil, "OVERLAY", template or "GameFontNormal")
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
    if not Core.CharacterCleanup then return nil, "YiboCore 角色清理能力不可用。" end
    return Core.CharacterCleanup:RegisterOwner("YiboAltoBoss", {
        Inspect = function(character, aliases)
            local keys = GetCleanupLegacyKeys(character, aliases)
            return {
                hasData = #keys > 0,
                label = "Boss 周常角色记录",
                detail = #keys > 0 and (tostring(#keys) .. " 组角色缓存") or "无角色缓存",
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
        and YiboAltoBossDB.characters[legacyKey] ~= nil
        and YAB.CharPassLevelFilter(legacyKey)
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
    local scope = context and context.scope or "all"
    local selectedRealm = scope:match("^realm:(.+)$")
    for _, character in ipairs(characters or {}) do
        local legacyKey = GetLegacyKeyByCharacterID(character.id)
        local info = legacyKey and YiboAltoBossDB.knownChars[legacyKey]
        local hasSnapshot = HasEligibleSnapshot(legacyKey)
        local realm = info and (info.realm or legacyKey:match("-(.+)$"))
        local visibleByScope = scope == "all" or (selectedRealm and realm == selectedRealm)
        if hasSnapshot and visibleByScope then
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
            for _, boss in ipairs(YAB.GetBossList()) do
                total = total + 1
                if YAB.IsBossKilled(legacyKey, boss.key) then killed = killed + 1 end
            end
        end
    end
    return string.format("Boss 击杀 %d/%d", killed, total)
end

local function GetActions(characters)
    local actions = {}
    for _, character in ipairs(characters or {}) do
        local legacyKey = GetLegacyKeyByCharacterID(character.id)
        if HasEligibleSnapshot(legacyKey) then
            for _, boss in ipairs(YAB.GetBossList()) do
                local status = YAB.GetBossKillStatus(legacyKey, boss.key)
                if status ~= "killed" and status ~= "loot_locked" then
                    actions[#actions + 1] = {
                        priority = 3,
                        title = YAB.GetCharacterLabel(legacyKey, "all"),
                        text = "可处理：" .. tostring(boss.name),
                    }
                    break
                end
            end
        end
    end
    return actions
end

function Integration:GetPreviewFields()
    local settings = YiboAltoBossDB.settings or {}
    return settings.previewColumns or {}
end

function Integration:SetPreviewFieldVisible(fieldID, visible)
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
        return nil, "YiboCore 不可用。"
    end
    local compatible = Core:CheckAPIVersion(3)
    if not compatible then
        return nil, "需要 YiboCore API v3。"
    end

    Core:RegisterAddon("YiboAltoBoss", { version = "2.1.0", requiredAPI = 3 })
    if Core.CharacterCleanup then
        local cleanupRegistered, cleanupError = RegisterCharacterCleanupOwner()
        if not cleanupRegistered then return nil, cleanupError end
    end
    ImportKnownCharacters()
    local page, errorMessage = Core.AccountView:RegisterPage("YiboAltoBoss", {
        id = PAGE_ID,
        title = "Boss 周常",
        order = 30,
        previewEnabled = true,
        fields = {
            { id = "kills", title = "击杀", defaultVisible = true },
            { id = "action", title = "行动", defaultVisible = true },
            { id = "phase", title = "位面", defaultVisible = true },
        },
        scope = BuildScopeDefinition(),
        GetEligibleCharacters = GetEligibleCharacters,
        GetPreviewFields = function() return Integration:GetPreviewFields() end,
        SetPreviewFieldVisible = function(fieldID, visible) Integration:SetPreviewFieldVisible(fieldID, visible) end,
        defaultEnabled = true,
        settings = {
            title = "Boss 周常",
            description = "Boss 击杀、位面观测、刷新样本和自定义目标由 AltoBoss 自行保存。",
            CreateSettingsPanel = function(parent, context)
                if YAB.CreateCoreSettingsPanel then
                    return YAB.CreateCoreSettingsPanel(parent, context)
                end
                return 1
            end,
        },
        Create = YAB.CreateAccountPage,
        Refresh = YAB.RefreshAccountPage,
        GetPreviewSize = YAB.GetAccountPreviewSize,
        GetHoverMetrics = YAB.GetAccountHoverMetrics,
        GetLayoutMetrics = YAB.GetAccountLayoutMetrics,
        GetSummary = GetSummary,
        GetActions = GetActions,
    })
    if not page and errorMessage then
        return nil, errorMessage
    end
    local entry, entryError = Core.Entry:RegisterBusinessEntry("YiboAltoBoss", {
        id = "yab",
        legacyIDs = { "YiboAltoBoss" },
        brokerName = "YiboAltoBoss",
        pageID = PAGE_ID,
        text = "[Yibo] Boss 周常",
        icon = "Interface\\AddOns\\YiboAltoBoss\\Media\\YAB_MinimapIcon",
    })
    if not entry and entryError then return nil, entryError end
    self.initialized = true
    return true
end

function YAB.NotifyCorePageChanged()
    if Core and Core.AccountView then
        Core.AccountView:NotifyPageChanged(PAGE_ID)
    end
end
