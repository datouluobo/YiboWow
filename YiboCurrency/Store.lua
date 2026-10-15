local Addon, Core = _G.YiboCurrency, _G.YiboCore
local Store = { MAX_AGE = 86400 }
Addon.Store = Store
local STATES = { known = true, partial = true, stale = true, unknown = true, unavailable = true, error = true }
local function Copy(value) return Core.Defaults:Copy(value) end
local function Now() return (GetServerTime and GetServerTime()) or time() end
local function Count(value) return type(value) == "number" and value >= 0 and value < math.huge and value % 1 == 0 end
local function Equal(a, b, ignoreTime)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for k, v in pairs(a) do if not (ignoreTime and k == "observedAt") and not Equal(v, b[k], ignoreTime) then return false end end
    for k in pairs(b) do if not (ignoreTime and k == "observedAt") and a[k] == nil then return false end end
    return true
end
Store.Copy, Store.Now, Store.Count, Store.Equal = Copy, Now, Count, Equal

function Store:Initialize()
    if self.db then return true end
    local db = Addon:EnsureDB()
    if (db.dataSchemaVersion ~= nil and db.dataSchemaVersion ~= 1) or db.version > 5 then return nil, Addon:T("MIGRATION.STORE_VERSION") end
    for _, key in ipairs({ "characters", "migration", "identityConflicts" }) do
        if db[key] ~= nil and type(db[key]) ~= "table" then return nil, Addon:T("MIGRATION.STORE_VERSION") end
        db[key] = db[key] or {}
    end
    for _, key in ipairs({ "byCharacter", "blocked", "blockedAliases" }) do
        if db.migration[key] ~= nil and type(db.migration[key]) ~= "table" then return nil, Addon:T("MIGRATION.STORE_VERSION") end
        db.migration[key] = db.migration[key] or {}
    end
    for id, record in pairs(db.characters) do
        if type(id) ~= "string" or type(record) ~= "table" then return nil, Addon:T("MIGRATION.STORE_VERSION") end
    end
    db.dataSchemaVersion, db.migration.version, db.version = 1, 1, 5
    self.db = db
    return true
end

function Store:Validate(kind, snapshot)
    if type(snapshot) ~= "table" or not STATES[snapshot.state] or not Count(snapshot.observedAt)
        or not Count(snapshot.revision) or snapshot.revision < 1 or type(snapshot.data) ~= "table"
        or type(snapshot.provenance) ~= "table" or type(snapshot.provenance.kind) ~= "string" then return nil, "invalid-snapshot" end
    local data = snapshot.data
    if kind == "native" then
        if data.moneyCopper ~= nil and not Count(data.moneyCopper) then return nil, "invalid-money" end
        if type(data.currencies) ~= "table" then return nil, "invalid-currencies" end
        for id, cell in pairs(data.currencies) do
            if not Count(id) or id == 0 or type(cell) ~= "table" then return nil, "invalid-currency" end
            for _, key in ipairs({ "quantity", "maxQuantity", "weeklyQuantity", "maxWeeklyQuantity", "weeklyResetAt", "observedAt" }) do
                if cell[key] ~= nil and not Count(cell[key]) then return nil, "invalid-currency-count" end
            end
        end
    elseif kind == "carriedTokens" then
        if type(data.items) ~= "table" then return nil, "invalid-items" end
        for id, cell in pairs(data.items) do
            if not Count(id) or id == 0 or type(cell) ~= "table" or not Count(cell.carried) then return nil, "invalid-item-count" end
        end
    else return nil, "invalid-kind" end
    return true
end

function Store:Get(id, kind)
    local record = self.db and self.db.characters[id]
    local snapshot = record and record[kind]
    if not self:Validate(kind, snapshot) then return nil end
    snapshot = Copy(snapshot)
    if snapshot.state == "known" or snapshot.state == "partial" then
        if snapshot.provenance.kind == "core-import" or Now() - snapshot.observedAt > self.MAX_AGE or snapshot.observedAt > Now() then snapshot.state = "stale" end
    end
    if kind == "native" then
        for _, cell in pairs(snapshot.data.currencies) do
            if cell.weeklyState ~= "known" or not cell.weeklyResetAt or Now() >= cell.weeklyResetAt then
                cell.weeklyQuantity, cell.weeklyState = nil, "unknown"
            end
        end
    end
    return snapshot
end

function Store:HasFacts(kind, snapshot)
    if not self:Validate(kind, snapshot) then return false end
    if kind == "native" then
        if snapshot.data.moneyCopper ~= nil then return true end
        for _, cell in pairs(snapshot.data.currencies) do if cell.quantity ~= nil then return true end end
    else return next(snapshot.data.items) ~= nil end
    return false
end

function Store:Changed(id, reason)
    self.db.revision = (self.Count(self.db.revision) and self.db.revision or 0) + 1
    if Addon.ArchiveProvider and Addon.ArchiveProvider.ref then
        Core.Contracts:NotifyChanged(Addon.NAME, Addon.ArchiveProvider.ref, { characterID = id, reason = reason })
    end
    if Addon.NotifyChanged then Addon:NotifyChanged() end
end

function Store:Commit(id, kind, data, state)
    if not self.db or not Core.Characters:Get(id, { identityOnly = true }) then return nil, "invalid-character" end
    local record = self.db.characters[id] or {}
    local previous = self:Validate(kind, record[kind]) and record[kind] or nil
    local candidate = { state = state, observedAt = Now(), revision = previous and previous.revision or 1,
        data = Copy(data or (previous and previous.data) or (kind == "native" and { currencies = {} } or { items = {} })),
        provenance = { kind = kind == "native" and "client" or "client-carried" } }
    if data == nil and previous then candidate.observedAt, candidate.provenance = previous.observedAt, Copy(previous.provenance) end
    if state ~= "known" and state ~= "partial" then
        candidate.observedAt = previous and previous.observedAt or 0
        if previous then candidate.provenance = Copy(previous.provenance) end
    end
    local valid, err = self:Validate(kind, candidate); if not valid then return nil, err end
    local effective = previous and self:Get(id, kind)
    local changed = not previous or (effective and effective.state ~= state) or not Equal(previous.data, candidate.data, true)
        or previous.provenance.kind ~= candidate.provenance.kind
    candidate.revision = (previous and previous.revision or 0) + (changed and 1 or 0)
    if candidate.revision == 0 then candidate.revision = 1 end
    record[kind] = candidate
    record.identityAliases = Core.Characters:GetAliases(id)
    self.db.characters[id] = record
    self:ScheduleExpiry()
    if changed then self:Changed(id, "scan") end
    return Copy(candidate), changed
end

function Store:ScheduleExpiry()
    if not (C_Timer and type(C_Timer.After) == "function") then return end
    local deadline, now = nil, Now()
    local function Consider(value) if value and value > now and (not deadline or value < deadline) then deadline = value end end
    for _, record in pairs(self.db.characters) do
        for _, kind in ipairs({ "native", "carriedTokens" }) do
            local snapshot = record[kind]
            if self:Validate(kind, snapshot) and snapshot.provenance.kind ~= "core-import" then
                Consider(snapshot.observedAt + self.MAX_AGE + 1)
                if kind == "native" then for _, cell in pairs(snapshot.data.currencies) do Consider(cell.weeklyResetAt) end end
            end
        end
    end
    -- Keep an earlier pending wakeup; observations must not create a timer per event.
    if not deadline or (self.expiryAt and self.expiryAt <= deadline) then return end
    self.expiryAt = deadline
    C_Timer.After(deadline - now, function()
        if self.expiryAt ~= deadline then return end
        self.expiryAt = nil
        self:Changed(nil, "freshness-expired")
        self:ScheduleExpiry()
    end)
end

function Addon:HasCurrencySnapshot(id, vaultRow, skipQuery)
    local native, tokens = self.Store:Get(id, "native"), self.Store:Get(id, "carriedTokens")
    if native then
        if native.data.moneyCopper ~= nil then return true end
        for _, cell in pairs(native.data.currencies) do if cell.quantity ~= nil then return true end end
    end
    if tokens and next(tokens.data.items) ~= nil then return true end
    if not vaultRow and not skipQuery and self.GetVaultPersonalCounts then
        local ids = {}; for _, entry in ipairs(self:GetCatalog()) do if entry.itemID then ids[#ids + 1] = entry.itemID end end
        local result = self:GetVaultPersonalCounts({ { id = id } }, ids)
        vaultRow = result and result.characters[id]
    end
    if vaultRow then
        for _, source in ipairs({ "bags", "bank", "equipment" }) do if vaultRow.coverage[source] and vaultRow.coverage[source].hasSnapshot then return true end end
    end
    return false
end

function Addon:GetEligibleCurrencyCharacters(characters)
    local result, missing, admitted = {}, {}, {}
    for _, character in ipairs(characters or {}) do
        if self:HasCurrencySnapshot(character.id, nil, true) then admitted[character.id] = true else missing[#missing + 1] = character end
    end
    local ids = {}; for _, entry in ipairs(self:GetCatalog()) do if entry.itemID then ids[#ids + 1] = entry.itemID end end
    local counts = #missing > 0 and self.GetVaultPersonalCounts and self:GetVaultPersonalCounts(missing, ids)
    for _, character in ipairs(characters or {}) do
        if admitted[character.id] or self:HasCurrencySnapshot(character.id, counts and counts.characters[character.id], true) then result[#result + 1] = character end
    end
    return result
end

local function Matches(id, record, character, aliases)
    if id == character.id then return true end
    if id:sub(1, 7) ~= "legacy:" then return false end
    for alias in pairs(record.identityAliases or {}) do if aliases[alias] then return true end end
    return false
end
function Store:DeleteCharacter(character, aliases, context)
    local deletedAt = context and context.deletedAt
    for id, record in pairs(self.db.characters) do
        if Matches(id, record, character, aliases or {}) then
            for _, kind in ipairs({ "native", "carriedTokens" }) do
                local snapshot = record[kind]
                local newerLocal = self:Validate(kind, snapshot) and snapshot.provenance.kind ~= "core-import"
                    and deletedAt and snapshot.observedAt > deletedAt and snapshot.observedAt <= Now()
                if not (context and context.replay and newerLocal) then record[kind] = nil end
            end
            if not record.native and not record.carriedTokens then self.db.characters[id] = nil end
            self.db.migration.blocked[id] = true
        end
    end
    self.db.migration.blocked[character.id] = true
    for alias in pairs(aliases or {}) do self.db.migration.blockedAliases[alias] = true end
    for key, conflict in pairs(self.db.identityConflicts) do
        if conflict.oldID == character.id or conflict.newID == character.id then
            if not (context and context.replay and deletedAt and conflict.recordedAt and conflict.recordedAt > deletedAt) then self.db.identityConflicts[key] = nil end
        end
    end
    self.db.migration.byCharacter[character.id] = { status = "deleted", deletedAt = deletedAt or Now() }
    self:Changed(character.id, "cache-deleted")
    return true
end

function Store:Remap(oldID, newID)
    if oldID == newID then return true end
    if type(oldID) ~= "string" or type(newID) ~= "string" or oldID:sub(1, 7) ~= "legacy:"
        or not Core.Characters:Get(newID, { identityOnly = true }) then return false end
    local old, target = self.db.characters[oldID], self.db.characters[newID] or {}
    if not old then return false end
    for _, kind in ipairs({ "native", "carriedTokens" }) do
        local left, right = old[kind], target[kind]
        if left and self:Validate(kind, left) then
            if not right or not self:Validate(kind, right) then target[kind] = Copy(left)
            elseif not Equal(left, right) then
                self.db.identityConflicts[oldID .. ">" .. newID .. ":" .. kind] = { oldID = oldID, newID = newID, recordedAt = Now(), old = Copy(left), current = Copy(right) }
                local leftFacts, rightFacts = self:HasFacts(kind, left), self:HasFacts(kind, right)
                local leftLocal, rightLocal = left.provenance.kind ~= "core-import", right.provenance.kind ~= "core-import"
                if leftFacts and not rightFacts then target[kind] = Copy(left)
                elseif leftFacts == rightFacts then
                    if (leftLocal and not rightLocal) or (leftLocal == rightLocal and left.observedAt > right.observedAt) then target[kind] = Copy(left)
                    elseif leftLocal == rightLocal and left.observedAt == right.observedAt and not Equal(left.data, right.data) then target[kind].state = "stale" end
                end
            end
        end
    end
    target.identityAliases = Core.Characters:GetAliases(newID)
    for alias in pairs(old.identityAliases or {}) do target.identityAliases[alias] = true end
    self.db.characters[newID], self.db.characters[oldID] = target, nil
    if self.db.migration.blocked[oldID] then self.db.migration.blocked[newID] = true end
    self.db.migration.byCharacter[newID] = self.db.migration.byCharacter[newID] or self.db.migration.byCharacter[oldID]
    self:Changed(newID, "identity-remapped")
    return true
end

function Store:ReconcileIDs()
    local moves = {}
    for oldID, record in pairs(self.db.characters) do
        if oldID:sub(1, 7) == "legacy:" and not Core.Characters:Get(oldID, { identityOnly = true }) then
            local target, ambiguous
            for alias in pairs(record.identityAliases or {}) do
                local id = Core.Characters:ResolveLegacyKey(alias)
                if id and Core.Characters:Get(id, { identityOnly = true }) then
                    if target and target ~= id then ambiguous = true end; target = id
                end
            end
            if target and not ambiguous then moves[#moves + 1] = { oldID, target } end
        end
    end
    for _, move in ipairs(moves) do self:Remap(move[1], move[2]) end
end

function Store:RegisterLifecycle()
    if self.registered then return true end
    local ok, err = Core.CharacterCleanup:RegisterOwner(Addon.NAME, {
        Inspect = function(character, aliases)
            local count = 0
            for id, record in pairs(self.db.characters) do if Matches(id, record, character, aliases) then count = count + 1 end end
            return { hasData = count > 0, label = Addon:T("MIGRATION.CACHE_LABEL"), detail = Addon:T("MIGRATION.CACHE_DETAIL", count) }
        end,
        Delete = function(...) return self:DeleteCharacter(...) end,
    })
    if not ok then return nil, err end
    Core.Events:Register("CHARACTER_ID_CHANGED", self, function(owner, oldID, newID) owner:Remap(oldID, newID) end)
    Core.Events:Register("CHARACTER_IMPORTED", self, function(_, id) Addon.Migration:ImportCharacter(id) end)
    self.registered = true
    self:ReconcileIDs()
    return true
end
