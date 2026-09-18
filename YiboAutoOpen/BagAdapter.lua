local Addon = _G.YiboAutoOpen
local Bags = {}; Addon.BagAdapter = Bags
function Bags:GetNumSlots(bag) return C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerNumSlots(bag) or (GetContainerNumSlots and GetContainerNumSlots(bag)) or 0 end
function Bags:GetItemInfo(bag, slot)
    if C_Container and C_Container.GetContainerItemInfo then
        local info = C_Container.GetContainerItemInfo(bag, slot)
        if not info then return nil end
        local link = info.hyperlink or info.itemLink
        local itemID = info.itemID or (link and tonumber(link:match("item:(%d+)")))
        if not itemID and C_Container.GetContainerItemID then itemID = C_Container.GetContainerItemID(bag, slot) end
        if not link and C_Container.GetContainerItemLink then link = C_Container.GetContainerItemLink(bag, slot) end
        itemID = itemID or (link and tonumber(link:match("item:(%d+)")))
        return { itemID = itemID, link = link, locked = info.isLocked }
    end
    if GetContainerItemInfo then
        local texture, _, locked, _, _, _, link, _, _, itemID = GetContainerItemInfo(bag, slot)
        return texture and { itemID = itemID or (link and tonumber(link:match("item:(%d+)"))), link = link, locked = locked } or nil
    end
    -- Some Classic clients expose the C_Container slot ID/link helpers but
    -- not the full item-info table.  They are sufficient for an allowlisted
    -- catalog scan; lock/readable metadata is simply unavailable there.
    local itemID = C_Container and C_Container.GetContainerItemID and C_Container.GetContainerItemID(bag, slot)
    local link = C_Container and C_Container.GetContainerItemLink and C_Container.GetContainerItemLink(bag, slot)
    itemID = itemID or (link and tonumber(link:match("item:(%d+)")))
    return itemID and { itemID = itemID, link = link, locked = false } or nil
end
function Bags:CountCatalogued(entries)
    local count = 0
    for bag = 4, 0, -1 do for slot = 1, self:GetNumSlots(bag) do
        local item = self:GetItemInfo(bag, slot)
        if item and item.itemID and entries[item.itemID] and item.locked ~= true then count = count + 1 end
    end end
    return count
end
function Bags:UseItem(bag, slot) if C_Container and C_Container.UseContainerItem then return C_Container.UseContainerItem(bag, slot) end return UseContainerItem(bag, slot) end
function Bags:GetFreeSlots(bag)
    local free, family
    if C_Container and C_Container.GetContainerNumFreeSlots then
        free, family = C_Container.GetContainerNumFreeSlots(bag)
    elseif GetContainerNumFreeSlots then
        free, family = GetContainerNumFreeSlots(bag)
    end
    if free == nil then return nil, nil, false end
    return tonumber(free) or 0, family or 0, true
end
function Bags:GetGenericFreeSlots()
    local total, complete = 0, true
    for bag = 0, 4 do
        local free, family, known = self:GetFreeSlots(bag)
        if not known then complete = false elseif bag == 0 or family == 0 then total = total + free end
    end
    return total, complete
end
function Bags:GetTotalItemCount(itemID) return GetItemCount and GetItemCount(itemID, false, false, false, false) or 0 end
function Bags:GetCooldown(bag, slot, itemID)
    if C_Container and C_Container.GetContainerItemCooldown then
        return C_Container.GetContainerItemCooldown(bag, slot)
    end
    if GetContainerItemCooldown then return GetContainerItemCooldown(bag, slot) end
    if C_Item and C_Item.GetItemCooldown then return C_Item.GetItemCooldown(itemID) end
    if GetItemCooldown then return GetItemCooldown(itemID) end
    return 0, 0, 1
end
function Bags:FindNextEligible(entries, quarantined)
    -- The catalog is the explicit opt-in allowlist.  Some valid MoP containers
    -- (including Nomi's treats) do not expose hasLoot/isReadable, so those
    -- optional flags are intentionally ignored for catalogued items.
    local retryAfter
    local now = GetTime and GetTime() or 0
    for bag = 4, 0, -1 do for slot = self:GetNumSlots(bag), 1, -1 do
        local item = self:GetItemInfo(bag, slot)
        if item and item.itemID and entries[item.itemID] and not quarantined[item.itemID] then
            local manualOnly = Addon.Catalog and ((Addon.Catalog.IsManualOnly and Addon.Catalog:IsManualOnly(item.itemID)) or (Addon.Catalog.manualOnly and Addon.Catalog.manualOnly[item.itemID]))
            if manualOnly then
                -- This item remains in the catalog for visibility, but needs a player click.
            elseif item.locked == true then
                retryAfter = retryAfter and math.min(retryAfter, 0.5) or 0.5
            else
                local start, duration = self:GetCooldown(bag, slot, item.itemID)
                local readyAt = (start or 0) + (duration or 0)
                if not start or start == 0 or readyAt <= now then return bag, slot, item end
                local remaining = math.max(0.1, readyAt - now + 0.05)
                retryAfter = retryAfter and math.min(retryAfter, remaining) or remaining
            end
        end
    end end
    return nil, nil, nil, retryAfter
end
