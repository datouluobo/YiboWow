if _G.YAB and _G.YAB.CoreReady == false then return end
local YAB = _G.YAB
local Plans = YAB.PlannedTargets
local plannedIndexes = setmetatable({}, { __mode = "k" })
local function Core() return _G.YiboCore end
local function Difficulty(catalogID, id)
    if YAB.TargetCatalog.CanonicalDifficulty then return YAB.TargetCatalog:CanonicalDifficulty(catalogID, id) end
    return id
end
local function Definition(catalogID) return YAB.TargetCatalog:Get(catalogID) end
local function Map(catalogID)
    local definition = Definition(catalogID)
    return definition and tonumber(definition.mapID)
end
function Plans:VisibleConfiguration(context)
    if not self.providerRef then return nil end
    local ids = {}
    for _, character in ipairs(context and context.characters or Core().Characters:GetAll({ identityOnly = true })) do ids[#ids + 1] = character.id end
    local config = self:Configuration(ids)
    return config and config.autoDisplay and config or nil
end
function Plans:IsPlanned(legacyKey, bossKey)
    if not self.providerRef then return false end
    local id = Core().Characters:ResolveLegacyKey(legacyKey)
    if not id then return false end
    local config = self:VisibleConfiguration({ characters = { { id = id } } })
    if not config then return false end
    local catalog = YAB.TargetCatalog
    local cached = plannedIndexes[config]
    if not cached or not catalog.value or cached.catalog ~= catalog.value then
        cached = { catalog = catalog.value, characters = {} }
        plannedIndexes[config] = cached
    end
    local index = cached.characters[id]
    if not index then
        index = {}
        for _, target in ipairs(config.targets[id] or {}) do
        local definition = target.active and YAB.TargetCatalog:Get(target.catalogID)
            if definition and definition.bossKey and not index[definition.bossKey] then
                index[definition.bossKey] = target
            end
        end
        cached.catalog = catalog.value
        cached.characters[id] = index
    end
    local target = index[bossKey]
    if target then return true, id, target end
    return false
end
function Plans:GetBossProgress(legacyKey, bossKey)
    local planned, id, target = self:IsPlanned(legacyKey, bossKey)
    if planned then return self:Progress(id, target) end
end
local BossList = YAB.GetBossList
function YAB.GetBossList(context)
    local list, seen = BossList(), {}
    local config = Plans:VisibleConfiguration(context)
    if not config then return list end
    for _, boss in ipairs(list) do seen[boss.key] = true end
    local all = {}; for _, b in ipairs(YAB.GetAllBossList()) do all[b.key] = b end
    for _, goals in pairs(config and config.targets or {}) do for _, target in ipairs(goals) do if target.active then
        local definition = YAB.TargetCatalog:Get(target.catalogID)
        local boss = definition and (all[definition.bossKey] or (YAB.Holiday and YAB.Holiday:GetBoss(definition.bossKey)))
        if boss and not seen[boss.key] then list[#list + 1], seen[boss.key] = boss, true end
    end end end
    return list
end
local Columns, Status, Tooltip = YAB.GetLockoutColumns, YAB.GetLockoutStatus, YAB.GetLockoutTooltip
function YAB.GetLockoutColumns(context)
    local columns, seen, planned, plannedMaps = Columns(context), {}, {}, {}
    local byMap = {}
    for _, column in ipairs(columns) do
        local mapID = tonumber(column.mapID or column.instanceID)
        if mapID then byMap[mapID] = column end
    end
    local config = Plans:VisibleConfiguration(context)
    for _, goals in pairs(config and config.targets or {}) do for _, goal in ipairs(goals) do
        if goal.active and goal.kind == "instance" then
            local definition = Definition(goal.catalogID)
            local mapID = Map(goal.catalogID)
            local difficultyID = Difficulty(goal.catalogID, goal.difficultyID)
            local key = "task:" .. (mapID and ("instance:" .. mapID) or goal.catalogID) .. ":" .. tostring(difficultyID)
            if not seen[key] then
                seen[key] = true
                local difficultyName = goal.difficultyName
                for _, d in ipairs(definition and definition.difficulties or {}) do if d.id == difficultyID then difficultyName = d.name end end
                local base = mapID and byMap[mapID]
                local fallback
                if base then
                    fallback = {}
                    for field, value in pairs(base) do fallback[field] = value end
                    -- Match the projected difficulty rather than an arbitrary
                    -- saved lockout for the same instance.
                    fallback.key, fallback.difficultyID = key, difficultyID
                end
                if mapID then plannedMaps[mapID] = true end
                planned[#planned + 1] = { key = key, plannedCatalogID = goal.catalogID, plannedDifficultyID = difficultyID,
                    name = goal.title .. " · " .. tostring(difficultyName), shortName = goal.title,
                    abbreviation = ((definition and definition.aliases[1]) or goal.title) .. "·" .. tostring(difficultyName),
                    difficultyName = difficultyName, difficultyID = difficultyID,
                    mapID = mapID, instanceID = mapID, isRaid = definition and definition.isRaid,
                    fallbackColumn = fallback }
            end
        end
    end end
    table.sort(planned, function(a, b) return tostring(a.key) < tostring(b.key) end)
    for _, column in ipairs(columns) do
        if not plannedMaps[tonumber(column.mapID or column.instanceID)] then planned[#planned + 1] = column end
    end
    return planned
end
local function Goal(legacyKey, column)
    local id = Core().Characters:ResolveLegacyKey(legacyKey)
    local config = id and Plans:VisibleConfiguration({ characters = { { id = id } } })
    local combined, selected = nil, {}
    for _, target in ipairs(config and config.targets[id] or {}) do
        local sameInstance = target.catalogID == column.plannedCatalogID
            or (column.mapID and Map(target.catalogID) == column.mapID)
        if target.active and sameInstance and Difficulty(target.catalogID, target.difficultyID) == column.plannedDifficultyID then
            if not combined then
                combined = {}
                for key, value in pairs(target) do combined[key] = value end
                combined.difficultyID, combined.difficultyName = column.plannedDifficultyID, column.difficultyName
                combined.encounterIDs = {}
            end
            if target.scope == "all" then combined.scope = "all" end
            for _, encounterID in ipairs(target.encounterIDs or {}) do
                if not selected[encounterID] then combined.encounterIDs[#combined.encounterIDs + 1], selected[encounterID] = encounterID, true end
            end
        end
    end
    if combined then return id, combined end
end
function YAB.GetLockoutStatus(legacyKey, column)
    if not column.plannedCatalogID then return Status(legacyKey, column) end
    local id, target = Goal(legacyKey, column)
    if not target then
        if column.fallbackColumn then return Status(legacyKey, column.fallbackColumn) end
        return "not-applicable", "—"
    end
    local p = Plans:Progress(id, target)
    if p.state == "completed" then
        return "clear", _G.YiboCore.Locale:Get("YiboAltoBoss", "LOCKOUT.CLEAR"), p.lockout
    end
    if p.state == "unknown" and p.lockout then
        return "locked", _G.YiboCore.Locale:Get("YiboAltoBoss", "LOCKOUT.LOCKED"), p.lockout
    end
    return p.state == "completed" and "clear" or (p.state == "ready" and "open" or "unknown"),
        p.state == "unknown" and _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.UNCONFIRMED") or p.reason, p.lockout
end
function YAB.GetLockoutTooltip(legacyKey, column)
    if not column.plannedCatalogID then return Tooltip(legacyKey, column) end
    local id, target = Goal(legacyKey, column)
    if not target then
        if column.fallbackColumn then return Tooltip(legacyKey, column.fallbackColumn) end
        return { _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.THIS_CHARACTER_HAS_NO_GOAL_FOR_THIS_DIFFICULTY") }
    end
    local p = Plans:Progress(id, target)
    local lines = { _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.SOURCE_ACTION_CENTER_GOAL"), _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.DIFFICULTY_2") .. tostring(target.difficultyName), _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.STATUS_2") .. p.reason }
    local definition = YAB.TargetCatalog:Get(target.catalogID)
    local wanted = {}; for _, eid in ipairs(target.encounterIDs) do wanted[eid] = true end
    if target.scope == "all" then lines[#lines + 1] = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.SCOPE_ALL_INSTANCE_BOSSES")
    else
        for _, difficulty in ipairs(definition and definition.difficulties or {}) do if difficulty.id == target.difficultyID then
            for _, encounter in ipairs(difficulty.encounters) do if wanted[encounter.id] then lines[#lines + 1] = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.TARGET_2") .. encounter.name end end
        end end
    end
    if p.observedAt then lines[#lines + 1] = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.SNAPSHOT") .. date("%m-%d %H:%M", p.observedAt) end
    if p.lockout and p.lockout.resetAt then
        lines[#lines + 1] = _G.YiboCore.Locale:Get("YiboAltoBoss", "LOCKOUT.RESET", date("%m-%d %H:%M", p.lockout.resetAt))
    end
    return lines
end
