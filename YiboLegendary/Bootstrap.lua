local ADDON_NAME = ...

local Addon = _G.YiboLegendary or {}
_G.YiboLegendary = Addon
Addon.runtime = Addon.runtime or { testProjectionByCharacter = {}, snapshotsByCharacter = {} }
Addon.runtime.testProjectionByCharacter = {}
Addon.runtime.snapshotsByCharacter = {}
Addon.NAME = "YiboLegendary"
Addon.VERSION = "2.2.0"
Addon.REQUIRED_CORE_API = 13

function Addon:T(key, ...)
    local core = self.Core or _G.YiboCore
    if core and core.Locale and type(core.Locale.Get) == "function" then
        return core.Locale:Get(self.NAME, key, ...)
    end
    local locale = GetLocale and GetLocale() or "enUS"
    local english = locale ~= "zhCN" and locale ~= "zhTW"
    if key == "ERROR.CORE_REQUIRED" then
        return english and "YiboLegendary requires YiboCore API v13 with localization:1 and character-name-format:1. Please update YiboCore." or "YiboLegendary 需要 YiboCore API v13、localization:1 和 character-name-format:1。请升级 YiboCore。"
    end
    if key == "CHAT.PREFIX" then return english and "|cff20e070[Yibo]|r Legendary Progress: " or "|cff20e070[Yibo]|r 传说之路：" end
    return "[" .. self.NAME .. ":" .. tostring(key) .. "]"
end

local DEFAULTS = {
    schemaVersion = 2,
    settings = {
        phaseAvailability = {},
        levelExpr = "",
        selectedTargetId = "CLOAK",
        targetPage = "active",
        previewColumnsVersion = 7,
        previewColumns = {
            CLOAK = true,
            THUNDERFURY = true,
            SORIDAL = true,
        },
    },
    byCharacter = {},
        probes = {},
}

local function CopyDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then
                target[key] = {}
            end
            CopyDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

function Addon:Print(message)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(self:T("CHAT.PREFIX") .. tostring(message))
    end
end

function Addon:GetTimestamp()
    return (GetServerTime and GetServerTime()) or time()
end

function Addon:GetCharacterStore()
    local character = self.Core and self.Core.Characters:GetCurrent()
    if not character then
        return nil
    end
    local store = self.db.byCharacter[character.id] or {}
    self.db.byCharacter[character.id] = store
    store.characterID = character.id
    store.lastSeenAt = self:GetTimestamp()
    return store, character
end

local function SameSnapshot(left, right)
    if left == right then return true end
    if type(left) ~= type(right) then return false end
    if type(left) ~= "table" then return false end
    for key, value in pairs(left) do
        if key ~= "updatedAt" and key ~= "reason" and not SameSnapshot(value, right[key]) then return false end
    end
    for key in pairs(right) do if key ~= "updatedAt" and key ~= "reason" and left[key] == nil then return false end end
    return true
end

function Addon:Refresh(reason, currencyID, quantity, quantityChange, quantityGain, trackedProgress)
    local store, character = self:GetCharacterStore()
    if not store then
        return
    end
    local valorProgress = trackedProgress and self.runtime.pendingValorProgress or self.Data:TrackValorProgress(store, currencyID, quantity, quantityChange, quantityGain)
    local previous = self.runtime.snapshotsByCharacter[character.id]
    local snapshot = self.Model:BuildSnapshot(character, store, self.db.settings.phaseAvailability, valorProgress)
    snapshot.updatedAt = self:GetTimestamp()
    snapshot.reason = reason
    self.runtime.snapshotsByCharacter[character.id] = snapshot
    local hasProjection = false
    for _, state in pairs(snapshot.targets or {}) do if state.evidence and state.evidence.source == "projection" then hasProjection = true; break end end
    if not hasProjection then store.snapshot = snapshot end
    if self.GoalTargets and self.GoalTargets.ref and not SameSnapshot(previous, snapshot) then
        self.db.goalRevision = (self.db.goalRevision or 0) + 1
        self.Core.Contracts:NotifyChanged(self.NAME, self.GoalTargets.ref, { reason = "legendary-progress-changed", characterID = character.id })
    end
    if self.UI and not SameSnapshot(previous, snapshot) then
        self.UI:Refresh(reason)
    end
end

function Addon:QueueRefresh(event, ...)
    -- Apply every currency delta in arrival order before coalescing the model.
    if event == "CURRENCY_DISPLAY_UPDATE" then
        local store = self:GetCharacterStore()
        if store then
            self.runtime.pendingValorProgress = self.Data:TrackValorProgress(store, ...)
            self.runtime.valorTracked = true
        end
    end
    self.runtime.refreshReason = event
    if self.runtime.refreshQueued then return end
    self.runtime.refreshQueued = true
    local function Run()
        local reason, tracked = self.runtime.refreshReason, self.runtime.valorTracked
        self.runtime.refreshQueued, self.runtime.refreshReason, self.runtime.valorTracked = nil, nil, nil
        self:Refresh(reason, nil, nil, nil, nil, tracked)
        self.runtime.pendingValorProgress = nil
    end
    if C_Timer and C_Timer.After then C_Timer.After(0.1, Run) else Run() end
end

function Addon:Initialize()
    if self.initialized then
        return
    end
    local core = _G.YiboCore
    if not (core and core.CheckAPIVersion and core:CheckAPIVersion(self.REQUIRED_CORE_API)
        and core.HasCapability and core:HasCapability("localization", 1)
        and core:HasCapability("character-name-format", 1)
        and core:HasCapability("account-view", 2)
        and core:HasCapability("account-entry", 2)
        and core.Locale and type(core.Locale.Get) == "function"
        and core.Characters and type(core.Characters.FormatName) == "function"
        and core.AccountView and type(core.AccountView.RegisterPage) == "function"
        and core.Entry and type(core.Entry.RegisterBusinessEntry) == "function"
        and core.LevelFilter and type(core.LevelFilter.Validate) == "function"
        and type(core.IsInitialized) == "function") then
        self:Print(self:T("ERROR.CORE_REQUIRED"))
        return
    end

    self.Core = core
    local initialized = core:IsInitialized()
    if not initialized then
        self:Print(self:T("ERROR.CORE_NOT_READY", "not-ready"))
        return
    end
    -- 将尚未发布的开发版存档迁移到正式名称，随后不再保存旧变量。
    _G.YiboLegendaryDB = _G.YiboLegendaryDB or _G.YiboCloakProgressDB or {}
    _G.YiboCloakProgressDB = nil
    self.db = _G.YiboLegendaryDB
    local settings = self.db.settings
    -- 悬停矩阵以目录目标 ID 为唯一列键。旧版的 character/任务/目标/行动
    -- 都是摘要字段，不能再参与业务列配置；新目录目标则一律默认显示。
    if type(settings) == "table" then
        settings.previewColumns = type(settings.previewColumns) == "table" and settings.previewColumns or {}
        for _, legacyField in ipairs({ "character", "task", "target", "action", "stage", "progress" }) do settings.previewColumns[legacyField] = nil end
        for _, target in ipairs(self.Catalog:GetTargets()) do
            if settings.previewColumns[target.id] == nil then settings.previewColumns[target.id] = true end
        end
        settings.previewColumnsVersion = math.max(7, tonumber(settings.previewColumnsVersion) or 0)
        settings.selectedTargetId = settings.selectedTargetId or "CLOAK"
    end
    CopyDefaults(self.db, DEFAULTS)
    settings = self.db.settings
    settings.previewColumns = type(settings.previewColumns) == "table" and settings.previewColumns or {}
    for _, legacyField in ipairs({ "character", "task", "target", "action", "stage", "progress" }) do settings.previewColumns[legacyField] = nil end
    for _, target in ipairs(self.Catalog:GetTargets()) do
        if settings.previewColumns[target.id] == nil then settings.previewColumns[target.id] = true end
    end
    settings.previewColumnsVersion = math.max(7, tonumber(settings.previewColumnsVersion) or 0)
    local registered, registerError = self.Core:RegisterAddon(self.NAME, { version = self.VERSION, requiredAPI = self.REQUIRED_CORE_API })
    if not registered then self:Print(self:T("ERROR.CORE_REGISTRATION", tostring(registerError))); return end
    if self.Core.CharacterCleanup then
        local cleanupRegistered, cleanupError = self.Core.CharacterCleanup:RegisterOwner(self.NAME, {
            Inspect = function(character)
                local hasData = type(Addon.db.byCharacter[character.id]) == "table"
            return { hasData = hasData, label = Addon:T("CLEANUP.LABEL"), detail = hasData and Addon:T("CLEANUP.HAS_DATA") or Addon:T("CLEANUP.NO_DATA") }
            end,
            Delete = function(character)
                Addon.db.byCharacter[character.id] = nil
                Addon.Model:ClearCharacterRuntime(character.id)
                Addon.runtime.snapshotsByCharacter[character.id] = nil
                if Addon.UI then Addon.UI:Refresh() end
                return true
            end,
        })
        if not cleanupRegistered then
            self:Print(self:T("ERROR.CLEANUP", tostring(cleanupError)))
            return
        end
    end
    if self.GoalTargets then self.GoalTargets:Initialize() end
    self.initialized = true
    self.Probe:Run()
    self:Refresh("initialize")
    self.UI:Initialize()
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("QUEST_LOG_UPDATE")
frame:RegisterEvent("UPDATE_FACTION")
frame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
frame:RegisterEvent("BAG_UPDATE_DELAYED")
frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
frame:SetScript("OnEvent", function(_, event, ...)
    local arg1, arg2, arg3, arg4 = ...
    if event == "ADDON_LOADED" then
        if arg1 == ADDON_NAME then
            Addon:Initialize()
        end
        return
    end
    if Addon.initialized then
        -- Keep the complete CURRENCY_DISPLAY_UPDATE payload.  The tracker uses
        -- its quantityChange field and keeps balance-delta fallback support.
        Addon:QueueRefresh(event, arg1, arg2, arg3, arg4)
    end
end)

SLASH_YIBOLEGENDARY1 = "/yle"
SlashCmdList.YIBOLEGENDARY = function(command)
    command = string.lower(strtrim(command or ""))
    if command == "debug" or command == "debug on" then
        Addon.UI:SetMatrixDebug(true)
    elseif command == "debug off" then
        Addon.UI:SetMatrixDebug(false)
    elseif command == "debug dump" then
        Addon.UI:DebugMatrix("dump")
    elseif command == "probe" then
        Addon.Probe:Run(true)
        Addon:Print(self:T("CHAT.PROBE_REFRESHED"))
    elseif command == "status" then
        Addon.UI:PrintStatus()
    elseif command:match("^test%s+") then
        local targetID, nodeID = command:match("^test%s+(%S+)%s*(%S*)")
        local store, character = Addon:GetCharacterStore()
        local ok, message = character and Addon.Model:SetTestProjection(character.id, string.upper(targetID or ""), nodeID ~= "" and nodeID or nil)
        Addon:Print(ok and self:T("CHAT.TEST_UPDATED") or (message or self:T("CHAT.TEST_FAILED")))
        if ok then Addon:Refresh("test") end
    else
        Addon.UI:ToggleDetails()
    end
end
