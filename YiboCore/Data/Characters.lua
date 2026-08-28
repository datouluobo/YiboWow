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

local function GetDisplayStore()
    local db = Core.Database:GetDB()
    if not db then return nil end
    db.characterDisplay = type(db.characterDisplay) == "table" and db.characterDisplay or {}
    return db.characterDisplay
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
        return false
    end

    local record = store.byID[oldID]
    record.id = newID
    store.byID[newID] = record
    store.byID[oldID] = nil

    store.seenOrder[newID] = store.seenOrder[oldID]
    store.seenOrder[oldID] = nil

    local display = GetDisplayStore()
    if display and display[oldID] and not display[newID] then display[newID] = display[oldID] end
    if display then display[oldID] = nil end

    for alias, characterID in pairs(store.aliases) do
        if characterID == oldID then
            store.aliases[alias] = newID
        end
    end
    Core.Events:Fire("CHARACTER_ID_CHANGED", oldID, newID, Snapshot(record))
    return true
end

local function NormalizeShortName(value)
    if value == nil then return "" end
    if type(value) ~= "string" then return nil, "短名必须是文本。" end
    value = value:match("^%s*(.-)%s*$")
    if value == "" then return "" end
    if value:find("[%z\1-\31\127]") then return nil, "短名不能包含控制字符。" end
    return value
end

function Characters:GetDisplayName(character, mode)
    local name = type(character) == "table" and character.name or ""
    if mode ~= "short" then return name end
    local display = character and character.id and GetDisplayStore()
    local shortName = display and display[character.id] and display[character.id].shortName
    return type(shortName) == "string" and shortName ~= "" and shortName or name
end

function Characters:SetShortName(characterID, value)
    local store = GetStore()
    if type(characterID) ~= "string" or not (store and store.byID[characterID]) then return nil, "角色缓存不存在。" end
    local normalized, errorMessage = NormalizeShortName(value)
    if normalized == nil then return nil, errorMessage end
    local display = GetDisplayStore()
    if normalized == "" then
        display[characterID] = nil
    else
        display[characterID] = display[characterID] or {}
        display[characterID].shortName = normalized
    end
    Core.Events:Fire("CHARACTER_DISPLAY_UPDATED", characterID, self:Get(characterID))
    return normalized
end

function Characters:GetShortNameDuplicates()
    local duplicates, grouped = {}, {}
    for _, character in ipairs(self:GetAll()) do
        local display = GetDisplayStore()
        local shortName = display and display[character.id] and display[character.id].shortName
        if type(shortName) == "string" and shortName ~= "" then
            grouped[shortName] = grouped[shortName] or {}
            grouped[shortName][#grouped[shortName] + 1] = character
        end
    end
    for shortName, characters in pairs(grouped) do if #characters > 1 then duplicates[shortName] = characters end end
    return duplicates
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

function Characters:GetAliases(characterID)
    local store, aliases = GetStore(), {}
    if not store then return aliases end
    for alias, resolvedID in pairs(store.aliases or {}) do
        if resolvedID == characterID then aliases[alias] = true end
    end
    return aliases
end

function Characters:CanDelete(characterID)
    local store = GetStore()
    if type(characterID) ~= "string" or characterID == "" then return false, "未选择角色。" end
    if characterID == self:GetCurrentID() then return false, "当前登录角色不能删除，请切换到其它角色后再删除。" end
    if not (store and store.byID and store.byID[characterID]) then return false, "角色缓存不存在。" end
    return true
end

function Characters:DeleteCached(characterID)
    local allowed, errorMessage = self:CanDelete(characterID)
    if not allowed then return nil, errorMessage end
    local db, store = Core.Database:GetDB(), GetStore()
    local deleted = Snapshot(store.byID[characterID])
    store.byID[characterID] = nil
    store.seenOrder[characterID] = nil
    local display = GetDisplayStore()
    if display then display[characterID] = nil end
    for alias, resolvedID in pairs(store.aliases or {}) do
        if resolvedID == characterID then store.aliases[alias] = nil end
    end
    local view = db.settings and db.settings.accountView
    if view then
        if view.hiddenCharacters then view.hiddenCharacters[characterID] = nil end
        if type(view.customCharacterOrder) == "table" then
            for index = #view.customCharacterOrder, 1, -1 do
                if view.customCharacterOrder[index] == characterID then table.remove(view.customCharacterOrder, index) end
            end
        end
    end
    return deleted
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

    local proposedID = data.id or self:ResolveLegacyKey(legacyKey)
    if Core.CharacterCleanup then
        local blocked = Core.CharacterCleanup:IsLegacyImportBlocked(sourceAddon, legacyKey, proposedID, data)
        if blocked then return nil, "该角色缓存已由用户删除，拒绝重新导入。" end
    end

    local characterID = self:ResolveLegacyKey(legacyKey)
    local resolved = characterID and store.byID[characterID] or nil
    if resolved and data.name and data.realm
        and (tostring(resolved.name) ~= tostring(data.name) or tostring(resolved.realm) ~= tostring(data.realm)) then
        -- An alias created from a reversed historical key may point at the
        -- wrong record.  Prefer an existing exact identity before creating a
        -- fallback record, and let AddAlias repair the alias below.
        characterID = nil
        for id, candidate in pairs(store.byID) do
            if tostring(candidate.name) == tostring(data.name) and tostring(candidate.realm) == tostring(data.realm) then
                characterID = id
                break
            end
        end
    end
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
