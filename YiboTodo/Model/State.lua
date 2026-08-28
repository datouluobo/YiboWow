local Addon = _G.YiboTodo
local State = {}
Addon.Model.State = State

State.Labels = { actionable = "可制作", cooldown = "冷却中", estimated = "预计可用", locked = "未学习", unknown = "待确认", ["not-applicable"] = "不适用" }

local function CrossedDailyReset(observedAt, now, hour)
    observedAt, now = tonumber(observedAt) or 0, tonumber(now) or Addon:Now()
    hour = tonumber(hour) or 7
    -- GetGameTime is the client API that exposes the realm clock.  The
    -- timestamp itself remains the canonical persistence value; this only
    -- derives today's realm reset boundary for a previously confirmed recipe.
    local currentHour, currentMinute = GetGameTime and GetGameTime()
    if currentHour == nil then
        local localTime = date("*t", now)
        currentHour, currentMinute = localTime.hour, localTime.min
    end
    local todayStart = now - ((tonumber(currentHour) or 0) * 3600 + (tonumber(currentMinute) or 0) * 60)
    local resetAt = todayStart + hour * 3600
    if now < resetAt then resetAt = resetAt - 86400 end
    return observedAt < resetAt and resetAt <= now
end

function State:Evaluate(group, observation, now)
    now = tonumber(now) or Addon:Now()
    if not observation or observation.sourceState ~= "known" then return { state = "unknown", confidence = "unknown" } end
    local learned, ready, cooling, expiredSinceScan = 0, 0, 0, false
    for _, recipe in ipairs(group.members or {}) do
        local value = observation.recipes and observation.recipes[recipe.recipeSpellID]
        if value and value.learned then
            learned = learned + 1
            if value.cooldownKnown then
                local readyAt = tonumber(value.readyAt) or 0
                if readyAt > now then
                    cooling = cooling + 1
                else
                    ready = ready + 1
                    -- A zero cooldown in the just-completed scan is confirmed
                    -- actionable.  Only a cooldown that expired after its own
                    -- observation becomes the deliberately weaker estimate.
                    expiredSinceScan = expiredSinceScan or readyAt > (tonumber(observation.observedAt) or 0)
                end
            end
        end
    end
    if learned == 0 then return { state = "locked", confidence = "confirmed" } end
    if cooling > 0 and ready > 0 then return { state = "unknown", confidence = "unknown", diagnostic = "group-conflict" } end
    if group.resetKind == "daily-07" and CrossedDailyReset(observation.observedAt, now, group.resetHour) then
        return { state = "estimated", confidence = "estimated", resetAt = true }
    end
    if cooling > 0 then
        local nearest
        for _, recipe in ipairs(group.members or {}) do local item = observation.recipes[recipe.recipeSpellID]; if item and item.readyAt and (not nearest or item.readyAt < nearest) then nearest = item.readyAt end end
        return { state = "cooldown", confidence = "confirmed", readyAt = nearest }
    end
    if expiredSinceScan then return { state = "estimated", confidence = "estimated" } end
    if ready > 0 then return { state = "actionable", confidence = "confirmed" } end
    return { state = "unknown", confidence = "unknown" }
end
