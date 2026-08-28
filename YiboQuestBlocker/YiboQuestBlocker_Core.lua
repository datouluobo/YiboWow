-- ============================================================================
-- YiboQuestBlocker_Core.lua
-- 数据层 + AcceptQuest 拦截
-- ============================================================================

-- ==================== 数据初始化 ====================
YiboQuestBlockerDB = YiboQuestBlockerDB or {}

local ADDON_NAME = ...
local Core = assert(_G.YiboCore, "YiboQuestBlocker v2 requires YiboCore")
local curCharacterID = Core.Characters:GetCurrentID()
local PersistDB

local function MergeTables(target, source)
    target = type(target) == "table" and target or {}
    if type(source) ~= "table" then return target end
    for key, value in pairs(source) do
        if type(value) == "table" then
            target[key] = MergeTables(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        elseif type(value) == "boolean" then
            target[key] = target[key] or value
        end
    end
    return target
end

local function ResolveV1CharacterID(key)
    return Core.Characters:ResolveLegacyKey(key)
end

local function BuildV1RealmSet()
    local realms, firstPartCounts = {}, {}
    for _, character in ipairs(Core.Characters:GetAll()) do
        if character.realm and character.realm ~= "" then realms[character.realm] = true end
    end
    for oldKey in pairs(YiboQuestBlockerDB.knownChars or {}) do
        local left = tostring(oldKey):match("^(.-)%-")
        if left then firstPartCounts[left] = (firstPartCounts[left] or 0) + 1 end
    end
    -- A server appears as the first component for multiple v1 characters;
    -- character names normally occur only once.  This also recognizes realms
    -- not yet present in Core without depending on Lua table iteration order.
    for value, count in pairs(firstPartCounts) do if count >= 2 then realms[value] = true end end
    return realms
end

local function BuildV1Identity(oldKey, identity, assumeRealmFirst, knownRealms)
    local existingID = ResolveV1CharacterID(oldKey)
    local left, right = tostring(oldKey or ""):match("^(.-)%-(.+)$")
    if not left or not right then return existingID end

    local realms = knownRealms or BuildV1RealmSet()

    local name, realm
    if realms[left] and not realms[right] then
        realm, name = left, right
    elseif realms[right] and not realms[left] then
        name, realm = left, right
    else
        local current = Core.Characters:GetCurrent()
        if current and ((left == current.realm and right == current.name) or (left == current.name and right == current.realm)) then
            name, realm = current.name, current.realm
        elseif assumeRealmFirst then
            -- QuestBlocker v1's canonical durable key was `服务器-角色名`.
            -- Reversed aliases introduced by intermediate builds will already
            -- resolve through Core before reaching this fallback.
            realm, name = left, right
        end
    end
    if not name or not realm then return existingID end

    local imported = {
        name = name,
        realm = realm,
        class = identity and identity.class,
        level = identity and identity.level,
        seenOrder = identity and identity.seenOrder,
    }
    return Core.Characters:ImportLegacyCharacter(ADDON_NAME, oldKey, imported)
end

local function MigrateV1Database()
    local characterData = type(YiboQuestBlockerDB.characterData) == "table" and YiboQuestBlockerDB.characterData or {}
    local sourceSnapshots = YiboQuestBlockerDB.perChar or {}
    local sourceCount, migratedCount = 0, 0
    local knownRealms = BuildV1RealmSet()

    -- One-time upgrade only: hand v1 identity metadata to Core first, then
    -- translate business snapshots to Core IDs.  v1 fields are erased only
    -- after every business snapshot has a durable Core identity.
    for oldKey, identity in pairs(YiboQuestBlockerDB.knownChars or {}) do
        BuildV1Identity(oldKey, identity, false, knownRealms)
    end
    for oldKey, data in pairs(sourceSnapshots) do
        sourceCount = sourceCount + 1
        local characterID = ResolveV1CharacterID(oldKey) or BuildV1Identity(oldKey, nil, true, knownRealms)
        if characterID then
            characterData[characterID] = MergeTables(characterData[characterID], data)
            migratedCount = migratedCount + 1
        end
    end
    YiboQuestBlockerDB.characterData = characterData
    YiboQuestBlockerDB.schemaVersion = 2
    if migratedCount == sourceCount then
        YiboQuestBlockerDB.knownChars = nil
        YiboQuestBlockerDB.perChar = nil
        YiboQuestBlockerDB.customCharOrder = nil
        YiboQuestBlockerDB.characterOrder = nil
        YiboQuestBlockerDB.characterKeyVersion = nil
        YiboQuestBlockerDB.migrationError = nil
    else
        YiboQuestBlockerDB.migrationError = {
            sourceCount = sourceCount,
            migratedCount = migratedCount,
        }
    end
end

MigrateV1Database()
YiboQuestBlockerDB.characterData = YiboQuestBlockerDB.characterData or {}
YiboQuestBlockerDB.characterData[curCharacterID] = YiboQuestBlockerDB.characterData[curCharacterID] or { blocked = {}, cache = {} }

-- 初始化全局屏蔽
if not YiboQuestBlockerDB.globalBlocked then YiboQuestBlockerDB.globalBlocked = {} end
if not YiboQuestBlockerDB.globalCache   then YiboQuestBlockerDB.globalCache   = {} end

-- 初始化过滤器
if not YiboQuestBlockerDB.filters then
    YiboQuestBlockerDB.filters = {
        showDaily     = true,
        showNormal    = true,
        hideComplete  = true,
        reportChat    = true,
        autoAbandon   = false,
        levelExpr     = "90",
    }
end

-- 账号视图的预览列仍归 QuestBlocker 自己保存；Core 只读取和渲染。
if not YiboQuestBlockerDB.settings then
    YiboQuestBlockerDB.settings = {}
end
if not YiboQuestBlockerDB.settings.previewColumns then
    YiboQuestBlockerDB.settings.previewColumns = {
        global = true,
        characters = true,
    }
end
-- 本地引用（加速 + 避免被外部篡改绕过的风险）
local YQBDB   = YiboQuestBlockerDB
local blocked = YiboQuestBlockerDB.globalBlocked
local cache   = YiboQuestBlockerDB.globalCache
local characterData = YiboQuestBlockerDB.characterData

local PREFIX      = "|cff00ccff[YQB]|r"
local PREFIX_ERR  = "|cffff0000[YQB]|r"
local PREFIX_INFO = "|cff888888[YQB]|r"
local recentBlockNotices = {}
local autoAbandonQueue = {}
local autoAbandonSet = {}
local autoAbandonTimerToken = 0
local autoAbandonTimerActive = false
local autoAbandonWaitingForClose = false
local autoAbandonProcessing = false
local reportedUnabandonable = {}
local syncThrottleUntil = 0
local MaybeStartAutoAbandonTimer

PersistDB = function()
    YiboQuestBlockerDB = YiboQuestBlockerDB or {}
    YiboQuestBlockerDB.globalBlocked = YQBDB.globalBlocked
    YiboQuestBlockerDB.globalCache = YQBDB.globalCache
    YiboQuestBlockerDB.characterData = YQBDB.characterData
    YiboQuestBlockerDB.filters = YQBDB.filters
    YiboQuestBlockerDB.settings = YQBDB.settings
    YiboQuestBlockerDB.schemaVersion = 2
end

local function BindDBReferences()
    YiboQuestBlockerDB = YiboQuestBlockerDB or {}
    YiboQuestBlockerDB.globalBlocked = YiboQuestBlockerDB.globalBlocked or {}
    YiboQuestBlockerDB.globalCache = YiboQuestBlockerDB.globalCache or {}
    YiboQuestBlockerDB.characterData = YiboQuestBlockerDB.characterData or {}
    YiboQuestBlockerDB.settings = YiboQuestBlockerDB.settings or {}
    YiboQuestBlockerDB.settings.previewColumns = YiboQuestBlockerDB.settings.previewColumns or {
        global = true,
        characters = true,
    }
    YiboQuestBlockerDB.filters = YiboQuestBlockerDB.filters or {
        showDaily = true,
        showNormal = true,
        hideComplete = true,
        reportChat = true,
        autoAbandon = false,
        levelExpr = "90",
    }
    if YiboQuestBlockerDB.filters.reportChat == nil then
        YiboQuestBlockerDB.filters.reportChat = true
    end
    if YiboQuestBlockerDB.filters.autoAbandon == nil then
        YiboQuestBlockerDB.filters.autoAbandon = false
    end

    if YiboQuestBlockerDB.filters.levelExpr == nil then
        local minLevel = tonumber(YiboQuestBlockerDB.filters.levelMin) or 0
        local maxLevel = tonumber(YiboQuestBlockerDB.filters.levelMax) or 90
        local op = YiboQuestBlockerDB.filters.levelOp
        if op == "以上" then
            YiboQuestBlockerDB.filters.levelExpr = ">=" .. minLevel
        elseif op == "以下" then
            YiboQuestBlockerDB.filters.levelExpr = "<=" .. maxLevel
        elseif op == "等于" then
            YiboQuestBlockerDB.filters.levelExpr = tostring(minLevel)
        elseif op == "至" and not (minLevel == 0 and maxLevel == 90) then
            YiboQuestBlockerDB.filters.levelExpr = minLevel .. "-" .. maxLevel
        else
            YiboQuestBlockerDB.filters.levelExpr = ""
        end
    end

    local latestID = Core.Characters:GetCurrentID()
    if latestID ~= curCharacterID then
        YiboQuestBlockerDB.characterData[latestID] = MergeTables(
            YiboQuestBlockerDB.characterData[latestID],
            YiboQuestBlockerDB.characterData[curCharacterID]
        )
        YiboQuestBlockerDB.characterData[curCharacterID] = nil
        curCharacterID = latestID
        if _G.YQB then _G.YQB.curCharacterID = latestID end
    end
    YiboQuestBlockerDB.characterData[curCharacterID] = YiboQuestBlockerDB.characterData[curCharacterID]
        or { blocked = {}, cache = {} }

    YQBDB = YiboQuestBlockerDB
    blocked = YQBDB.globalBlocked
    cache = YQBDB.globalCache
    characterData = YQBDB.characterData
end

-- 暴露给 UI 模块的引用（UI 会通过全局表 YQB 访问）
YQB = YQB or {}
YQB.curCharacterID = curCharacterID
YQB.PREFIX     = PREFIX
YQB.PREFIX_ERR = PREFIX_ERR
YQB.PREFIX_INFO = PREFIX_INFO
YQB.PersistDB = function()
    PersistDB()
end
YQB.IsChatReportingEnabled = function()
    return not not (YQBDB.filters and YQBDB.filters.reportChat)
end
YQB.ReportMessage = function(message, isError)
    if not YQB.IsChatReportingEnabled() or not message then
        return
    end
    DEFAULT_CHAT_FRAME:AddMessage((isError and PREFIX_ERR or PREFIX_INFO) .. " " .. message)
end

Core.Events:Register("CHARACTER_ID_CHANGED", ADDON_NAME, function(_, oldID, newID)
    if not oldID or not newID or oldID == newID then return end
    local oldData = characterData[oldID]
    if oldData then
        characterData[newID] = MergeTables(characterData[newID], oldData)
        characterData[oldID] = nil
    end
    if curCharacterID == oldID then
        curCharacterID = newID
        YQB.curCharacterID = newID
    end
    PersistDB()
    if YQB.NotifyCorePageChanged then YQB.NotifyCorePageChanged() end
end)
YQB.IsAutoAbandonEnabled = function()
    return not not (YQBDB.filters and YQBDB.filters.autoAbandon)
end
YQB.GetDatabase = function()
    return YQBDB
end
YQB.GetCurrentCharacterID = function()
    return curCharacterID
end
BindDBReferences()
PersistDB()

-- ==================== 工具函数 ====================

-- 获取任务名称：优先从日志，其次从缓存，最后返回 nil
function YQB.GetQuestName(questID)
    if not questID then return nil end

    -- 1) 从任务日志查
    if GetQuestLogIndexByID then
        local idx = GetQuestLogIndexByID(questID)
        if idx and idx > 0 then
            local name = select(1, GetQuestLogTitle(idx))
            if name then
                -- 写入缓存
                if characterData[curCharacterID] and characterData[curCharacterID].cache then
                    characterData[curCharacterID].cache[questID] = name
                end
                cache[questID] = name
                return name
            end
        end
    end

    -- 2) 从全局缓存找
    if cache[questID] then
        return cache[questID]
    end

    -- 3) 从当前角色缓存找
    if characterData[curCharacterID] and characterData[curCharacterID].cache and characterData[curCharacterID].cache[questID] then
        return characterData[curCharacterID].cache[questID]
    end

    return nil
end

-- 判断任务是否被屏蔽（全局 OR 当前角色）
function YQB.IsQuestBlocked(questID)
    if not questID then return false end
    if YQBDB.globalBlocked[questID] then return true end
    if characterData[curCharacterID] and characterData[curCharacterID].blocked[questID] then return true end
    return false
end

-- 判断任务是否被任何角色屏蔽（用于"屏蔽组"显示）
function YQB.IsQuestBlockedByAny(questID)
    if not questID then return false end
    if YQBDB.globalBlocked[questID] then return true end
    for _, data in pairs(characterData) do
        if data.blocked and data.blocked[questID] then
            return true
        end
    end
    return false
end

-- 获取角色屏蔽状态表，以 Core characterID 为索引。
function YQB.GetBlockStatus(questID)
    local status = { global = YQBDB.globalBlocked[questID] or false }
    for characterID in pairs(characterData) do
        if characterData[characterID] and characterData[characterID].blocked then
            status[characterID] = characterData[characterID].blocked[questID] or false
        else
            status[characterID] = false
        end
    end
    return status
end

-- 获取角色等级
function YQB.GetCharLevel(characterID)
    local character = Core.Characters:Get(characterID)
    return character and character.level or 0
end

local DAILY_OVERRIDE_IDS = {
    [29433] = true,
    [91710] = true,
    [32642] = true,
    [32643] = true,
    [32645] = true,
    [32646] = true,
    [32647] = true,
    [32648] = true,
    [32649] = true,
    [32650] = true,
    [32653] = true,
    [32657] = true,
    [32658] = true,
    [32659] = true,
    [32942] = true,
    [32943] = true,
    [32944] = true,
    [32945] = true,
}

local function tableSize(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end

local function IsQuestInteractionVisible()
    return (QuestFrame and QuestFrame:IsShown())
        or (GossipFrame and GossipFrame:IsShown())
end

local function IsQuestStillInLog(questID)
    local idx = GetQuestLogIndexByID and GetQuestLogIndexByID(questID)
    return idx and idx > 0
end

local function RemoveAutoAbandonQuest(questID)
    if not questID or not autoAbandonSet[questID] then
        return
    end

    autoAbandonSet[questID] = nil
    for index = #autoAbandonQueue, 1, -1 do
        if autoAbandonQueue[index] == questID then
            table.remove(autoAbandonQueue, index)
        end
    end
end

local function PruneAutoAbandonQueue()
    for index = #autoAbandonQueue, 1, -1 do
        local questID = autoAbandonQueue[index]
        if not questID or not YQB.IsQuestBlocked(questID) or not IsQuestStillInLog(questID) then
            autoAbandonSet[questID] = nil
            table.remove(autoAbandonQueue, index)
        end
    end
end

local function EnqueueAutoAbandonQuest(questID)
    if not questID or autoAbandonSet[questID] then
        return false
    end

    autoAbandonSet[questID] = true
    autoAbandonQueue[#autoAbandonQueue + 1] = questID
    return true
end

local function ResetAutoAbandonState()
    autoAbandonTimerToken = autoAbandonTimerToken + 1
    autoAbandonTimerActive = false
    autoAbandonWaitingForClose = false
    autoAbandonProcessing = false
    wipe(autoAbandonQueue)
    wipe(autoAbandonSet)
end

local function HasRejectedQuestInLog()
    local numEntries = GetNumQuestLogEntries and GetNumQuestLogEntries() or 0
    for idx = 1, numEntries do
        local _, _, _, isHeader, _, _, _, questID = GetQuestLogTitle(idx)
        if not isHeader and questID and YQB.IsQuestBlocked(questID) then
            return true
        end
    end
    return false
end

local function SyncRejectedQuestsToQueue(force)
    if not YQB.IsAutoAbandonEnabled() then
        wipe(autoAbandonQueue)
        wipe(autoAbandonSet)
        autoAbandonWaitingForClose = false
        syncThrottleUntil = 0
        return 0
    end

    -- 节流：非强制调用时，2秒内不重复扫描
    if not force and GetTime() < syncThrottleUntil then
        return -1
    end
    syncThrottleUntil = GetTime() + 2

    local queued = 0
    local numEntries = GetNumQuestLogEntries and GetNumQuestLogEntries() or 0
    for idx = 1, numEntries do
        local _, _, _, isHeader, _, _, _, questID = GetQuestLogTitle(idx)
        if not isHeader and questID and YQB.IsQuestBlocked(questID) then
            if EnqueueAutoAbandonQuest(questID) then
                queued = queued + 1
            end
        end
    end
    PruneAutoAbandonQueue()
    MaybeStartAutoAbandonTimer()
    return queued
end

YQB.HasRejectedQuestInLog = HasRejectedQuestInLog
YQB.SyncRejectedQuestsToQueue = SyncRejectedQuestsToQueue
YQB.CancelAutoAbandonTimer = ResetAutoAbandonState

local function ReportQueuedQuest(scope, questID, name, confirmType)
    local key = table.concat({
        tostring(scope or "unknown"),
        tostring(questID or 0),
        "queued",
    }, ":")

    if recentBlockNotices[key] then
        return
    end

    recentBlockNotices[key] = true

    local actionText = confirmType and "已标记确认型拒绝任务: " or "已标记"
    if scope == "global" then
        YQB.ReportMessage(actionText .. "全局拒绝任务，等待自动放弃: " .. name, true)
    else
        YQB.ReportMessage(actionText .. "个人拒绝任务，等待自动放弃: " .. name, true)
    end
end

local function QueueRejectedQuest(questID, scope, confirmType)
    if not questID or not YQB.IsQuestBlocked(questID) then
        return false
    end

    if not YQB.IsAutoAbandonEnabled() then
        return false
    end

    local name = YQB.GetQuestName(questID) or ("ID: " .. questID)
    if EnqueueAutoAbandonQuest(questID) then
        ReportQueuedQuest(scope, questID, name, confirmType)
        PersistDB()
        MaybeStartAutoAbandonTimer()
        return true
    end
    return false
end

local function ConfirmVisibleAbandonPopup()
    for index = 1, 4 do
        local popup = _G["StaticPopup" .. index]
        if popup and popup:IsShown() then
            local which = popup.which
            if which == "ABANDON_QUEST" or which == "ABANDON_QUEST_WITH_ITEMS" then
                StaticPopup_OnClick(popup, 1)
                return true
            end
        end
    end
    return false
end

local function CanAbandonQuestByID(questID)
    if not questID then
        return nil
    end

    if C_QuestLog and C_QuestLog.CanAbandonQuest then
        local ok, canAbandon = pcall(C_QuestLog.CanAbandonQuest, questID)
        if ok and canAbandon ~= nil then
            return not not canAbandon
        end
    end

    if CanAbandonQuest then
        local ok, canAbandon = pcall(CanAbandonQuest, questID)
        if ok and canAbandon ~= nil then
            return not not canAbandon
        end

        ok, canAbandon = pcall(CanAbandonQuest)
        if ok and canAbandon ~= nil then
            return not not canAbandon
        end
    end

    return nil
end

local function RunAbandonQuestFlow(idx, questID)
    if not idx or idx <= 0 then
        return false
    end

    local lastSelection = GetQuestLogSelection and GetQuestLogSelection() or nil

    SelectQuestLogEntry(idx)
    SetAbandonQuest()
    AbandonQuest()
    ConfirmVisibleAbandonPopup()

    if lastSelection and lastSelection > 0 and lastSelection ~= idx then
        SelectQuestLogEntry(lastSelection)
    end

    return true
end

local function TryAutoAbandonQuest(questID)
    local idx = GetQuestLogIndexByID and GetQuestLogIndexByID(questID)
    if not idx or idx <= 0 then
        RemoveAutoAbandonQuest(questID)
        return false, "missing"
    end

    local canAbandon = CanAbandonQuestByID(questID)
    if canAbandon == false then
        return false, "locked"
    end

    RunAbandonQuestFlow(idx, questID)
    return true, "abandoned"
end

MaybeStartAutoAbandonTimer = function()
    if autoAbandonTimerActive or autoAbandonProcessing then
        return
    end

    if not YQB.IsAutoAbandonEnabled() then
        return
    end

    if #autoAbandonQueue == 0 then
        autoAbandonWaitingForClose = false
        return
    end

    if IsQuestInteractionVisible() then
        autoAbandonWaitingForClose = true
        return
    end

    autoAbandonWaitingForClose = false
    autoAbandonTimerActive = true
    autoAbandonTimerToken = autoAbandonTimerToken + 1

    local token = autoAbandonTimerToken
    C_Timer.After(3, function()
        if token ~= autoAbandonTimerToken then
            return
        end
        autoAbandonTimerActive = false
        autoAbandonProcessing = true

        PruneAutoAbandonQueue()
        local questID = autoAbandonQueue[1]
        if not questID then
            autoAbandonProcessing = false
            MaybeStartAutoAbandonTimer()
            return
        end

        local ok, reason = TryAutoAbandonQuest(questID)
        if ok then
            RemoveAutoAbandonQuest(questID)
        elseif reason == "locked" then
            RemoveAutoAbandonQuest(questID)
            if not reportedUnabandonable[questID] then
                reportedUnabandonable[questID] = true
                YQB.ReportMessage("任务无法放弃: " .. (YQB.GetQuestName(questID) or ("ID: " .. questID)), true)
            end
        end

        autoAbandonProcessing = false
        PersistDB()
        MaybeStartAutoAbandonTimer()
    end)
end

local function GetQuestFrequencyData(idx)
    local frequency = select(7, GetQuestLogTitle(idx))
    local isRecurring = frequency and frequency > 1
    local isDaily = frequency == 2
    return frequency, isRecurring, isDaily
end

local function GetQuestTypeFlags(questID, idx)
    local frequency, isRecurring, isDaily = GetQuestFrequencyData(idx)
    local isWeekly = frequency == 3
    local isRepeatable = false
    local isMonthly = false

    if DAILY_OVERRIDE_IDS[questID] then
        isDaily = true
        isRecurring = true
    end

    if QuestieDB then
        if QuestieDB.IsDailyQuest and QuestieDB.IsDailyQuest(questID) then
            isDaily = true
            isRecurring = true
        end
        if QuestieDB.IsWeeklyQuest and QuestieDB.IsWeeklyQuest(questID) then
            isWeekly = true
            isRecurring = true
        end
        if QuestieDB.IsRepeatable and QuestieDB.IsRepeatable(questID) then
            isRepeatable = true
            isRecurring = true
        end
        if QuestieDB.IsMonthlyQuest and QuestieDB.IsMonthlyQuest(questID) then
            isMonthly = true
            isRecurring = true
        end
        if QuestieDB.QueryQuestSingle then
            local questFlags = QuestieDB.QueryQuestSingle(questID, "questFlags") or 0
            local specialFlags = QuestieDB.QueryQuestSingle(questID, "specialFlags") or 0

            if questFlags > 0 then
                if QuestieDB.IsDailyQuest and QuestieDB.IsDailyQuest(questID) then
                    isDaily = true
                end
                if QuestieDB.IsWeeklyQuest and QuestieDB.IsWeeklyQuest(questID) then
                    isWeekly = true
                end
                if QuestieDB.IsMonthlyQuest and QuestieDB.IsMonthlyQuest(questID) then
                    isMonthly = true
                end
            end
            if specialFlags > 0 then
                isRepeatable = isRepeatable or (bit.band(specialFlags, 1) ~= 0)
            end
        end
    end

    local questName = questID and YQB.GetQuestName(questID)
    if questName and string.find(questName, "产品订单", 1, true) then
        isDaily = true
        isRecurring = true
    end

    return {
        frequency = frequency,
        isRecurring = isRecurring or isDaily or isWeekly or isMonthly or isRepeatable,
        isDaily = isDaily,
        isWeekly = isWeekly,
        isMonthly = isMonthly,
        isRepeatable = isRepeatable,
    }
end

local levelExprCacheText, levelExprCacheRules, levelExprCacheError

function YQB.NormalizeLevelExpr(expr)
    expr = tostring(expr or "")
    expr = expr:gsub("%s+", "")
    expr = expr:gsub(",+", ",")
    expr = expr:gsub("^,", "")
    expr = expr:gsub(",$", "")
    return expr
end

local function parseLevelExpr(expr)
    local normalized = YQB.NormalizeLevelExpr(expr)
    if normalized == "" or normalized == "0" then
        return true, {}, ""
    end

    if levelExprCacheText == normalized then
        return levelExprCacheError == nil, levelExprCacheRules or {}, levelExprCacheError
    end

    local rules = {}
    for token in string.gmatch(normalized, "[^,]+") do
        local a, b = string.match(token, "^(%d+)%-(%d+)$")
        if a and b then
            local minLevel = tonumber(a)
            local maxLevel = tonumber(b)
            if minLevel > maxLevel then
                minLevel, maxLevel = maxLevel, minLevel
            end
            rules[#rules + 1] = { kind = "range", min = minLevel, max = maxLevel }
        else
            local ge = string.match(token, "^>=(%d+)$")
            local le = string.match(token, "^<=(%d+)$")
            local gt = string.match(token, "^>(%d+)$")
            local lt = string.match(token, "^<(%d+)$")
            local eq = string.match(token, "^(%d+)$")

            if ge then
                rules[#rules + 1] = { kind = "ge", value = tonumber(ge) }
            elseif le then
                rules[#rules + 1] = { kind = "le", value = tonumber(le) }
            elseif gt then
                rules[#rules + 1] = { kind = "gt", value = tonumber(gt) }
            elseif lt then
                rules[#rules + 1] = { kind = "lt", value = tonumber(lt) }
            elseif eq then
                rules[#rules + 1] = { kind = "eq", value = tonumber(eq) }
            else
                levelExprCacheText = normalized
                levelExprCacheRules = nil
                levelExprCacheError = token
                return false, {}, token
            end
        end
    end

    levelExprCacheText = normalized
    levelExprCacheRules = rules
    levelExprCacheError = nil
    return true, rules, ""
end

function YQB.ValidateLevelExpr(expr)
    local valid, _, badToken = parseLevelExpr(expr)
    return valid, YQB.NormalizeLevelExpr(expr), badToken
end

function YQB.GetLevelFilterExpr()
    return (YQBDB.filters and YQBDB.filters.levelExpr) or ""
end

function YQB.SetLevelFilterExpr(expr)
    local valid, normalized, badToken = YQB.ValidateLevelExpr(expr)
    if not valid then return false, badToken end
    YQBDB.filters.levelExpr = normalized
    PersistDB()
    if YQB.NotifyCorePageChanged then YQB.NotifyCorePageChanged() end
    return true, normalized
end

-- 判断角色是否通过等级过滤
function YQB.CharPassLevelFilter(characterID)
    local filter = YQBDB.filters
    local level  = YQB.GetCharLevel(characterID)
    local valid, rules = parseLevelExpr(filter.levelExpr)

    if not valid or not rules or #rules == 0 then
        return true
    end

    for _, rule in ipairs(rules) do
        if rule.kind == "range" and level >= rule.min and level <= rule.max then
            return true
        elseif rule.kind == "ge" and level >= rule.value then
            return true
        elseif rule.kind == "le" and level <= rule.value then
            return true
        elseif rule.kind == "gt" and level > rule.value then
            return true
        elseif rule.kind == "lt" and level < rule.value then
            return true
        elseif rule.kind == "eq" and level == rule.value then
            return true
        end
    end

    return false
end

-- 判断任务是否通过任务类型过滤器
function YQB.QuestPassFilter(questID)
    local idx = GetQuestLogIndexByID(questID)
    if not idx or idx <= 0 then return true end  -- 不在日志中的任务不筛选

    local _, _, _, _, _, isComplete = GetQuestLogTitle(idx)
    local flags = GetQuestTypeFlags(questID, idx)

    local filter = YQBDB.filters
    -- 日常/周常/可重复任务
    if flags.isRecurring and not filter.showDaily then return false end
    -- 普通任务
    if not flags.isRecurring and not filter.showNormal then return false end
    -- 已完成任务
    if filter.hideComplete and isComplete and isComplete ~= 0 then return false end

    return true
end

-- 扫描当前角色任务日志，返回未屏蔽的任务列表
-- 注意：Lua 没有 continue，用 skip 标志跳过不合条件的条目
function YQB.GetCurrentQuestList()
    local list = {}
    local numEntries = GetNumQuestLogEntries()

    for idx = 1, numEntries do
        local name, level, _, isHeader, _, isComplete, _, questID = GetQuestLogTitle(idx)
        local flags = GetQuestTypeFlags(questID, idx)

        -- 没有名称 = 日志结束
        if not name then break end

        local skip = false

        -- 跳过标题头（分组标题如"地下城""日常"）
        if isHeader then skip = true end

        -- 跳过已被屏蔽的
        if not skip and YQB.IsQuestBlocked(questID) then skip = true end

        -- 应用过滤器
        if not skip and flags.isRecurring and not YQBDB.filters.showDaily then skip = true end
        if not skip and not flags.isRecurring and not YQBDB.filters.showNormal then skip = true end
        if not skip and YQBDB.filters.hideComplete and isComplete and isComplete ~= 0 then skip = true end

        if not skip and questID and questID > 0 then
            tinsert(list, {
                id       = questID,
                name     = name,
                level    = level,
                isDaily  = flags.isDaily,
                isWeekly = flags.isWeekly,
                frequency = flags.frequency,
                isRepeatable = flags.isRepeatable,
                idx      = idx,
            })
        end
    end

    return list
end

function YQB.GetFilteredCurrentQuestCount()
    local count = 0
    local numEntries = GetNumQuestLogEntries()

    for idx = 1, numEntries do
        local name, _, _, isHeader, _, isComplete, _, questID = GetQuestLogTitle(idx)
        local flags = GetQuestTypeFlags(questID, idx)

        if not name then break end

        local skip = false
        if isHeader then skip = true end
        if not skip and flags.isRecurring and not YQBDB.filters.showDaily then skip = true end
        if not skip and not flags.isRecurring and not YQBDB.filters.showNormal then skip = true end
        if not skip and YQBDB.filters.hideComplete and isComplete and isComplete ~= 0 then skip = true end

        if not skip and questID and questID > 0 then
            count = count + 1
        end
    end

    return count
end

function YQB.GetCurrentQuestTotalCount()
    local count = 0
    local numEntries = GetNumQuestLogEntries()

    for idx = 1, numEntries do
        local name, _, _, isHeader, _, _, _, questID = GetQuestLogTitle(idx)
        if not name then break end
        if not isHeader and questID and questID > 0 then
            count = count + 1
        end
    end

    return count
end

-- 获取被屏蔽的任务列表（含来源信息）
function YQB.GetBlockedQuestList()
    local list = {}
    local seen = {}

    -- 全局屏蔽
    for questID, _ in pairs(YQBDB.globalBlocked) do
        local name = YQB.GetQuestName(questID) or cache[questID] or "?"
        tinsert(list, {
            id   = questID,
            name = name,
        })
        seen[questID] = true
    end

    -- 各角色个人屏蔽
    for characterID, charData in pairs(characterData) do
        if charData.blocked then
            for questID, _ in pairs(charData.blocked) do
                if not seen[questID] then
                    local name = charData.cache and charData.cache[questID] or cache[questID] or "?"
                    tinsert(list, {
                        id   = questID,
                        name = name,
                    })
                    seen[questID] = true
                end
            end
        end
    end

    table.sort(list, function(a, b)
        if a.id ~= b.id then
            return a.id < b.id
        end
        return (a.name or "") < (b.name or "")
    end)

    return list
end

-- 添加屏蔽
function YQB.AddBlock(questID, scope)
    -- scope: "global" or "char"
    if not questID then return end

    if scope == "global" then
        YQBDB.globalBlocked[questID] = true
    else
        if not characterData[curCharacterID] then
            characterData[curCharacterID] = { blocked = {}, cache = {} }
        end
        characterData[curCharacterID].blocked[questID] = true
    end

    -- 尝试缓存名称
    YQB.GetQuestName(questID)
    if YQB.IsAutoAbandonEnabled() and IsQuestStillInLog(questID) then
        EnqueueAutoAbandonQuest(questID)
        MaybeStartAutoAbandonTimer()
    end
    PersistDB()
    if YQB.NotifyCorePageChanged then YQB.NotifyCorePageChanged() end
end

function YQB.AddCharBlock(questID, characterID)
    if not questID or not characterID then return end

    if not characterData[characterID] then
        characterData[characterID] = {
            blocked = {},
            cache = {},
        }
    end
    if not characterData[characterID].blocked then
        characterData[characterID].blocked = {}
    end
    if not characterData[characterID].cache then
        characterData[characterID].cache = {}
    end

    characterData[characterID].blocked[questID] = true
    YQB.GetQuestName(questID)
    if characterID == curCharacterID and YQB.IsAutoAbandonEnabled() and IsQuestStillInLog(questID) then
        EnqueueAutoAbandonQuest(questID)
        MaybeStartAutoAbandonTimer()
    end
    PersistDB()
    if YQB.NotifyCorePageChanged then YQB.NotifyCorePageChanged() end
end

-- 移除屏蔽
function YQB.RemoveBlock(questID, scope)
    if not questID then return end

    if scope == "global" then
        YQBDB.globalBlocked[questID] = nil
    else
        if characterData[curCharacterID] and characterData[curCharacterID].blocked then
            characterData[curCharacterID].blocked[questID] = nil
        end
    end
    if YQB.IsQuestBlocked(questID) and IsQuestStillInLog(questID) and YQB.IsAutoAbandonEnabled() then
        EnqueueAutoAbandonQuest(questID)
        MaybeStartAutoAbandonTimer()
    else
        RemoveAutoAbandonQuest(questID)
    end
    PersistDB()
    if YQB.NotifyCorePageChanged then YQB.NotifyCorePageChanged() end
end

-- 移除指定角色的指定任务屏蔽
function YQB.RemoveCharBlock(questID, characterID)
    if not questID or not characterID then return end
    if characterData[characterID] and characterData[characterID].blocked then
        characterData[characterID].blocked[questID] = nil
        if characterID == curCharacterID and YQB.IsQuestBlocked(questID) and IsQuestStillInLog(questID) and YQB.IsAutoAbandonEnabled() then
            EnqueueAutoAbandonQuest(questID)
            MaybeStartAutoAbandonTimer()
        elseif characterID == curCharacterID then
            RemoveAutoAbandonQuest(questID)
        end
        PersistDB()
        if YQB.NotifyCorePageChanged then YQB.NotifyCorePageChanged() end
    end
end

-- 放弃当前角色日志中的任务
function YQB.AbandonQuest(questID)
    local idx = GetQuestLogIndexByID(questID)
    if idx and idx > 0 then
        RunAbandonQuestFlow(idx, questID)
    end
end

function YQB.AbandonRejectedQuestsInLog()
    local abandoned = 0
    local numEntries = GetNumQuestLogEntries()
    local lastSelection = GetQuestLogSelection and GetQuestLogSelection() or nil

    ResetAutoAbandonState()

    for idx = numEntries, 1, -1 do
        local _, _, _, isHeader, _, _, _, questID = GetQuestLogTitle(idx)
        if not isHeader and questID and YQB.IsQuestBlocked(questID) then
            local canAbandon = CanAbandonQuestByID(questID)
            if canAbandon ~= false and RunAbandonQuestFlow(idx, questID) then
                abandoned = abandoned + 1
                RemoveAutoAbandonQuest(questID)
            end
        end
    end

    if lastSelection and lastSelection > 0 then
        SelectQuestLogEntry(lastSelection)
    end

    return abandoned
end

-- 统计信息
function YQB.GetStats()
    local globalCount = tableSize(YQBDB.globalBlocked)
    local charCount   = characterData[curCharacterID] and tableSize(characterData[curCharacterID].blocked) or 0
    local total       = tableSize(YQBDB.globalBlocked)
    for _, charData in pairs(characterData) do
        if charData.blocked then
            total = total + tableSize(charData.blocked)
        end
    end

    return globalCount, charCount, total
end

-- ==================== 核心：包裹 AcceptQuest ====================
local OriginalAcceptQuest = AcceptQuest
AcceptQuest = function(...)
    local questID = GetQuestID()
    if questID then
        if YQBDB.globalBlocked[questID] then
            QueueRejectedQuest(questID, "global", false)
            return OriginalAcceptQuest(...)
        end
        if characterData[curCharacterID] and characterData[curCharacterID].blocked[questID] then
            QueueRejectedQuest(questID, "char", false)
            return OriginalAcceptQuest(...)
        end
    end
    return OriginalAcceptQuest(...)
end

-- ==================== 核心：包裹 ConfirmAcceptQuest ====================
if ConfirmAcceptQuest then
    local OriginalConfirmAcceptQuest = ConfirmAcceptQuest
    ConfirmAcceptQuest = function(...)
        local questID = GetQuestID()
        if questID then
            if YQBDB.globalBlocked[questID] then
                QueueRejectedQuest(questID, "global", true)
                return OriginalConfirmAcceptQuest(...)
            end
            if characterData[curCharacterID] and characterData[curCharacterID].blocked[questID] then
                QueueRejectedQuest(questID, "char", true)
                return OriginalConfirmAcceptQuest(...)
            end
        end
        return OriginalConfirmAcceptQuest(...)
    end
end

-- ==================== 事件监听 ====================
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("QUEST_DETAIL")
frame:RegisterEvent("QUEST_ACCEPT_CONFIRM")
frame:RegisterEvent("PLAYER_LEVEL_UP")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:RegisterEvent("QUEST_LOG_UPDATE")
frame:RegisterEvent("QUEST_FINISHED")
frame:RegisterEvent("GOSSIP_CLOSED")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName ~= ADDON_NAME then return end
        BindDBReferences()
        PersistDB()
        if YQB and YQB.SyncUIBindings then
            YQB.SyncUIBindings()
        end

    elseif event == "PLAYER_ENTERING_WORLD" then
        Core.Characters:RefreshCurrent()
        BindDBReferences()
        if YQB and YQB.SyncUIBindings then
            YQB.SyncUIBindings()
        end
        ResetAutoAbandonState()
        wipe(reportedUnabandonable)
        wipe(recentBlockNotices)
        SyncRejectedQuestsToQueue(true)
        PersistDB()
        if YQB.NotifyCorePageChanged then YQB.NotifyCorePageChanged() end

    elseif event == "PLAYER_LOGOUT" then
        PersistDB()

    elseif event == "PLAYER_LEVEL_UP" then
        Core.Characters:RefreshCurrent()
        if YQB.NotifyCorePageChanged then YQB.NotifyCorePageChanged() end

    elseif event == "QUEST_DETAIL" then
        local questID = GetQuestID()
        if questID and YQB.GetQuestName(questID) then
            -- 已通过 YQB.GetQuestName 自动更新缓存
        end

    elseif event == "QUEST_ACCEPT_CONFIRM" then
        local questID = GetQuestID()
        if questID then
            YQB.GetQuestName(questID)  -- 尝试更新缓存
        end

    elseif event == "QUEST_LOG_UPDATE" then
        if YQB.IsAutoAbandonEnabled() then
            SyncRejectedQuestsToQueue()
        end
        if YQB.NotifyCorePageChanged then YQB.NotifyCorePageChanged() end

    elseif event == "QUEST_FINISHED" or event == "GOSSIP_CLOSED" then
        if YQB.IsAutoAbandonEnabled() and autoAbandonWaitingForClose then
            MaybeStartAutoAbandonTimer()
        end
    end
end)
