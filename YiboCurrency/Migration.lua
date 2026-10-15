local Addon, Core = _G.YiboCurrency, _G.YiboCore
local Migration = {}
Addon.Migration = Migration

function Migration:CheckCoreHandoff()
    local major, minor, patch = tostring(Core:GetVersion()):match("^(%d+)%.(%d+)%.(%d+)")
    local version = major and (tonumber(major) * 1000000 + tonumber(minor) * 1000 + tonumber(patch)) or 0
    if version < 1012004 or not Core:HasCapability("character-archive-providers", 1)
        or not Core:HasCapability("character-cleanup", 2) or Core.CurrencyCatalog ~= nil then return nil, Addon:T("MIGRATION.CORE_COLLECTOR") end
    for _, definition in ipairs(Core.DataDomains:GetDefinitions()) do
        if definition.id == "economy" or definition.id == "economy-items" then return nil, Addon:T("MIGRATION.CORE_COLLECTOR") end
    end
    return true
end

local function Convert(source, kind)
    local store = Addon.Store
    if type(source) ~= "table" or source.schemaVersion ~= 1 or type(source.data) ~= "table"
        or not store.Count(source.updatedAt) or not store.Count(source.revision) then return nil, "invalid-legacy-schema" end
    if source.state ~= "known" and source.state ~= "stale" then return nil, "invalid-legacy-state" end
    local data = {}
    if kind == "native" then
        data.moneyCopper, data.moneyState, data.currencies = source.data.money, "stale", {}
        if type(source.data.currencies) ~= "table" then return nil, "invalid-legacy-currencies" end
        for key, cell in pairs(source.data.currencies) do
            local id = tonumber(key)
            if not store.Count(id) or id == 0 or data.currencies[id] or type(cell) ~= "table" then return nil, "invalid-legacy-currency" end
            local copy = store.Copy(cell)
            copy.state, copy.weeklyState, copy.weeklyResetAt, copy.observedAt = "stale", "unknown", nil, source.updatedAt
            data.currencies[id] = copy
        end
    else
        if type(source.data.items) ~= "table" then return nil, "invalid-legacy-items" end
        data.items = {}
        for key, cell in pairs(source.data.items) do
            local id = tonumber(key)
            if not store.Count(id) or id == 0 or type(cell) ~= "table" then return nil, "invalid-legacy-item" end
            if cell.carried ~= nil then
                if data.items[id] or not store.Count(cell.carried) then return nil, "invalid-legacy-carried" end
                data.items[id] = { carried = cell.carried }
            end
        end
    end
    local result = { state = "stale", observedAt = source.updatedAt, revision = 1, data = data,
        provenance = { kind = "core-import", sourceSchema = source.schemaVersion, sourceRevision = source.revision,
            sourceUpdatedAt = source.updatedAt, importedAt = store.Now() } }
    local valid, reason = store:Validate(kind, result)
    if not valid then return nil, reason end
    return result
end

function Migration:ImportCharacter(id)
    local store, character = Addon.Store, Core.Characters:Get(id, { identityOnly = true })
    if not store.db or not character then return false end
    local db, metadata = store.db, store.db.migration
    if id:sub(1, 7) == "legacy:" then
        for alias in pairs(Core.Characters:GetAliases(id)) do if metadata.blockedAliases[alias] then metadata.blocked[id] = true end end
    end
    if metadata.blocked[id] or Core.CharacterCleanup:IsLegacyImportBlocked(Addon.NAME, nil, id, character) then metadata.blocked[id] = true; return false end
    local record, staged = db.characters[id] or {}, {}
    for _, pair in ipairs({ { "native", "economy" }, { "carriedTokens", "economy-items" } }) do
        local kind, domain = pair[1], pair[2]
        local existing = record[kind]
        local valid = store:Validate(kind, existing)
        local empty = valid and not store:HasFacts(kind, existing)
        if not valid or (empty and existing.state ~= "known" and existing.state ~= "partial" and existing.state ~= "stale") then
            local ok, source = pcall(Core.DataDomains.Get, Core.DataDomains, id, domain)
            if not ok then metadata.byCharacter[id] = { status = "failed", reason = tostring(source) }; return nil end
            if source then
                local converted, err = Convert(source, kind)
                if not converted then metadata.byCharacter[id] = { status = "failed", reason = err }; return nil end
                staged[kind] = converted
            end
        end
    end
    if next(staged) then
        local nextRecord = store.Copy(record)
        for kind, snapshot in pairs(staged) do nextRecord[kind] = snapshot end
        nextRecord.identityAliases = Core.Characters:GetAliases(id)
        db.characters[id] = nextRecord
        metadata.byCharacter[id] = { status = "imported", importedAt = store.Now() }
        store:Changed(id, "legacy-import")
        return true
    end
    local previous = metadata.byCharacter[id]
    if not previous or previous.status == "failed" then
        metadata.byCharacter[id] = { status = next(record) and "existing" or "empty", checkedAt = store.Now(), previousFailure = previous and previous.reason }
    end
    return false
end

function Migration:ImportAll()
    local ready, err = self:CheckCoreHandoff()
    if not ready then return nil, nil, err end
    local imported, failed = 0, 0
    for _, character in ipairs(Core.Characters:GetAll({ identityOnly = true })) do
        local result = self:ImportCharacter(character.id)
        if result then imported = imported + 1 elseif result == nil then failed = failed + 1 end
    end
    Addon.Store:ScheduleExpiry()
    if failed > 0 then Addon:Print(Addon:T("MIGRATION.FAILED", failed)) end
    return imported, failed
end
