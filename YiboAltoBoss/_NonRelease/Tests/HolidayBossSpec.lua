-- Run from repository root: lua YiboAltoBoss/_NonRelease/Tests/HolidayBossSpec.lua
local checks, language, resources = 0, "zh", { zh = {}, en = {} }
local clock = os.time({ year = 2026, month = 10, day = 18, hour = 15 })
local title, reward, quest, dungeon, queued = "万圣节", false, false, 285, false
local function check(value, label) checks = checks + 1; assert(value, label) end
time = os.time
date = function(format, stamp) return os.date(format, stamp or clock) end
GetServerTime = function() return clock end
C_Calendar = {
    GetNumDayEvents = function() return title and 1 or 0 end,
    GetDayEvent = function() return { title = title } end,
}
YiboCore = { Locale = {
    Register = function(_, owner, lang, values) for key, value in pairs(values) do resources[lang][key] = value end end,
    Get = function(_, owner, key, ...) return string.format(assert(resources[language][key], key), ...) end,
} }
YiboAltoBossDB = { settings = {}, characters = { A = {}, B = {} } }
YAB = {
    GetCurrentCharKey = function() return "A" end,
    PersistDB = function() end,
    GetAllBossList = function() return {} end,
    GetInstanceCatalog = function() return {} end,
}
GetLFGDungeonRewards = function(id) return id == 285 and reward end
IsQuestFlaggedCompleted = function(id) return id == 25482 and quest end
GetInstanceInfo = function() return nil, nil, nil, nil, nil, nil, nil, nil, nil, dungeon end
GetLFGDungeonInfo = function(id)
    return id == 285 and "无头骑士" or "Other", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, true
end
LE_LFG_CATEGORY_LFD = 1
GetLFGQueuedList = function() return queued and { [285] = true } or {} end
GetLFGMode = function(_, id) return queued and id == dungeon and "queued" or nil end
IsLFGDungeonJoinable = function() return true, true end
GetAvailableRoles = function() return false, false, true end
GetLFGRoles = function() return false, false, false, true end
dofile("YiboAltoBoss/Locale.lua")
dofile("YiboAltoBoss/HolidayBoss.lua")
local Holiday, key = YAB.Holiday, "holiday:headless-horseman"
check(Holiday:GetBoss(key).name == "万圣节·无头骑士", "Chinese player-visible name")
local active = Holiday:GetActiveBosses()
check(#active == 1 and active[1].key == key, "Halloween shows Horseman automatically and excludes Brewfest")
for _, alias in ipairs({ "萬聖節", "Hallow's End", "Hallow’s End" }) do
    title = alias
    check(Holiday:GetActiveBosses()[1].key == key, "calendar alias " .. alias)
end
title = nil
check(#Holiday:GetActiveBosses() == 0, "no calendar event does not invent availability")
title = "万圣节"
check(Holiday:ObserveCurrent() and Holiday:GetStatus("A", key) == "available", "login records daily observation")
check(Holiday:GetStatus("B", key) == "unobserved", "offline character remains unobserved")
check(not Holiday:ObserveCurrent(), "repeat observation is idempotent")
reward = true
check(Holiday:ObserveCurrent() and Holiday:GetStatus("A", key) == "completed", "daily reward marks completion")
check(not Holiday:ObserveCurrent(), "repeat reward does not duplicate completion")
reward = false
clock = os.time({ year = 2026, month = 10, day = 19, hour = 6, min = 59 })
check(Holiday:GetStatus("A", key) == "completed", "completion retained until 07 reset")
clock = clock + 60
check(Holiday:GetStatus("A", key) == "unobserved", "new day requires observation")
quest = true
check(Holiday:ObserveCurrent() and Holiday:GetStatus("A", key) == "completed", "reward quest marks completion")
quest = false
clock = clock + 86400
dungeon = 287
check(not Holiday:RecordCompletionReward(), "other seasonal dungeon does not complete Horseman")
dungeon = 285
check(Holiday:RecordCompletionReward() and Holiday:GetStatus("A", key) == "completed", "matching LFG reward event completes Horseman")
check(Holiday:GetQueueState(key).state == "ready", "matching dungeon supports queue action")
queued = true
check(Holiday:GetQueueState(key).state == "queued", "existing Horseman queue recognized")
GetLFGDungeonInfo = function() return "Unrelated Dungeon" end
check(Holiday:GetQueueState(key).state == "unavailable", "unsupported client dungeon fails safely")
YiboAltoBossDB.settings.showHolidayBosses = false
check(#Holiday:GetActiveBosses() == 0, "manual display toggle hides seasonal row")
clock = clock + 86400
dofile("YiboAltoBoss/PlannedTargets.lua")
YAB.PlannedTargets.Period = function() end
YAB.PlannedTargets.ScheduleChange = function() end
YAB.PlannedTargets:Observe()
check(Holiday:GetStatus("A", key) == "available", "planned observation enumerates Horseman with manual display disabled")
dofile("YiboAltoBoss/TargetCatalog.lua")
YAB.TargetCatalog:Build()
local definition = YAB.TargetCatalog:Get(key)
check(definition and definition.kind == "holiday" and definition.reset == "daily", "Horseman exported in action-center catalog")
check(YAB.TargetCatalog:Get("holiday:coren-direbrew") ~= nil, "Brewfest remains in catalog")
language = "en"
dofile("YiboAltoBoss/HolidayBoss.lua")
check(YAB.Holiday:GetBoss(key).name == "Hallow's End · Headless Horseman", "English player-visible name")
-- Audit every seasonal dungeon with independent expected client identifiers.
local roster = {
    { key = "holiday:coren-direbrew", dungeonID = 287, questID = 25483,
        titles = { "美酒节", "啤酒節", "Brewfest" }, names = { "科林·烈酒", "柯林·烈酒", "Coren Direbrew" } },
    { key = "holiday:headless-horseman", dungeonID = 285, questID = 25482,
        titles = { "万圣节", "萬聖節", "Hallow's End" }, names = { "无头骑士", "無頭騎士", "The Headless Horseman" } },
    { key = "holiday:ahune", dungeonID = 286, questID = 25484,
        titles = { "仲夏火焰节", "仲夏火焰節", "Midsummer Fire Festival" }, names = { "冰霜之王埃霍恩", "冰霜之王艾胡恩", "The Frost Lord Ahune" } },
    { key = "holiday:crown-chemical", dungeonID = 288, questID = 25485,
        titles = { "情人节", "愛就在身邊", "Love is in the Air" }, names = { "皇冠药剂公司", "皇冠藥劑公司", "The Crown Chemical Co." } },
}
check(#YAB.Holiday:GetBosses() == #roster, "four seasonal dungeon entries")
local requests, expectedOffset, viewedMonth = 0, 0, 10
C_Calendar.OpenCalendar = function() requests = requests + 1 end
C_Calendar.GetMonthInfo = function() return { year = 2026, month = viewedMonth } end
C_Calendar.GetNumDayEvents = function(offset)
    assert(offset == expectedOffset, "calendar query uses current month rather than viewed month")
    return title and 1 or 0
end
C_Calendar.GetDayEvent = function(offset)
    assert(offset == expectedOffset, "calendar event uses matching month")
    return { title = title }
end
for _, spec in ipairs(roster) do
    for index, eventTitle in ipairs(spec.titles) do
        language = index == 3 and "en" or "zh"
        dofile("YiboAltoBoss/HolidayBoss.lua")
        Holiday = YAB.Holiday
        YiboAltoBossDB = { settings = {}, characters = { A = {}, B = {} } }
        title, reward, quest, dungeon, queued = eventTitle, false, false, spec.dungeonID, false
        -- A shifted event date must still honor the client's live calendar.
        clock = os.time({ year = 2026, month = 10, day = 18, hour = 15 })
        expectedOffset, viewedMonth = 0, 10
        GetLFGDungeonRewards = function(id) return id == spec.dungeonID and reward end
        IsQuestFlaggedCompleted = function(id) return id == spec.questID and quest end
        GetLFGDungeonInfo = function(id)
            return id == spec.dungeonID and spec.names[index] or "Other", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, true
        end
        GetLFGQueuedList = function() return queued and { [spec.dungeonID] = true } or {} end
        check(Holiday:RequestCalendar(), "calendar data requested without manual calendar opening")
        active = Holiday:GetActiveBosses()
        check(#active == 1 and active[1].key == spec.key, "only matching holiday displayed: " .. spec.key)
        check(Holiday:GetQueueState(spec.key).state == "ready", "queue works for each localized dungeon name")
        local selectedDungeon, joinedDungeon, leftCategory
        LFDQueueFrame_SetType = function(id) selectedDungeon = id end
        LFG_JoinDungeon = function(category, id)
            assert(category == LE_LFG_CATEGORY_LFD, "queue category")
            joinedDungeon, queued = id, true
        end
        LeaveLFG = function(category) leftCategory, queued = category, false end
        check(Holiday:ToggleQueue(spec.key) and selectedDungeon == spec.dungeonID and joinedDungeon == spec.dungeonID,
            "queue click submits matching dungeon")
        check(Holiday:ToggleQueue(spec.key) and leftCategory == LE_LFG_CATEGORY_LFD and not queued,
            "queue click cancels existing seasonal queue")
        check(Holiday:ObserveCurrent() and Holiday:GetStatus("A", spec.key) == "available", "daily observation for each boss")
        check(Holiday:GetStatus("B", spec.key) == "unobserved", "offline role does not inherit daily state")
        reward = true
        check(Holiday:ObserveCurrent() and Holiday:GetStatus("A", spec.key) == "completed", "daily reward routed to correct boss")
        reward, quest = false, true
        clock = clock + 86400
        check(Holiday:ObserveCurrent() and Holiday:GetStatus("A", spec.key) == "completed", "daily quest routed to correct boss")
        quest = false
        clock = clock + 86400
        check(Holiday:RecordCompletionReward(), "correct completion event routed to each boss")
        dungeon = 999
        check(not Holiday:RecordCompletionReward(), "unrelated completion event ignored")
        YiboAltoBossDB.settings.showHolidayBosses = false
        check(#Holiday:GetActiveBosses() == 0, "display switch applies to every holiday")
        clock = clock + 86400
        YAB.PlannedTargets:Observe()
        check(Holiday:GetStatus("A", spec.key) == "available", "explicit target observed independently of display")
        YAB.TargetCatalog:Invalidate()
        check(YAB.TargetCatalog:Get(spec.key).name == Holiday:GetBoss(spec.key).name, "target catalog shares localized name")
        YiboAltoBossDB.settings.showHolidayBosses = true
        viewedMonth, expectedOffset = 1, 9
        check(Holiday:GetActiveBosses()[1].key == spec.key, "browsing another month does not hide active boss")
        viewedMonth, expectedOffset, title = 10, 0, nil
        check(#Holiday:GetActiveBosses() == 0, "event closure removes seasonal row")
    end
end
check(requests == 12, "all simulated sessions request calendar data")
title = "仲夏火焰节"
local query = IsQuestFlaggedCompleted
IsQuestFlaggedCompleted = function() error("client not ready") end
GetLFGDungeonRewards = function() return false end
check(not Holiday:ObserveCurrent() and Holiday:GetStatus("A", "holiday:ahune") == "unobserved", "failed query preserves unknown state")
GetLFGDungeonRewards = function() return true end
check(Holiday:ObserveCurrent() and Holiday:GetStatus("A", "holiday:ahune") == "completed", "positive reward remains valid when quest API fails")
IsQuestFlaggedCompleted = query
C_Calendar.GetNumDayEvents = function() error("calendar not ready") end
check(#Holiday:GetActiveBosses() == 0, "unready calendar fails safely")
C_Calendar.GetNumDayEvents = function() return 1 end
check(Holiday:GetActiveBosses()[1].key == "holiday:ahune", "late calendar data restores seasonal row")
C_Calendar.GetNumDayEvents = function() return 0 end
check(Holiday:GetTargetSnapshot("A", "holiday:ahune").availability == "unknown", "empty unready calendar remains unknown")
Holiday:OnCalendarUpdated()
check(Holiday:GetTargetSnapshot("A", "holiday:ahune").availability == "closed", "loaded empty calendar confirms event closure")
C_Calendar.GetNumDayEvents = function() return 1 end
check(Holiday:GetTargetSnapshot("A", "holiday:ahune").availability == "open", "next event restores target availability")
-- Live queue mode must remain authoritative regardless of list/icon state.
GetLFGDungeonInfo = function()
    return "The Frost Lord Ahune", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, true
end
local liveMode, liveID = nil, 286
GetLFGMode = function(category, id)
    assert(category == LE_LFG_CATEGORY_LFD, "live queue category")
    return id == liveID and liveMode or nil
end
GetLFGQueuedList = function() return { [286] = true } end
check(Holiday:GetQueueState("holiday:ahune").state == "ready", "idle live mode overrides stale dungeon list")
GetLFGQueuedList = function() return {} end
for _, mode in ipairs({ "queued", "proposal", "rolecheck", "suspended" }) do
    liveMode = mode
    check(Holiday:GetQueueState("holiday:ahune").state == "queued", "live queue remains active with missing list/icon: " .. mode)
end
liveID, liveMode = 285, "queued"
check(Holiday:GetQueueState("holiday:ahune").state == "ready", "other dungeon queue is not attributed to Ahune")
liveID = 286
for _, mode in ipairs({ "finished", "lfgparty", "abandonedInDungeon" }) do
    liveMode = mode
    check(Holiday:GetQueueState("holiday:ahune").state == "ready", "nonqueue mode is not cancel-queue: " .. mode)
end
local timers, refreshes, observed = {}, 0, {}
C_Timer = { After = function(delay, callback) timers[#timers + 1] = { delay = delay, callback = callback } end }
YAB.NotifyCorePageChanged = function()
    refreshes = refreshes + 1
    observed[#observed + 1] = Holiday:GetQueueState("holiday:ahune").state
end
liveMode = "queued"
Holiday:RefreshQueueState()
Holiday:RefreshQueueState()
check(#timers == 2 and refreshes == 2, "event burst coalesces delayed refreshes")
liveMode = nil
timers[1].callback()
timers[2].callback()
check(observed[1] == "queued" and observed[#observed] == "ready", "late system cancellation is reflected after event")
check(not Holiday.queueRefreshPending, "delayed refresh releases coalescing flag")
timers = {}
Holiday:RefreshQueueState()
check(#timers == 2, "next queue transition can schedule another refresh")
GetLFGMode = nil
check(Holiday:GetQueueState("holiday:ahune").state == "unavailable", "missing live API never trusts stale list")
GetLFGMode = function() error("client unavailable") end
check(Holiday:GetQueueState("holiday:ahune").state == "unavailable", "live API failure is handled safely")
local estimate, statsID, hasData = 125, 286, true
local uptime, queuedAt = 190, 100
GetTime = function() return uptime end
GetLFGMode = function() return "queued" end
GetLFGQueueStats = function(category, id)
    assert(category == LE_LFG_CATEGORY_LFD and id == 286, "estimate queries exact seasonal dungeon")
    return hasData, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, 999, nil, nil, nil, estimate, queuedAt, statsID
end
check(Holiday:GetQueueWait("holiday:ahune") == 125, "estimate uses personal wait rather than overall average")
check(select(2, Holiday:GetQueueWait("holiday:ahune")) == 90, "elapsed uses uptime minus system queue start")
queuedAt = 0
check(select(2, Holiday:GetQueueWait("holiday:ahune")) == 190, "zero queue timestamp is valid")
queuedAt = 200
check(select(2, Holiday:GetQueueWait("holiday:ahune")) == nil, "future queue timestamp stays unknown")
queuedAt = nil
check(select(2, Holiday:GetQueueWait("holiday:ahune")) == nil, "missing queue timestamp stays unknown")
queuedAt = 100
estimate = 0
check(Holiday:GetQueueWait("holiday:ahune") == 0, "zero-second estimate is valid")
estimate = -1
check(Holiday:GetQueueWait("holiday:ahune") == nil, "negative unknown estimate is not displayed as zero")
check(select(2, Holiday:GetQueueWait("holiday:ahune")) == 90, "elapsed remains available without estimate")
estimate, statsID = 125, 285
check(Holiday:GetQueueWait("holiday:ahune") == nil, "other dungeon estimate is rejected")
statsID, hasData = 286, false
check(Holiday:GetQueueWait("holiday:ahune") == nil, "unready queue statistics remain unknown")
hasData = true
GetLFGMode = function() return "proposal" end
check(Holiday:GetQueueWait("holiday:ahune") == nil, "proposal does not display stale waiting estimate")
GetLFGMode = function() return "queued" end
local stats = GetLFGQueueStats
GetLFGQueueStats = function() error("stats unavailable") end
check(Holiday:GetQueueWait("holiday:ahune") == nil, "statistics error fails safely")
GetLFGQueueStats = nil
check(Holiday:GetQueueWait("holiday:ahune") == nil, "missing statistics API fails safely")
GetLFGQueueStats = stats
YiboCore.UITheme = {
    Colors = { text = {}, accent = {}, muted = {}, successSurface = {}, timer = {}, selected = {} },
    Table = {}, GetCharacterMatrixColumnWidth = function() return 88 end,
    BindTooltip = function(_, control, title, lines) control.title, control.lines = title, lines end,
    ShowTooltip = function(_, control, title, lines) control.title, control.lines = title, lines end,
}
dofile("YiboAltoBoss/AccountPage.lua")
local visited = {}
local function Find(fn, wanted)
    if visited[fn] then return end
    visited[fn] = true
    for index = 1, 100 do
        local name, value = debug.getupvalue(fn, index)
        if not name then break end
        if name == wanted then return value end
        if type(value) == "function" then local found = Find(value, wanted); if found then return found end end
    end
end
local setAction = assert(Find(YAB.RefreshAccountPage, "SetHolidayAction"))
local control = { scripts = {}, label = { SetTextColor = function() end },
    SetText = function() end, SetState = function() end, SetBackdropColor = function() end,
    SetScript = function(self, event, callback) self.scripts[event] = callback end }
for _, lang in ipairs({ "zh", "en" }) do
    language, estimate, uptime = lang, 125, 190
    setAction(control, Holiday:GetBoss("holiday:ahune"))
    local expected = YiboCore.Locale:Get("YiboAltoBoss", "QUEUE.ESTIMATED_WAIT", "2" .. YiboCore.Locale:Get("YiboAltoBoss", "TIME.MINUTES_SUFFIX"))
    check(control.lines[2].text == expected, "localized estimate is rendered in actual action tooltip")
    check(control.lines[3].text == YiboCore.Locale:Get("YiboAltoBoss", "QUEUE.ELAPSED_WAIT", "1" .. YiboCore.Locale:Get("YiboAltoBoss", "TIME.MINUTES_SUFFIX")),
        "elapsed time is adjacent to estimate in actual localized tooltip")
    estimate = -1
    uptime = 250
    control.scripts.OnEnter(control)
    check(control.lines[2].text == YiboCore.Locale:Get("YiboAltoBoss", "QUEUE.ESTIMATED_WAIT", YiboCore.Locale:Get("YiboAltoBoss", "QUEUE.WAIT_UNAVAILABLE")),
        "hover fetches current statistics and renders unknown estimate")
    check(control.lines[3].text == YiboCore.Locale:Get("YiboAltoBoss", "QUEUE.ELAPSED_WAIT", "2" .. YiboCore.Locale:Get("YiboAltoBoss", "TIME.MINUTES_SUFFIX")),
        "next hover updates elapsed time independently of estimate")
end
-- Exercise the matrix's actual status renderer and business-action wrapper.
for _, name in ipairs({ "chrome", "matrixLine", "success", "successSurface", "accent", "muted", "text" }) do
    YiboCore.UITheme.Colors[name] = { 0.2, 0.5, 0.7, 1 }
end
control.SetBackdropBorderColor = function() end
control.GetScript = function(self, event) return self.scripts[event] end
control.RegisterForClicks = function() end
local intercepted, saves, changes = false, 0, 0
YiboCore.Characters = { ResolveLegacyKey = function(_, id) return id end }
YiboCore.Defaults = { Copy = function(self, value)
    if type(value) ~= "table" then return value end
    local copy = {}; for k, v in pairs(value) do copy[k] = self:Copy(v) end
    return copy
end }
YiboCore.BusinessItemActions = {
    Unbind = function(self, cell) cell.binding = nil end,
    Bind = function(self, cell, options) cell.binding = options end,
    Handle = function() return intercepted end,
    TooltipLines = function(_, lines) return lines end,
}
dofile("YiboAltoBoss/GoalTargets.lua")
YAB.GoalTargets.ref = {}
YAB.PersistDB = function() saves = saves + 1 end
YAB.NotifyCorePageChanged = function() changes = changes + 1 end
local plans, holidayKey = YAB.PlannedTargets, "holiday:ahune"
plans.LegacyKey = function(_, id) return id end
local planned = true
plans.IsPlanned = function(_, id)
    return planned, id, { catalogID = holidayKey }
end
YiboAltoBossDB = { settings = {}, characters = { A = {}, B = {} } }
visited = {}
local setStatus = assert(Find(YAB.RefreshAccountPage, "SetStatus"))
for _, lang in ipairs({ "zh", "en" }) do
    language = lang
    local boss = Holiday:GetBoss(holidayKey)
    setStatus(control, "unobserved", "B", boss)
    check(control.binding and control.binding.reservedButtons.LeftButton, "Hub binding preserves ordinary left click")
    check(control.lines[#control.lines].text == YiboCore.Locale:Get("YiboAltoBoss", "UI.CLICK_TO_ADD_OR_REMOVE_A_MANUAL_MARK"),
        "planned holiday advertises localized manual mark")
    local beforeSaves, beforeChanges = saves, changes
    control.scripts.OnClick(control, "LeftButton")
    check(Holiday:GetStatus("B", holidayKey) == "completed", "offline planned holiday can be marked completed")
    check(plans:Progress("B", { catalogID = holidayKey }).state == "completed", "Hub progress reads owner's manual completion")
    check(saves == beforeSaves + 1 and changes == beforeChanges + 1, "manual completion persists and notifies shared views")
    check(Holiday:GetStatus("A", holidayKey) == "unobserved", "manual completion affects only clicked character")
    setStatus(control, "completed", "B", boss)
    intercepted = true
    control.scripts.OnClick(control, "LeftButton")
    check(Holiday:GetStatus("B", holidayKey) == "completed", "Core action gesture does not also toggle completion")
    intercepted = false
    control.scripts.OnClick(control, "RightButton")
    check(Holiday:GetStatus("B", holidayKey) == "completed", "right click does not toggle completion")
    control.scripts.OnClick(control, "LeftButton")
    check(plans:Progress("B", { catalogID = holidayKey }).state == "ready", "manual completion can be removed in planned matrix")
    planned = false
    setStatus(control, "available", "B", boss)
    control.scripts.OnClick(control, "LeftButton")
    check(Holiday:GetStatus("B", holidayKey) == "completed", "ordinary holiday matrix retains manual toggle")
    control.scripts.OnClick(control, "LeftButton")
    planned = true
end
GetLFGDungeonRewards = function() return true end
check(Holiday:ObservePlanned(holidayKey), "current role gets authoritative completion")
setStatus(control, "completed", "A", Holiday:GetBoss(holidayKey))
control.scripts.OnClick(control, "LeftButton")
check(select(2, Holiday:GetStatus("A", holidayKey)).source == "lfg-reward", "planned matrix protects automatic completion")
check(control.lines[#control.lines].text ~= YiboCore.Locale:Get("YiboAltoBoss", "UI.CLICK_TO_ADD_OR_REMOVE_A_MANUAL_MARK"),
    "automatic completion does not advertise manual toggle")
print("HolidayBossSpec: " .. checks .. " checks passed")
