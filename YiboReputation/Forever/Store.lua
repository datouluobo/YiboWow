local Addon = _G.YiboReputation
local Store = {}; Addon.Store = Store
function Store:Plain(value) return type(issecretvalue) ~= "function" or not issecretvalue(value) end
function Store:Integer(value, minimum, maximum)
    return self:Plain(value) and type(value) == "number" and value >= minimum and value <= maximum and value % 1 == 0
end
function Store:ValidRow(id, row)
    if not self:Integer(id, 1, 2147483647) or type(row) ~= "table" or row.factionID ~= id
        or type(row.name) ~= "string" or row.name == "" or not self:Integer(row.observedAt, 0, 9007199254740991) then return false end
    for _, key in ipairs({ "reaction", "minimum", "maximum", "value" }) do
        if not self:Integer(row[key], -9007199254740991, 9007199254740991) then return false end
    end
    return row.isAccountWide == nil or type(row.isAccountWide) == "boolean"
end
function Store:Initialize()
    local db = _G.YiboReputationForeverDB
    if db ~= nil then
        if type(db) ~= "table" or db.schema ~= 1 or type(db.clientScope) ~= "table"
            or db.clientScope.target ~= "Forever" or db.clientScope.projectID ~= WOW_PROJECT_ID
            or db.clientScope.scope ~= "current-character" or type(db.characters) ~= "table"
            or type(db.settings) ~= "table" or type(db.settings.previewColumns) ~= "table" then return false end
        for id, snapshot in pairs(db.characters) do
            if type(id) ~= "string" or type(snapshot) ~= "table" or type(snapshot.factions) ~= "table"
                or not self:Integer(snapshot.observedAt, 0, 9007199254740991) then return false end
            for factionID, row in pairs(snapshot.factions) do if not self:ValidRow(factionID, row) then return false end end
            if snapshot.watched ~= nil then
                if type(snapshot.watched) ~= "table" then return false end
                for factionID, selected in pairs(snapshot.watched) do
                    if not self:Integer(factionID, 1, 2147483647) or selected ~= true then return false end
                end
            end
        end
        if db.factionDirectory ~= nil then
            if type(db.factionDirectory) ~= "table" then return false end
            for factionID, row in pairs(db.factionDirectory) do
                if not self:Integer(factionID, 1, 2147483647) or type(row) ~= "table"
                    or row.id ~= factionID or type(row.name) ~= "string" or row.name == ""
                    or not self:Integer(row.discoveredAt, 0, 9007199254740991) then
                    return false
                end
            end
        end
    else
        db = { schema = 1, clientScope = { target = "Forever", projectID = WOW_PROJECT_ID,
            scope = "current-character", rulesetState = "unknown" }, characters = {},
            settings = { previewColumns = { faction = true, reaction = true, value = true, scope = true, state = true } } }
    end
    db.factionDirectory = db.factionDirectory or {}
    for _, snapshot in pairs(db.characters) do
        for factionID, row in pairs(snapshot.factions or {}) do
            if not db.factionDirectory[factionID] and self:ValidRow(factionID, row) then
                db.factionDirectory[factionID] = {
                    id = factionID,
                    name = row.name,
                    discoveredAt = row.observedAt,
                    updatedAt = row.observedAt
                }
            end
        end
    end
    local order = db.settings.watchedFactionIDs
    if order == nil then
        local migrated = {}
        for _, snapshot in pairs(db.characters) do
            for factionID in pairs(snapshot.watched or {}) do migrated[factionID] = true end
        end
        order = {}
        for factionID in pairs(migrated) do order[#order + 1] = factionID end
        table.sort(order)
        db.settings.watchedFactionIDs = order
    end
    if type(order) ~= "table" then return false end
    local seen, count = {}, 0
    for index, factionID in pairs(order) do
        if not self:Integer(index, 1, #order) or not self:Integer(factionID, 1, 2147483647) or seen[factionID] then return false end
        seen[factionID] = true
        count = count + 1
    end
    if count ~= #order then return false end
    self.db = db; _G.YiboReputationForeverDB = db; return true
end
function Store:GetFactionDirectory()
    return self.db and self.db.factionDirectory or {}
end
function Store:Get(id)
    if not Addon.Core or not id or id ~= Addon.Core.Characters:GetCurrentID() then return nil, "unsupported-scope" end
    local row = self.db and self.db.characters[id]
    return row and Addon.Core.Defaults:Copy(row) or nil,
        self.error or (row and (self.freshID == id and Addon.Scanner.inWorld and "partial" or "stale") or "unknown")
end
function Store:RowState(id, factionID)
    return not self.error and self.freshID == id and Addon.Scanner.inWorld and self.freshFactions
        and self.freshFactions[factionID] and "observed" or "stale"
end
function Store:GetSessionChange(id, factionID)
    if not id or self.sessionID ~= id or id ~= Addon.Core.Characters:GetCurrentID()
        or self:RowState(id, factionID) ~= "observed" then return nil end
    local baseline = self.sessionStart[factionID]
    local current = self.db.characters[id].factions[factionID]
    return baseline and current and current.value - baseline.value or nil
end
function Store:ToggleWatched(factionID)
    if not self:Integer(factionID, 1, 2147483647) then return false end
    local order = self.db.settings.watchedFactionIDs
    local position
    for index, selected in ipairs(order) do
        if selected == factionID then position = index; break end
    end
    if position then
        table.remove(order, position)
    elseif self:GetFactionDirectory()[factionID] then
        order[#order + 1] = factionID
    else
        return false
    end
    Addon:NotifyChanged()
    return true
end
function Store:Commit(id, factions, stamp)
    if not id or id ~= Addon.Core.Characters:GetCurrentID() or not self:Integer(stamp, 0, 9007199254740991) then return false end
    for factionID, row in pairs(factions) do if not self:ValidRow(factionID, row) then return false end end
    local previous = self.db.characters[id]
    local snapshot = previous and Addon.Core.Defaults:Copy(previous) or { factions = {} }
    if self.sessionID ~= id then self.sessionID, self.sessionStart = id, {} end
    self.freshFactions = {}
    for factionID, row in pairs(factions) do
        local baseline = self.sessionStart[factionID]
        if not Addon.ReputationDisplay:OrdinaryRank(row) then
            self.sessionStart[factionID] = nil
        elseif not baseline or baseline.isAccountWide ~= row.isAccountWide then
            self.sessionStart[factionID] = { value = row.value, isAccountWide = row.isAccountWide }
        end
        snapshot.factions[factionID] = Addon.Core.Defaults:Copy(row)
        self.freshFactions[factionID] = true
    end
    self.db.factionDirectory = self.db.factionDirectory or {}
    for factionID, row in pairs(factions) do
        local entry = self.db.factionDirectory[factionID]
        if not entry then
            self.db.factionDirectory[factionID] = {
                id = factionID,
                name = row.name,
                discoveredAt = stamp,
                updatedAt = stamp
            }
        else
            entry.name = row.name
            entry.updatedAt = stamp
        end
    end
    snapshot.observedAt = stamp; self.db.characters[id] = snapshot
    self.freshID, self.error = id, nil; Addon:NotifyChanged(); return true
end
function Store:Delete(character, context)
    local snapshot = self.db.characters[character.id]
    local now = GetServerTime and GetServerTime()
    if context and context.replay and snapshot and self:Integer(context.deletedAt, 0, 9007199254740991)
        and self:Integer(now, 0, 9007199254740991) then
        local kept = {}
        for id, row in pairs(snapshot.factions) do
            if row.observedAt > context.deletedAt and row.observedAt <= now then kept[id] = row end
        end
        if next(kept) then snapshot.factions = kept; Addon:NotifyChanged(); return true end
    end
    self.db.characters[character.id] = nil
    if character.id == Addon.Core.Characters:GetCurrentID() then
        Addon.Scanner:Cancel(); self.freshID, self.freshFactions, self.error = nil, nil, nil
        self.sessionID, self.sessionStart = nil, nil
    end
    Addon:NotifyChanged(); return true
end
