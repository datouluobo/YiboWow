-- Actual Core calendar + both production consumers, using the 2026-10-22 trace.
local checks = 0
local function Check(value, label) checks = checks + 1; assert(value, label) end
time, date = os.time, os.date
GetServerTime = function() return os.time({ year = 2026, month = 10, day = 22, hour = 12 }) end
C_DateAndTime = { GetCurrentCalendarTime = function()
    return { year = 2026, month = 10, monthDay = 22, weekday = 5 }
end }
YiboCore = { Locale = { Get = function(_, _, key) return key end } }
YAB = { CoreReady = true }
dofile("YiboCore/_NonRelease/Tests/LoadCalendar.lua")
dofile("YiboAltoBoss/HolidayBoss.lua")
dofile("YiboTodo/Namespace.lua")
dofile("YiboTodo/Mists/Darkmoon.lua")
local viewed, repairs, fail = { year = 2021, month = 11 }, 0, false
local titles = { "暗月马戏团", "万圣节", "Other event" }
C_Calendar = {
    GetMonthInfo = function() return viewed end,
    SetAbsMonth = function(month, year)
        repairs = repairs + 1
        if not fail then viewed = { year = year, month = month } end
    end,
    GetNumDayEvents = function(offset)
        if math.abs(offset) > 12 then return 0 end
        return #titles
    end,
    GetDayEvent = function(_, _, index) return { title = titles[index] } end,
}
local horseman = "holiday:headless-horseman"
local function Open()
    return YAB.Holiday:GetTargetSnapshot("offline", horseman).availability
end
Check(C_Calendar.GetNumDayEvents(59) == 0, "raw query reproduces incorrect zero")
Check(YiboTodo.Darkmoon.IsOpen(GetServerTime()) == true, "Todo repairs 59-month anchor")
Check(Open() == "open", "AltoBoss shares the corrected calendar")
Check(repairs == 1, "second consumer does not repeat repair")
viewed = { year = 2021, month = 11 }
Check(Open() == "open", "AltoBoss repairs a later external anchor change")
Check(YiboTodo.Darkmoon.IsOpen(GetServerTime()) == true, "Todo remains open after AltoBoss read")
Check(repairs == 2, "one repair per external corruption")
viewed, fail = { year = 2021, month = 11 }, true
Check(Open() == "unknown", "failed repair cannot close a holiday goal")
Check(YiboTodo.Darkmoon.IsOpen(GetServerTime()) == nil, "failed repair is unknown in Todo")
fail = false
Check(Open() == "open", "the same session recovers after repair becomes available")
-- Missing capability must stop initialization before consumer registration.
local function Methods() return setmetatable({}, { __index = function() return function() return true end end }) end
local core = { Calendar = Methods(), Locale = Methods(), Characters = Methods(), UITheme = Methods(),
    AccountView = Methods(), Entry = Methods(), CharacterCleanup = Methods(), LevelFilter = Methods(),
    ItemConfirmation = Methods(), CheckAPIVersion = function() return true end,
    IsInitialized = function() return true end,
    HasCapability = function(_, name) return name ~= "calendar-day-query" end }
YiboCore = core
dofile("YiboAltoBoss/CoreRequirements.lua")
Check(YAB.CoreReady == false, "AltoBoss stops with old Core")
dofile("YiboTodo/CoreIntegration.lua")
Check(YiboTodo.CoreIntegration:Initialize() == nil, "Todo stops with old Core")
print("CalendarAnchor consumers: " .. checks .. " checks passed")
