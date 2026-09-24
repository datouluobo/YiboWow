local _, NS = ...

local data = NS.Data or {}
local mounts = data.mounts or {}
local mountKeyBySpellID = data.mountKeyBySpellID or {}

-- MoP Classic can report the modern journal spell ID for Celestial Steed
-- while its supported tooltip record is keyed by the original spell ID.
-- Keep this client alias in runtime lookup without admitting the excluded
-- journal record into the player-facing catalogue.
local spellIDAliases = {
    [1239372] = 75614,
}

NS.Catalog = {}

function NS.Catalog:GetBySpellID(spellID)
    if type(spellID) ~= "number" then return nil end
    local mountKey = mountKeyBySpellID[spellID]
    if not mountKey then
        local canonicalSpellID = spellIDAliases[spellID]
        mountKey = canonicalSpellID and mountKeyBySpellID[canonicalSpellID]
    end
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

    local sources = {}
    for _, source in ipairs(record.sources or {}) do
        if source.active ~= false then
            table.insert(sources, source)
        end
    end

    -- Auction listings, particularly the Black Market Auction House, are
    -- fallback acquisition channels.  Keep them after direct routes even when
    -- a catalogue record happens to name one as its primary maintenance source.
    table.sort(sources, function(left, right)
        local leftIsAuction = left.type == "auction_house"
        local rightIsAuction = right.type == "auction_house"
        if leftIsAuction ~= rightIsAuction then return not leftIsAuction end

        local leftIsPrimary = left.sourceID == record.primarySourceID
        local rightIsPrimary = right.sourceID == record.primarySourceID
        if leftIsPrimary ~= rightIsPrimary then return leftIsPrimary end

        local leftPriority = tonumber(left.priority) or 0
        local rightPriority = tonumber(right.priority) or 0
        if leftPriority ~= rightPriority then return leftPriority > rightPriority end
        return tostring(left.sourceID or "") < tostring(right.sourceID or "")
    end)
    return sources
end
