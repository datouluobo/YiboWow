local Addon, Core = _G.YiboCurrency, _G.YiboCore

-- One read model is shared by surface sizing, rows, totals and row tooltips.
-- It lives only in Core's per-refresh context; no SavedVariables are added.
function Addon:GetCurrencyProjection(context, characters, entries)
    local projection = context.currencyProjection
    if projection then return projection end
    projection = { snapshots = {}, values = {}, totals = {} }
    context.currencyProjection = projection
    local itemIDs, seen = {}, {}
    for _, entry in ipairs(entries) do
        local itemID = tonumber(entry.itemID)
        if entry.source == "item" and itemID and itemID > 0 and itemID % 1 == 0 and not seen[itemID] then
            itemIDs[#itemIDs + 1], seen[itemID] = itemID, true
        end
    end
    for _, character in ipairs(characters) do
        projection.snapshots[character.id] = {
            economy = Core.DataDomains:Get(character.id, "economy"),
            ["economy-items"] = Core.DataDomains:Get(character.id, "economy-items"),
        }
    end
    projection.vault = self.GetVaultPersonalCounts and self:GetVaultPersonalCounts(characters, itemIDs)
    for _, entry in ipairs(entries) do
        local values = {}
        projection.values[entry.id] = values
        local total, confirmed, missing, bankPending = 0, 0, 0, false
        for _, character in ipairs(characters) do
            local value, state = self:GetValue(character, entry, projection)
            values[character.id] = { value = value, state = state }
            local kind = self:ValueState(value, state)
            if kind == "known" or kind == "bank" then
                local quantity = entry.source == "item" and (value.total or value.carried or value.quantity) or value.quantity
                if quantity ~= nil then total, confirmed = total + quantity, confirmed + 1 end
                if kind == "bank" then bankPending = true end
            else missing = missing + 1 end
        end
        projection.totals[entry.id] = { quantity = total, confirmed = confirmed,
            missing = missing, bankPending = bankPending, complete = missing == 0 and not bankPending }
    end
    return projection
end

function Addon:ProjectionValue(projection, character, entry)
    local cell = projection and projection.values[entry.id] and projection.values[entry.id][character.id]
    if cell then return cell.value, cell.state end
    if projection then return nil, "not-yet-scanned" end
    return self:GetValue(character, entry)
end

function Addon:ProjectionTotal(projection, characters, entry)
    return projection and projection.totals[entry.id] or self:TotalFor(characters, entry)
end
