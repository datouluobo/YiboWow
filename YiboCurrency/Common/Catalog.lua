local Addon, Core = _G.YiboCurrency, _G.YiboCore

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
function Addon:BuildDiscoveredCatalog(builtins, directory, customItems, nativeCatalog)
    local entries, nativeIDs, known = {}, {}, {}
    for _, entry in ipairs(builtins or {}) do
        if entry.source ~= "currency" then
            local copy = {}
            for key, value in pairs(entry) do copy[key] = value end
            copy.title = copy.title or self:T(copy.titleKey)
            entries[#entries + 1] = copy
        end
    end
    for id, row in pairs(directory or {}) do
        if type(id) == "number" and id > 0 and id % 1 == 0 and type(row) == "table"
            and row.id == id and type(row.name) == "string" and row.name ~= "" then
            nativeIDs[#nativeIDs + 1] = id
            known[id] = row
        end
    end
    nativeCatalog = nativeCatalog or {}
    for id in pairs(nativeCatalog) do
        if not known[id] then nativeIDs[#nativeIDs + 1] = id end
    end
    table.sort(nativeIDs)
    for _, id in ipairs(nativeIDs) do
        local row, builtin = known[id], nativeCatalog[id]
        local title = row and row.name or self:T(builtin.titleKey)
        local icon = row and row.icon
        if not icon or icon == 0 then icon = builtin and builtin.icon end
        entries[#entries + 1] = { id = "currency:" .. id, currencyID = id,
            title = title, shortTitle = title, icon = icon,
            source = "currency", sourceType = self:T("CURRENCY.STANDARD_CURRENCY_F0C941"),
            totalAllowed = false, verified = row and "client" or "catalog" }
    end
    return self:MergeCatalog(entries, customItems)
end

function Addon:GetCatalogEntry(reference)
    local id = type(reference) == "table" and reference.id or reference
    for _, entry in ipairs(self:GetCatalog()) do if entry.id == id then return entry end end
end

function Addon:GetMonitoredCatalog()
    local result = {}
    for _, entry in ipairs(self:GetCatalog()) do if self:IsMonitored(entry) then result[#result + 1] = entry end end
    return result
end

function Addon:GetDisplayCatalog(preview, fields)
    if preview then return self:GetMonitoredCatalog() end
    local result, visible = {}, {}
    for _, field in ipairs(fields or Core.AccountView:GetVisibleFields("currency")) do visible[field.id] = true end
    for _, entry in ipairs(self:GetCatalog()) do if visible[entry.id] then result[#result + 1] = entry end end
    return result
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

function Addon:IsVisible(entry)
    return Core.AccountView:GetFieldVisible("currency", entry.id)
end
function Addon:SetCurrencyDisplay(reference, surface, visible)
    local entry = self:GetCatalogEntry(reference)
    if not entry then return false end
    if surface == "main" then
        Core.AccountView:SetFieldVisible("currency", entry.id, visible == true)
    elseif surface == "hover" then
        self:GetSettings().previewColumns[entry.id] = visible == true
        self:NotifyChanged()
    else return false end
    return true
end

function Addon:IsHoverTransposed()
    return self:GetSettings().hoverTranspose == true
end
