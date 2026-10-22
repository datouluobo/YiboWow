local Core = _G.YiboCore
local Calendar = { reading = false }
Core.Calendar = Calendar

function Calendar:IsReading()
    return self.reading
end

function Calendar:GetCurrentDate(now)
    if C_DateAndTime and type(C_DateAndTime.GetCurrentCalendarTime) == "function" then
        local ok, value = pcall(C_DateAndTime.GetCurrentCalendarTime)
        if ok and type(value) == "table" then
            local year, month, day, weekday = tonumber(value.year), tonumber(value.month), tonumber(value.monthDay), tonumber(value.weekday)
            if year and year >= 1 and month and month >= 1 and month <= 12 and day and day >= 1 and day <= 31
                and (not weekday or weekday >= 1 and weekday <= 7) then
                return { year = year, month = month, day = day, wday = weekday }
            end
        end
        -- During addon loading the client can return 1999-00-00. This is
        -- not an authoritative realm date and must not trigger anchor repair.
        return nil
    end
    local value = date and date("*t", now or (GetServerTime and GetServerTime()) or time())
    if type(value) == "table" then return value end
end

-- This API returns raw calendar facts; event identity and business periods
-- remain with the owner. Never interpret a failed query as a closed holiday.
function Calendar:ReadDay()
    if self.reading then return { state = "unknown", reason = "reading" } end
    local today = self:GetCurrentDate()
    local api = C_Calendar
    if not today or not api or type(api.GetMonthInfo) ~= "function"
        or type(api.GetNumDayEvents) ~= "function" or type(api.GetDayEvent) ~= "function" then
        return { state = "unknown", reason = "unavailable" }
    end
    self.reading = true
    local ok, result = pcall(function()
        local viewed = api.GetMonthInfo(0)
        if type(viewed) ~= "table" or not viewed.year or not viewed.month then
            return { state = "unknown", reason = "month" }
        end
        local offset = (today.year - viewed.year) * 12 + today.month - viewed.month
        local originalOffset = offset
        -- Keep ordinary browsing intact. Do not trust multi-year relative
        -- queries: the client can return a successful but empty result.
        -- Repair this stale global anchor rather than restoring it afterwards.
        if math.abs(offset) > 12 then
            if type(api.SetAbsMonth) ~= "function" then return { state = "unknown", reason = "anchor" } end
            api.SetAbsMonth(today.month, today.year)
            viewed = api.GetMonthInfo(0)
            if type(viewed) ~= "table" or viewed.year ~= today.year or viewed.month ~= today.month then
                return { state = "unknown", reason = "anchor" }
            end
            offset = 0
        end
        local count = tonumber(api.GetNumDayEvents(offset, today.day))
        if not count or count < 0 then return { state = "unknown", reason = "count" } end
        local events = {}
        for index = 1, count do
            local event = api.GetDayEvent(offset, today.day, index)
            if type(event) ~= "table" or type(event.title) ~= "string" or event.title == "" then
                return { state = "unknown", reason = "partial" }
            end
            -- Copy public facts, never return the client's internal table.
            events[#events + 1] = { title = event.title, eventID = event.eventID,
                calendarType = event.calendarType, sequenceType = event.sequenceType }
        end
        return { state = "ready", date = today, events = events, originalOffset = originalOffset,
            repairedAnchor = originalOffset ~= offset }
    end)
    self.reading = false
    if not ok then return { state = "unknown", reason = "query" } end
    return result
end

Core.Capabilities:Register("calendar-day-query", 1)
