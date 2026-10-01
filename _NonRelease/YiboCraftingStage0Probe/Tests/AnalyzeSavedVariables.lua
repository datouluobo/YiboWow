local path = assert(arg[1], "usage: lua AnalyzeSavedVariables.lua <SavedVariables file>")
local chunk = assert(loadfile(path))
local isolated = {}
setfenv(chunk, isolated)
assert(pcall(chunk), "could not parse probe SavedVariables")
local db = assert(isolated.YiboCraftingStage0DB, "probe database missing")

local function Set(values)
    local result = {}
    for _, id in ipairs(values or {}) do result[id] = true end
    return result
end

local function Difference(left, right)
    local count = 0
    for id in pairs(left) do if not right[id] then count = count + 1 end end
    return count
end

local acrossSessions = {}
for sessionIndex, session in ipairs(db.sessions or {}) do
    print(string.format("session %d: interface=%s, snapshots=%d, events=%d", sessionIndex,
        tostring(session.client and session.client.interface), #(session.snapshots or {}), #(session.events or {})))
    local owned = {}
    local initial = session.snapshots and session.snapshots[1]
    for _, entry in ipairs(initial and initial.professions and initial.professions.entries or {}) do
        if entry.name then owned[#owned + 1] = entry.name .. "(" .. tostring(entry.skillLineID or "?") .. ")" end
    end
    print("  character professions: " .. table.concat(owned, ", "))
    local previous = {}
    for index, snapshot in ipairs(session.snapshots or {}) do
        local context, legacy, modern = snapshot.context or {}, snapshot.legacy or {}, snapshot.modern or {}
        local filters = legacy.filters or {}
        local line = tostring(context.legacyLine or "unknown")
        local current = Set(legacy.recipeIDs)
        local earlier = previous[line]
        local change = earlier and string.format(" +%d/-%d", Difference(current, earlier), Difference(earlier, current)) or " first"
        local headers, emptyGroups = 0, 0
        local activeHeader, hasVisibleRecipe = false, false
        for _, row in ipairs(legacy.rows or {}) do
            if row.difficulty == "header" then
                if activeHeader and not hasVisibleRecipe then emptyGroups = emptyGroups + 1 end
                headers = headers + 1
                activeHeader, hasVisibleRecipe = true, false
            else hasVisibleRecipe = true end
        end
        if activeHeader and not hasVisibleRecipe then emptyGroups = emptyGroups + 1 end
        print(string.format("  %02d %-18s %-12s rows=%s recipeIDs=%s headers=%d emptyGroups=%d modern=%s filter=%s/%s%s",
            index, tostring(snapshot.reason), line, tostring(legacy.rowCount), tostring(legacy.uniqueRecipeCount),
            headers, emptyGroups, tostring(modern.allRecipeIDsError or modern.allCount), tostring(legacy.subClassFilter),
            tostring(legacy.inventoryFilter), change))
        if legacy.filters then
            print(string.format("     filters subclassAll=%s subclassSelected=%d slotAll=%s slotSelected=%d makeable=%s skillUps=%s searchActive=%s expansionUnknown=%s collapsed=%s",
                tostring(filters.subClasses and filters.subClasses.all), #(filters.subClasses and filters.subClasses.checked or {}),
                tostring(filters.inventorySlots and filters.inventorySlots.all), #(filters.inventorySlots and filters.inventorySlots.checked or {}),
                tostring(filters.onlyMakeable), tostring(filters.onlySkillUps),
                tostring(filters.searchText and filters.searchText ~= ""),
                tostring(legacy.unknownExpansionHeaderCount), tostring(legacy.collapsedHeaderCount)))
        end
        previous[line] = current
        if line ~= "UNKNOWN" and not acrossSessions[line] then
            acrossSessions[line] = { session = sessionIndex, ids = current }
        elseif line ~= "UNKNOWN" and acrossSessions[line].session ~= sessionIndex then
            local baseline = acrossSessions[line]
            print(string.format("     vs session %d: only-current=%d only-earlier=%d",
                baseline.session, Difference(current, baseline.ids), Difference(baseline.ids, current)))
        end
    end
    local events = {}
    for _, event in ipairs(session.events or {}) do events[event.event] = (events[event.event] or 0) + 1 end
    local names = {}
    for name in pairs(events) do names[#names + 1] = name end
    table.sort(names)
    for _, name in ipairs(names) do print(string.format("  event %-28s %d", name, events[name])) end
    for _, recipe in ipairs(session.recipeSamples or {}) do
        local legacy = recipe.legacy or {}
        local reagents = {}
        for _, reagent in ipairs(legacy.reagents or {}) do
            reagents[#reagents + 1] = tostring(reagent.itemID or "?") .. "x" .. tostring(reagent.quantity or "?")
        end
        print(string.format("  recipe id=%s output=%s reagents=%s source=%s",
            tostring(recipe.id), tostring(legacy.outputItemID or recipe.outputItemID or "unknown"),
            table.concat(reagents, ","), tostring(recipe.context and recipe.context.source)))
    end
    for index, archaeology in ipairs(session.archaeologySamples or {}) do
        local unique, missing = {}, 0
        for _, race in ipairs(archaeology.races or {}) do
            for _, project in ipairs(race.projects or {}) do
                if project.spellID then unique[project.spellID] = true else missing = missing + 1 end
            end
        end
        local ids = 0
        for _ in pairs(unique) do ids = ids + 1 end
        print(string.format("  archaeology %02d shown=%s races=%s projects=%s uniqueSpellIDs=%d missingSpellIDs=%d completed=%s completeness=%s",
            index, tostring(archaeology.frameShown), tostring(archaeology.raceCount),
            tostring(archaeology.projectCount), ids, missing,
            tostring(archaeology.completedCount), tostring(archaeology.completeness)))
    end
end

if arg[2] then
    local output = assert(io.open(arg[2], "w"))
    output:write("-- Anonymized stage 0 recipe ID samples. No character identifiers.\nreturn {\n")
    local selectedSession = tonumber(arg[3])
    for sessionIndex, session in ipairs(db.sessions or {}) do
        if not selectedSession or sessionIndex == selectedSession then
        local latest = {}
        for _, snapshot in ipairs(session.snapshots or {}) do
            local line = snapshot.context and snapshot.context.legacyLine
            if line and line ~= "UNKNOWN" and snapshot.legacy and
                (not latest[line] or (snapshot.legacy.uniqueRecipeCount or 0) > (latest[line].uniqueRecipeCount or 0)) then
                latest[line] = snapshot.legacy
            end
        end
        local lines = {}
        for line in pairs(latest) do lines[#lines + 1] = line end
        table.sort(lines)
        for _, line in ipairs(lines) do
            local legacy = latest[line]
            output:write(string.format("  { session = %d, interface = %d, build = %q, profession = %q, rows = %d, recipeIDs = {",
                sessionIndex, tonumber(session.client and session.client.interface) or 0,
                tostring(session.client and session.client.build or "unknown"), line,
                tonumber(legacy.rowCount) or 0))
            for index, id in ipairs(legacy.recipeIDs or {}) do
                if type(id) == "number" then
                    if index > 1 then output:write(",") end
                    output:write(tostring(id))
                end
            end
            output:write("} },\n")
        end
        end
    end
    output:write("}\n")
    output:close()
    print("anonymized recipe ID sample saved")
end
