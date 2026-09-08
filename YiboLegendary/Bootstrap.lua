local ADDON_NAME = ...

local Addon = _G.YiboLegendary or {}
_G.YiboLegendary = Addon
Addon.runtime = Addon.runtime or { testProjectionByCharacter = {}, snapshotsByCharacter = {} }
Addon.runtime.testProjectionByCharacter = {}
Addon.runtime.snapshotsByCharacter = {}
Addon.NAME = "YiboLegendary"
Addon.VERSION = "2.0.1"
Addon.REQUIRED_CORE_API = 5

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
        DEFAULT_CHAT_FRAME:AddMessage("|cffff9d2e[YiboLegendary]|r " .. tostring(message))
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

function Addon:Refresh(reason, currencyID, quantity, quantityChange, quantityGain)
    local store, character = self:GetCharacterStore()
    if not store then
        return
    end
    local valorProgress = self.Data:TrackValorProgress(store, currencyID, quantity, quantityChange, quantityGain)
    local snapshot = self.Model:BuildSnapshot(character, store, self.db.settings.phaseAvailability, valorProgress)
    snapshot.updatedAt = self:GetTimestamp()
    snapshot.reason = reason
    self.runtime.snapshotsByCharacter[character.id] = snapshot
    local hasProjection = false
    for _, state in pairs(snapshot.targets or {}) do if state.evidence and state.evidence.source == "projection" then hasProjection = true; break end end
    if not hasProjection then store.snapshot = snapshot end
    if self.UI then
        self.UI:Refresh(reason)
    end
end

function Addon:Initialize()
    if self.initialized then
        return
    end
    local core = _G.YiboCore
    if not core or not core:CheckAPIVersion(self.REQUIRED_CORE_API) then
        self:Print("需要 YiboCore API v" .. self.REQUIRED_CORE_API .. "。")
        return
    end

    self.Core = core
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
    self.Core:RegisterAddon(self.NAME, { version = self.VERSION, requiredAPI = self.REQUIRED_CORE_API })
    if self.Core.CharacterCleanup then
        local cleanupRegistered, cleanupError = self.Core.CharacterCleanup:RegisterOwner(self.NAME, {
            Inspect = function(character)
                local hasData = type(Addon.db.byCharacter[character.id]) == "table"
                return { hasData = hasData, label = "传说之路角色进度", detail = hasData and "已有任务进度快照" or "无角色缓存" }
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
            self:Print("角色缓存清理接入失败：" .. tostring(cleanupError))
            return
        end
    end
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
        Addon.Probe:Run()
        Addon:Refresh(event, arg1, arg2, arg3, arg4)
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
        Addon:Print("客户端探针已刷新；使用 /yle probe 查看聊天输出。")
    elseif command == "status" then
        Addon.UI:PrintStatus()
    elseif command:match("^test%s+") then
        local targetID, nodeID = command:match("^test%s+(%S+)%s*(%S*)")
        local store, character = Addon:GetCharacterStore()
        local ok, message = character and Addon.Model:SetTestProjection(character.id, string.upper(targetID or ""), nodeID ~= "" and nodeID or nil)
        Addon:Print(ok and "测试投影已更新。" or (message or "无法写入测试投影。"))
        if ok then Addon:Refresh("test") end
    else
        Addon.UI:ToggleDetails()
    end
end
