local Addon = _G.YiboCurrency

function Addon:MergeCatalog(builtins, customItems)
    local result, known = {}, {}
    for _, entry in ipairs(builtins or {}) do
        result[#result + 1] = entry
        known[entry.id] = true
    end
    for _, entry in ipairs(customItems or {}) do
        local copy = {}
        for key, value in pairs(entry) do copy[key] = value end
        copy.id = "item:" .. tostring(copy.itemID)
        copy.source = "item"
        copy.sourceType = self:T("CURRENCY.ITEM_TOKEN_1605F4")
        copy.shortTitle = copy.shortTitle or copy.title
        copy.expansion = copy.expansion or self:T("CURRENCY.CUSTOM_CURRENCY_72DBEB")
        copy.status = self:T("CURRENCY.OBTAINABLE_2BF203")
        copy.totalAllowed = true
        copy.isCustom = true
        if not known[copy.id] then
            result[#result + 1] = copy
            known[copy.id] = true
        end
    end
    return result
end

-- Compose target-owned native discoveries with money and item entries.  The
-- target supplies its own directory and item catalog; no cross-target state
-- or display preferences are changed by rebuilding this view.
function Addon:BuildDiscoveredCatalog(builtins, directory, customItems)
    local entries, nativeIDs = {}, {}
    for _, entry in ipairs(builtins or {}) do
        if entry.source ~= "currency" then entries[#entries + 1] = entry end
    end
    for id, row in pairs(directory or {}) do
        if type(id) == "number" and id > 0 and id % 1 == 0 and type(row) == "table"
            and row.id == id and type(row.name) == "string" and row.name ~= "" then
            nativeIDs[#nativeIDs + 1] = id
        end
    end
    table.sort(nativeIDs)
    for _, id in ipairs(nativeIDs) do
        local row = directory[id]
        entries[#entries + 1] = { id = "currency:" .. id, currencyID = id,
            title = row.name, shortTitle = row.name, icon = row.icon,
            source = "currency", sourceType = self:T("CURRENCY.STANDARD_CURRENCY_F0C941"),
            totalAllowed = false, verified = "client" }
    end
    return self:MergeCatalog(entries, customItems)
end

-- The caller owns the saved settings and Core main-view field state. Explicit
-- false remains false and absent hover choices do not change on discovery.
function Addon:BuildDisplayFields(catalog, visible, preview)
    local fields = {}
    for _, entry in ipairs(catalog or {}) do
        local id = entry.id
        if type(id) == "string" then
            fields[#fields + 1] = { id = id, title = entry.title or (entry.titleKey and self:T(entry.titleKey)), group = entry.expansion,
                defaultVisible = type(visible) ~= "table" or visible[id] ~= false,
                previewVisible = type(preview) == "table" and preview[id] == true or false }
        end
    end
    return fields
end
