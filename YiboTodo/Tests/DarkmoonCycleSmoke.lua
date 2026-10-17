-- Run from the workspace root with Lua 5.1; no client or saved data required.
_G.YiboTodo = nil
local clock
local function At(year, month, day, hour, minute, second)
    return os.time({ year = year, month = month, day = day, hour = hour or 0,
        min = minute or 0, sec = second or 0, isdst = false })
end
date, time = os.date, os.time
GetServerTime = function() return clock end
GetGameTime = function()
    local current = os.date("*t", clock)
    return current.hour, current.min
end
C_Calendar = {
    GetNumDayEvents = function() return 1 end,
    GetDayEvent = function() return { title = "Darkmoon Faire" } end,
}

dofile("YiboTodo/Namespace.lua")
dofile("YiboTodo/Database.lua")
dofile("YiboTodo/Catalog/MonitoringGroupCatalog.lua")
dofile("YiboTodo/Catalog/SpecialActivityCatalog_MoP.lua")
dofile("YiboTodo/Model/Schedule.lua")
dofile("YiboTodo/Providers/Registry.lua")
dofile("YiboTodo/Providers/SpecialActivity.lua")
local Addon = _G.YiboTodo
_G.YiboTodoDB = {}
Addon.Database:Initialize()
Addon.NotifyChanged = function() end
local provider = assert(Addon.Providers.Registry:Get("special-activity"))
local definition = Addon.Catalog.specialActivities["mop.darkmoon-faire.29512"]
local function Project(id) return assert(provider:GetProject(id or "current", definition, clock)) end
local function Legacy(id, completedAt)
    local record = Addon.Database:GetProvider(id, "special-activity", true)
    local day = { state = "completed", completedAt = completedAt, observedAt = completedAt }
    record.days = { [definition.id] = { ["2026-10-2"] = day } }
    return day
end

-- Same-month reopen: the screenshot reports the previous October 9 completion.
clock = At(2026, 10, 9, 12)
assert(provider:RecordTurnIn("current", definition.questID))
local previousKey = Project().cycleKey
assert(Project().state == "completed")
local oldDay = Legacy("offline", clock)
clock = At(2026, 10, 18, 0)
assert(Project().state == "actionable", "a same-month Faire opening clears the previous event at midnight")
assert(Project().cycleKey ~= previousKey, "each opening has its own cycle identity")
assert(Project("offline").state == "actionable", "legacy offline completions cannot carry into a new opening")
assert(oldDay.state == "completed", "historical saved data is preserved")
clock = At(2026, 10, 18, 2, 18)
assert(Project().state == "actionable", "the new event is actionable before 07:00")
assert(provider:RecordTurnIn("current", definition.questID))
local openingKey = Project().cycleKey
assert(Project().state == "completed", "a new pre-07:00 turn-in belongs to the current event")
clock = At(2026, 10, 18, 7)
assert(Project().state == "completed" and Project().cycleKey == openingKey, "Sunday 07:00 does not clear a new event completion")
clock = At(2026, 10, 19, 0)
assert(Project().state == "completed" and Project().cycleKey == openingKey, "Monday does not split the opening cycle")

clock = At(2026, 10, 22, 6, 59, 59)
assert(Project().state == "completed", "Thursday before 07:00 retains the opening completion")
assert(Project().nextChangeAt == At(2026, 10, 22, 7), "Thursday transition is scheduled at 07:00")
clock = At(2026, 10, 22, 7)
assert(Project().state == "actionable" and Project().cycleKey ~= openingKey, "Thursday 07:00 starts the second cycle")
assert(provider:RecordTurnIn("current", definition.questID))
local secondKey = Project().cycleKey
clock = At(2026, 10, 24, 23, 59, 59)
assert(Project().state == "completed" and Project().cycleKey == secondKey, "Saturday retains the second-cycle completion")
C_Calendar.GetNumDayEvents = function() return 0 end
clock = At(2026, 10, 25, 0)
assert(provider:GetProject("current", definition, clock) == nil, "closed events are hidden")
assert(provider:GetTargetProject("current", definition, clock).state == "not-applicable", "explicit targets use the same closed-event rule")
C_Calendar.GetNumDayEvents = function() return 1 end

-- Upgrading preserves trustworthy legacy completions within the actual cycle.
clock = At(2026, 10, 18, 2, 18)
Legacy("valid-legacy", At(2026, 10, 18, 1))
assert(Project("valid-legacy").state == "completed", "valid legacy completion survives the key change")
assert(Project("valid-legacy").observedAt == At(2026, 10, 18, 1), "legacy evidence keeps its observation time")
Legacy("future-legacy", At(2026, 10, 22, 8))
assert(Project("future-legacy").state == "actionable", "future evidence cannot complete this cycle")
clock = At(2026, 10, 22, 7)
assert(Project("valid-legacy").state == "actionable", "legacy completion expires at the actual weekly reset")
Legacy("valid-second-cycle", At(2026, 10, 22, 7))
assert(Project("valid-second-cycle").state == "completed", "valid second-cycle legacy evidence is retained")

-- The event crosses a month boundary without resetting its second cycle.
clock = At(2026, 5, 31, 2)
assert(provider:RecordTurnIn("month-crossing", definition.questID))
local monthKey = Project("month-crossing").cycleKey
clock = At(2026, 6, 1, 2)
assert(Project("month-crossing").state == "completed" and Project("month-crossing").cycleKey == monthKey,
    "the calendar month does not split an event cycle")

-- Server calendar and realm clock remain authoritative across local timezones.
clock = At(2026, 10, 18, 0)
local realmMidnight = clock
GetGameTime = function()
    local seconds = clock - realmMidnight
    return math.floor(seconds / 3600) % 24, math.floor(seconds / 60) % 60
end
C_DateAndTime = { GetCurrentCalendarTime = function()
    return { year = 2026, month = 10, monthDay = 18, weekday = 1 }
end }
date = function(format, value) return os.date(format, (value or clock) - 8 * 3600) end
assert(provider:RecordTurnIn("realm-calendar", definition.questID))
local realmKey = Project("realm-calendar").cycleKey
clock = realmMidnight + 8 * 3600
assert(Project("realm-calendar").state == "completed" and Project("realm-calendar").cycleKey == realmKey,
    "local midnight does not split the realm event cycle")
C_DateAndTime = nil
date = os.date
GetGameTime = function()
    local current = os.date("*t", clock)
    return current.hour, current.min
end

-- A visible account snapshot must invalidate at Thursday 07:00 without a login.
clock = At(2026, 10, 18, 2, 18)
assert(provider:RecordTurnIn("snapshot", definition.questID))
clock = At(2026, 10, 22, 6, 59, 59)
Addon.Core = {
    Characters = { GetAll = function() return { { id = "snapshot" }, { id = "offline" } } end,
        GetCurrent = function() return { id = "snapshot" } end },
    DataDomains = { Get = function() return { state = "known", data = {
        professions = { { id = 129, name = "First Aid" } },
    } } end },
}
Addon.Settings = {
    IsMonitoringGroupEnabled = function(_, id) return id == "darkmoon-faire" end,
    IsMonitoringItemEnabled = function(_, _, id) return id == definition.id end,
    GetMode = function() return "hidden" end,
}
local timers = {}
C_Timer = { After = function(delay, callback) timers[#timers + 1] = { delay = delay, callback = callback } end }
dofile("YiboTodo/Model/Snapshot.lua")
local notifications = 0
Addon.NotifyChanged = function() notifications = notifications + 1; Addon.Snapshot:Invalidate() end
local snapshot = Addon.Snapshot:Build()
assert(snapshot.characters.snapshot.monitoringProjects["darkmoon-faire"][1].state == "completed")
assert(Addon.Snapshot.nextTransitionAt == At(2026, 10, 22, 7), "account refresh follows the event boundary")
assert(#timers == 1 and timers[1].delay < 2, "an automatic refresh is queued at the weekly reset")
clock = At(2026, 10, 22, 7)
timers[1].callback()
assert(notifications == 1 and Addon.Snapshot.dirty, "the timer invalidates and publishes the shared snapshot")
local refreshed = Addon.Snapshot:Build()
local project = refreshed.characters.snapshot.monitoringProjects["darkmoon-faire"][1]
assert(project.state == "actionable", "the refreshed account view clears the old completion")
assert(provider:GetTargetProject("snapshot", definition, clock).cycleKey == project.cycleKey,
    "explicit goals and account views share the same cycle")
dofile("YiboTodo/ActionTodo.lua")
dofile("YiboTodo/ActionActivities.lua")
local tasks = Addon.ActionActivities:ProjectAll("snapshot", refreshed.characters.snapshot, clock, "test")
assert(#tasks == 1 and tasks[1].state == "active" and tasks[1].temporal.cycleKey == project.cycleKey,
    "the action center consumes the same reset state and identity")
print("YiboTodo Darkmoon cycle smoke passed")
