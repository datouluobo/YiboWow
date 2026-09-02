local Addon = _G.YiboTodo
local Schedule = {}
Addon.Model.Schedule = Schedule

function Schedule:ReadyAt(observedAt, remaining)
    return (tonumber(observedAt) or 0) + math.max(0, tonumber(remaining) or 0)
end

function Schedule:RealmClock(now)
    local hour, minute
    if GetGameTime then hour, minute = GetGameTime() end
    if hour == nil then
        local localTime = date("*t", now)
        hour, minute = localTime.hour, localTime.min
    end
    return tonumber(hour) or 0, tonumber(minute) or 0
end

function Schedule:CurrentResetAt(now, hour)
    now, hour = tonumber(now) or Addon:Now(), tonumber(hour) or 7
    local currentHour, currentMinute = self:RealmClock(now)
    local todayStart = now - currentHour * 3600 - currentMinute * 60
    local resetAt = todayStart + hour * 3600
    if now < resetAt then resetAt = resetAt - 86400 end
    return resetAt
end

function Schedule:NextResetAt(now, hour)
    return self:CurrentResetAt(now, hour) + 86400
end

function Schedule:CrossedReset(observedAt, now, hour)
    observedAt, now = tonumber(observedAt) or 0, tonumber(now) or Addon:Now()
    local resetAt = self:CurrentResetAt(now, hour)
    return observedAt < resetAt and resetAt <= now
end

function Schedule:ServerDay(now, hour)
    return date("%Y-%m-%d", self:CurrentResetAt(now, hour))
end
