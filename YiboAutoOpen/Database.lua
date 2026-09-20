local Addon = _G.YiboAutoOpen
local Database = {}; Addon.Database = Database
local function CopyOrder(source) local result = {}; for i, id in ipairs(source) do result[i] = id end; return result end
local function BuildEntries(order) local entries = {}; for _, id in ipairs(order) do entries[id] = true end; return entries end
function Database:Normalize()
    local db = self.db
    local hadConfirmSources = type(db.confirmSourceOrder) == "table" and type(db.confirmSourceEntries) == "table"
    local savedConfirmSourceVersion = tonumber(db.confirmSourceVersion) or 1
    for key, value in pairs(Addon.DEFAULTS) do if db[key] == nil then db[key] = value end end
    db.schemaVersion = 1; db.catalogVersion = math.max(1, math.floor(tonumber(db.catalogVersion) or 1))
    db.confirmSourceVersion = math.max(1, math.floor(tonumber(db.confirmSourceVersion) or 1))
    db.enabled = db.enabled ~= false; db.scanExistingOnLogin = db.scanExistingOnLogin ~= false; db.bindConfirmFollowCursor = db.bindConfirmFollowCursor ~= false
    db.minFreeSlots = math.max(Addon.LIMITS.minFreeSlots.min, math.min(Addon.LIMITS.minFreeSlots.max, math.floor(tonumber(db.minFreeSlots) or 5)))
    if db.notificationMode ~= "silent" and db.notificationMode ~= "issues" and db.notificationMode ~= "verbose" then db.notificationMode = "issues" end
    db.catalog = type(db.catalog) == "table" and db.catalog or {}; local clean, seen = {}, {}
    for _, id in ipairs(type(db.catalog.order) == "table" and db.catalog.order or {}) do id = tonumber(id); if id and id >= 1 and id == math.floor(id) and not seen[id] then clean[#clean + 1] = id; seen[id] = true end end
    db.catalog.order, db.catalog.entries = clean, BuildEntries(clean)
    if not hadConfirmSources then
        db.confirmSourceOrder, db.confirmSourceEntries = {}, {}
        for _, key in ipairs(Addon.DEFAULTS.confirmSourceOrder) do
            local source = Addon.DEFAULTS.confirmSourceEntries[key]
            db.confirmSourceOrder[#db.confirmSourceOrder + 1] = key
            db.confirmSourceEntries[key] = { kind = source.kind, objectID = source.objectID, label = source.label }
        end
    elseif type(db.confirmSourceEntries) ~= "table" then
        db.confirmSourceEntries = {}
    end
    local sources, sourceSeen = {}, {}
    for _, key in ipairs(db.confirmSourceOrder) do
        if type(key) == "string" and db.confirmSourceEntries[key] and not sourceSeen[key] then
            sources[#sources + 1] = key; sourceSeen[key] = true
        end
    end
    db.confirmSourceOrder = sources
    if savedConfirmSourceVersion < 2 then
        db.confirmSourceEntries["object:210565"] = nil
        for index = #db.confirmSourceOrder, 1, -1 do
            if db.confirmSourceOrder[index] == "object:210565" then table.remove(db.confirmSourceOrder, index) end
        end
        db.confirmSourceVersion = 2
    end
end
function Database:MigrateCatalog()
    local db = self.db
    if #db.catalog.order == 0 and not db.catalogSeeded then db.catalog.order = CopyOrder(Addon.Catalog.defaultOrder); db.catalog.entries = BuildEntries(db.catalog.order); db.catalogSeeded = true end
    for _, migration in ipairs(Addon.Catalog.migrations) do
        if db.catalogVersion < migration.toVersion then for _, id in ipairs(migration.addedIDs) do self:AddItem(id) end; db.catalogVersion = migration.toVersion end
    end
    db.catalogVersion = math.max(db.catalogVersion, Addon.Catalog.version)
end
function Database:Initialize() self.db = type(YiboAutoOpenDB) == "table" and YiboAutoOpenDB or {}; YiboAutoOpenDB = self.db; self:Normalize(); self:MigrateCatalog(); Addon.db = self.db end
function Database:EnsureInitialized()
    if not self.db then Addon:Initialize() end
    return self.db
end
function Database:AddItem(itemID) self:EnsureInitialized(); itemID = tonumber(itemID); if not itemID or itemID < 1 or itemID ~= math.floor(itemID) then return nil, "invalid" end; if self.db.catalog.entries[itemID] then return nil, "already_exists" end; Addon:ResetItemRuntimeState(itemID); self.db.catalog.entries[itemID] = true; self.db.catalog.order[#self.db.catalog.order + 1] = itemID; return true end
function Database:RemoveItem(itemID) self:EnsureInitialized(); itemID = tonumber(itemID); if not self.db.catalog.entries[itemID] then return nil, "not_found" end; self.db.catalog.entries[itemID] = nil; for i = #self.db.catalog.order, 1, -1 do if self.db.catalog.order[i] == itemID then table.remove(self.db.catalog.order, i) end end; if Addon.Queue then Addon.Queue:CancelItem(itemID) end; Addon:ResetItemRuntimeState(itemID); return true end
function Database:GetOrderedItems() self:EnsureInitialized(); return CopyOrder(self.db.catalog.order) end
function Database:GetConfirmSources()
    self:EnsureInitialized()
    local result = {}
    for _, key in ipairs(self.db.confirmSourceOrder) do
        local source = self.db.confirmSourceEntries[key]
        if source then result[#result + 1] = { key = key, kind = source.kind, objectID = source.objectID, label = source.label, enabled = source.enabled ~= false } end
    end
    return result
end
function Database:IsConfirmSourceEnabled(key)
    self:EnsureInitialized()
    local source = self.db.confirmSourceEntries[key]
    return source ~= nil and source.enabled ~= false
end
function Database:HasConfirmSource(key)
    self:EnsureInitialized()
    return self.db.confirmSourceEntries[key] ~= nil
end
function Database:SetConfirmSourceEnabled(key, enabled)
    self:EnsureInitialized()
    local source = self.db.confirmSourceEntries[key]
    if not source then return nil, "not_found" end
    source.enabled = enabled ~= false
    return true
end
function Database:SetConfirmSourceLabel(key, label)
    self:EnsureInitialized()
    local source = self.db.confirmSourceEntries[key]
    label = type(label) == "string" and label:match("^%s*(.-)%s*$") or ""
    if not source then return nil, "not_found" end
    if label == "" then return nil, "invalid" end
    source.label = label
    return true
end
function Database:AddConfirmObject(raw, label)
    self:EnsureInitialized()
    local objectID = tonumber(raw)
    if not objectID or objectID < 1 or objectID ~= math.floor(objectID) then return nil, "invalid" end
    local key = "object:" .. objectID
    if self.db.confirmSourceEntries[key] then return nil, "already_exists" end
    self.db.confirmSourceEntries[key] = { kind = "object", objectID = objectID, label = label or ("拾取来源对象 #" .. objectID), enabled = true }
    self.db.confirmSourceOrder[#self.db.confirmSourceOrder + 1] = key
    return true
end
function Database:RemoveConfirmSource(key)
    self:EnsureInitialized()
    if key == "auto-open-catalog" then return nil, "builtin" end
    if not self.db.confirmSourceEntries[key] then return nil, "not_found" end
    self.db.confirmSourceEntries[key] = nil
    for index = #self.db.confirmSourceOrder, 1, -1 do
        if self.db.confirmSourceOrder[index] == key then table.remove(self.db.confirmSourceOrder, index) end
    end
    return true
end
