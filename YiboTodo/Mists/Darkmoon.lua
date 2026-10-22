local Addon = _G.YiboTodo
local requestedDay, syncedDay
local function DayKey(today)
    return string.format("%04d-%02d-%02d", today.year, today.month, today.day)
end

local function RequestCalendar(today)
    local key = today and DayKey(today)
    if key and requestedDay ~= key and C_Calendar and type(C_Calendar.OpenCalendar) == "function" then
        requestedDay = key
        local ok = pcall(C_Calendar.OpenCalendar)
        if not ok then requestedDay = nil end
    end
end

local function RealmDate(now)
    local calendar = _G.YiboCore and _G.YiboCore.Calendar
    return calendar and calendar:GetCurrentDate(now)
end

local function EventPeriod(now)
    local current = RealmDate(now)
    if type(current) == "table" and tonumber(current.wday) then
        -- Calendar visibility determines whether the Faire is open. Its task
        -- identity is the actual Sunday/Thursday boundary, so two openings in
        -- one month cannot share completion records. Sunday opens at 00:00;
        -- the second task cycle starts at Thursday 07:00, not at midnight.
        local sunday = Addon.Model.Schedule:CurrentResetAt(now, 0) - (current.wday - 1) * 86400
        local thursday = sunday + 4 * 86400 + 7 * 3600
        local startAt = now < thursday and sunday or thursday
        local resetAt = now < thursday and thursday or sunday + 7 * 86400
        return "darkmoon:" .. tostring(startAt), startAt, resetAt
    end
    return tostring(math.floor(now / 604800)), nil, Addon.Model.Schedule:NextResetAt(now, 0)
end

local function EventObservation(record, definition, now)
    local days = record and record.days and record.days[definition.id]
    if not days then return nil end
    local key, startAt = EventPeriod(now)
    -- The realm clock has minute precision and is sampled separately from
    -- GetServerTime. A saved boundary can therefore differ by a minute from
    -- the next observation. Completion time, not exact key equality, decides
    -- whether evidence belongs to the current cycle. Keep saved data intact.
    local latest
    for savedKey, day in pairs(days) do
        local recognized = type(savedKey) == "string" and (savedKey == key
            or string.match(savedKey, "^darkmoon:%d+$")
            or string.match(savedKey, "^%d%d%d%d%-%d%d%-[12]$"))
        if startAt and recognized and type(day) == "table" then
            local completedAt = tonumber(day.completedAt) or tonumber(day.observedAt)
            if day.state == "completed" and completedAt and completedAt >= startAt and completedAt <= now
                and (not latest or completedAt > (tonumber(latest.completedAt) or tonumber(latest.observedAt) or 0)) then
                latest = day
            end
        end
    end
    return latest
end

local function IsDarkmoonOpen(now)
    local today = RealmDate(now)
    if type(today) ~= "table" then return nil end
    RequestCalendar(today)
    local calendar = _G.YiboCore and _G.YiboCore.Calendar
    if not calendar then return nil end
    local snapshot = calendar:ReadDay()
    if snapshot.state ~= "ready" then return nil end
    for _, event in ipairs(snapshot.events) do
        local title = string.lower(event.title)
        if string.find(title, "暗月", 1, true) or string.find(title, "darkmoon", 1, true) then return true end
    end
    if #snapshot.events > 0 or syncedDay == DayKey(today) then return false end
    return nil
end

Addon.Darkmoon = { EventPeriod = EventPeriod, EventObservation = EventObservation, IsOpen = IsDarkmoonOpen }

function Addon.Darkmoon.IsHolidayOpen(definition)
    local calendar = _G.YiboCore and _G.YiboCore.Calendar
    if not definition or not calendar then return nil end
    local snapshot = calendar:ReadDay()
    if snapshot.state ~= "ready" then return nil end
    for _, event in ipairs(snapshot.events) do
        local title = string.lower(event.title)
        for _, alias in ipairs(definition.eventTitleAliases or {}) do
            if title == string.lower(tostring(alias)) then return true end
        end
    end
    if #snapshot.events > 0 or syncedDay == DayKey(snapshot.date) then return false end
end

-- Keep target-specific calendar events and requests in the Mists adapter.
function Addon.Darkmoon:Initialize()
    if self.frame then return end
    local frame = CreateFrame("Frame")
    self.frame = frame
    frame:RegisterEvent("CALENDAR_UPDATE_EVENT_LIST")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:SetScript("OnEvent", function(_, event)
        local today = RealmDate(Addon:Now())
        if not today then return end
        if event == "CALENDAR_UPDATE_EVENT_LIST" then
            if _G.YiboCore.Calendar:IsReading() then return end
            syncedDay = DayKey(today)
        else
            requestedDay, syncedDay = nil, nil
            RequestCalendar(today)
        end
        Addon:NotifyChanged()
    end)
    RequestCalendar(RealmDate(Addon:Now()))
end
