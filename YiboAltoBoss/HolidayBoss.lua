local YAB = _G.YAB

-- Seasonal queue targets are intentionally kept separate from the world-boss
-- catalog: their availability is calendar-bound and their completion resets
-- daily rather than weekly.
local Holiday = {}
YAB.Holiday = Holiday

local BOSSES = {
    {
        key = "holiday:coren-direbrew",
        name = "美酒节·科林·烈酒",
        reset = "holiday-daily",
        order = 80,
        group = "holiday",
        scheduleKind = "event-daily-07",
        resetHour = 7,
        eventTitleAliases = { "美酒节", "Brewfest" },
        questID = 25483,
        lfgDungeonID = 287,
        lfgNameAliases = { "科林·烈酒", "Coren Direbrew" },
        hidePhaseTracking = true,
        trackPhase = false,
    },
}

local byKey = {}
for _, boss in ipairs(BOSSES) do byKey[boss.key] = boss end

local function Now()
    return (YAB.GetServerTimestamp and YAB.GetServerTimestamp()) or (GetServerTime and GetServerTime()) or time()
end

local function DayKey(boss, now)
    now = now or Now()
    return date("%Y-%j", now - (tonumber(boss.resetHour) or 7) * 3600)
end

local function CurrentCharacter(create)
    local key = YAB.GetCurrentCharKey and YAB.GetCurrentCharKey()
    local characters = YiboAltoBossDB and YiboAltoBossDB.characters
    if not (key and characters) then return nil end
    if create and not characters[key] then characters[key] = { kills = {}, phases = {}, lootLockouts = {} } end
    return characters[key]
end

local function IsCalendarOpen(boss)
    if not (C_Calendar and type(C_Calendar.GetNumDayEvents) == "function" and type(C_Calendar.GetDayEvent) == "function") then return false end
    local today = date("*t")
    if not today then return false end
    local ok, count = pcall(C_Calendar.GetNumDayEvents, 0, today.day)
    if not ok then return false end
    for index = 1, tonumber(count) or 0 do
        local eventOK, event = pcall(C_Calendar.GetDayEvent, 0, today.day, index)
        local title = eventOK and event and string.lower(tostring(event.title or "")) or ""
        for _, alias in ipairs(boss.eventTitleAliases or {}) do
            if title == string.lower(tostring(alias)) then return true end
        end
    end
    return false
end

local function QuestCompleted(questID)
    local query = C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted or IsQuestFlaggedCompleted
    if type(query) ~= "function" then return false end
    local ok, completed = pcall(query, questID)
    return ok and completed == true
end

local function GetRecord(charKey, boss, create)
    local characters = YiboAltoBossDB and YiboAltoBossDB.characters
    local character = characters and characters[charKey]
    if not character and create and charKey == (YAB.GetCurrentCharKey and YAB.GetCurrentCharKey()) then character = CurrentCharacter(true) end
    if not character then return nil end
    character.holidayBosses = character.holidayBosses or {}
    local records = character.holidayBosses[boss.key]
    if not records and create then records = {}; character.holidayBosses[boss.key] = records end
    return records and records[DayKey(boss)]
end

local function WriteRecord(boss, source)
    local character = CurrentCharacter(true)
    if not character then return false end
    character.holidayBosses = character.holidayBosses or {}
    local records = character.holidayBosses[boss.key] or {}; character.holidayBosses[boss.key] = records
    records[DayKey(boss)] = { completed = true, source = source, completedAt = Now(), observedAt = Now() }
    return true
end

function Holiday:IsEnabled()
    return not (YiboAltoBossDB and YiboAltoBossDB.settings and YiboAltoBossDB.settings.showHolidayBosses == false)
end

function Holiday:SetEnabled(enabled)
    YiboAltoBossDB.settings = YiboAltoBossDB.settings or {}
    YiboAltoBossDB.settings.showHolidayBosses = not not enabled
    YAB.PersistDB()
    if YAB.NotifyCorePageChanged then YAB.NotifyCorePageChanged() end
    if YAB.RefreshSettingsUI then YAB.RefreshSettingsUI() end
end

function Holiday:GetBoss(ref)
    if type(ref) == "table" then return byKey[ref.key] end
    return byKey[tostring(ref or "")]
end

function Holiday:IsBoss(ref)
    return self:GetBoss(ref) ~= nil
end

function Holiday:GetActiveBosses()
    local result = {}
    if not self:IsEnabled() then return result end
    for _, boss in ipairs(BOSSES) do if IsCalendarOpen(boss) then result[#result + 1] = boss end end
    return result
end

function Holiday:HasActiveBosses()
    return #self:GetActiveBosses() > 0
end

function Holiday:GetStatus(charKey, ref)
    local boss = self:GetBoss(ref)
    if not boss then return "unavailable" end
    local record = GetRecord(charKey, boss, false)
    if record and record.completed then return "completed", record end
    if record and record.observedAt then return "available", record end
    return "unobserved"
end

function Holiday:ObserveCurrent()
    local changed = false
    for _, boss in ipairs(self:GetActiveBosses()) do
        local record = GetRecord(YAB.GetCurrentCharKey(), boss, true)
        if QuestCompleted(boss.questID) then
            if not (record and record.completed) then changed = WriteRecord(boss, "quest") or changed end
        elseif record and not record.completed then
            record.observedAt = Now()
            changed = true
        else
            local character = CurrentCharacter(true)
            character.holidayBosses = character.holidayBosses or {}
            local records = character.holidayBosses[boss.key] or {}; character.holidayBosses[boss.key] = records
            records[DayKey(boss)] = { observedAt = Now() }
            changed = true
        end
    end
    return changed
end

function Holiday:RecordCompletionReward()
    local instanceID = select(10, GetInstanceInfo())
    for _, boss in ipairs(self:GetActiveBosses()) do
        if tonumber(instanceID) == tonumber(boss.lfgDungeonID) then return WriteRecord(boss, "lfg-reward") end
    end
    return false
end

function Holiday:ToggleManual(ref, charKey)
    local boss = self:GetBoss(ref)
    if not boss or not self:IsEnabled() then return false end
    charKey = charKey or YAB.GetCurrentCharKey()
    local record = GetRecord(charKey, boss, false)
    if record and record.completed and record.source ~= "manual" then return false end
    local characters = YiboAltoBossDB and YiboAltoBossDB.characters
    local character = characters and characters[charKey]
    if record and record.source == "manual" then
        character.holidayBosses[boss.key][DayKey(boss)] = { observedAt = Now() }
    else
        local character = characters and characters[charKey]
        if not character then return false end
        character.holidayBosses = character.holidayBosses or {}
        local records = character.holidayBosses[boss.key] or {}; character.holidayBosses[boss.key] = records
        records[DayKey(boss)] = { completed = true, source = "manual", completedAt = Now(), observedAt = Now() }
    end
    YAB.PersistDB()
    if YAB.NotifyCorePageChanged then YAB.NotifyCorePageChanged() end
    return true
end

function Holiday:GetRoles()
    if type(GetLFGRoles) ~= "function" then return {}, "未检测到地下城查找器职责。" end
    local tank, healer, damage = GetLFGRoles()
    local roles = {}
    if tank then roles[#roles + 1] = "坦克" end
    if healer then roles[#roles + 1] = "治疗" end
    if damage then roles[#roles + 1] = "输出" end
    return roles
end

local function IsExpectedDungeon(boss)
    if type(GetLFGDungeonInfo) ~= "function" then return false end
    local name, _, _, _, _, _, _, _, _, _, _, _, _, _, isHoliday = GetLFGDungeonInfo(boss.lfgDungeonID)
    if not name or isHoliday ~= true then return false end
    local lower = string.lower(tostring(name))
    for _, alias in ipairs(boss.lfgNameAliases or {}) do if string.find(lower, string.lower(alias), 1, true) then return true end end
    return false
end

function Holiday:GetQueueState(ref)
    local boss = self:GetBoss(ref)
    if not boss then return { state = "unavailable", reason = "节日 Boss 不可用。" } end
    if not IsExpectedDungeon(boss) then return { state = "unavailable", reason = "客户端未提供匹配的节日副本。" } end
    local category = LE_LFG_CATEGORY_LFD
    if type(GetLFGQueuedList) == "function" then
        local queued = GetLFGQueuedList(category)
        if type(queued) == "table" and queued[boss.lfgDungeonID] then return { state = "queued" } end
    end
    local available, joinable = false, false
    if type(IsLFGDungeonJoinable) == "function" then available, joinable = IsLFGDungeonJoinable(boss.lfgDungeonID) end
    if not joinable then
        local reason = "当前角色暂不可排队。"
        if type(GetLFDLockInfo) == "function" then
            local _, lockedReason, _, _, _, lockedText = GetLFDLockInfo(boss.lfgDungeonID, 1)
            if lockedText and lockedText ~= "" then reason = lockedText elseif lockedReason and lockedReason ~= 0 then reason = "当前角色不满足副本要求。" end
        end
        return { state = "locked", reason = reason, available = available }
    end
    local roles = self:GetRoles()
    if #roles == 0 then return { state = "no-roles", reason = "请先在地下城查找器选择职责。" } end
    return { state = "ready", roles = roles }
end

function Holiday:ToggleQueue(ref)
    local boss = self:GetBoss(ref)
    local queue = self:GetQueueState(boss)
    if queue.state == "queued" then
        if type(LFG_LeaveQueue) == "function" then LFG_LeaveQueue(LE_LFG_CATEGORY_LFD); return true, "已取消排队。" end
        return false, "客户端不支持取消该队列。"
    end
    if queue.state ~= "ready" then return false, queue.reason or "当前不可排队。" end
    if type(LFDQueueFrame_SetType) == "function" then LFDQueueFrame_SetType(boss.lfgDungeonID) end
    if type(LFG_JoinDungeon) ~= "function" then return false, "客户端不支持地下城查找器排队。" end
    LFG_JoinDungeon(LE_LFG_CATEGORY_LFD, boss.lfgDungeonID, _G.LFDDungeonList, _G.LFDHiddenByCollapseList)
    return true, "已加入节日副本队列。"
end
