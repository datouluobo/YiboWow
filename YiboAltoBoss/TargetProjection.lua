if _G.YAB and _G.YAB.CoreReady == false then return end
local YAB = _G.YAB
local Plans = YAB.PlannedTargets
local function Core() return _G.YiboCore end
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
    for _, target in ipairs(config and config.targets[id] or {}) do
        local definition = target.active and YAB.TargetCatalog:Get(target.catalogID)
        if definition and definition.bossKey == bossKey then return true, id, target end
    end
    return false
end
function Plans:GetBossProgress(legacyKey, bossKey)
    local planned, id, target = self:IsPlanned(legacyKey, bossKey)
    if planned then return self:Progress(id, target) end
end
local BossList = YAB.GetBossList
function YAB.GetBossList(context)
    local list, seen = BossList(), {}
    for _, boss in ipairs(list) do seen[boss.key] = true end
    local config = Plans:VisibleConfiguration(context)
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
            local key = "task:" .. goal.catalogID .. ":" .. tostring(goal.difficultyID)
            if not seen[key] then
                seen[key] = true
                local definition = YAB.TargetCatalog:Get(goal.catalogID)
                local mapID = definition and tonumber(definition.mapID)
                local base = mapID and byMap[mapID]
                local fallback
                if base then
                    fallback = {}
                    for field, value in pairs(base) do fallback[field] = value end
                    -- Match the projected difficulty rather than an arbitrary
                    -- saved lockout for the same instance.
                    fallback.key, fallback.difficultyID = key, goal.difficultyID
                end
                if mapID then plannedMaps[mapID] = true end
                planned[#planned + 1] = { key = key, plannedCatalogID = goal.catalogID, plannedDifficultyID = goal.difficultyID,
                    name = goal.title .. " · " .. tostring(goal.difficultyName), shortName = goal.title,
                    abbreviation = ((definition and definition.aliases[1]) or goal.title) .. "·" .. tostring(goal.difficultyName),
                    difficultyName = goal.difficultyName, difficultyID = goal.difficultyID,
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
    for _, target in ipairs(config and config.targets[id] or {}) do
        if target.active and target.catalogID == column.plannedCatalogID and target.difficultyID == column.plannedDifficultyID then return id, target end
    end
end
function YAB.GetLockoutStatus(legacyKey, column)
    if not column.plannedCatalogID then return Status(legacyKey, column) end
    local id, target = Goal(legacyKey, column)
    if not target then
        if column.fallbackColumn then return Status(legacyKey, column.fallbackColumn) end
        return "not-applicable", "—"
    end
    local p = Plans:Progress(id, target)
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
    return lines
end
