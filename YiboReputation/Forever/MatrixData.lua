local Addon = _G.YiboReputation

function Addon:GetSettings()
    return self.Store.db.settings
end

function Addon:GetMatrixExpansion()
    self.matrixExpansion = self.matrixExpansion or {}
    return self.matrixExpansion
end

function Addon:HasMatrixSnapshot(character)
    local snapshot = self.Store.db.characters[character.id]
    return snapshot and next(snapshot.factions) ~= nil
end

function Addon:GetSnapshot(id)
    local saved = self.Store.db.characters[id]
    if not saved then return nil end
    local current = self.Core.Characters:GetCurrentID() == id
    local scanState = current and self.Store.error
    local state = (scanState == "error" or scanState == "unavailable") and scanState or "stale"
    if current and not self.Store.error and self.Store.freshID == id and self.Scanner.inWorld then state = "known" end
    return { factions = self.Core.Defaults:Copy(saved.factions), updatedAt = saved.observedAt, state = state }
end

function Addon:GetMatrixNodes(characters, readSnapshot)
    local nodes, seen = {}, {}
    for _, character in ipairs(characters) do
        local snapshot = readSnapshot(character)
        for id, row in pairs(snapshot and snapshot.factions or {}) do
            if not seen[id] then
                seen[id] = true
                nodes[#nodes + 1] = { key = "matrix:faction:" .. id, kind = "faction", factionID = id,
                    title = row.name, children = {} }
            end
        end
    end
    table.sort(nodes, function(a, b)
        if a.title == b.title then return a.factionID < b.factionID end
        return a.title < b.title
    end)
    return nodes
end

function Addon:GetMatrixCell(snapshot, node, character)
    local data = snapshot and snapshot.factions[node.factionID]
    if not data then return { state = "missing" } end
    local state = self.Store:RowState(character.id, node.factionID) == "stale" and (snapshot.state == "known" and "stale" or snapshot.state)
    local scope = data.isAccountWide == nil and "MATRIX.SCOPE_UNKNOWN"
        or (data.isAccountWide and "MATRIX.SCOPE_ACCOUNT_FLAG" or "MATRIX.SCOPE_CHARACTER_FLAG")
    if not self.ReputationDisplay:OrdinaryRank(data) then return { state = state or "unconfirmed", scope = scope } end
    return { state = state, observedAt = data.observedAt, rank = data.reaction, current = data.value - data.minimum,
        maximum = data.maximum - data.minimum, complete = self.ReputationDisplay:IsComplete(data), scope = scope,
        session = self.Store:GetSessionChange(character.id, node.factionID) }
end

function Addon:GetMonitoredFactions()
    return self:GetSettings().watchedFactionIDs
end

function Addon:IsMonitored(factionID)
    for _, id in ipairs(self:GetMonitoredFactions()) do if id == factionID then return true end end
    return false
end

function Addon:ToggleMonitored(factionID)
    return self.Store:ToggleWatched(factionID)
end

function Addon:CanToggleMonitored(factionID)
    return self:IsMonitored(factionID) or self.Store:GetFactionDirectory()[factionID] ~= nil
end

function Addon:RefreshCurrentReputation()
    self.Scanner:Scan()
end

Addon.MatrixExtraFields = {
    { id = "session", label = "MATRIX.FIELD_SESSION", defaultVisible = true },
    { id = "scope", label = "MATRIX.FIELD_SCOPE", defaultVisible = true },
}

function Addon:ScanStatus()
    local _, state = self.Store:Get(self.Core.Characters:GetCurrentID())
    local keys = { partial = "FOREVER.PARTIAL", stale = "FOREVER.STALE", error = "FOREVER.ERROR",
        pending = "FOREVER.PENDING", unavailable = "FOREVER.UNAVAILABLE" }
    return self:T(keys[state] or "FOREVER.UNKNOWN")
end
