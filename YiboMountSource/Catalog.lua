local _, NS = ...

local data = NS.Data or {}
local mounts = data.mounts or {}
local mountKeyBySpellID = data.mountKeyBySpellID or {}

NS.Catalog = {}

function NS.Catalog:GetBySpellID(spellID)
    if type(spellID) ~= "number" then return nil end
    local mountKey = mountKeyBySpellID[spellID]
    return mountKey and mounts[mountKey] or nil
end

function NS.Catalog:GetByMountKey(mountKey)
    return type(mountKey) == "string" and mounts[mountKey] or nil
end

function NS.Catalog:IterateMounts()
    return pairs(mounts)
end

function NS.Catalog:GetPrimarySource(record)
    if type(record) ~= "table" or type(record.primarySourceID) ~= "string" then return nil end
    for _, source in ipairs(record.sources or {}) do
        if source.sourceID == record.primarySourceID then return source end
    end
    return nil
end
