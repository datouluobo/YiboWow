local Addon, Core = _G.YiboReputation, _G.YiboCore
local Store = {}
Addon.Store = Store
local STATES = { known=true, stale=true, unavailable=true, error=true, ["not-yet-scanned"]=true }

local function Copy(value) return Core.Defaults:Copy(value) end
local function Now() return (GetServerTime and GetServerTime()) or time() end
local function Equal(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for k, v in pairs(a) do if not Equal(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end
Store.Copy, Store.Now = Copy, Now

function Store:Initialize()
    if self.db then return true end
    local db = Addon:EnsureDB()
    if db.dataSchemaVersion and db.dataSchemaVersion ~= 1 then return nil, Addon:T("ERROR.STORE_VERSION") end
    db.dataSchemaVersion = 1
    db.characters = type(db.characters) == "table" and db.characters or {}
    db.migrations = type(db.migrations) == "table" and db.migrations or {}
    db.migrations.coreReputationV1 = type(db.migrations.coreReputationV1) == "table" and db.migrations.coreReputationV1 or {}
    local migration = db.migrations.coreReputationV1
    migration.characters = type(migration.characters) == "table" and migration.characters or {}
    migration.blocked = type(migration.blocked) == "table" and migration.blocked or {}
    migration.remapped = type(migration.remapped) == "table" and migration.remapped or {}
    db.identityConflicts = type(db.identityConflicts) == "table" and db.identityConflicts or {}
    self.db = db
    return true
end

function Store:Validate(snapshot)
    if type(snapshot) ~= "table" or type(snapshot.schemaVersion) ~= "number"
        or snapshot.schemaVersion % 1 ~= 0 or snapshot.schemaVersion < 1 or snapshot.schemaVersion > 5
        or not STATES[snapshot.state] or type(snapshot.data) ~= "table"
        or type(snapshot.data.factions) ~= "table" then return nil, "invalid-snapshot" end
    if snapshot.updatedAt ~= nil and type(snapshot.updatedAt) ~= "number" then return nil, "invalid-timestamp" end
    for _, data in pairs(snapshot.data.factions) do
        if type(data) ~= "table" then return nil, "invalid-faction" end
    end
    if snapshot.schemaVersion == 5 then
        if snapshot.data.contractVersion ~= 1 or type(snapshot.data.statuses) ~= "table" then return nil, "invalid-contract" end
        for key, data in pairs(snapshot.data.factions) do
            local id = tonumber(key)
            if not id or id <= 0 or id % 1 ~= 0 or type(data) ~= "table" or tonumber(data.factionID) ~= id
                or (data.friendship ~= nil and type(data.friendship) ~= "table") then return nil, "invalid-faction" end
            for _, field in ipairs({ "standingID", "value", "min", "max" }) do
                if data[field] ~= nil and type(data[field]) ~= "number" then return nil, "invalid-value" end
            end
            if data.name ~= nil and type(data.name) ~= "string" then return nil, "invalid-name" end
            if data.nativeGroup ~= nil and type(data.nativeGroup) ~= "string" then return nil, "invalid-group" end
            if data.friendship then
                for _, field in ipairs({ "reaction", "rank", "maxRank", "reactionThreshold", "nextThreshold", "maxValue" }) do
                    if data.friendship[field] ~= nil and type(data.friendship[field]) ~= "number" then return nil, "invalid-friendship" end
                end
                for _, field in ipairs({ "reactionName", "friendName" }) do
                    if data.friendship[field] ~= nil and type(data.friendship[field]) ~= "string" then return nil, "invalid-friendship-name" end
                end
            end
        end
        for key, state in pairs(snapshot.data.statuses) do
            if not tonumber(key) or not STATES[state] then return nil, "invalid-faction-state" end
        end
    end
    return true
end

function Addon:GetSnapshot(characterID)
    local record = self.Store.db and self.Store.db.characters[characterID]
    return record and Copy(record.snapshot) or nil
end

function Store:IsEmptyPlaceholder(record)
    if type(record) ~= "table" or record.origin ~= nil or record.lastScanAt ~= nil then return false end
    local snapshot = record.snapshot
    if snapshot == nil then return true end
    if type(snapshot) ~= "table" or snapshot.schemaVersion ~= 5 or snapshot.state == "known" then return false end
    local data = snapshot.data
    return type(data) == "table" and data.contractVersion == 1 and type(data.factions) == "table" and next(data.factions) == nil
end

function Store:Changed(characterID, reason)
    Addon._matrixDataRevision = (Addon._matrixDataRevision or 0) + 1
    Addon._matrixSnapshotCache, Addon._matrixNodeCaches = nil, nil
    Addon._factionLookupCache = setmetatable({}, { __mode="k" })
    local record = self.db.characters[characterID]
    local snapshot = record and record.snapshot
    Core.Events:FireIsolated("YIBO_REPUTATION_SNAPSHOT_CHANGED", {
        source="YiboReputation", characterID=characterID, reason=reason,
        revision=snapshot and snapshot.revision, state=snapshot and snapshot.state,
        updatedAt=snapshot and snapshot.updatedAt,
    })
    if Addon.CoreIntegration and Addon.CoreIntegration.pageRegistered then Addon:NotifyChanged() end
end

function Addon:CommitSnapshot(characterID, data, state, context)
    local store, now = self.Store, Now()
    if not store.db or not Core.Characters:Get(characterID, { identityOnly=true }) or not STATES[state] then
        return nil, "invalid-character-or-state"
    end
    local record = store.db.characters[characterID] or {}
    local previous = record.snapshot
    local successful = state == "known" and data ~= nil
    local schema = successful and 5 or (previous and previous.schemaVersion or 5)
    local nextData = data or (previous and previous.data) or { contractVersion=1, factions={}, statuses={} }
    local candidate = { schemaVersion=schema, data=nextData, state=state }
    local valid, err = store:Validate(candidate)
    if not valid then return nil, err end
    local changed = not previous or previous.schemaVersion ~= schema or previous.state ~= state or not Equal(previous.data, nextData)
    if successful then
        record.lastScanAt = now; record.origin = { kind="local-scan" }
        record.identityAliases = Core.Characters:GetAliases(characterID)
    end
    record.lastError = successful and nil or (context and context.error)
    if changed then
        record.snapshot = { schemaVersion=schema, state=state, data=Copy(nextData), updatedAt=now,
            revision=(previous and tonumber(previous.revision) or 0) + 1 }
    end
    store.db.characters[characterID] = record
    if changed then store:Changed(characterID, context and context.reason or "scan") end
    return Copy(record.snapshot), changed
end

local function LegacyMatches(record, id, aliases)
    if id:sub(1, 7) ~= "legacy:" then return false end
    for alias in pairs(record.identityAliases or {}) do if aliases and aliases[alias] then return true end end
    return false
end

function Addon:InspectCharacter(character, aliases)
    local hasData = self.Store.db.characters[character.id] ~= nil
    for id, record in pairs(self.Store.db.characters) do if LegacyMatches(record, id, aliases) then hasData = true end end
    return { hasData=hasData, label=self:T("CACHE.LABEL") }
end

function Addon:DeleteCharacter(character, aliases)
    local db, id = self.Store.db, character.id
    local ids = { [id]=true }
    for oldID, record in pairs(db.characters) do if LegacyMatches(record, oldID, aliases) then ids[oldID] = true end end
    for target in pairs(ids) do
        db.migrations.coreReputationV1.blocked[target] = true
        db.characters[target], db.migrations.coreReputationV1.characters[target], db.identityConflicts[target] = nil, nil, nil
    end
    self.Store:Changed(id, "character-deleted")
    return true
end

local function Priority(record)
    local snapshot = record and record.snapshot
    if not snapshot then return 0, 0 end
    local localScan = record.origin and record.origin.kind == "local-scan"
    local known = snapshot.schemaVersion == 5 and snapshot.state == "known" and snapshot.data and snapshot.data.contractVersion == 1
    return (localScan and 4 or 0) + (known and 2 or 0), tonumber(record.lastScanAt or snapshot.updatedAt) or 0
end

function Store:RemapCharacter(oldID, newID)
    if oldID == newID then return end
    local db, migration = self.db, self.db.migrations.coreReputationV1
    local old, current = db.characters[oldID], db.characters[newID]
    if not old and migration.remapped[oldID] == newID then return end
    if old then
        if not current then db.characters[newID] = old
        else
            local op, ot = Priority(old); local np, nt = Priority(current)
            if op > np or (op == np and ot > nt) then
                db.characters[newID] = old
            elseif op == np and ot == nt and not Equal(old.snapshot, current.snapshot) then
                db.identityConflicts[newID] = { oldID=oldID, record=Copy(old), detectedAt=Now() }
                current.snapshot.state = "not-yet-scanned"
                current.snapshot.revision = (tonumber(current.snapshot.revision) or 0) + 1
                current.snapshot.updatedAt = Now()
                Addon:Print(Addon:T("ERROR.IDENTITY_CONFLICT"))
            end
        end
    end
    if migration.blocked[oldID] then migration.blocked[newID] = true end
    if not migration.characters[newID] then migration.characters[newID] = migration.characters[oldID] end
    migration.blocked[oldID] = true
    migration.remapped[oldID] = newID
    db.characters[oldID], migration.characters[oldID] = nil, nil
    if db.identityConflicts[oldID] then db.identityConflicts[newID] = db.identityConflicts[newID] or db.identityConflicts[oldID]; db.identityConflicts[oldID] = nil end
    self:Changed(newID, "character-id-changed")
end

function Store:RegisterLifecycle()
    if self.lifecycleRegistered then return true end
    Core.Events:Register("CHARACTER_ID_CHANGED", self, function(owner, oldID, newID) owner:RemapCharacter(oldID, newID) end)
    local ok, err = Core.CharacterCleanup:RegisterOwner(Addon.NAME, {
        Inspect=function(character, aliases) return Addon:InspectCharacter(character, aliases) end,
        Delete=function(character, aliases) return Addon:DeleteCharacter(character, aliases) end,
    })
    if not ok then Core.Events:Unregister("CHARACTER_ID_CHANGED", self); return nil, err end
    Core.Events:Register("CHARACTER_IMPORTED", self, function(_, id)
        if Addon.Migration then Addon.Migration:ImportCharacter(id) end
    end)
    self.lifecycleRegistered = true
    return true
end

function Store:ReconcileLegacyIDs()
    -- A late-loaded addon can miss Core's promotion event. Only Core's own
    -- alias resolver may repair a fallback ID; never remap one GUID to another.
    local moves = {}
    for oldID, record in pairs(self.db.characters) do
        if oldID:sub(1, 7) == "legacy:" and not Core.Characters:Get(oldID, { identityOnly=true }) then
            local target, ambiguous
            for alias in pairs(record.identityAliases or {}) do
                local id = Core.Characters:ResolveLegacyKey(alias)
                if id and Core.Characters:Get(id, { identityOnly=true }) then
                    if target and target ~= id then ambiguous = true end
                    target = id
                end
            end
            if target and not ambiguous then moves[#moves+1] = {oldID, target} end
        end
    end
    for _, move in ipairs(moves) do self:RemapCharacter(move[1], move[2]) end
end
