local Addon = _G.YiboTodo
local Registry = Addon.Providers.Registry
local Provider = { id = "farm-operation-observation", schemaVersion = 1 }

local function CurrentMapID()
    local map = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    return tonumber(map)
end

local function TrimHistory(days)
    local keys = {}
    for serverDay in pairs(days or {}) do keys[#keys + 1] = serverDay end
    table.sort(keys, function(left, right) return tostring(left) > tostring(right) end)
    for index = 9, #keys do days[keys[index]] = nil end
end

function Provider:GetDefinition()
    return Addon.Catalog.farmOperations and Addon.Catalog.farmOperations["mop.farm.operation-observed"]
end

function Provider:RecordOperation(kind, label, eventKey, source, spellID)
    local definition = self:GetDefinition()
    if not definition then return false, "missing-definition" end
    if CurrentMapID() ~= tonumber(definition.mapID) then return false, "outside-farm-map" end
    local current = Addon.Core and Addon.Core.Characters and Addon.Core.Characters:GetCurrent()
    if not current then return false, "character-unavailable" end
    local now, resetHour = Addon:Now(), definition.resetHour
    local serverDay = Addon.Model.Schedule:ServerDay(now, resetHour)
    local record = Addon.Database:GetProvider(current.id, self.id, true)
    record.days = record.days or {}
    local day = record.days[serverDay] or { observedAt = now, nextResetAt = Addon.Model.Schedule:NextResetAt(now, resetHour), operations = {} }
    record.days[serverDay] = day
    TrimHistory(record.days)
    for _, operation in ipairs(day.operations) do
        if eventKey and operation.eventKey == eventKey then return false, "duplicate-observation" end
    end
    day.operations[#day.operations + 1] = {
        spellID = spellID, kind = kind, label = label, at = now,
        eventKey = eventKey, castGUID = source == "UNIT_SPELLCAST_SUCCEEDED" and eventKey or nil, source = source,
    }
    day.observedAt, day.nextResetAt = now, Addon.Model.Schedule:NextResetAt(now, resetHour)
    record.revision = (tonumber(record.revision) or 0) + 1
    record.providerVersion, record.catalogVersion, record.rulesetID = self.schemaVersion, Addon.CATALOG_VERSION, Addon.RULESET_ID
    record.lastAttemptAt, record.lastSuccessAt, record.state, record.errorCode = now, now, "available", nil
    Addon:NotifyChanged()
    return true, kind
end

function Provider:RecordSucceededCast(unit, castGUID, spellID)
    if unit ~= "player" then return false, "not-player" end
    spellID = tonumber(spellID)
    local definition = self:GetDefinition()
    local rule = definition and definition.rules and definition.rules[spellID]
    if not rule then return false, "untracked-spell" end
    return self:RecordOperation(rule.kind, rule.label, castGUID, "UNIT_SPELLCAST_SUCCEEDED", spellID)
end

function Provider:RecordGrowingMouseover()
    local name = UnitName and UnitName("mouseover")
    if type(name) ~= "string" or not string.match(name, "^生长中的") then return false, "not-growing-crop" end
    local guid = UnitGUID and UnitGUID("mouseover")
    if not guid then return false, "mouseover-guid-unavailable" end
    return self:RecordOperation("growing", name, "mouseover:" .. guid, "UPDATE_MOUSEOVER_UNIT", nil)
end

function Provider:GetCurrentDay(characterID, now)
    local definition = self:GetDefinition()
    local record = Addon.Database:GetProvider(characterID, self.id, false)
    if not (definition and record and record.days) then return nil, definition end
    local exact = record.days[Addon.Model.Schedule:ServerDay(now, definition.resetHour)]
    if exact then return exact, definition end
    -- Realm-clock and local timestamp dates can briefly disagree around a
    -- date boundary. The saved reset timestamp is authoritative for a
    -- current observation, so use it as a safe projection fallback.
    local current
    for _, day in pairs(record.days) do
        if (tonumber(day.observedAt) or 0) <= now and (tonumber(day.nextResetAt) or 0) > now
            and (not current or (tonumber(day.observedAt) or 0) > (tonumber(current.observedAt) or 0)) then
            current = day
        end
    end
    return current, definition
end

function Provider:GetLatestExpiredDay(characterID, now)
    local definition = self:GetDefinition()
    local record = Addon.Database:GetProvider(characterID, self.id, false)
    if not (definition and record and record.days) then return nil, definition end
    local latest
    for _, day in pairs(record.days) do
        if (tonumber(day.nextResetAt) or 0) <= now
            and (not latest or (tonumber(day.nextResetAt) or 0) > (tonumber(latest.nextResetAt) or 0)) then
            latest = day
        end
    end
    return latest, definition
end

Registry:Register(Provider)
