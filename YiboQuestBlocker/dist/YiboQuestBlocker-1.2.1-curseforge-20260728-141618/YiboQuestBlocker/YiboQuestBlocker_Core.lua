-- ============================================================================
-- YiboQuestBlocker_Core.lua
-- 数据层 + AcceptQuest 拦截
-- ============================================================================

-- ==================== 数据初始化 ====================
YiboQuestBlockerDB = YiboQuestBlockerDB or {}

-- 当前角色识别
local ADDON_NAME = ...
local curCharName = UnitName("player") or "Unknown"
local curRealm    = GetRealmName() or "Unknown"
local curCharKey  = curRealm .. "-" .. curCharName
local PersistDB

-- 初始化已知角色（首次运行时注册当前角色）
if not YiboQuestBlockerDB.knownChars then
    YiboQuestBlockerDB.knownChars = {}
end

if not YiboQuestBlockerDB.customCharOrder then
    YiboQuestBlockerDB.customCharOrder = {}
end

local function nextSeenOrder()
    local maxOrder = 0
    for _, data in pairs(YiboQuestBlockerDB.knownChars) do
        if data.seenOrder and data.seenOrder > maxOrder then
            maxOrder = data.seenOrder
        end
    end
    return maxOrder + 1
end

if not YiboQuestBlockerDB.knownChars[curCharKey] then
    YiboQuestBlockerDB.knownChars[curCharKey] = {
        level = UnitLevel("player") or 1,
        class = select(2, UnitClass("player")) or "UNKNOWN",
        seenOrder = nextSeenOrder(),
    }
elseif not YiboQuestBlockerDB.knownChars[curCharKey].seenOrder then
    YiboQuestBlockerDB.knownChars[curCharKey].seenOrder = nextSeenOrder()
end

local function ensureCustomCharOrder(charKey)
    local order = YiboQuestBlockerDB.customCharOrder
    for _, existing in ipairs(order) do
        if existing == charKey then
            return
        end
    end
    table.insert(order, charKey)
end

ensureCustomCharOrder(curCharKey)

-- 初始化全局屏蔽
if not YiboQuestBlockerDB.globalBlocked then YiboQuestBlockerDB.globalBlocked = {} end
if not YiboQuestBlockerDB.globalCache   then YiboQuestBlockerDB.globalCache   = {} end

-- 初始化当前角色 perChar
if not YiboQuestBlockerDB.perChar then YiboQuestBlockerDB.perChar = {} end
if not YiboQuestBlockerDB.perChar[curCharKey] then
    YiboQuestBlockerDB.perChar[curCharKey] = {
        blocked    = {},
        cache      = {},
        minimapPos = 0,
        windowShown = false,
    }
end

if not YiboQuestBlockerDB.ui then
    YiboQuestBlockerDB.ui = {
        windowWidth = 580,
        windowHeight = 500,
        headerCharsPerLine = 3,
    }
end

-- 初始化过滤器
if not YiboQuestBlockerDB.filters then
    YiboQuestBlockerDB.filters = {
        showDaily     = true,
        showNormal    = true,
        hideComplete  = true,
        reportChat    = true,
        autoAbandon   = false,
        levelExpr     = "",
        sortBy        = "custom", -- custom / name / level / count
    }
end
if YiboQuestBlockerDB.filters.sortBy == "order" then
    YiboQuestBlockerDB.filters.sortBy = "custom"
end

if not YiboQuestBlockerDB.minimap then
    YiboQuestBlockerDB.minimap = {
        hide = false,
        minimapPos = YiboQuestBlockerDB.perChar[curCharKey].minimapPos or 0,
    }
end
if YiboQuestBlockerDB.minimap.hide == nil then
    YiboQuestBlockerDB.minimap.hide = false
end
if YiboQuestBlockerDB.minimap.minimapPos == nil then
    YiboQuestBlockerDB.minimap.minimapPos = YiboQuestBlockerDB.perChar[curCharKey].minimapPos or 0
end

-- 每次加载时更新当前角色等级
YiboQuestBlockerDB.knownChars[curCharKey].level = UnitLevel("player") or 1

-- 本地引用（加速 + 避免被外部篡改绕过的风险）
local YQBDB   = YiboQuestBlockerDB
local blocked = YiboQuestBlockerDB.globalBlocked
local cache   = YiboQuestBlockerDB.globalCache
local perChar = YiboQuestBlockerDB.perChar

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
    YiboQuestBlockerDB.knownChars = YQBDB.knownChars
    YiboQuestBlockerDB.customCharOrder = YQBDB.customCharOrder
    YiboQuestBlockerDB.globalBlocked = YQBDB.globalBlocked
    YiboQuestBlockerDB.globalCache = YQBDB.globalCache
    YiboQuestBlockerDB.perChar = YQBDB.perChar
    YiboQuestBlockerDB.ui = YQBDB.ui
    YiboQuestBlockerDB.filters = YQBDB.filters
    YiboQuestBlockerDB.minimap = YQBDB.minimap
end

local function BindDBReferences()
    YiboQuestBlockerDB = YiboQuestBlockerDB or {}
    YiboQuestBlockerDB.knownChars = YiboQuestBlockerDB.knownChars or {}
    YiboQuestBlockerDB.customCharOrder = YiboQuestBlockerDB.customCharOrder or {}
    YiboQuestBlockerDB.globalBlocked = YiboQuestBlockerDB.globalBlocked or {}
    YiboQuestBlockerDB.globalCache = YiboQuestBlockerDB.globalCache or {}
    YiboQuestBlockerDB.perChar = YiboQuestBlockerDB.perChar or {}
    YiboQuestBlockerDB.ui = YiboQuestBlockerDB.ui or {}
    YiboQuestBlockerDB.minimap = YiboQuestBlockerDB.minimap or {}
    YiboQuestBlockerDB.filters = YiboQuestBlockerDB.filters or {
        showDaily = true,
        showNormal = true,
        hideComplete = true,
        reportChat = true,
        autoAbandon = false,
        levelExpr = "",
        sortBy = "custom",
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

    if YiboQuestBlockerDB.ui.windowWidth == nil or YiboQuestBlockerDB.ui.windowHeight == nil then
        local legacyCharDB = YiboQuestBlockerDB.perChar[curCharKey]
        YiboQuestBlockerDB.ui.windowWidth = (legacyCharDB and legacyCharDB.windowWidth) or 580
        YiboQuestBlockerDB.ui.windowHeight = (legacyCharDB and legacyCharDB.windowHeight) or 500
    end
    if YiboQuestBlockerDB.ui.headerCharsPerLine == nil then
        YiboQuestBlockerDB.ui.headerCharsPerLine = 3
    end
    if YiboQuestBlockerDB.minimap.hide == nil then
        YiboQuestBlockerDB.minimap.hide = false
    end

    if YiboQuestBlockerDB.filters.sortBy == "order" then
        YiboQuestBlockerDB.filters.sortBy = "custom"
    end

    if not YiboQuestBlockerDB.knownChars[curCharKey] then
        YiboQuestBlockerDB.knownChars[curCharKey] = {
            level = UnitLevel("player") or 1,
            class = select(2, UnitClass("player")) or "UNKNOWN",
            seenOrder = nextSeenOrder(),
        }
    elseif not YiboQuestBlockerDB.knownChars[curCharKey].seenOrder then
        YiboQuestBlockerDB.knownChars[curCharKey].seenOrder = nextSeenOrder()
    end

    local order = YiboQuestBlockerDB.customCharOrder
    local foundOrder
    for _, existing in ipairs(order) do
        if existing == curCharKey then
            foundOrder = true
            break
        end
    end
    if not foundOrder then
        table.insert(order, curCharKey)
    end

    if not YiboQuestBlockerDB.perChar[curCharKey] then
        YiboQuestBlockerDB.perChar[curCharKey] = {
            blocked = {},
            cache = {},
            minimapPos = 0,
            windowShown = false,
        }
    end
    if YiboQuestBlockerDB.minimap.minimapPos == nil then
        YiboQuestBlockerDB.minimap.minimapPos = YiboQuestBlockerDB.perChar[curCharKey].minimapPos or 0
    end

    YiboQuestBlockerDB.knownChars[curCharKey].level = UnitLevel("player") or 1

    YQBDB = YiboQuestBlockerDB
    blocked = YQBDB.globalBlocked
    cache = YQBDB.globalCache
    perChar = YQBDB.perChar
end

-- 暴露给 UI 模块的引用（UI 会通过全局表 YQB 访问）
YQB = YQB or {}
YQB.curCharKey = curCharKey
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
YQB.IsAutoAbandonEnabled = function()
    return not not (YQBDB.filters and YQBDB.filters.autoAbandon)
end
YQB.GetMinimapConfig = function()
    YQBDB.minimap = YQBDB.minimap or {}
    if YQBDB.minimap.hide == nil then
        YQBDB.minimap.hide = false
    end
    if YQBDB.minimap.minimapPos == nil then
        local charDB = perChar[curCharKey]
        YQBDB.minimap.minimapPos = (charDB and charDB.minimapPos) or 0
    end
    return YQBDB.minimap
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
                if perChar[curCharKey] and perChar[curCharKey].cache then
                    perChar[curCharKey].cache[questID] = name
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
    if perChar[curCharKey] and perChar[curCharKey].cache and perChar[curCharKey].cache[questID] then
        return perChar[curCharKey].cache[questID]
    end

    return nil
end

-- 判断任务是否被屏蔽（全局 OR 当前角色）
function YQB.IsQuestBlocked(questID)
    if not questID then return false end
    if YQBDB.globalBlocked[questID] then return true end
    if perChar[curCharKey] and perChar[curCharKey].blocked[questID] then return true end
    return false
end

-- 判断任务是否被任何角色屏蔽（用于"屏蔽组"显示）
function YQB.IsQuestBlockedByAny(questID)
    if not questID then return false end
    if YQBDB.globalBlocked[questID] then return true end
    for charKey, data in pairs(perChar) do
        if data.blocked and data.blocked[questID] then
            return true
        end
    end
    return false
end

-- 获取角色屏蔽状态表
-- 返回: { global = true/false, ["莫格莱尼-天堂暴风"] = true/false, ... }
function YQB.GetBlockStatus(questID)
    local status = { global = YQBDB.globalBlocked[questID] or false }
    for charKey, _ in pairs(YQBDB.knownChars) do
        if perChar[charKey] and perChar[charKey].blocked then
            status[charKey] = perChar[charKey].blocked[questID] or false
        else
            status[charKey] = false
        end
    end
    return status
end

-- 获取角色等级
function YQB.GetCharLevel(charKey)
    if YQBDB.knownChars and YQBDB.knownChars[charKey] then
        return YQBDB.knownChars[charKey].level or 0
    end
    return 0
end

function YQB.GetCharSeenOrder(charKey)
    if YQBDB.knownChars and YQBDB.knownChars[charKey] then
        return YQBDB.knownChars[charKey].seenOrder or 999999
    end
    return 999999
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

local function normalizeCustomCharOrder()
    local order = YQBDB.customCharOrder
    local seen = {}
    local normalized = {}

    for _, charKey in ipairs(order) do
        if YQBDB.knownChars[charKey] and not seen[charKey] then
            seen[charKey] = true
            table.insert(normalized, charKey)
        end
    end

    local missing = {}
    for charKey in pairs(YQBDB.knownChars) do
        if not seen[charKey] then
            table.insert(missing, charKey)
        end
    end
    table.sort(missing, function(a, b)
        local oa = YQB.GetCharSeenOrder(a)
        local ob = YQB.GetCharSeenOrder(b)
        if oa ~= ob then return oa < ob end
        return a < b
    end)

    for _, charKey in ipairs(missing) do
        table.insert(normalized, charKey)
    end

    YQBDB.customCharOrder = normalized
    return normalized
end

function YQB.GetCustomCharOrder()
    return normalizeCustomCharOrder()
end

function YQB.MoveCustomCharOrder(charKey, delta)
    if not charKey or not delta or delta == 0 then return false end

    local order = normalizeCustomCharOrder()
    local index
    for i, existing in ipairs(order) do
        if existing == charKey then
            index = i
            break
        end
    end
    if not index then return false end

    local target = index + delta
    if target < 1 or target > #order then
        return false
    end

    order[index], order[target] = order[target], order[index]
    PersistDB()
    return true
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

-- 判断角色是否通过等级过滤
function YQB.CharPassLevelFilter(charKey)
    local filter = YQBDB.filters
    local level  = YQB.GetCharLevel(charKey)
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
    for charKey, charData in pairs(perChar) do
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

-- 获取排序后的可见角色列表
function YQB.GetSortedVisibleChars()
    local chars = {}
    for charKey, _ in pairs(YQBDB.knownChars) do
        if YQB.CharPassLevelFilter(charKey) then
            tinsert(chars, charKey)
        end
    end

    local sortBy = YQBDB.filters.sortBy
    if sortBy == "custom" or sortBy == "order" then
        local manualIndex = {}
        for index, charKey in ipairs(normalizeCustomCharOrder()) do
            manualIndex[charKey] = index
        end
        table.sort(chars, function(a, b)
            local oa = manualIndex[a] or 999999
            local ob = manualIndex[b] or 999999
            if oa ~= ob then return oa < ob end
            return a < b
        end)
    elseif sortBy == "name" then
        table.sort(chars)
    elseif sortBy == "level" then
        table.sort(chars, function(a, b)
            local la = YQB.GetCharLevel(a) or 0
            local lb = YQB.GetCharLevel(b) or 0
            if la ~= lb then return la > lb end
            return a < b
        end)
    elseif sortBy == "count" then
        table.sort(chars, function(a, b)
            local ca = perChar[a] and perChar[a].blocked and tableSize(perChar[a].blocked) or 0
            local cb = perChar[b] and perChar[b].blocked and tableSize(perChar[b].blocked) or 0
            if ca ~= cb then return ca > cb end
            return a < b
        end)
    end
    return chars
end

-- 添加屏蔽
function YQB.AddBlock(questID, scope)
    -- scope: "global" or "char"
    if not questID then return end

    if scope == "global" then
        YQBDB.globalBlocked[questID] = true
    else
        if not perChar[curCharKey] then
            perChar[curCharKey] = { blocked = {}, cache = {} }
        end
        perChar[curCharKey].blocked[questID] = true
    end

    -- 尝试缓存名称
    YQB.GetQuestName(questID)
    if YQB.IsAutoAbandonEnabled() and IsQuestStillInLog(questID) then
        EnqueueAutoAbandonQuest(questID)
        MaybeStartAutoAbandonTimer()
    end
    PersistDB()
end

function YQB.AddCharBlock(questID, charKey)
    if not questID or not charKey then return end

    if not perChar[charKey] then
        perChar[charKey] = {
            blocked = {},
            cache = {},
            minimapPos = 0,
            windowShown = false,
        }
    end
    if not perChar[charKey].blocked then
        perChar[charKey].blocked = {}
    end
    if not perChar[charKey].cache then
        perChar[charKey].cache = {}
    end

    perChar[charKey].blocked[questID] = true
    YQB.GetQuestName(questID)
    if charKey == curCharKey and YQB.IsAutoAbandonEnabled() and IsQuestStillInLog(questID) then
        EnqueueAutoAbandonQuest(questID)
        MaybeStartAutoAbandonTimer()
    end
    PersistDB()
end

-- 移除屏蔽
function YQB.RemoveBlock(questID, scope)
    if not questID then return end

    if scope == "global" then
        YQBDB.globalBlocked[questID] = nil
    else
        if perChar[curCharKey] and perChar[curCharKey].blocked then
            perChar[curCharKey].blocked[questID] = nil
        end
    end
    if YQB.IsQuestBlocked(questID) and IsQuestStillInLog(questID) and YQB.IsAutoAbandonEnabled() then
        EnqueueAutoAbandonQuest(questID)
        MaybeStartAutoAbandonTimer()
    else
        RemoveAutoAbandonQuest(questID)
    end
    PersistDB()
end

-- 移除指定角色的指定任务屏蔽
function YQB.RemoveCharBlock(questID, charKey)
    if not questID or not charKey then return end
    if perChar[charKey] and perChar[charKey].blocked then
        perChar[charKey].blocked[questID] = nil
        if charKey == curCharKey and YQB.IsQuestBlocked(questID) and IsQuestStillInLog(questID) and YQB.IsAutoAbandonEnabled() then
            EnqueueAutoAbandonQuest(questID)
            MaybeStartAutoAbandonTimer()
        elseif charKey == curCharKey then
            RemoveAutoAbandonQuest(questID)
        end
        PersistDB()
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
    local charCount   = perChar[curCharKey] and tableSize(perChar[curCharKey].blocked) or 0
    local total       = tableSize(YQBDB.globalBlocked)
    for _, charData in pairs(perChar) do
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
        if perChar[curCharKey] and perChar[curCharKey].blocked[questID] then
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
            if perChar[curCharKey] and perChar[curCharKey].blocked[questID] then
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
        BindDBReferences()
        if YQB and YQB.SyncUIBindings then
            YQB.SyncUIBindings()
        end
        ResetAutoAbandonState()
        wipe(reportedUnabandonable)
        wipe(recentBlockNotices)
        -- 更新等级
        if YQBDB.knownChars and YQBDB.knownChars[curCharKey] then
            YQBDB.knownChars[curCharKey].level = UnitLevel("player") or 1
        end
        SyncRejectedQuestsToQueue(true)
        PersistDB()

    elseif event == "PLAYER_LOGOUT" then
        PersistDB()

    elseif event == "PLAYER_LEVEL_UP" then
        local newLevel = ...
        if YQBDB.knownChars and YQBDB.knownChars[curCharKey] then
            YQBDB.knownChars[curCharKey].level = newLevel
        end

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

    elseif event == "QUEST_FINISHED" or event == "GOSSIP_CLOSED" then
        if YQB.IsAutoAbandonEnabled() and autoAbandonWaitingForClose then
            MaybeStartAutoAbandonTimer()
        end
    end
end)
