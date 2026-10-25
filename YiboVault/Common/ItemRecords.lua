local Addon = _G.YiboVault

local function ParseLink(link)
    if type(link) ~= "string" then return nil, nil end
    local linkType, payload = link:match("|H([^:|]+):([^|]+)|h")
    if not linkType then linkType, payload = link:match("^([^:|]+):([^|]+)$") end
    return linkType, payload
end

local function BuildRecord(source, character, container, slot, itemID, quantity, link)
    itemID = tonumber(itemID)
    quantity = tonumber(quantity)
    if not itemID or itemID <= 0 or not quantity or quantity <= 0 then return nil end
    local linkType, payload = ParseLink(link)
    local itemKey = "item:" .. itemID
    local variantKey = linkType and payload and ("link:" .. linkType .. ":" .. payload) or itemKey
    local observedAt, clockSource = Addon:Now()
    return {
        sourceID = source .. ":" .. character.id .. ":" .. tostring(container) .. ":" .. tostring(slot),
        source = source,
        sourceClass = "physical",
        itemID = itemID,
        itemLink = link,
        itemKey = itemKey,
        variantKey = variantKey,
        identityQuality = linkType and payload and "full-link" or "item-id-only",
        quantity = math.floor(quantity),
        characterID = character.id,
        realm = character.realm,
        location = { container = container, slot = slot },
        observedAt = observedAt,
        clockSource = clockSource,
        state = "observed",
    }
end

-- Shared record construction for target collectors; business-private, not a Core service.
Addon.BuildItemRecord = BuildRecord
