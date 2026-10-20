local Addon = _G.YiboTodo

local function RealmDate(now)
    if C_DateAndTime and type(C_DateAndTime.GetCurrentCalendarTime) == "function" then
        local ok, current = pcall(C_DateAndTime.GetCurrentCalendarTime)
        if ok and current and current.year and current.month and current.monthDay and current.weekday then
            return { year = current.year, month = current.month, day = current.monthDay, wday = current.weekday }
        end
    end
    return date and date("*t", now)
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
    local function ScheduledThisWeek()
        -- Darkmoon opens on the first Sunday of each month and closes at the
        -- end of the following Saturday. Calendar data is preferred, but some
        -- clients do not populate C_Calendar until its UI is opened.
        local first = date("*t", time({ year = today.year, month = today.month, day = 1, hour = 12 }))
        if not first then return nil end
        local firstSunday = 1 + ((8 - tonumber(first.wday or 1)) % 7)
        return today.day >= firstSunday and today.day <= firstSunday + 6
    end
    if not (C_Calendar and type(C_Calendar.GetNumDayEvents) == "function" and type(C_Calendar.GetDayEvent) == "function") then return ScheduledThisWeek() end
    local ok, count = pcall(C_Calendar.GetNumDayEvents, 0, today.day)
    if not ok then return ScheduledThisWeek() end
    for index = 1, tonumber(count) or 0 do
        local eventOK, event = pcall(C_Calendar.GetDayEvent, 0, today.day, index)
        local title = eventOK and event and string.lower(tostring(event.title or "")) or ""
        if string.find(title, "暗月", 1, true) or string.find(title, "darkmoon", 1, true) then return true end
    end
    return false
end

Addon.Darkmoon = { EventPeriod = EventPeriod, EventObservation = EventObservation, IsOpen = IsDarkmoonOpen }
