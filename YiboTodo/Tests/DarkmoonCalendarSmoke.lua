-- Run from the workspace root with Lua 5.1.
date, time = os.date, os.time
local clock = os.time({ year = 2026, month = 10, day = 22, hour = 12 })
local current = { year = 2026, month = 10, monthDay = 22, weekday = 5 }
C_DateAndTime = { GetCurrentCalendarTime = function() return current end }
local viewed, offset, events = { year = 2026, month = 11 }, -1, {}
local requests, notifications, frames = 0, 0, {}
C_Calendar = {
    OpenCalendar = function() requests = requests + 1 end,
    GetMonthInfo = function() return viewed end,
    GetNumDayEvents = function(actualOffset, day)
        assert(actualOffset == offset and day == current.monthDay, "query the realm day relative to the browsed month")
        return #events
    end,
    GetDayEvent = function(actualOffset, day, index)
        assert(actualOffset == offset and day == current.monthDay)
        return events[index]
    end,
}
CreateFrame = function()
    local frame = { events = {} }
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:SetScript(_, callback) self.callback = callback end
    frames[#frames + 1] = frame
    return frame
end
dofile("YiboTodo/Namespace.lua")
local Addon = YiboTodo
Addon.Now = function() return clock end
Addon.NotifyChanged = function() notifications = notifications + 1 end
dofile("YiboTodo/Model/Schedule.lua")
dofile("YiboCore/_NonRelease/Tests/LoadCalendar.lua")
dofile("YiboTodo/Mists/Darkmoon.lua")
local darkmoon = Addon.Darkmoon
darkmoon:Initialize()
darkmoon:Initialize()
assert(requests == 1 and #frames == 1, "initialize and request only once")
assert(darkmoon.IsOpen(clock) == nil, "an unsynchronized empty calendar is unknown")
assert(requests == 1, "snapshot queries do not flood calendar requests")
events = { { title = "Darkmoon Faire" } }
frames[1].callback(nil, "CALENDAR_UPDATE_EVENT_LIST")
assert(notifications == 1 and darkmoon.IsOpen(clock) == true, "sync restores the event after Thursday maintenance")
viewed, offset = { year = 2027, month = 1 }, -3
assert(darkmoon.IsOpen(clock) == true, "browsing across a year does not close the fair")
viewed, offset = { year = 2026, month = 9 }, 1
assert(darkmoon.IsOpen(clock) == true, "browsing an earlier month does not close the fair")
events = { { title = "暗月马戏团" } }
assert(darkmoon.IsOpen(clock) == true)
-- The user's closing Sunday remains visible when the realm calendar lists it.
current.monthDay, current.weekday = 25, 1
clock = clock + 3 * 86400
assert(darkmoon.IsOpen(clock) == true and requests == 2, "Sunday visibility follows the realm calendar")
events = {}
assert(darkmoon.IsOpen(clock) == nil, "yesterday's sync cannot confirm today's empty data")
frames[1].callback(nil, "CALENDAR_UPDATE_EVENT_LIST")
assert(darkmoon.IsOpen(clock) == false, "a synced empty day confirms closure")
events = { false }
assert(darkmoon.IsOpen(clock) == nil, "partial calendar records are unknown")
frames[1].callback(nil, "PLAYER_ENTERING_WORLD")
assert(requests == 3 and darkmoon.IsOpen(clock) == nil, "world entry requests fresh data")
C_Calendar = nil
assert(darkmoon.IsOpen(clock) == nil, "missing calendar cannot invent a monthly schedule")
print("YiboTodo Darkmoon calendar smoke passed")
