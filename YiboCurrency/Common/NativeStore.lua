-- Target databases remain separate; this shared object owns only the native
-- discovery subtable inside the database explicitly supplied by its caller.
local Addon = _G.YiboCurrency
local NativeStore = {}; NativeStore.__index = NativeStore
Addon.NativeStore = NativeStore

local function Copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, child in pairs(value) do result[key] = Copy(child) end
    return result
end

function NativeStore:New(db, identity, ready)
    assert(type(db) == "table" and type(identity) == "function" and type(ready) == "function")
    local existing = db.nativeDiscovery
    if existing ~= nil and (type(existing) ~= "table" or existing.schema ~= 1
        or type(existing.directory) ~= "table" or type(existing.characters) ~= "table") then return nil end
    return setmetatable({ db = db, identity = identity, ready = ready }, self)
end

function NativeStore:Load(id)
    if type(id) ~= "string" or id == "" then return nil end
    local root = self.db.nativeDiscovery
    if root == nil then return { directory = {}, snapshot = {} } end
    local character = root.characters[id]
    if character ~= nil and type(character) ~= "table" then return nil end
    return { directory = Copy(root.directory), snapshot = Copy(character or {}) }
end

function NativeStore:Commit(id, directory, snapshot)
    if type(id) ~= "string" or id == "" or type(directory) ~= "table" or type(snapshot) ~= "table"
        or not self.ready() or self.identity() ~= id then return false end
    local old = self.db.nativeDiscovery
    if old ~= nil and (type(old) ~= "table" or old.schema ~= 1
        or type(old.directory) ~= "table" or type(old.characters) ~= "table") then return false end
    local nextRoot = old and Copy(old) or { schema = 1, directory = {}, characters = {} }
    nextRoot.directory, nextRoot.characters[id] = Copy(directory), Copy(snapshot)
    if not self.ready() or self.identity() ~= id then return false end
    self.db.nativeDiscovery = nextRoot
    return true
end

function NativeStore:DeleteCharacter(id)
    if type(id) ~= "string" or not self.ready() then return false end
    local root = self.db.nativeDiscovery
    if not root or not root.characters[id] then return true end
    local nextRoot = Copy(root)
    nextRoot.characters[id] = nil
    self.db.nativeDiscovery = nextRoot
    return true
end

-- Import is additive and may only run after the target's identity and Core
-- guards succeed. Repeating it cannot overwrite a more recent observation.
function NativeStore:Import(expected, directory, snapshots)
    if type(expected) ~= "string" or expected == "" or type(directory) ~= "table"
        or type(snapshots) ~= "table" or not self.ready() or self.identity() ~= expected then return false end
    local old = self.db.nativeDiscovery
    if old ~= nil and (type(old) ~= "table" or old.schema ~= 1
        or type(old.directory) ~= "table" or type(old.characters) ~= "table") then return false end
    local nextRoot = old and Copy(old) or { schema = 1, directory = {}, characters = {} }
    for id, row in pairs(directory) do
        if not nextRoot.directory[id] then nextRoot.directory[id] = Copy(row) end
    end
    for id, snapshot in pairs(snapshots) do
        if type(id) ~= "string" or type(snapshot) ~= "table" then return false end
        local previous, newer = nextRoot.characters[id] or {}, {}
        for currencyID, candidate in pairs(snapshot) do
            local oldValue = previous[currencyID]
            if type(candidate) == "table" and (type(oldValue) ~= "table"
                or (type(candidate.observedAt) == "number" and type(oldValue.observedAt) == "number"
                    and candidate.observedAt > oldValue.observedAt)) then
                newer[currencyID] = candidate
            end
        end
        nextRoot.characters[id] = Addon.NativeDiscovery:MergeSnapshot(previous, newer)
    end
    if not self.ready() or self.identity() ~= expected then return false end
    self.db.nativeDiscovery = nextRoot
    return true
end
