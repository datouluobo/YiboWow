local Addon = _G.YiboTodo
local State = {}
Addon.Model.State = State

State.Labels = { actionable = "可制作", cooldown = "冷却中", estimated = "预计可用", ["skill-insufficient"] = "专业技能不足", locked = "未学习", unknown = "待确认", ["not-applicable"] = "不适用" }

function State:Evaluate(group, observation, now, skillLevel)
    now = tonumber(now) or Addon:Now()
    local requiredSkillLevel = tonumber(group.requiredSkillLevel)
    if requiredSkillLevel and tonumber(skillLevel) and tonumber(skillLevel) < requiredSkillLevel then
        return { state = "skill-insufficient", confidence = "profession", requiredSkillLevel = requiredSkillLevel, skillLevel = tonumber(skillLevel) }
    end
    -- Profession ownership only tells us that this character might be able to
    -- craft the item.  It says nothing about the per-character daily lockout,
    -- so it must never be projected as an actionable cooldown.
    if not observation or observation.sourceState ~= "known" then return { state = "unknown", confidence = "unknown" } end
    local learned, craftable, insufficient, ready, cooling, expiredSinceScan, dailyCooldownObserved = 0, 0, 0, 0, 0, false, false
    for _, recipe in ipairs(group.members or {}) do
        local value = observation.recipes and observation.recipes[recipe.recipeSpellID]
        if value and value.learned then
            learned = learned + 1
            if value.craftable == false then
                insufficient = insufficient + 1
            else
                craftable = craftable + 1
            end
            if value.craftable ~= false and value.cooldownKnown then
                local readyAt = tonumber(value.readyAt) or 0
                if group.resetKind == "daily-07" and readyAt > (tonumber(observation.observedAt) or 0) then
                    dailyCooldownObserved = true
                end
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
    -- Keep the visual state as unknown: the marker continues to mean that
    -- this project is not actionable.  The reason lets the UI explain the
    -- specific, confirmed case of an unlearned recipe without adding a new
    -- state or icon treatment.
    if learned == 0 then return { state = "unknown", confidence = "unknown", reason = "recipe-unlearned" } end
    -- A shared-cooldown group is unavailable only when every observed learned
    -- member is below its recipe skill requirement. One craftable alternative
    -- remains actionable/cooling according to its own cooldown observation.
    if craftable == 0 and insufficient > 0 then
        return { state = "skill-insufficient", confidence = "confirmed", requiredSkillLevel = requiredSkillLevel, skillLevel = tonumber(skillLevel) }
    end
    if cooling > 0 and ready > 0 then return { state = "unknown", confidence = "unknown", diagnostic = "group-conflict" } end
    if group.resetKind == "daily-07" and Addon.Model.Schedule:CrossedReset(observation.observedAt, now, group.resetHour) then
        return { state = "estimated", confidence = "estimated", resetAt = true }
    end
    -- Some MoP clients report a daily profession cooldown as a countdown to
    -- midnight even though the configured server reset is 07:00.  Once the
    -- scan has confirmed that a daily recipe entered cooldown, do not turn it
    -- actionable before that server reset merely because this API countdown
    -- expired early.
    if group.resetKind == "daily-07" and dailyCooldownObserved then
        return { state = "cooldown", confidence = "confirmed", readyAt = Addon.Model.Schedule:NextResetAt(now, group.resetHour) }
    end
    if cooling > 0 then
        local nearest
        for _, recipe in ipairs(group.members or {}) do local item = observation.recipes[recipe.recipeSpellID]; if item and item.readyAt and (not nearest or item.readyAt < nearest) then nearest = item.readyAt end end
        return { state = "cooldown", confidence = "confirmed", readyAt = nearest }
    end
    if expiredSinceScan then return { state = "estimated", confidence = "estimated" } end
    if ready > 0 then return { state = "actionable", confidence = "confirmed" } end
    return { state = "actionable", confidence = "profession" }
end
