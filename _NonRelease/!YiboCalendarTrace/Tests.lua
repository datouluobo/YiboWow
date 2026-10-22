local checks = 0
local function Check(value, label) checks = checks + 1; assert(value, label) end
local month, year, calls, hooks, time = 11, 2021, 0, 0, 0
local caller = "Interface/AddOns/Questie/Database/Corrections/Holidays/QuestieEvent.lua:144"
GetTime = function() time = time + 0.1; return time end
GetServerTime = function() return 1792641600 end
GetLocale = function() return "zhCN" end
debugstack = function() return caller .. ": in function 'Initialize'\nInterface/AddOns/!YiboCalendarTrace/Trace.lua:1" end
local realmDate = { year = 2026, month = 10, monthDay = 22 }
C_DateAndTime = { GetCurrentCalendarTime = function() return realmDate end }
C_Calendar = {
    OpenCalendar = function() return "requested" end,
    GetMonthInfo = function() return { year = year, month = month } end,
    SetMonth = function(offset) calls = calls + 1; month = month + offset; return 37, nil, "sentinel" end,
    SetAbsMonth = function(m, y) calls = calls + 1; month, year = m, y; return 37, nil, "sentinel" end,
}
local function Pack(...) return { n = select("#", ...), ... } end
hooksecurefunc = function(api, name, hook)
    hooks = hooks + 1
    local original = api[name]
    api[name] = function(...)
        local values = Pack(original(...))
        hook(...)
        return unpack(values, 1, values.n)
    end
end
local frames, messages = {}, {}
CreateFrame = function()
    local f = { events = {} }
    function f:RegisterEvent(name) self.events[name] = true end
    function f:SetScript(_, callback) self.callback = callback end
    frames[#frames + 1] = f
    return f
end
SlashCmdList = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, value) messages[#messages + 1] = value end }
YiboCalendarTraceDB = { sessions = { { id = 1 }, { id = 2 }, { id = 3 } } }
local function Load() assert(loadfile("_NonRelease/!YiboCalendarTrace/Trace.lua"))("!YiboCalendarTrace") end
Load()
Check(calls == 0, "installing the probe does not change the calendar")
Check(hooks == 3 and #frames == 1, "both mutation methods and opening hooked once")
Load()
Check(hooks == 3 and #frames == 1, "repeated load does not duplicate hooks or frames")
frames[1].callback(nil, "ADDON_LOADED", "!YiboCalendarTrace")
local session = YiboCalendarTraceDB.sessions[3]
Check(#YiboCalendarTraceDB.sessions == 3 and YiboCalendarTraceDB.sessions[1].id == 2, "bounded sessions retain newest history")
Check(session.rows[1].kind == "probe-load" and session.rows[1].after == "2021-11", "initial uninitialized anchor recorded without attribution")
local a, b, c = C_Calendar.SetMonth(0)
local row = session.rows[#session.rows]
Check(a == 37 and b == nil and c == "sentinel", "post-hook preserves original multiple return values")
Check(row.kind == "SetMonth" and row.arg1 == 0 and row.offset == 59, "method arguments and anomaly captured")
Check(row.origin:find("Questie", 1, true) and row.stack:find("Initialize", 1, true), "caller location and stack captured")
Check(row.previousObserved == row.after, "a no-op on an already bad anchor is not labeled as its first change")
Check(C_Calendar.OpenCalendar() == "requested" and session.rows[#session.rows].kind == "OpenCalendar", "native calendar requests also have attributable observations")
caller = "Interface/AddOns/MountsJournal/components/Calendar.lua:191"
C_Calendar.SetAbsMonth(10, 2026)
caller = "Interface/AddOns/MountsJournal/components/Calendar.lua:55"
C_Calendar.SetAbsMonth(11, 2021)
row = session.rows[#session.rows]
Check(row.previousObserved == "2026-10" and row.after == "2021-11", "restoring a stale anchor is visible")
Check(row.arg1 == 11 and row.arg2 == 2021 and row.origin:find(":55", 1, true), "restoring call site remains distinct")
year, month = 2020, 2
frames[1].callback(nil, "ADDON_LOADED", "CachedReferenceAddon")
row = session.rows[#session.rows]
Check(row.kind == "ADDON_LOADED" and row.origin == "unknown", "unhooked changes are recorded without invented attribution")
for i = 1, 220 do C_Calendar.SetMonth(0) end
Check(#session.rows == 180 and session.lastSeq > 220, "bounded rows preserve global ordering")
Check(session.initial.after == "2021-11" and session.firstAbnormalCall.origin:find("Questie", 1, true), "initial and first abnormal calls survive ring eviction")
Check(session.firstObservedCrossing.origin:find("MountsJournal", 1, true) and session.firstRepairCall ~= nil, "first observed crossing and repair remain pinned")
SlashCmdList.YIBOCALENDARTRACE("mark")
Check(session.rows[#session.rows].kind == "manual-mark", "manual marker does not change the calendar")
SlashCmdList.YIBOCALENDARTRACE("")
Check(#messages >= 3 and SLASH_YIBOCALENDARTRACE1 == "/ycm", "three-letter command reports status")
debugstack = function() error("unavailable") end
Check(pcall(C_Calendar.SetMonth, 0), "diagnostic stack errors cannot break the caller")
realmDate = { year = 1999, month = 0, monthDay = 0 }
SlashCmdList.YIBOCALENDARTRACE("mark")
row = session.rows[#session.rows]
Check(row.realmReady == false and row.realmRaw == "1999-00-00", "startup sentinel preserved as raw unavailable data")
Check(row.offset == nil and row.previousObservedOffset == nil, "invalid realm date cannot create anomaly offsets")
print("CalendarTrace: " .. checks .. " checks passed")
