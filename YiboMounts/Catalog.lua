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

function NS.Catalog:GetTooltipSources(record)
    if type(record) ~= "table" then return {} end

    local primary = self:GetPrimarySource(record)
    local alternatives = {}
    for _, source in ipairs(record.sources or {}) do
        if source ~= primary and source.active ~= false then
            table.insert(alternatives, source)
        end
    end
    table.sort(alternatives, function(left, right)
        local leftPriority = tonumber(left.priority) or 0
        local rightPriority = tonumber(right.priority) or 0
        if leftPriority ~= rightPriority then return leftPriority > rightPriority end
        return tostring(left.sourceID or "") < tostring(right.sourceID or "")
    end)

    local ordered = {}
    if primary and primary.active ~= false then table.insert(ordered, primary) end
    for _, source in ipairs(alternatives) do table.insert(ordered, source) end
    return ordered
end
