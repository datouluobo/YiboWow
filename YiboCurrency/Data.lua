local Addon, Core = _G.YiboCurrency, _G.YiboCore
local function Copy(entry) local result = {}; for key, value in pairs(entry) do result[key] = value end; return result end

function Addon:GetCatalog()
    local list, known = {}, {}
    for _, entry in ipairs(self.Catalog) do list[#list + 1] = entry; known[entry.id] = true end
    for _, entry in ipairs(self:GetSettings().customItems or {}) do
        local copy = Copy(entry); copy.id = "item:" .. tostring(copy.itemID); copy.source = "item"; copy.sourceType = Addon:T("CURRENCY.ITEM_TOKEN_1605F4")
        copy.shortTitle = copy.shortTitle or copy.title; copy.expansion = copy.expansion or Addon:T("CURRENCY.CUSTOM_CURRENCY_72DBEB"); copy.status = Addon:T("CURRENCY.OBTAINABLE_2BF203"); copy.totalAllowed = true; copy.isCustom = true
        if not known[copy.id] then list[#list + 1] = copy; known[copy.id] = true end
    end
    return list
end

function Addon:GetCustomItem(itemID)
    itemID = tonumber(itemID)
    if not itemID then return nil end
    for _, entry in ipairs(self:GetSettings().customItems or {}) do
        if tonumber(entry.itemID) == itemID then return entry end
    end
end

function Addon:RemoveCustomItem(itemID)
    itemID = tonumber(itemID)
    if not itemID or itemID <= 0 or itemID % 1 ~= 0 then return nil, Addon:T("CURRENCY.ENTER_A_VALID_ITEMID_0CEB2F") end
    local settings = self:GetSettings()
    local found
    for index = #settings.customItems, 1, -1 do
        if tonumber(settings.customItems[index].itemID) == itemID then
            found = table.remove(settings.customItems, index)
            break
        end
    end
    if not found then return nil, Addon:T("CURRENCY.THIS_ITEMID_IS_NOT_IN_THE_CUSTOM_CATALOG_8F16E6") end

    local id = "item:" .. itemID
    settings.visible[id], settings.monitored[id] = nil, nil
    if settings.previewColumns then settings.previewColumns[id] = nil end
    if Core.AccountView and Core.AccountView.SetFieldVisible then Core.AccountView:SetFieldVisible("currency", id, true) end
    if settings.hoverOrderOverride then
        for index = #settings.hoverOrderOverride, 1, -1 do
            if settings.hoverOrderOverride[index] == id then table.remove(settings.hoverOrderOverride, index) end
        end
    end
    if self.Scanner and self.Scanner.frame then self.Scanner:Request("catalog") end
    return found
end

function Addon:AddCustomItem(itemID, expansion)
    itemID = tonumber(itemID)
    if not itemID or itemID <= 0 or itemID % 1 ~= 0 then return nil, Addon:T("CURRENCY.ITEMID_MUST_BE_A_POSITIVE_INTEGER_4A1D60") end
    local id = "item:" .. itemID
    for _, entry in ipairs(self:GetCatalog()) do if entry.id == id then return nil, Addon:T("CURRENCY.THIS_ITEMID_IS_ALREADY_IN_THE_CURRENCY_CATALOG_5C497A") end end
    local name, _, _, _, _, _, _, _, _, icon = GetItemInfo(itemID)
    if not name then return nil, Addon:T("CURRENCY.ITEM_DATA_IS_NOT_CACHED_INSPECT_THE_ITEM_IN_GAME_AND_RE_CA951B") end
    local entry = { itemID = itemID, title = name, shortTitle = name, icon = icon,
        expansion = expansion, expansionID = not expansion and "custom" or nil,
        source = "item", totalAllowed = true, verified = "client" }
    self:GetSettings().customItems[#self:GetSettings().customItems + 1] = entry
    entry.id = id
    if self.Scanner and self.Scanner.frame then self.Scanner:Request("catalog") end
    return entry
end

function Addon:GetFieldDefinitions()
    local fields = {}
    for _, entry in ipairs(self:GetCatalog()) do
        fields[#fields + 1] = { id = entry.id, title = entry.title, group = entry.expansion,
            defaultVisible = self:GetSettings().visible[entry.id] ~= false }
    end
    return fields
end
function Addon:IsVisible(entry)
    return Core.AccountView:GetFieldVisible("currency", entry.id)
end
function Addon:SetVisible(entry, value)
    Core.AccountView:SetFieldVisible("currency", entry.id, value)
end
function Addon:IsMonitored(entry) return self:GetSettings().previewColumns[entry.id] == true end
function Addon:GetMonitoredCount() return #self:GetMonitoredCatalog() end
function Addon:SetMonitored(entry, value)
    self:GetSettings().previewColumns[entry.id] = not not value
    self:NotifyChanged()
    return true
end
function Addon:GetMonitoredCatalog()
    local result = {}
    for _, entry in ipairs(self:GetCatalog()) do if self:IsMonitored(entry) then result[#result + 1] = entry end end
    return result
end
function Addon:GetDisplayCatalog(preview)
    if preview then return self:GetMonitoredCatalog() end
    local result = {}
    for _, entry in ipairs(self:GetCatalog()) do if self:IsVisible(entry) then result[#result + 1] = entry end end
    return result
end

function Addon:GetIcon(entry)
    if entry.icon then return entry.icon end
    if entry.itemID and GetItemIcon then
        local ok, icon = pcall(GetItemIcon, entry.itemID)
        if ok and icon then return icon end
    end
    if entry.currencyID then
        local ok, info
        if C_CurrencyInfo and type(C_CurrencyInfo.GetCurrencyInfo) == "function" then ok, info = pcall(C_CurrencyInfo.GetCurrencyInfo, entry.currencyID) end
        if ok and type(info) == "table" and info.iconFileID then return info.iconFileID end
        if GetCurrencyInfo then
            local worked, _, _, icon = pcall(GetCurrencyInfo, entry.currencyID)
            if worked and icon then return icon end
        end
    end
    if entry.currencyID and self.Store then
        local current = Core.Characters:GetCurrent({ identityOnly = true })
        local snapshot = current and self.Store:Get(current.id, "native")
        local info = snapshot and snapshot.data.currencies[entry.currencyID]
        if info and info.iconFileID then return info.iconFileID end
    end
    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

function Addon:GetValue(character, entry, projection)
    if not character or not entry then return nil, "not-yet-scanned" end
    local cached = projection and projection.snapshots[character.id]
    if entry.source == "item" then
        if entry.verified == "pending-client" and GetItemInfo and GetItemInfo(entry.itemID) then entry.verified = "client" end
        if entry.verified ~= "client" and entry.verified ~= "implemented" then return nil, "unverified" end
        local vault
        if projection then
            local row = projection.vault and projection.vault.characters[character.id]
            local item = row and row.items[entry.itemID]
            if item then vault = { carried = item.bags, bank = item.bank, equipped = item.equipment,
                bagsKnown = row.coverage.bags.hasSnapshot, bankKnown = row.coverage.bank.hasSnapshot,
                equipmentKnown = row.coverage.equipment and row.coverage.equipment.hasSnapshot or false } end
        else vault = self:GetVaultItemBalance(character, entry.itemID) end
        if vault and (vault.bagsKnown or vault.bankKnown or vault.equipmentKnown) then
            local carried, bank, equipped = vault.bagsKnown and vault.carried or nil, vault.bankKnown and vault.bank or nil, vault.equipmentKnown and vault.equipped or nil
            if carried ~= nil or bank ~= nil or equipped ~= nil then
                return { itemID = entry.itemID, carried = carried, bank = bank, equipped = equipped,
                    total = (carried or 0) + (bank or 0) + (equipped or 0), sourceID = "vault.items",
                    bankKnown = bank ~= nil, equipmentKnown = equipped ~= nil },
                    carried ~= nil and bank ~= nil and equipped ~= nil and "known" or "bank"
            end
        end
        local snapshot = cached and cached.carriedTokens or (not projection and self.Store:Get(character.id, "carriedTokens"))
        local item = snapshot and snapshot.data.items[entry.itemID]
        if not item then return nil, snapshot and snapshot.state ~= "partial" and snapshot.state ~= "known" and snapshot.state or "not-yet-scanned" end
        if snapshot.state ~= "known" and snapshot.state ~= "partial" and snapshot.state ~= "stale" then return nil, snapshot.state end
        return { itemID = entry.itemID, carried = item.carried, total = item.carried,
            bankKnown = false, equipmentKnown = false, sourceID = "currency.carried", observedAt = snapshot.observedAt },
            snapshot.state == "stale" and "historical" or "bank"
    end
    local snapshot = cached and cached.native or (not projection and self.Store:Get(character.id, "native"))
    if not snapshot then return nil, "not-yet-scanned" end
    if snapshot.state ~= "known" and snapshot.state ~= "stale" then return nil, snapshot.state end
    local state = snapshot.state == "stale" and "historical" or "known"
    if entry.source == "money" then
        if snapshot.data.moneyCopper == nil then return nil, "not-yet-scanned" end
        if snapshot.data.moneyState ~= "known" and snapshot.data.moneyState ~= "stale" then return nil, snapshot.data.moneyState or "unavailable" end
        return { quantity = snapshot.data.moneyCopper, observedAt = snapshot.observedAt, sourceID = "currency.native" }, state
    end
    local cell = snapshot.data.currencies[entry.currencyID]
    if not cell then return nil, "not-yet-scanned" end
    if cell.state ~= "known" and cell.state ~= "stale" then return nil, cell.state or "unavailable" end
    if cell.quantity == nil then return nil, "unavailable" end
    if cell.state == "stale" or (cell.observedAt and self.Store.Now() - cell.observedAt > self.Store.MAX_AGE) then state = "historical" end
    return Copy(cell), state
end

function Addon:ValueState(value, state)
    if state ~= "known" and state ~= "bank" and state ~= "historical" then return "unknown" end
    if not value then return "na" end
    if value.quantity == nil and value.total == nil and value.carried == nil then return "na" end
    return (state == "bank" or state == "historical") and "bank" or "known"
end
function Addon:StateDescription(value, state)
    if state == "historical" then return self:T("MIGRATION.HISTORICAL") end
    if state == "bank" and value and value.sourceID == "currency.carried" then return self:T("MIGRATION.CARRIED_ONLY") end
    if state == "unverified" then return Addon:T("CURRENCY.CATALOG_ENTRY_HAS_NOT_BEEN_VERIFIED_ON_THIS_CLIENT_10B736") end
    if state == "unsupported" then return Addon:T("CURRENCY.THIS_CLIENT_CANNOT_READ_THE_STABLE_ID_796174") end
    if state == "not-yet-scanned" or state == "unsynced" then return Addon:T("CURRENCY.CHARACTER_HAS_NOT_BEEN_SYNCED_D90186") end
    if state == "unavailable" then return Addon:T("CURRENCY.CURRENCY_API_IS_UNAVAILABLE_CC0295") end
    if state == "stale" then return Addon:T("CURRENCY.CHARACTER_DATA_IS_STALE_D8D851") end
    if state == "error" then return Addon:T("CURRENCY.CURRENCY_READ_FAILED_7E7AEA") end
    if state == "bank" then return Addon:T("CURRENCY.PERSONAL_INVENTORY_SOURCES_ARE_INCOMPLETE_F4E8EE") end
    return nil
end
function Addon:FormatCompact(value, entry)
    local quantity = value and (entry and entry.source == "item" and (value.total or value.carried or value.quantity) or value.quantity)
    quantity = tonumber(quantity); if quantity == nil then return "—" end
    if entry and entry.source == "money" then quantity = math.floor(quantity / 10000) end
    local language = Core.Locale:GetLanguage()
    local divisor, suffix
    if language == "zh" and quantity >= 10000 then divisor, suffix = 10000, Addon:T("FORMAT.TEN_THOUSAND")
    elseif language == "en" and quantity >= 1000000 then divisor, suffix = 1000000, "m"
    elseif quantity >= 1000 then divisor, suffix = 1000, "k" end
    if divisor then return (string.format("%.1f", quantity / divisor):gsub("%.0$", "")) .. suffix end
    return BreakUpLargeNumbers(quantity)
end
function Addon:FormatCell(value, state, entry)
    local kind = self:ValueState(value, state)
    if kind == "known" then return self:FormatCompact(value, entry), kind end
    if kind == "bank" then return self:FormatCompact(value, entry) .. "~", kind end
    return kind == "na" and "—" or "?", kind
end
function Addon:FormatExact(value, entry)
    local quantity = entry and entry.source == "item" and (value.total or value.carried or value.quantity) or value and value.quantity
    return quantity ~= nil and BreakUpLargeNumbers(quantity) or "—"
end
function Addon:FormatWeeklyProgress(value, entry)
    if not entry or not entry.currencyID or not value then return nil end
    local parts = {}
    local weeklyCap = tonumber(value.maxWeeklyQuantity)
    if weeklyCap and weeklyCap > 0 then
        local earned = tonumber(value.weeklyQuantity)
        parts[#parts + 1] = Addon:T("FORMAT.WEEKLY", earned ~= nil and BreakUpLargeNumbers(earned) or "?", BreakUpLargeNumbers(weeklyCap))
    end
    -- Some MoP Classic currencies, including 战火徽记, expose their active
    -- cap through maxQuantity rather than maxWeeklyQuantity. Keep this
    -- separate from weekly progress; a currency can expose both fields.
    local holdingCap = tonumber(value.maxQuantity)
    if holdingCap and holdingCap > 0 then
        local quantity = tonumber(value.quantity)
        parts[#parts + 1] = Addon:T("FORMAT.HOLDING", quantity ~= nil and BreakUpLargeNumbers(quantity) or "?", BreakUpLargeNumbers(holdingCap))
    end
    return #parts > 0 and table.concat(parts, " · ") or nil
end
function Addon:GetLimitState(value, entry)
    -- A holding or weekly cap is meaningful even when a currency is no longer
    -- obtainable.  For example, MoP Classic still exposes 正义点数的 4,000
    -- holding cap although the catalog labels it as a legacy balance.
    if not entry or entry.source ~= "currency" or not value then return nil end
    local ratio = 0
    local weeklyCap, weekly = tonumber(value.maxWeeklyQuantity), tonumber(value.weeklyQuantity)
    if weeklyCap and weeklyCap > 0 and weekly then ratio = math.max(ratio, weekly / weeklyCap) end
    local holdingCap, quantity = tonumber(value.maxQuantity), tonumber(value.quantity)
    if holdingCap and holdingCap > 0 and quantity then ratio = math.max(ratio, quantity / holdingCap) end
    if ratio >= 1 then return "capped" end
    if ratio >= 0.8 then return "near-cap" end
    return nil
end
function Addon:FormatLimitCell(value, state, entry, formatter)
    local text, kind = formatter(self, value, state, entry)
    return text, kind
end
function Addon:FormatFull(value, entry)
    local quantity = entry and entry.source == "item" and (value.total or value.carried or value.quantity) or value and value.quantity
    quantity = tonumber(quantity); if quantity == nil then return "—" end
    if entry and entry.source == "money" then return BreakUpLargeNumbers(math.floor(quantity / 10000)) end
    return BreakUpLargeNumbers(quantity)
end
function Addon:FormatFullCell(value, state, entry)
    local kind = self:ValueState(value, state)
    if kind == "known" then return self:FormatFull(value, entry), kind end
    if kind == "bank" then return self:FormatFull(value, entry) .. "~", kind end
    return kind == "na" and "—" or "?", kind
end

function Addon:TotalFor(characters, entry)
    local total, confirmed, missing, bankPending = 0, 0, 0, false
    for _, character in ipairs(characters or {}) do
        local value, state = self:GetValue(character, entry); local kind = self:ValueState(value, state)
        if kind == "known" or kind == "bank" then
            local quantity = entry.source == "item" and (value.total or value.carried or value.quantity) or value.quantity
            if quantity ~= nil then total = total + quantity; confirmed = confirmed + 1 end
            if kind == "bank" then bankPending = true end
        else missing = missing + 1 end
    end
    return { quantity = total, confirmed = confirmed, missing = missing, bankPending = bankPending, complete = missing == 0 and not bankPending }
end
