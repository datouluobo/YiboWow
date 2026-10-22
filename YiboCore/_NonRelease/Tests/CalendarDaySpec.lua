local checks = 0
local function Check(value, label) checks = checks + 1; assert(value, label) end
_G.YiboCore = {}
dofile("YiboCore/Runtime/Capabilities.lua")
dofile("YiboCore/Mists/Calendar.lua")
local calendar = YiboCore.Calendar
local viewed = { year = 2021, month = 11 }
local real = { year = 2026, month = 10, monthDay = 22, weekday = 5 }
C_DateAndTime = { GetCurrentCalendarTime = function() return real end }
local repairs, queries, failRepair = 0, {}, false
local titles = { "暗月马戏团", "万圣节", "Other event" }
local reentrant
C_Calendar = {
    GetMonthInfo = function() return { year = viewed.year, month = viewed.month } end,
    SetAbsMonth = function(month, year)
        repairs = repairs + 1
        reentrant = calendar:ReadDay()
        if not failRepair then viewed = { year = year, month = month } end
    end,
    GetNumDayEvents = function(offset, day)
        queries[#queries + 1] = offset
        assert(day == 22)
        -- Exact client evidence: 59 months returns a successful zero.
        if math.abs(offset) > 12 then return 0 end
        return #titles
    end,
    GetDayEvent = function(_, _, index) return { title = titles[index], eventID = index } end,
}
Check(C_Calendar.GetNumDayEvents(59, 22) == 0, "client reproducer returns zero")
local result = calendar:ReadDay()
Check(result.state == "ready" and #result.events == 3, "stale 2021 anchor recovers all current events")
Check(result.originalOffset == 59 and result.repairedAnchor, "records the actual repair")
Check(viewed.year == 2026 and viewed.month == 10 and repairs == 1, "invalid global anchor is repaired")
Check(reentrant.state == "unknown", "reentrant calendar events cannot read partial state")
Check(queries[#queries] == 0, "reads absolute current month after repair")
calendar:ReadDay()
Check(repairs == 1, "repeated reads do not change the calendar")
result.events[1].title = "tampered"
Check(calendar:ReadDay().events[1].title == titles[1], "query results are isolated")
viewed = { year = 2027, month = 1 }
result = calendar:ReadDay()
Check(result.state == "ready" and result.originalOffset == -3 and repairs == 1, "normal browsing is preserved")
viewed, failRepair = { year = 2021, month = 11 }, true
Check(calendar:ReadDay().state == "unknown", "failed anchor repair cannot mean closure")
failRepair = false
C_Calendar.SetAbsMonth = function() error("unavailable") end
Check(calendar:ReadDay().state == "unknown" and not calendar.reading, "API exception clears reentrancy guard")
C_Calendar.SetAbsMonth = nil
Check(calendar:ReadDay().state == "unknown", "missing absolute-month API stops unsafe query")
viewed = { year = 2026, month = 10 }
C_Calendar.GetDayEvent = function() return nil end
Check(calendar:ReadDay().state == "unknown", "partial data cannot mean closure")
titles = {}
Check(calendar:ReadDay().state == "ready" and #calendar:ReadDay().events == 0, "valid empty day remains a fact for the consumer")
C_Calendar.GetNumDayEvents = function() error("not ready") end
Check(calendar:ReadDay().state == "unknown", "unready calendar cannot mean closure")
Check(YiboCore:HasCapability("calendar-day-query", 1), "minimum capability is published")
real = { year = 1999, month = 0, monthDay = 0, weekday = 0 }
local repairCount = repairs
Check(calendar:GetCurrentDate() == nil, "startup sentinel date is not a realm date")
Check(calendar:ReadDay().state == "unknown" and repairs == repairCount, "startup sentinel cannot trigger anchor repair")
real = { year = 2026, month = 10, monthDay = 22, weekday = 5 }
C_Calendar.GetNumDayEvents = function() return 0 end
Check(calendar:ReadDay().state == "ready", "realm date becomes usable after native initialization")
print("CalendarDaySpec: " .. checks .. " checks passed")
