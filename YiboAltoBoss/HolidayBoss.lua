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
        activeWindow = {
            start = { month = 9, day = 20, hour = 10 },
            finish = { month = 10, day = 6, hour = 10 },
        },
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

local function IsWithinActiveWindow(boss, now)
    local window = boss and boss.activeWindow
    if not window then return true end

    now = now or Now()
    local current = date("*t", now)
    if not current then return false end

    local function Timestamp(spec)
        return time({
            year = current.year,
            month = tonumber(spec.month),
            day = tonumber(spec.day),
            hour = tonumber(spec.hour) or 0,
            min = tonumber(spec.min) or 0,
            sec = tonumber(spec.sec) or 0,
            isdst = current.isdst,
        })
    end

    local startsAt = Timestamp(window.start)
    local endsAt = Timestamp(window.finish)
    return startsAt and endsAt and now >= startsAt and now < endsAt
end

local function CurrentCharacter(create)
    local key = YAB.GetCurrentCharKey and YAB.GetCurrentCharKey()
    local characters = YiboAltoBossDB and YiboAltoBossDB.characters
    if not (key and characters) then return nil end
    if create and not characters[key] then characters[key] = { kills = {}, phases = {}, lootLockouts = {} } end
    return characters[key]
end

local function IsCalendarOpen(boss)
    if not IsWithinActiveWindow(boss) then return false end
    if not (C_Calendar and type(C_Calendar.GetNumDayEvents) == "function" and type(C_Calendar.GetDayEvent) == "function") then return false end
    local today = date("*t")
    if not today then return false end
    local ok, count = pcall(C_Calendar.GetNumDayEvents, 0, today.day)
    if not ok then return false end
    for index = 1, tonumber(count) or 0 do
        local eventOK, event = pcall(C_Calendar.GetDayEvent, 0, today.day, index)
        local title = eventOK and event and string.lower(tostring(event.title or "")) or ""
        for _, alias in ipairs(boss.eventTitleAliases or {}) do
            local normalizedAlias = string.lower(tostring(alias))
            if normalizedAlias ~= "" and string.find(title, normalizedAlias, 1, true) then
                return true
            end
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

local function LFGDailyRewardCompleted(boss)
    if not boss or type(GetLFGDungeonRewards) ~= "function" then return false end
    local ok, doneToday = pcall(GetLFGDungeonRewards, boss.lfgDungeonID)
    return ok and doneToday == true
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
        local questCompleted = QuestCompleted(boss.questID)
        local rewardCompleted = LFGDailyRewardCompleted(boss)
        if questCompleted or rewardCompleted then
            if not (record and record.completed) then
                changed = WriteRecord(boss, questCompleted and "quest" or "lfg-reward") or changed
            end
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

function Holiday:GetAvailableRoles()
    if C_LFGList and type(C_LFGList.GetAvailableRoles) == "function" then
        local ok, available = pcall(C_LFGList.GetAvailableRoles)
        if ok and type(available) == "table" then
            local result = {
                tank = available.tank and true or false,
                healer = available.healer and true or false,
                damage = (available.dps or available.damage) and true or false,
            }
            if result.tank or result.healer or result.damage then return result end
        end
    end
    if type(GetAvailableRoles) == "function" then
        local ok, tank, healer, damage = pcall(GetAvailableRoles)
        if ok and (tank ~= nil or healer ~= nil or damage ~= nil) then
            local result = { tank = tank and true or false, healer = healer and true or false, damage = damage and true or false }
            if result.tank or result.healer or result.damage then return result end
        end
    end
    -- Some Classic clients do not expose either availability API.  Build the
    -- same role union the system panel uses by checking every specialization;
    -- this keeps hybrid classes selectable while DPS-only classes remain fixed.
    if type(GetNumSpecializations) == "function" and type(GetSpecializationRole) == "function" then
        local result = { tank = false, healer = false, damage = false }
        local ok, count = pcall(GetNumSpecializations)
        if ok then
            for index = 1, tonumber(count) or 0 do
                local roleOK, role = pcall(GetSpecializationRole, index)
                if roleOK then
                    if role == "TANK" then result.tank = true end
                    if role == "HEALER" then result.healer = true end
                    if role == "DAMAGER" then result.damage = true end
                end
            end
        end
        if result.tank or result.healer or result.damage then return result end
    end
    -- If the client exposes no role metadata yet, keep the selector usable;
    -- Blizzard will still reject an invalid role when the queue is submitted.
    return { tank = true, healer = true, damage = true }
end

function Holiday:GetRoleSelection()
    -- Read the roles selected in Blizzard's Dungeon Finder panel.  Modern
    -- clients may expose them as a table; the legacy API returns leader first,
    -- followed by tank, healer, and damage.
    local available = self:GetAvailableRoles()
    local availableCount = (available.tank and 1 or 0) + (available.healer and 1 or 0) + (available.damage and 1 or 0)
    local function Normalize(selected)
        if availableCount == 1 then return available end
        return {
            tank = available.tank and selected.tank == true or false,
            healer = available.healer and selected.healer == true or false,
            damage = available.damage and selected.damage == true or false,
        }
    end
    if C_LFGList and type(C_LFGList.GetRoles) == "function" then
        local ok, selected = pcall(C_LFGList.GetRoles)
        if ok and type(selected) == "table" then
            return Normalize({ tank = selected.tank == true, healer = selected.healer == true, damage = (selected.dps or selected.damage) == true })
        end
    end
    if type(GetLFGRoles) ~= "function" then return nil end
    local _, tank, healer, damage = GetLFGRoles()
    return Normalize({ tank = tank == true, healer = healer == true, damage = damage == true })
end

function Holiday:GetRoles()
    local selected = self:GetRoleSelection()
    if not selected then return {}, "未检测到地下城查找器职责。" end
    return self:BuildRoleList(selected.tank, selected.healer, selected.damage)
end

function Holiday:BuildRoleList(tank, healer, damage)
    local roles = {}
    if tank then roles[#roles + 1] = "T" end
    if damage then roles[#roles + 1] = "D" end
    if healer then roles[#roles + 1] = "N" end
    return roles
end

function Holiday:GetRoleNames()
    local selected = self:GetRoleSelection()
    if not selected then return {} end
    local roles = {}
    if selected.tank then roles[#roles + 1] = "T坦克" end
    if selected.damage then roles[#roles + 1] = "D输出" end
    if selected.healer then roles[#roles + 1] = "N治疗" end
    return roles
end

function Holiday:NotifyRoleChanged()
    if YAB.NotifyCorePageChanged then YAB.NotifyCorePageChanged() end
    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(0.05, function()
            if YAB.NotifyCorePageChanged then YAB.NotifyCorePageChanged() end
        end)
    end
end

function Holiday:SetRoleSelection(tank, healer, damage)
    local available = self:GetAvailableRoles()
    tank = tank == true and available.tank
    healer = healer == true and available.healer
    damage = damage == true and available.damage
    local count = (available.tank and 1 or 0) + (available.healer and 1 or 0) + (available.damage and 1 or 0)
    if count == 1 then
        tank, healer, damage = available.tank, available.healer, available.damage
    end
    if C_LFGList and type(C_LFGList.SetRoles) == "function" then
        local ok = pcall(C_LFGList.SetRoles, { tank = tank == true, healer = healer == true, dps = damage == true })
        if ok then return true end
    end
    if type(SetLFGRoles) == "function" then
        local leader = false
        if type(GetLFGRoles) == "function" then leader = select(1, GetLFGRoles()) == true end
        local ok = pcall(SetLFGRoles, leader, tank == true, healer == true, damage == true)
        if ok then return true end
    end
    return false
end

function Holiday:OpenRoleSelector(anchor)
    local selected = self:GetRoleSelection()
    if not selected then return false end
    local available = self:GetAvailableRoles()
    local availableCount = (available.tank and 1 or 0) + (available.healer and 1 or 0) + (available.damage and 1 or 0)
    if availableCount <= 1 then return false end

    if type(EasyMenu) == "function" and type(CreateFrame) == "function" then
        self.roleMenu = self.roleMenu or CreateFrame("Frame", "YiboAltoBossRoleMenu", UIParent, "UIDropDownMenuTemplate")
        local function ToggleRole(role)
            local nextSelection = {
                tank = selected.tank,
                healer = selected.healer,
                damage = selected.damage,
            }
            nextSelection[role] = not nextSelection[role]
            if not nextSelection.tank and not nextSelection.healer and not nextSelection.damage then
                return
            end
            if self:SetRoleSelection(nextSelection.tank, nextSelection.healer, nextSelection.damage) then
                self:NotifyRoleChanged()
            end
        end
        local menu = {
            { text = "坦克", checked = selected.tank, disabled = not available.tank, func = function() ToggleRole("tank") end },
            { text = "治疗", checked = selected.healer, disabled = not available.healer, func = function() ToggleRole("healer") end },
            { text = "输出", checked = selected.damage, disabled = not available.damage, func = function() ToggleRole("damage") end },
        }
        EasyMenu(menu, self.roleMenu, "cursor", 0, 0, "MENU")
        return true
    end

    -- Protected clients may reject direct role mutation.  Let Blizzard's
    -- Dungeon Finder own the selection in that case.
    if type(LFDQueueFrame_ToggleFrame) == "function" then
        LFDQueueFrame_ToggleFrame()
        return true
    end
    if type(PVEFrame_ToggleFrame) == "function" then
        PVEFrame_ToggleFrame()
        return true
    end
    return false
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
