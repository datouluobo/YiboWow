local Addon = _G.YiboCurrency
local Store = {}; Addon.Store = Store
function Store:Count(value)
    if type(issecretvalue) == "function" and issecretvalue(value) then return false end
    return type(value) == "number" and value >= 0 and value <= 9007199254740991 and value % 1 == 0
end
function Store:Initialize()
    local db = _G.YiboCurrencyForeverDB
    if db ~= nil then
        if type(db) ~= "table" or db.schema ~= 1 or type(db.clientScope) ~= "table"
            or db.clientScope.target ~= "Forever" or db.clientScope.projectID ~= WOW_PROJECT_ID
            or db.clientScope.scope ~= "current-character" or type(db.characters) ~= "table"
            or type(db.settings) ~= "table" or type(db.settings.previewColumns) ~= "table" then return false end
        for id, row in pairs(db.characters) do
            if type(id) ~= "string" or type(row) ~= "table" or not self:Count(row.moneyCopper)
                or not self:Count(row.observedAt) then return false end
        end
        if db.settings.customItems ~= nil then
            if type(db.settings.customItems) ~= "table" then return false end
            for id, name in pairs(db.settings.customItems) do
                if not self:ItemID(id) or type(name) ~= "string" or name == "" then return false end
            end
        end
        if db.itemSnapshots ~= nil then
            if type(db.itemSnapshots) ~= "table" then return false end
            for id, snapshot in pairs(db.itemSnapshots) do
                if type(id) ~= "string" or type(snapshot) ~= "table" then return false end
                for itemID, row in pairs(snapshot) do
                    if not self:ItemID(itemID) or type(row) ~= "table" or not self:Count(row.count)
                        or not self:Count(row.observedAt) then return false end
                end
            end
        end
        if db.nativeDiscovery ~= nil then
            if type(db.nativeDiscovery) ~= "table" or db.nativeDiscovery.schema ~= 1
                or type(db.nativeDiscovery.directory) ~= "table" or type(db.nativeDiscovery.characters) ~= "table" then return false end
        end
    else
        db = { schema = 1, clientScope = { target = "Forever", projectID = WOW_PROJECT_ID,
            scope = "current-character", rulesetState = "unknown" }, characters = {},
            settings = { previewColumns = { money = true } } }
    end
    self.db = db; _G.YiboCurrencyForeverDB = db
    if Addon.NativeStore then
        self.nativeStore = Addon.NativeStore:New(db,
            function() return Addon.Core and Addon.Core.Characters:GetCurrentID() end,
            function() return Addon.initialized and Addon.Scanner and Addon.Scanner.inWorld end
        )
    end
    return true
end
function Store:ItemID(id)
    return self:Count(id) and id > 0 and id <= 2147483647
end
function Store:Items()
    return self.db.settings.customItems or {}
end
function Store:CommitItems(id, counts, stamp)
    if not id or id ~= Addon.Core.Characters:GetCurrentID() or not self:Count(stamp) then return end
    self.freshItemsID, self.freshItems = id, counts
    if self.itemSessionID ~= id then self.itemSessionID, self.itemSessionStart = id, {} end
    if not next(counts) then return end
    self.db.itemSnapshots = self.db.itemSnapshots or {}
    local snapshot = self.db.itemSnapshots[id] or {}
    for itemID, count in pairs(counts) do
        if self.itemSessionStart[itemID] == nil then self.itemSessionStart[itemID] = count end
        snapshot[itemID] = { count = count, observedAt = stamp }
    end
    self.db.itemSnapshots[id] = snapshot
end
function Store:GetItemCount(id, itemID)
    if not id or id ~= Addon.Core.Characters:GetCurrentID() or not self:Items()[itemID] then return nil end
    local snapshots = self.db.itemSnapshots
    local row = snapshots and snapshots[id] and snapshots[id][itemID]
    if row then
        local fresh = Addon.Scanner.inWorld and self.freshItemsID == id and self.freshItems and self.freshItems[itemID] ~= nil
        local start = fresh and self.itemSessionID == id and self.itemSessionStart[itemID]
        return row.count, fresh, start and row.count - start or nil
    end
end
function Store:ClearItemSession(itemID)
    if self.itemSessionStart then self.itemSessionStart[itemID] = nil end
    if self.freshItems then self.freshItems[itemID] = nil end
end
function Store:Get(id)
    if not Addon.Core or id ~= Addon.Core.Characters:GetCurrentID() then return nil, "unsupported-scope" end
    local row = self.db and self.db.characters[id]
    local state = self.error and "error" or (row and (self.freshID == id and Addon.Scanner.inWorld and "known" or "stale") or "unknown")
    return row and Addon.Core.Defaults:Copy(row) or nil, state
end
function Addon:ReadArchiveMoney(id)
    local current = id == self.Core.Characters:GetCurrentID()
    local row = Store.db.characters[id]
    if not row then return {state="unknown"} end
    local fresh = current and Store.freshID == id and self.Scanner.inWorld and not Store.error
    return {value=row.moneyCopper, state=fresh and "known" or "stale", observedAt=row.observedAt}
end

function Store:GetCachedItemCount(id, itemID)
    local rows = self.db.itemSnapshots and self.db.itemSnapshots[id]
    local row = rows and rows[itemID]
    local fresh = id == Addon.Core.Characters:GetCurrentID() and Addon.Scanner.inWorld
        and self.freshItemsID == id and self.freshItems and self.freshItems[itemID] ~= nil
    return row and row.count, fresh == true
end

function Store:GetNativeDirectory()
    local root = self.db and self.db.nativeDiscovery
    return root and root.directory or {}
end

function Store:GetNativeCurrency(id, currencyID)
    local root = self.db and self.db.nativeDiscovery
    local character = root and root.characters and root.characters[id]
    local observations = self.freshObservationsID == id and self.freshObservations
    if Addon.NativeDiscovery then
        return Addon.NativeDiscovery:GetValue(character, observations, currencyID)
    end
    return nil, "unknown"
end

function Store:Commit(id, copper, observedAt)
    if not id or id ~= Addon.Core.Characters:GetCurrentID() or not self:Count(copper) or not self:Count(observedAt) then return false end
    if self.sessionID ~= id then self.sessionID, self.sessionStart = id, copper end
    self.db.characters[id] = { moneyCopper = copper, observedAt = observedAt }
    self.freshID, self.error = id, nil; Addon:NotifyChanged(); return true
end
function Store:GetSessionChange(id, snapshot, state)
    if id and id == self.sessionID and state == "known" and snapshot then
        return snapshot.moneyCopper - self.sessionStart
    end
end
function Store:ResetSession()
    self.sessionID, self.sessionStart = nil, nil
    self.itemSessionID, self.itemSessionStart = nil, nil
    self.freshObservationsID, self.freshObservations = nil, nil
end
function Store:Delete(character, context)
    local row = self.db.characters[character.id]
    local now = GetServerTime and GetServerTime()
    local function Keep(record)
        return context and context.replay and record and self:Count(context.deletedAt) and self:Count(now)
            and record.observedAt > context.deletedAt and record.observedAt <= now
    end
    local keepMoney = Keep(row)
    if not keepMoney then self.db.characters[character.id] = nil end
    local snapshots = self.db.itemSnapshots
    local items = snapshots and snapshots[character.id]
    local kept = {}
    for itemID, item in pairs(items or {}) do if Keep(item) then kept[itemID] = item end end
    if snapshots then snapshots[character.id] = next(kept) and kept or nil end
    if self.nativeStore and not keepMoney then
        self.nativeStore:DeleteCharacter(character.id)
    end
    if character.id == Addon.Core.Characters:GetCurrentID() then
        if not keepMoney or (items and not next(kept)) then Addon.Scanner:Cancel() end
        if not keepMoney then
            self.freshID, self.error, self.sessionID, self.sessionStart = nil, nil, nil, nil
            self.freshObservationsID, self.freshObservations = nil, nil
        end
        for itemID in pairs(items or {}) do if not kept[itemID] then self:ClearItemSession(itemID) end end
    end
    Addon:NotifyChanged(); return true
end
