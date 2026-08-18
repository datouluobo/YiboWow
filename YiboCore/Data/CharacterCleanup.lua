local Core = _G.YiboCore

local CharacterCleanup = {}
Core.CharacterCleanup = CharacterCleanup
CharacterCleanup._owners = CharacterCleanup._owners or {}
CharacterCleanup.MAX_HISTORY = 100
CharacterCleanup.EXPECTED_OWNERS = {
    YiboAltoBoss = "Boss 周常角色记录",
    YiboLegendary = "传说之路角色进度",
    YiboQuestBlocker = "任务屏蔽个人设置",
}

local function Copy(value)
    return Core.Defaults:Copy(value)
end

local function Timestamp()
    return (GetServerTime and GetServerTime()) or time()
end

local function History()
    local db = Core.Database:GetDB()
    db.characterDeletionHistory = type(db.characterDeletionHistory) == "table" and db.characterDeletionHistory or {}
    return db.characterDeletionHistory
end

local function CompactCharacter(character)
    return {
        id = character.id,
        name = character.name,
        realm = character.realm,
        class = character.class,
        level = character.level,
        lastSeenAt = character.lastSeenAt,
    }
end

local function SortedHistory()
    local records = {}
    for _, record in pairs(History()) do
        if type(record) == "table" and type(record.id) == "string" then records[#records + 1] = record end
    end
    table.sort(records, function(left, right)
        if (tonumber(left.deletedAt) or 0) ~= (tonumber(right.deletedAt) or 0) then
            return (tonumber(left.deletedAt) or 0) < (tonumber(right.deletedAt) or 0)
        end
        return tostring(left.id) < tostring(right.id)
    end)
    return records
end

local function PruneHistory()
    local records = SortedHistory()
    local removeCount = math.max(0, #records - CharacterCleanup.MAX_HISTORY)
    for _, record in ipairs(records) do
        if removeCount <= 0 then break end
        local safe = type(record.acknowledgedOwners) == "table"
        for addonName in pairs(CharacterCleanup.EXPECTED_OWNERS) do
            if not safe or record.acknowledgedOwners[addonName] ~= true then safe = false; break end
        end
        if safe and not next(record.failures or {}) then
            History()[record.id] = nil
            removeCount = removeCount - 1
        end
    end
end

local function CallOwner(owner, method, ...)
    local callback = owner and owner[method]
    if type(callback) ~= "function" then return nil, "数据所有者未提供 " .. tostring(method) .. "。" end
    local arguments = { ... }
    local unpackArguments = unpack or table.unpack
    local ok, first, second = xpcall(function() return callback(unpackArguments(arguments)) end, function(message) return tostring(message) end)
    if not ok then return nil, first end
    return first, second
end

function CharacterCleanup:GetOwners()
    local owners = {}
    for addonName, owner in pairs(self._owners) do owners[addonName] = owner end
    return owners
end

function CharacterCleanup:ProcessOwnerRecord(addonName, record)
    local owner = self._owners[addonName]
    if not owner or type(record) ~= "table" then return nil, "数据所有者当前不可用。" end
    record.acknowledgedOwners = type(record.acknowledgedOwners) == "table" and record.acknowledgedOwners or {}
    record.failures = type(record.failures) == "table" and record.failures or {}
    if record.acknowledgedOwners[addonName] == true then return true end
    local deleted, errorMessage = CallOwner(owner, "Delete", Copy(record.character), Copy(record.aliases or {}))
    if deleted == true then
        record.acknowledgedOwners[addonName] = true
        record.failures[addonName] = nil
        return true
    end
    errorMessage = tostring(errorMessage or "角色缓存删除失败。")
    record.failures[addonName] = errorMessage
    return nil, errorMessage
end

function CharacterCleanup:RegisterOwner(addonName, definition)
    if type(addonName) ~= "string" or addonName == "" or type(definition) ~= "table" then
        return nil, "角色数据所有者注册参数无效。"
    end
    if not (Core.Registry and Core.Registry:Get(addonName)) then
        return nil, "角色数据所有者所属插件尚未注册: " .. addonName
    end
    if type(definition.Inspect) ~= "function" or type(definition.Delete) ~= "function" then
        return nil, "角色数据所有者必须提供 Inspect 与 Delete。"
    end
    if self._owners[addonName] then return nil, "角色数据所有者已注册: " .. addonName end
    self._owners[addonName] = { addonName = addonName, Inspect = definition.Inspect, Delete = definition.Delete }
    self:RetryPending(addonName)
    return true
end

function CharacterCleanup:RetryPending(onlyAddonName)
    local processed, failed = 0, 0
    for _, record in ipairs(SortedHistory()) do
        for addonName in pairs(self._owners) do
            if not onlyAddonName or onlyAddonName == addonName then
                record.acknowledgedOwners = record.acknowledgedOwners or {}
                if record.acknowledgedOwners[addonName] ~= true then
                    local ok = self:ProcessOwnerRecord(addonName, record)
                    if ok then processed = processed + 1 else failed = failed + 1 end
                end
            end
        end
    end
    return processed, failed
end

function CharacterCleanup:GetImpact(characterID)
    local character = Core.Characters:Get(characterID)
    if not character then return nil, "角色缓存不存在。" end
    local aliases = Core.Characters:GetAliases(characterID)
    local impact = { character = character, aliases = aliases, owners = {} }
    for addonName, owner in pairs(self._owners) do
        local supplied, errorMessage = CallOwner(owner, "Inspect", Copy(character), Copy(aliases))
        if type(supplied) == "table" then
            impact.owners[addonName] = supplied
        else
            impact.owners[addonName] = { hasData = nil, label = addonName, error = tostring(errorMessage or "无法读取缓存摘要。") }
        end
    end
    for addonName, label in pairs(self.EXPECTED_OWNERS) do
        if not impact.owners[addonName] then
            impact.owners[addonName] = { hasData = nil, label = label, detail = "插件当前未加载；以后加载时清理" }
        end
    end
    return impact
end

function CharacterCleanup:CanDelete(characterID)
    return Core.Characters:CanDelete(characterID)
end

function CharacterCleanup:Delete(characterID)
    local canDelete, errorMessage = self:CanDelete(characterID)
    if not canDelete then return nil, errorMessage end
    local impact = self:GetImpact(characterID)
    if not impact then return nil, "无法读取角色缓存。" end

    local now = Timestamp()
    local deletionID = "delete:" .. tostring(now) .. ":" .. tostring(characterID)
    local suffix = 1
    while History()[deletionID] do
        suffix = suffix + 1
        deletionID = "delete:" .. tostring(now) .. ":" .. tostring(characterID) .. ":" .. suffix
    end
    local record = {
        id = deletionID,
        characterID = characterID,
        character = CompactCharacter(impact.character),
        aliases = Copy(impact.aliases),
        deletedAt = now,
        acknowledgedOwners = {},
        failures = {},
    }
    History()[deletionID] = record

    local result = { complete = true, owners = {}, deletionID = deletionID }
    local resultOwners = {}
    for addonName in pairs(self.EXPECTED_OWNERS) do resultOwners[addonName] = true end
    for addonName in pairs(self._owners) do resultOwners[addonName] = true end
    for addonName in pairs(resultOwners) do
        if self._owners[addonName] then
            local deleted, ownerError = self:ProcessOwnerRecord(addonName, record)
            result.owners[addonName] = deleted and { status = "deleted" } or { status = "pending", error = ownerError }
            if not deleted then result.complete = false end
        else
            result.owners[addonName] = { status = "pending", error = "插件当前未加载。" }
            result.complete = false
        end
    end

    local deletedCore, coreError = Core.Characters:DeleteCached(characterID)
    if not deletedCore then
        History()[deletionID] = nil
        return nil, coreError
    end
    PruneHistory()
    Core.Events:Fire("CHARACTER_CACHE_DELETED", characterID, Copy(record.character), Copy(result))
    return result
end

function CharacterCleanup:IsLegacyImportBlocked(sourceAddon, legacyKey, proposedID, data)
    local active = proposedID and Core.Characters:Get(proposedID)
    if active then return false end
    local aliases = {}
    if type(legacyKey) == "string" then aliases[legacyKey] = true end
    if type(data) == "table" and data.name and data.realm then
        for _, alias in ipairs(Core.Characters:BuildLegacyAliases(data.name, data.realm)) do aliases[alias] = true end
    end
    for _, record in ipairs(SortedHistory()) do
        if not Core.Characters:Get(record.characterID) then
            if proposedID and proposedID == record.characterID then return true, record end
            for alias in pairs(aliases) do
                if record.aliases and record.aliases[alias] then return true, record end
            end
        end
    end
    return false
end

Core.Capabilities:Register("character-cleanup", 1)
