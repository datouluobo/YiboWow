local YAB = _G.YAB
if YAB and YAB.CoreReady == false then return end
YAB.Calendar = {}

function YAB.Calendar:IsOpen(boss, syncedDay)
    local calendar = _G.YiboCore and _G.YiboCore.Calendar
    if not calendar then return false, false end
    local snapshot = calendar:ReadDay()
    if snapshot.state ~= "ready" then return false, false end
    for _, event in ipairs(snapshot.events) do
        local title = string.lower(event.title)
        for _, alias in ipairs(boss.eventTitleAliases or {}) do
            local normalized = string.lower(tostring(alias))
            if normalized ~= "" and string.find(title, normalized, 1, true) then return true, true end
        end
    end
    local d = snapshot.date
    local today = string.format("%04d-%02d-%02d", d.year, d.month, d.day)
    return false, #snapshot.events > 0 or syncedDay == today
end

function YAB.Calendar:DayKey()
    local calendar = _G.YiboCore and _G.YiboCore.Calendar
    local d = calendar and calendar:GetCurrentDate()
    return d and string.format("%04d-%02d-%02d", d.year, d.month, d.day)
end
