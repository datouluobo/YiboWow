local YQB = _G.YQB
local Core = _G.YiboCore

function YQB.RememberQuestName(id, title)
    if not title then return end
    local db = YQB.GetDatabase()
    db.globalCache[id] = title
    local character = db.characterData[YQB.GetCurrentCharacterID()]
    if character and character.cache then character.cache[id] = title end
end

function YQB.GetQuestName(id)
    local db = YQB.GetDatabase()
    local character = db.characterData[YQB.GetCurrentCharacterID()]
    local title = db.globalCache[id] or (character and character.cache and character.cache[id])
    if type(title) == "table" then title = title.title end
    return title or YQB.ReadQuestTitle(id)
end

function YQB.GetBlockedQuestList()
    local db = YQB.GetDatabase()
    local rows, seen = {}, {}
    for id in pairs(db.globalBlocked) do
        rows[#rows + 1] = { id = id, name = YQB.GetQuestName(id) }
        seen[id] = true
    end
    for _, character in pairs(db.characterData) do
        for id in pairs(character.blocked or {}) do
            if not seen[id] then
                local title = character.cache and character.cache[id]
                if type(title) == "table" then title = title.title end
                rows[#rows + 1] = { id = id, name = title or YQB.GetQuestName(id) }
                seen[id] = true
            end
        end
    end
    table.sort(rows, function(a, b) return a.id < b.id end)
    return rows
end

local function PassesFilter(row, filter)
    if row.isComplete and filter.hideComplete then return false end
    if row.isRecurring == true then return filter.showDaily end
    if row.isRecurring == false then return filter.showNormal end
    return filter.showNormal and filter.showDaily
end

function YQB.GetCurrentQuestList()
    local rows, filter = {}, YQB.GetDatabase().filters
    local log, hasCollapsed = YQB.ReadQuestLog()
    for _, row in ipairs(log) do
        if not YQB.IsQuestBlocked(row.id) and PassesFilter(row, filter) then
            rows[#rows + 1] = row
        end
    end
    return rows, hasCollapsed
end

function YQB.RefreshQuestNames()
    for _, row in ipairs(YQB.ReadQuestLog()) do
        if YQB.IsQuestBlocked(row.id) then YQB.RememberQuestName(row.id, row.name) end
    end
end

function YQB.ValidateLevelExpr(expression)
    return Core.LevelFilter:Validate(expression)
end

function YQB.GetLevelFilterExpr()
    return YQB.GetDatabase().filters.levelExpr
end

function YQB.SetLevelFilterExpr(expression)
    local valid, normalized, badToken = YQB.ValidateLevelExpr(expression)
    if not valid then return false, badToken end
    YQB.GetDatabase().filters.levelExpr = normalized
    YQB.NotifyCorePageChanged()
    return true, normalized
end
