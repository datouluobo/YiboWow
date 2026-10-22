-- Independent, early-load diagnostic. No dependency on Core or business addons.
-- Post-hooks observe calls without replacing APIs or changing calendar state.
local addonName = ... or "!YiboCalendarTrace"
if _G.YiboCalendarTraceInstalled then return end
_G.YiboCalendarTraceInstalled = true
local rows, session, seq, lastMonth = {}, nil, 0, nil
local hooked = {}
local ROW_LIMIT, SESSION_LIMIT = 180, 3
local language = GetLocale and GetLocale() or "enUS"
local chinese = language == "zhCN" or language == "zhTW"
local resources = {
    STATUS = { "日历追踪：会话记录 %d 条；SetMonth=%s，SetAbsMonth=%s，OpenCalendar=%s。", "Calendar trace: %d session records; SetMonth=%s, SetAbsMonth=%s, OpenCalendar=%s." },
    ROW = { "%s | %s → %s | %s", "%s | %s -> %s | %s" },
    SAVE = { "记录在重载或正常退出后写入 !YiboCalendarTrace.lua。", "Records are saved to !YiboCalendarTrace.lua after reload or normal exit." },
    MARK = { "已记录当前日历状态。", "Current calendar state recorded." },
}
local function Print(key, ...)
    local message = string.format(resources[key][chinese and 1 or 2], ...)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff20e070[Yibo]|r " .. message) end
end
local function Month()
    if not (C_Calendar and C_Calendar.GetMonthInfo) then return nil end
    local ok, m = pcall(C_Calendar.GetMonthInfo, 0)
    if ok and type(m) == "table" and m.year and m.month then
        return string.format("%04d-%02d", m.year, m.month), tonumber(m.year), tonumber(m.month)
    end
end
local function Realm()
    if not (C_DateAndTime and C_DateAndTime.GetCurrentCalendarTime) then return nil end
    local ok, d = pcall(C_DateAndTime.GetCurrentCalendarTime)
    if ok and type(d) == "table" and d.year and d.month and d.monthDay then
        local raw = string.format("%04d-%02d-%02d", d.year, d.month, d.monthDay)
        local y, m, day = tonumber(d.year), tonumber(d.month), tonumber(d.monthDay)
        if y and y >= 1 and m and m >= 1 and m <= 12 and day and day >= 1 and day <= 31 then
            return raw, y, m, raw
        end
        return nil, nil, nil, raw
    end
end
local function Stack()
    if not debugstack then return "" end
    local ok, value = pcall(debugstack, 3, 14, 14)
    return ok and string.sub(tostring(value), 1, 3500) or ""
end
local function Origin(stack)
    for line in string.gmatch(stack or "", "[^\n]+") do
        if string.find(line, "AddOns", 1, true) and not string.find(line, "!YiboCalendarTrace", 1, true) then
            return string.sub(line, 1, 250)
        end
    end
    return "unknown"
end
local function Pin(row)
    if not session then return end
    session.initial = session.initial or row
    if row.offset and math.abs(row.offset) > 12 then
        session.firstAbnormalObservation = session.firstAbnormalObservation or row
        if row.kind == "SetMonth" or row.kind == "SetAbsMonth" or row.kind == "OpenCalendar" then
            session.firstAbnormalCall = session.firstAbnormalCall or row
        end
    end
    if row.offset and row.previousObservedOffset
        and (row.kind == "SetMonth" or row.kind == "SetAbsMonth" or row.kind == "OpenCalendar") then
        if math.abs(row.offset) > 12 and math.abs(row.previousObservedOffset) <= 12 then
            session.firstObservedCrossing = session.firstObservedCrossing or row
        elseif math.abs(row.offset) <= 12 and math.abs(row.previousObservedOffset) > 12 then
            session.firstRepairCall = session.firstRepairCall or row
        end
    end
end
local function Record(kind, first, second, withStack)
    local after, year, month = Month()
    local realm, realmYear, realmMonth, realmRaw = Realm()
    seq = seq + 1
    local stack = withStack and Stack() or ""
    local offset = year and realmYear and ((realmYear - year) * 12 + realmMonth - month)
    local previousYear, previousMonth = string.match(lastMonth or "", "^(%d+)%-(%d+)$")
    local previousOffset = previousYear and realmYear and ((realmYear - tonumber(previousYear)) * 12 + realmMonth - tonumber(previousMonth))
    local row = { seq = seq, kind = kind, arg1 = first, arg2 = second,
        at = GetServerTime and GetServerTime(), elapsed = GetTime and GetTime(),
        realm = realm, realmRaw = realmRaw, realmReady = realm ~= nil,
        previousObserved = lastMonth, previousObservedOffset = previousOffset, after = after, offset = offset,
        stack = stack, origin = Origin(stack) }
    -- previousObserved is NOT an intercepted before-state. An API reference
    -- cached before the hooks were installed can escape observation.
    rows[#rows + 1] = row
    while #rows > ROW_LIMIT do table.remove(rows, 1) end
    lastMonth = after
    if session then session.lastSeq, session.lastMonth = seq, after end
    Pin(row)
end
local function SafeRecord(...)
    -- Diagnostics must not propagate an error into the observed addon.
    pcall(Record, ...)
end
local function InstallHooks()
    if not (C_Calendar and hooksecurefunc) then return end
    for _, method in ipairs({ "SetMonth", "SetAbsMonth", "OpenCalendar" }) do
        if not hooked[method] and type(C_Calendar[method]) == "function" then
            local name = method
            local ok = pcall(hooksecurefunc, C_Calendar, name, function(first, second)
                SafeRecord(name, first, second, true)
            end)
            hooked[name] = ok or nil
        end
    end
end
local loadedBeforeHooks = {}
local isLoaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
for _, name in ipairs({ "AllTheThings", "DataStore_Agenda", "MountsJournal", "Questie", "SilverDragon", "HandyNotes_MistsOfPandariaTreasures" }) do
    if isLoaded then
        local ok, loaded = pcall(isLoaded, name)
        loadedBeforeHooks[name] = ok and (loaded == true) or false
    end
end
InstallHooks()
SafeRecord("probe-load")
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("CALENDAR_UPDATE_EVENT_LIST")
frame:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and name == addonName then
        local db = type(_G.YiboCalendarTraceDB) == "table" and _G.YiboCalendarTraceDB or {}
        _G.YiboCalendarTraceDB = db
        db.schemaVersion = 1
        db.sessions = type(db.sessions) == "table" and db.sessions or {}
        session = { startedAt = GetServerTime and GetServerTime(), rows = rows, version = "0.1.1",
            loadedBeforeHooks = loadedBeforeHooks }
        db.sessions[#db.sessions + 1] = session
        while #db.sessions > SESSION_LIMIT do table.remove(db.sessions, 1) end
        for _, row in ipairs(rows) do Pin(row) end
        InstallHooks()
        SafeRecord("probe-ready")
    elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        InstallHooks()
        SafeRecord(event)
    elseif event == "ADDON_LOADED" or event == "CALENDAR_UPDATE_EVENT_LIST" then
        local observed = Month()
        if observed ~= lastMonth then SafeRecord(event, name) end
    end
end)
SLASH_YIBOCALENDARTRACE1 = "/ycm"
SlashCmdList.YIBOCALENDARTRACE = function(message)
    if string.match(message or "", "^%s*mark%s*$") then
        SafeRecord("manual-mark")
        Print("MARK")
        return
    end
    Print("STATUS", #rows, tostring(hooked.SetMonth == true), tostring(hooked.SetAbsMonth == true), tostring(hooked.OpenCalendar == true))
    local shown = 0
    for index = #rows, 1, -1 do
        local row = rows[index]
        if row.kind == "SetMonth" or row.kind == "SetAbsMonth" or row.offset and math.abs(row.offset) > 12 then
            Print("ROW", row.kind, row.previousObserved or "?", row.after or "?", row.origin)
            shown = shown + 1
            if shown == 5 then break end
        end
    end
    Print("SAVE")
end
