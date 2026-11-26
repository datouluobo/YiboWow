local Addon=_G.YiboBuilds
local Store={}; Addon.Store=Store
function Store:Plain(value) return not (type(issecretvalue)=="function" and issecretvalue(value)) end
function Store:Integer(value,min,max) return self:Plain(value) and type(value)=="number" and value>=min and value<=max and value%1==0 end
function Store:ConfigID(value) return self:Integer(value,1,2147483647) end
function Store:Valid(row)
    if type(row)~="table" or not self:Integer(row.observedAt,0,9007199254740991) or type(row.slots)~="table" then return false end
    local count=0
    for slot,item in pairs(row.slots) do
        if not self:Integer(slot,1,19) or type(item)~="table" or not self:Integer(item.itemID,0,2147483647)
            or not self:Plain(item.itemLink) or (item.itemLink~=nil and (type(item.itemLink)~="string" or item.itemLink=="" or item.itemID==0)) then return false end
        count=count+1
    end
    return count==19
end
local function CompleteEquipment(row)
    if not row then return end
    for _, item in ipairs(row.slots) do
        if item.itemID > 0 and not item.itemLink then return end
    end
    return row
end

local function SavedEquipment(entry)
    if entry.savedEquipment == nil then return CompleteEquipment(entry.equipment) end
    return entry.savedEquipment or nil
end

local function ItemPayload(link)
    return link and (link:match("|Hitem:([^|]+)|h") or link)
end
function Store:Initialize()
    local db=_G.YiboBuildsForeverDB
    if db~=nil then
        if type(db)~="table" or db.schema~=1 or type(db.clientScope)~="table" or db.clientScope.target~="Forever"
            or db.clientScope.projectID~=WOW_PROJECT_ID or db.clientScope.scope~="current-character" or type(db.characters)~="table"
            or type(db.settings)~="table" or type(db.settings.previewColumns)~="table" then return false end
        for id,row in pairs(db.characters) do if type(id)~="string" or not self:Valid(row) then return false end end
        if db.talents ~= nil then
            if type(db.talents) ~= "table" then return false end
            for id, row in pairs(db.talents) do
                if type(id) ~= "string" or not Addon.Talents:Valid(row) then return false end
            end
        end
        if db.configurations ~= nil then
            if type(db.configurations) ~= "table" then return false end
            for id, configs in pairs(db.configurations) do
                if type(id) ~= "string" or type(configs) ~= "table" or not self:ConfigID(configs.active)
                    or type(configs.entries) ~= "table" then return false end
                for configID, entry in pairs(configs.entries) do
                    if not self:ConfigID(configID) or type(entry) ~= "table"
                        or (entry.equipment ~= nil and not self:Valid(entry.equipment))
                        or (entry.talents ~= nil and not Addon.Talents:Valid(entry.talents))
                        or (entry.savedEquipment ~= nil and entry.savedEquipment ~= false
                            and not (self:Valid(entry.savedEquipment) and CompleteEquipment(entry.savedEquipment)))
                        or not (entry.equipment or entry.talents or entry.savedEquipment) then return false end
                end
                if not next(configs.entries) then return false end
            end
        end
    else
        db={schema=1,clientScope={target="Forever",projectID=WOW_PROJECT_ID,scope="current-character",rulesetState="unknown"},characters={},
            settings={previewColumns={slot=true,item=true}}}
    end
    self.db=db; _G.YiboBuildsForeverDB=db; return true
end
function Store:Configuration(id, mode)
    local configs = self.db.configurations and self.db.configurations[id]
    if not configs then return end
    if mode ~= "backup" then return configs.entries[configs.active], configs.active end
    local latest, chosen
    for configID, entry in pairs(configs.entries) do
        if configID ~= configs.active then
            local equipment = entry.equipment or SavedEquipment(entry)
            local observedAt = math.max(equipment and equipment.observedAt or 0,
                entry.talents and entry.talents.observedAt or 0)
            if not latest or observedAt > latest or (observedAt == latest and configID < chosen) then
                latest, chosen = observedAt, configID
            end
        end
    end
    if chosen then return configs.entries[chosen], chosen end
end

function Store:ReadSnapshot(id, kind, mode)
    local entry, configID = self:Configuration(id, mode)
    if configID then
        if entry and kind == "equipment" and (mode == "backup" or id ~= Addon.Core.Characters:GetCurrentID()) then
            return SavedEquipment(entry) or entry.equipment, configID
        end
        return entry and (entry[kind] or (kind == "equipment" and SavedEquipment(entry) or nil)), configID
    end
    if mode == "backup" then return end
    local records = kind == "equipment" and self.db.characters or self.db.talents
    return records and records[id]
end

function Store:HasSnapshot(id)
    return (self.db.configurations and self.db.configurations[id] ~= nil)
        or self:ReadSnapshot(id, "equipment") ~= nil or self:ReadSnapshot(id, "talents") ~= nil
end

function Store:SaveObservedEquipment(id)
    local entry = self:Configuration(id)
    local observed = entry and CompleteEquipment(entry.equipment)
    if not observed then return false end
    entry.savedEquipment = observed
    if self.changedSlots then self.changedSlots[id] = nil end
    return true
end

function Store:EquipmentSaveState(id, mode)
    local entry, configID = self:Configuration(id, mode)
    if not entry then return end
    local saved, observed = SavedEquipment(entry), entry.equipment
    if mode == "backup" or id ~= Addon.Core.Characters:GetCurrentID() or not Addon.Scanner.inWorld then
        return saved and "saved" or (observed and "pending"), configID
    end
    if not observed or self.error or self.freshID ~= id or self.freshConfig ~= configID then return end
    if not saved then return "pending", configID end
    local unreadable, changes = false, nil
    for slot, item in ipairs(observed.slots) do
        local before = saved.slots[slot]
        local changed = before.itemID ~= item.itemID
        if not changed and item.itemID > 0 then
            if not item.itemLink then unreadable = true
            else changed = ItemPayload(before.itemLink) ~= ItemPayload(item.itemLink) end
        end
        if changed then changes = changes or {}; changes[slot] = true end
    end
    if changes then return "changed", configID, changes end
    return unreadable and "incomplete" or "saved", configID
end

function Store:WriteSnapshot(id, kind, configID, row)
    if configID then
        local all = self.db.configurations or {}
        self.db.configurations = all
        local configs = all[id] or {entries={}}
        if configs.active and configs.active ~= configID then self:SaveObservedEquipment(id) end
        all[id] = configs
        local entry = configs.entries[configID] or {}
        configs.entries[configID] = entry
        if kind == "equipment" and entry.savedEquipment == nil then
            entry.savedEquipment = SavedEquipment(entry) or false
        end
        entry[kind] = row
        configs.active = configID
    else
        if self.db.configurations and self.db.configurations[id] then return false end
        local field = kind == "equipment" and "characters" or "talents"
        self.db[field] = self.db[field] or {}
        self.db[field][id] = row
    end
    return true
end

function Store:Get(id, mode)
    local row, configID=self:ReadSnapshot(id, "equipment", mode)
    local current = id == Addon.Core.Characters:GetCurrentID()
    local live = current and mode ~= "backup"
    local state=live and self.error and "error" or (row and
        (live and self.freshID==id and self.freshConfig==configID and Addon.Scanner.inWorld and "known" or "stale") or "unknown")
    return row and Addon.Core.Defaults:Copy(row) or nil,state
end
function Store:Commit(id,row,configID,saveNow)
    if id~=Addon.Core.Characters:GetCurrentID() or not self:Valid(row) then return false end
    local current = self:ReadSnapshot(id, "equipment")
    local configs = self.db.configurations and self.db.configurations[id]
    local entry = configs and configs.entries[configID]
    local previous = entry and entry.equipment or (configID == nil and current or nil)
    if not self:WriteSnapshot(id, "equipment", configID, Addon.Core.Defaults:Copy(row)) then return false end
    if self.freshConfig ~= configID and self.changedSlots then self.changedSlots[id] = nil end
    if previous then
        self.changedSlots = self.changedSlots or {}
        local changes = self.changedSlots[id] or {}
        self.changedSlots[id] = changes
        for slot, item in ipairs(row.slots) do
            local before = previous.slots[slot]
            if before.itemID ~= item.itemID or (before.itemLink and item.itemLink and ItemPayload(before.itemLink) ~= ItemPayload(item.itemLink)) then
                changes[slot] = true
            end
        end
    end
    local saved = saveNow and self:SaveObservedEquipment(id)
    self.freshID,self.freshConfig,self.error=id,configID,nil
    Addon:NotifyChanged()
    return true, saved
end
function Store:Delete(character,context)
    local id=character.id
    local now=GetServerTime and GetServerTime()
    local activeEquipment = self:ReadSnapshot(id, "equipment")
    local activeTalents = self:ReadSnapshot(id, "talents")
    local function DeleteRecord(records, key)
        key = key or id
        local row=records and records[key]
        if context and context.replay and type(row)=="table" and self:Integer(row.observedAt,0,9007199254740991)
            and self:Integer(context.deletedAt,0,9007199254740991)
            and self:Integer(now,0,9007199254740991) and row.observedAt>context.deletedAt and row.observedAt<=now then return false end
        if records then records[key]=nil end
        return true
    end
    DeleteRecord(self.db.characters)
    DeleteRecord(self.db.talents)
    local configs = self.db.configurations and self.db.configurations[id]
    if configs then
        for configID, entry in pairs(configs.entries) do
            local explicitSave = entry.savedEquipment ~= nil
            local removedEquipment = DeleteRecord(entry, "equipment")
            local removedTalents = DeleteRecord(entry, "talents")
            local removedSaved = not explicitSave or DeleteRecord(entry, "savedEquipment")
            if removedEquipment and removedTalents and removedSaved then configs.entries[configID] = nil
            elseif explicitSave and removedSaved then entry.savedEquipment = false end
        end
        if not next(configs.entries) then self.db.configurations[id] = nil end
    end
    if type(self.db.equipmentBaselines)=="table" then DeleteRecord(self.db.equipmentBaselines) end
    local equipmentDeleted = not activeEquipment or activeEquipment ~= self:ReadSnapshot(id, "equipment")
    local talentsDeleted = not activeTalents or activeTalents ~= self:ReadSnapshot(id, "talents")
    if equipmentDeleted and self.changedSlots then self.changedSlots[id] = nil end
    if id==Addon.Core.Characters:GetCurrentID() then
        if equipmentDeleted then Addon.Scanner:Cancel(); self.freshID,self.error=nil,nil end
        if talentsDeleted then Addon.Talents:Cancel() end
    end
    Addon:NotifyChanged(); return true
end
