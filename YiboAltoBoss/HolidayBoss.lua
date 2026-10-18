if _G.YAB and _G.YAB.CoreReady == false then return end
local YAB = _G.YAB

-- Seasonal queue targets are intentionally kept separate from the world-boss
-- catalog: their availability is calendar-bound and their completion resets
-- daily rather than weekly.
local Holiday = {}
YAB.Holiday = Holiday

local BOSSES = {
    {
        key = "holiday:coren-direbrew",
        name = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.BREWFEST_COREN_DIREBREW"),
        englishName = "Coren Direbrew",
        catalogAliases = { "Brewfest", "美酒节", "科林", "Coren" },
        reset = "holiday-daily",
        order = 80,
        group = "holiday",
        scheduleKind = "event-daily-07",
        resetHour = 7,
        eventTitleAliases = { "美酒节", "啤酒節", "美酒節", "Brewfest" },
        questID = 25483,
        lfgDungeonID = 287,
        lfgNameAliases = { "科林·烈酒", "柯林·烈酒", "Coren Direbrew" },
        hidePhaseTracking = true,
        trackPhase = false,
    },
    {
        key = "holiday:ahune",
        name = _G.YiboCore.Locale:Get("YiboAltoBoss", "HOLIDAY.AHUNE"),
        englishName = "Ahune",
        catalogAliases = { "Midsummer Fire Festival", "仲夏火焰节", "埃霍恩", "Ahune" },
        reset = "holiday-daily",
        order = 82,
        group = "holiday",
        scheduleKind = "event-daily-07",
        resetHour = 7,
        eventTitleAliases = { "仲夏火焰节", "仲夏火焰節", "Midsummer Fire Festival" },
        questID = 25484,
        lfgDungeonID = 286,
        lfgNameAliases = { "埃霍恩", "艾胡恩", "Ahune" },
        hidePhaseTracking = true,
        trackPhase = false,
    },
    {
        key = "holiday:crown-chemical",
        name = _G.YiboCore.Locale:Get("YiboAltoBoss", "HOLIDAY.CROWN_CHEMICAL"),
        englishName = "The Crown Chemical Co.",
        catalogAliases = { "Love is in the Air", "情人节", "皇冠药剂公司", "Apothecary Hummel", "Crown Chemical" },
        reset = "holiday-daily",
        order = 83,
        group = "holiday",
        scheduleKind = "event-daily-07",
        resetHour = 7,
        eventTitleAliases = { "情人节", "愛就在身邊", "情人節", "Love is in the Air" },
        questID = 25485,
        lfgDungeonID = 288,
        lfgNameAliases = { "皇冠药剂公司", "皇冠藥劑公司", "Crown Chemical", "药剂师汉摩尔", "藥劑師胡默爾", "Apothecary Hummel" },
        hidePhaseTracking = true,
        trackPhase = false,
    },
    {
        key = "holiday:headless-horseman",
        name = _G.YiboCore.Locale:Get("YiboAltoBoss", "HOLIDAY.HEADLESS_HORSEMAN"),
        englishName = "Headless Horseman",
        catalogAliases = { "Hallow's End", "万圣节", "无头骑士", "Headless Horseman" },
        reset = "holiday-daily",
        order = 81,
        group = "holiday",
        scheduleKind = "event-daily-07",
        resetHour = 7,
        -- The client's calendar determines the event dates for this realm.
        eventTitleAliases = { "万圣节", "萬聖節", "Hallow's End", "Hallow’s End" },
        questID = 25482,
        lfgDungeonID = 285,
        lfgNameAliases = { "无头骑士", "無頭騎士", "Headless Horseman" },
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
    local today = date("*t", Now())
    if not today then return false end
    local monthOffset = 0
    -- Calendar queries are relative to the month the player is browsing.
    if type(C_Calendar.GetMonthInfo) == "function" then
        local ok, viewed = pcall(C_Calendar.GetMonthInfo, 0)
        if ok and type(viewed) == "table" and viewed.year and viewed.month then
            monthOffset = (today.year - viewed.year) * 12 + today.month - viewed.month
        end
    end
    local ok, count = pcall(C_Calendar.GetNumDayEvents, monthOffset, today.day)
    if not ok then return false end
    local complete = true
    for index = 1, tonumber(count) or 0 do
        local eventOK, event = pcall(C_Calendar.GetDayEvent, monthOffset, today.day, index)
        if not eventOK or type(event) ~= "table" then complete = false end
        local title = eventOK and event and string.lower(tostring(event.title or "")) or ""
        for _, alias in ipairs(boss.eventTitleAliases or {}) do
            local normalizedAlias = string.lower(tostring(alias))
            if normalizedAlias ~= "" and string.find(title, normalizedAlias, 1, true) then
                return true, true
            end
        end
    end
    return false, complete and (Holiday.calendarReady or (tonumber(count) or 0) > 0)
end

function Holiday:RequestCalendar()
    if C_Calendar and type(C_Calendar.OpenCalendar) == "function" then
        return pcall(C_Calendar.OpenCalendar)
    end
    return false
end

function Holiday:OnCalendarUpdated()
    self.calendarReady = true
end

local function DailyState(boss)
    local query = C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted or IsQuestFlaggedCompleted
    local questOK, questDone, rewardOK, rewardDone = false, nil, false, nil
    if type(query) == "function" then questOK, questDone = pcall(query, boss.questID) end
    if type(GetLFGDungeonRewards) == "function" then rewardOK, rewardDone = pcall(GetLFGDungeonRewards, boss.lfgDungeonID) end
    if questOK and questDone == true then return "completed", "quest" end
    if rewardOK and rewardDone == true then return "completed", "lfg-reward" end
    if questOK and questDone == false and rewardOK and rewardDone == false then return "available" end
end

local function GetRecord(charKey, boss, create)
    local characters = YiboAltoBossDB and YiboAltoBossDB.characters
    local character = characters and characters[charKey]
    if not character and create and charKey == (YAB.GetCurrentCharKey and YAB.GetCurrentCharKey()) then character = CurrentCharacter(true) end
    if not character then return nil end
    if create then character.holidayBosses = character.holidayBosses or {} end
    local records = character.holidayBosses and character.holidayBosses[boss.key]
    if not records and create then records = {}; character.holidayBosses[boss.key] = records end
    return records and records[DayKey(boss)]
end

local function WriteRecord(boss, source)
    local character = CurrentCharacter(true)
    if not character then return false end
    character.holidayBosses = character.holidayBosses or {}
    local records = character.holidayBosses[boss.key] or {}; character.holidayBosses[boss.key] = records
    if records[DayKey(boss)] and records[DayKey(boss)].completed then return false end
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

function Holiday:GetBosses()
    local result = {}
    for _, boss in ipairs(BOSSES) do result[#result + 1] = boss end
    return result
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

-- Task goals remain independent of the manual display toggle.
function Holiday:GetTargetSnapshot(charKey, ref)
    local boss = self:GetBoss(ref)
    if not boss then return nil end
    local now, day = Now(), date("*t", Now())
    day.hour, day.min, day.sec = boss.resetHour, 0, 0
    local boundary = time(day)
    if boundary <= now then day.day = day.day + 1; boundary = time(day) end
    local open, known = IsCalendarOpen(boss)
    return { open = open, availability = open and "open" or (known and "closed" or "unknown"), cycleKey = DayKey(boss), nextResetAt = boundary,
        record = GetRecord(charKey, boss, false) }
end

function Holiday:ObservePlanned(ref)
    local boss = self:GetBoss(ref)
    if not boss or not IsCalendarOpen(boss) then return end
    local state, source = DailyState(boss)
    if state == "completed" then return WriteRecord(boss, source) end
    if state ~= "available" then return false end
    local character = CurrentCharacter(true)
    if not character then return end
    character.holidayBosses = character.holidayBosses or {}
    character.holidayBosses[boss.key] = character.holidayBosses[boss.key] or {}
    local records, key = character.holidayBosses[boss.key], DayKey(boss)
    if not records[key] then records[key] = { observedAt = Now() }; return true end
    return false
end

function Holiday:ObserveCurrent()
    local changed = false
    for _, boss in ipairs(self:GetActiveBosses()) do
        changed = self:ObservePlanned(boss.key) or changed
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
    if not selected then return {}, _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.DUNGEON_FINDER_ROLES_ARE_UNAVAILABLE") end
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
    if selected.tank then roles[#roles + 1] = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.T_TANK") end
    if selected.damage then roles[#roles + 1] = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.D_DPS") end
    if selected.healer then roles[#roles + 1] = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.H_HEALER") end
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
            { text = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.TANK"), checked = selected.tank, disabled = not available.tank, func = function() ToggleRole("tank") end },
            { text = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.HEALER"), checked = selected.healer, disabled = not available.healer, func = function() ToggleRole("healer") end },
            { text = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.DPS"), checked = selected.damage, disabled = not available.damage, func = function() ToggleRole("damage") end },
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
    if not boss then return { state = "unavailable", reason = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.SEASONAL_BOSS_UNAVAILABLE") } end
    if not IsExpectedDungeon(boss) then return { state = "unavailable", reason = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.THE_CLIENT_HAS_NO_MATCHING_SEASONAL_DUNGEON") } end
    local category = LE_LFG_CATEGORY_LFD
    -- The live mode owns queue state. A dungeon-list entry alone must never
    -- override an idle mode or imply that this specific dungeon is queued.
    if type(GetLFGMode) ~= "function" then
        return { state = "unavailable", reason = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.THE_CLIENT_DOES_NOT_SUPPORT_DUNGEON_FINDER_QUEUES") }
    end
    local ok, mode = pcall(GetLFGMode, category, boss.lfgDungeonID)
    if not ok then return { state = "unavailable", reason = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.CANNOT_QUEUE_RIGHT_NOW") } end
    if mode == "queued" or mode == "proposal" or mode == "rolecheck" or mode == "suspended" then
        return { state = "queued", mode = mode }
    end
    local available, joinable = false, false
    if type(IsLFGDungeonJoinable) == "function" then available, joinable = IsLFGDungeonJoinable(boss.lfgDungeonID) end
    if not joinable then
        local reason = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.THIS_CHARACTER_CANNOT_QUEUE_RIGHT_NOW")
        if type(GetLFDLockInfo) == "function" then
            local _, lockedReason, _, _, _, lockedText = GetLFDLockInfo(boss.lfgDungeonID, 1)
            if lockedText and lockedText ~= "" then reason = lockedText elseif lockedReason and lockedReason ~= 0 then reason = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.THIS_CHARACTER_DOES_NOT_MEET_THE_DUNGEON_REQUIREMENTS") end
        end
        return { state = "locked", reason = reason, available = available }
    end
    local roles = self:GetRoles()
    if #roles == 0 then return { state = "no-roles", reason = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.SELECT_ROLES_IN_THE_DUNGEON_FINDER_FIRST") } end
    return { state = "ready", roles = roles }
end

function Holiday:GetQueueWait(ref)
    local boss = self:GetBoss(ref)
    if not boss or self:GetQueueState(boss).mode ~= "queued" or type(GetLFGQueueStats) ~= "function" then return nil end
    -- Match Blizzard's queue display: myWait is return 16, in seconds.
    local result = { pcall(GetLFGQueueStats, LE_LFG_CATEGORY_LFD, boss.lfgDungeonID) }
    if not result[1] or not result[2] then return nil end
    local estimate, queuedAt, activeID = result[17], result[18], result[19]
    if activeID and activeID ~= boss.lfgDungeonID then return nil end
    local function Valid(value)
        return type(value) == "number" and value == value and value >= 0 and value < math.huge
    end
    if not Valid(estimate) then estimate = nil end
    local elapsed
    if Valid(queuedAt) and type(GetTime) == "function" then
        local now = GetTime()
        if Valid(now) and queuedAt <= now then elapsed = now - queuedAt end
    end
    return estimate, elapsed
end

function Holiday:RefreshQueueState()
    if YAB.NotifyCorePageChanged then YAB.NotifyCorePageChanged() end
    if self.queueRefreshPending or not (C_Timer and type(C_Timer.After) == "function") then return end
    self.queueRefreshPending = true
    -- Some LFG events arrive before GetLFGMode exposes the final state.
    -- Coalesce a short follow-up pass instead of guessing from the event name.
    C_Timer.After(0.1, function()
        if YAB.NotifyCorePageChanged then YAB.NotifyCorePageChanged() end
    end)
    C_Timer.After(0.5, function()
        self.queueRefreshPending = nil
        if YAB.NotifyCorePageChanged then YAB.NotifyCorePageChanged() end
    end)
end

local function ConfirmQueueChanges(boss, previous)
    local state = previous.state .. ":" .. tostring(previous.reason)
    local function Check()
        local current = Holiday:GetQueueState(boss)
        local key = current.state .. ":" .. tostring(current.reason)
        if key ~= state then
            state = key
            if YAB.NotifyCorePageChanged then YAB.NotifyCorePageChanged() end
        end
    end
    Check()
    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(0.05, Check)
        C_Timer.After(0.25, Check)
    end
end

function Holiday:ToggleQueue(ref)
    local boss = self:GetBoss(ref)
    local queue = self:GetQueueState(boss)
    if queue.state == "queued" then
        if type(LeaveLFG) == "function" then
            LeaveLFG(LE_LFG_CATEGORY_LFD)
            ConfirmQueueChanges(boss, queue)
            return true, _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.LEFT_THE_QUEUE")
        end
        return false, _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.THE_CLIENT_CANNOT_CANCEL_THIS_QUEUE")
    end
    if queue.state ~= "ready" then return false, queue.reason or _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.CANNOT_QUEUE_RIGHT_NOW") end
    if type(LFDQueueFrame_SetType) == "function" then LFDQueueFrame_SetType(boss.lfgDungeonID) end
    if type(LFG_JoinDungeon) ~= "function" then return false, _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.THE_CLIENT_DOES_NOT_SUPPORT_DUNGEON_FINDER_QUEUES") end
    LFG_JoinDungeon(LE_LFG_CATEGORY_LFD, boss.lfgDungeonID, _G.LFDDungeonList, _G.LFDHiddenByCollapseList)
    ConfirmQueueChanges(boss, queue)
    return true, _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.JOINED_THE_SEASONAL_DUNGEON_QUEUE")
end
