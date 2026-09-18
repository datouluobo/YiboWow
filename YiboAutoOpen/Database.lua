local Addon = _G.YiboAutoOpen
local Database = {}; Addon.Database = Database
local function CopyOrder(source) local result = {}; for i, id in ipairs(source) do result[i] = id end; return result end
local function BuildEntries(order) local entries = {}; for _, id in ipairs(order) do entries[id] = true end; return entries end
function Database:Normalize()
    local db = self.db
    for key, value in pairs(Addon.DEFAULTS) do if db[key] == nil then db[key] = value end end
    db.schemaVersion = 1; db.catalogVersion = math.max(1, math.floor(tonumber(db.catalogVersion) or 1))
    db.enabled = db.enabled ~= false; db.scanExistingOnLogin = db.scanExistingOnLogin ~= false; db.bindConfirmFollowCursor = db.bindConfirmFollowCursor ~= false
    db.minFreeSlots = math.max(Addon.LIMITS.minFreeSlots.min, math.min(Addon.LIMITS.minFreeSlots.max, math.floor(tonumber(db.minFreeSlots) or 5)))
    if db.notificationMode ~= "silent" and db.notificationMode ~= "issues" and db.notificationMode ~= "verbose" then db.notificationMode = "issues" end
    db.catalog = type(db.catalog) == "table" and db.catalog or {}; local clean, seen = {}, {}
    for _, id in ipairs(type(db.catalog.order) == "table" and db.catalog.order or {}) do id = tonumber(id); if id and id >= 1 and id == math.floor(id) and not seen[id] then clean[#clean + 1] = id; seen[id] = true end end
    db.catalog.order, db.catalog.entries = clean, BuildEntries(clean)
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
