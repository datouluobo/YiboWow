local Core = _G.YiboCore

local Characters = {}
Core.Characters = Characters

local function GetTimestamp()
    return (GetServerTime and GetServerTime()) or time()
end

local function Snapshot(record)
    if type(record) ~= "table" then
        return nil
    end
    return Core.Defaults:Copy(record)
end

local function GetStore()
    local db = Core.Database:GetDB()
    return db and db.characters
end

local function BuildFallbackID(name, realm)
    return "legacy:" .. tostring(realm or "Unknown") .. ":" .. tostring(name or "Unknown")
end

local function AddAlias(store, characterID, alias)
    if type(alias) == "string" and alias ~= "" then
        store.aliases[alias] = characterID
    end
end

local function ReplaceCharacterID(store, oldID, newID)
    if oldID == newID or not store.byID[oldID] or store.byID[newID] then
        return
    end

    local record = store.byID[oldID]
    record.id = newID
    store.byID[newID] = record
    store.byID[oldID] = nil

    store.seenOrder[newID] = store.seenOrder[oldID]
    store.seenOrder[oldID] = nil

    for alias, characterID in pairs(store.aliases) do
        if characterID == oldID then
            store.aliases[alias] = newID
        end
    end
end

local function EnsureSeenOrder(store, characterID)
    if store.seenOrder[characterID] then
        return store.seenOrder[characterID]
    end

    local highest = 0
    for _, order in pairs(store.seenOrder) do
        highest = math.max(highest, tonumber(order) or 0)
    end
    store.seenOrder[characterID] = highest + 1
    return store.seenOrder[characterID]
end

function Characters:BuildLegacyAliases(name, realm)
    if not name or not realm then
        return {}
    end
    return {
        tostring(name) .. "-" .. tostring(realm),
        tostring(realm) .. "-" .. tostring(name),
    }
end

function Characters:GetCurrentID()
    local guid = UnitGUID and UnitGUID("player")
    if guid and guid ~= "" then
        return guid
    end
    return BuildFallbackID(UnitName("player"), GetRealmName())
end

function Characters:RefreshCurrent()
    local store = GetStore()
    if not store then
        return nil
    end

    local name = UnitName("player") or "Unknown"
    local realm = GetRealmName() or "Unknown"
    local characterID = self:GetCurrentID()
    local aliases = self:BuildLegacyAliases(name, realm)

    -- ADDON_LOADED can run before UnitGUID is available.  When the player GUID
    -- arrives at PLAYER_LOGIN, promote the earlier fallback record instead of
    -- creating a second character.
    if string.sub(characterID, 1, 7) ~= "legacy:" and not store.byID[characterID] then
        for _, alias in ipairs(aliases) do
            local previousID = store.aliases[alias]
            if previousID and previousID ~= characterID then
                ReplaceCharacterID(store, previousID, characterID)
                break
            end
        end
    end

    local record = store.byID[characterID] or {}

    record.id = characterID
    record.name = name
    record.realm = realm
    record.class = select(2, UnitClass("player")) or "UNKNOWN"
    record.level = UnitLevel("player") or 1
    record.lastSeenAt = GetTimestamp()
    record.seenOrder = EnsureSeenOrder(store, characterID)
    store.byID[characterID] = record

    for _, alias in ipairs(aliases) do
        AddAlias(store, characterID, alias)
    end

    Core.Events:Fire("CHARACTER_UPDATED", characterID, Snapshot(record))
    return Snapshot(record)
end

function Characters:GetCurrent()
    return self:Get(self:GetCurrentID())
end

function Characters:Get(characterID)
    local store = GetStore()
    return store and Snapshot(store.byID[characterID]) or nil
end

function Characters:GetAll()
    local store = GetStore()
    local items = {}
    if not store then
        return items
    end

    for _, record in pairs(store.byID) do
        items[#items + 1] = Snapshot(record)
    end
    table.sort(items, function(left, right)
        if left.seenOrder ~= right.seenOrder then
            return (left.seenOrder or math.huge) < (right.seenOrder or math.huge)
        end
        return tostring(left.id) < tostring(right.id)
    end)
    return items
end

function Characters:ResolveLegacyKey(key)
    local store = GetStore()
    return store and store.aliases[key] or nil
end

function Characters:ImportLegacyCharacter(sourceAddon, legacyKey, data)
    local store = GetStore()
    if not store or type(data) ~= "table" then
        return nil, "无有效的角色数据。"
    end

    local characterID = self:ResolveLegacyKey(legacyKey)
    if not characterID then
        characterID = data.id or BuildFallbackID(data.name or legacyKey, data.realm)
    end

    local record = store.byID[characterID] or {}
    record.id = characterID
    record.name = data.name or record.name or legacyKey or "Unknown"
    record.realm = data.realm or record.realm or "Unknown"
    record.class = data.class or record.class or "UNKNOWN"
    record.level = tonumber(data.level) or record.level or 1
    record.lastSeenAt = tonumber(data.lastSeenAt) or record.lastSeenAt
    record.seenOrder = tonumber(data.seenOrder) or record.seenOrder or EnsureSeenOrder(store, characterID)
    record.sources = record.sources or {}
    record.sources[tostring(sourceAddon or "legacy")] = true
    store.byID[characterID] = record
    store.seenOrder[characterID] = record.seenOrder

    AddAlias(store, characterID, legacyKey)
    for _, alias in ipairs(self:BuildLegacyAliases(record.name, record.realm)) do
        AddAlias(store, characterID, alias)
    end

    Core.Events:Fire("CHARACTER_IMPORTED", characterID, tostring(sourceAddon or "legacy"), Snapshot(record))
    return characterID, Snapshot(record)
end

Core.Capabilities:Register("characters", 1)
