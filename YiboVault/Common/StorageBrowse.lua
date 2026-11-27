local Addon = _G.YiboVault
local Browse = {}
Addon.StorageBrowse = Browse
Browse.__index = Browse

function Browse:New(source)
    return setmetatable({ normal = { source = source } }, self)
end

function Browse:SetQuery(text)
    local query = (text or ""):match("^%s*(.-)%s*$"):lower()
    if query == "" then
        self.search = nil
    elseif not self.search then
        self.search = { owner = self.normal.owner, source = self.normal.source }
    end
    return query, self.search ~= nil
end

function Browse:Selection()
    return self.search or self.normal
end

function Browse:SelectOwner(key, resetSource)
    local selection = self:Selection()
    if resetSource then selection.source = nil end
    selection.owner = key
end

function Browse:SelectSource(source, enabled)
    local selection = self:Selection()
    if not enabled or selection.source == source then return false end
    selection.source = source
    return true
end

function Browse:ResolveOwner(selection, owners, byKey, fallback)
    return byKey[selection.owner] or byKey[fallback] or owners[1]
end

function Browse:ResolveSource(preferred, tabs, excluded)
    local first
    for _, tab in ipairs(tabs) do
        if tab.enabled and tab.id ~= excluded then
            if tab.id == preferred then return preferred end
            first = first or tab.id
        end
    end
    return first
end

function Browse:GroupRecords(records, transit, query, getName, sourceKey, allowedOwners)
    local byKey, ordered, names = {}, {}, {}
    local function AddRecords(entries)
        for _, record in ipairs(entries or {}) do
            local key = record.guildKey or record.characterID
            if key and (not allowedOwners or allowedOwners[key]) then
                local itemID = record.itemID
                local matches = query == "" or tostring(itemID):find(query, 1, true)
                if not matches then
                    local name = names[itemID]
                    if name == nil then
                        name = (getName(record) or ""):lower()
                        names[itemID] = name
                    end
                    matches = name:find(query, 1, true)
                end
                if matches then
                    local group = byKey[key]
                    if not group then
                        group = { id = key, guildKey = record.guildKey, guildName = record.guildName,
                            records = {}, bySource = {}, quantity = 0 }
                        byKey[key] = group
                        ordered[#ordered + 1] = group
                    end
                    group.records[#group.records + 1] = record
                    local source = sourceKey and sourceKey(record) or record.source
                    local bucket = group.bySource[source]
                    if not bucket then
                        bucket = {}
                        group.bySource[source] = bucket
                    end
                    bucket[#bucket + 1] = record
                    group.quantity = group.quantity + record.quantity
                end
            end
        end
    end
    AddRecords(records)
    AddRecords(transit)
    return byKey, ordered
end
