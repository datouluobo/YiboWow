local Addon, Core = _G.YiboCurrency, _G.YiboCore
local MAX_MONITORED = 16

local function Copy(entry) local result = {}; for key, value in pairs(entry) do result[key] = value end; return result end

function Addon:GetCatalog()
    local list, known = {}, {}
    for _, entry in ipairs(self.Catalog) do list[#list + 1] = entry; known[entry.id] = true end
    for _, entry in ipairs(self:GetSettings().customItems or {}) do
        local copy = Copy(entry); copy.id = "item:" .. tostring(copy.itemID); copy.source = "item"; copy.sourceType = "物品代币"
        copy.shortTitle = copy.shortTitle or copy.title; copy.expansion = copy.expansion or "自定义货币"; copy.status = copy.status or "当前可获取"; copy.totalAllowed = true
        if not known[copy.id] then list[#list + 1] = copy; known[copy.id] = true end
    end
    return list
end

function Addon:RegisterCatalogWithCore()
    if self._catalogRegistered or not Core.CurrencyCatalog then return end
    for _, entry in ipairs(self:GetCatalog()) do
        if entry.currencyID then Core.CurrencyCatalog:RegisterCurrency(self.NAME, entry)
        elseif entry.itemID then Core.CurrencyCatalog:RegisterItem(self.NAME, entry) end
    end
    self._catalogRegistered = true
    if Core.DataDomains then Core.DataDomains:Dispatch("YIBO_CURRENCY_CATALOG_REGISTERED") end
end

function Addon:AddCustomItem(itemID, expansion)
    itemID = tonumber(itemID)
    if not itemID or itemID <= 0 or itemID % 1 ~= 0 then return nil, "itemID 必须是正整数。" end
    local id = "item:" .. itemID
    for _, entry in ipairs(self:GetCatalog()) do if entry.id == id then return nil, "该 itemID 已在货币目录中。" end end
    local name, _, _, _, _, _, _, _, _, icon = GetItemInfo(itemID)
    if not name then return nil, "客户端尚未缓存该物品；请先在游戏内查看该物品后重试。" end
    local entry = { itemID = itemID, title = name, shortTitle = name, icon = icon, expansion = expansion or "自定义货币", source = "item", sourceType = "物品代币", status = "当前可获取", totalAllowed = true, verified = "client" }
    self:GetSettings().customItems[#self:GetSettings().customItems + 1] = entry
    if Core.CurrencyCatalog then Core.CurrencyCatalog:RegisterItem(self.NAME, entry) end
    return entry
end

function Addon:IsVisible(entry) return self:GetSettings().visible[entry.id] ~= false end
function Addon:SetVisible(entry, value) self:GetSettings().visible[entry.id] = not not value end
function Addon:IsMonitored(entry) return self:GetSettings().monitored[entry.id] == true end
function Addon:GetMonitoredCount() local count = 0; for _, entry in ipairs(self:GetCatalog()) do if self:IsMonitored(entry) then count = count + 1 end end; return count end

function Addon:SetMonitored(entry, value)
    local settings = self:GetSettings()
    if value and not self:IsMonitored(entry) and self:GetMonitoredCount() >= MAX_MONITORED then return false, "悬停监控最多 16 项。" end
    settings.monitored[entry.id] = not not value
    -- Selection alone must not silently convert the default global order into
    -- a custom order.  An override is created only by the explicit ↑/↓ tools.
    if not value and settings.hoverOrderOverride then
        for index = #settings.hoverOrderOverride, 1, -1 do if settings.hoverOrderOverride[index] == entry.id then table.remove(settings.hoverOrderOverride, index) end end
    end
    return true
end

function Addon:GetMonitoredCatalog()
    local all, byID = self:GetCatalog(), {}; for _, entry in ipairs(all) do byID[entry.id] = entry end
    local result, added, override = {}, {}, self:GetSettings().hoverOrderOverride
    if type(override) == "table" then for _, id in ipairs(override) do local entry = byID[id]; if entry and self:IsMonitored(entry) then result[#result + 1] = entry; added[id] = true end end end
    for _, entry in ipairs(all) do if self:IsMonitored(entry) and not added[entry.id] then result[#result + 1] = entry end end
    return result
end

function Addon:MoveMonitored(entryID, direction)
    local list = self:GetMonitoredCatalog(); local index
    for i, entry in ipairs(list) do if entry.id == entryID then index = i; break end end
    if not index then return end
    local target = index + direction; if target < 1 or target > #list then return end
    list[index], list[target] = list[target], list[index]
    local order = {}; for _, entry in ipairs(list) do order[#order + 1] = entry.id end
    self:GetSettings().hoverOrderOverride = order
end
function Addon:ResetHoverOrder() self:GetSettings().hoverOrderOverride = nil end

function Addon:GetIcon(entry)
    if entry.icon then return entry.icon end
    if entry.itemID and GetItemIcon then
        local icon = GetItemIcon(entry.itemID)
        if icon then return icon end
    end
    if entry.currencyID then
        local info = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo and C_CurrencyInfo.GetCurrencyInfo(entry.currencyID)
        if info and info.iconFileID then return info.iconFileID end
        if GetCurrencyInfo then
            local _, _, icon = GetCurrencyInfo(entry.currencyID)
            if icon then return icon end
        end
    end
    if entry.currencyID and Core.DataDomains then
        local current = Core.Characters:GetCurrent(); local snapshot = current and Core.DataDomains:Get(current.id, "economy")
        local info = snapshot and snapshot.data and snapshot.data.currencies and snapshot.data.currencies[entry.currencyID]
        if info and info.iconFileID then return info.iconFileID end
    end
    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

function Addon:GetValue(character, entry)
    local domainID = entry.source == "item" and "economy-items" or "economy"
    local snapshot = Core.DataDomains:Get(character.id, domainID)
    if not snapshot or snapshot.state ~= "known" then return nil, snapshot and snapshot.state or "not-yet-scanned" end
    if entry.source == "money" then return { quantity = snapshot.data and snapshot.data.money }, "known" end
    -- GetItemCount returns 0 even for arbitrary, unverified item IDs.  A zero
    -- must only become a balance after the item's client identity has been
    -- confirmed; otherwise the matrix would turn a missing probe into `0~`.
    if entry.source == "item" then
        if entry.verified == "pending-client" and GetItemInfo and GetItemInfo(entry.itemID) then entry.verified = "client" end
        if entry.verified ~= "client" and entry.verified ~= "implemented" then return nil, "unverified" end
        return snapshot.data and snapshot.data.items and snapshot.data.items[entry.itemID], "known"
    end
    if snapshot.data and snapshot.data.currencyState ~= "known" then return nil, snapshot.data.currencyState end
    local value = snapshot.data and snapshot.data.currencies and snapshot.data.currencies[entry.currencyID]
    -- A stable standard ID absent from an otherwise working currency API is
    -- unsupported by this client, not "not applicable" to every character.
    if not value then return nil, "unsupported" end
    return value, "known"
end

function Addon:ValueState(value, state)
    if state ~= "known" then return "unknown" end
    if not value then return "na" end
    if value.itemID and not value.bankKnown then return "bank" end
    if value.quantity == nil then return "na" end
    return "known"
end
function Addon:StateDescription(value, state)
    if state == "unverified" then return "目录尚未在目标客户端核验" end
    if state == "unsupported" then return "此客户端无法读取该稳定 ID" end
    if state == "not-yet-scanned" or state == "unsynced" then return "该角色尚未同步" end
    if state == "unavailable" then return "货币 API 当前不可用" end
    if state == "stale" then return "角色数据已过期" end
    if state == "error" then return "读取货币时发生错误" end
    if value and value.itemID and not value.bankKnown then return "银行尚未完整扫描" end
    return nil
end
function Addon:FormatCompact(value, entry)
    local quantity = entry and entry.source == "item" and (value.total or value.carried or value.quantity) or value and value.quantity
    quantity = tonumber(quantity); if quantity == nil then return "—" end
    if entry and entry.source == "money" then quantity = math.floor(quantity / 10000); return quantity >= 10000 and (string.format("%.1f万", quantity / 10000):gsub("%.0万$", "万")) or quantity >= 1000 and (string.format("%.1fk", quantity / 1000):gsub("%.0k$", "k")) or quantity end
    if quantity >= 10000 then return (string.format("%.1f万", quantity / 10000):gsub("%.0万$", "万")) end
    if quantity >= 1000 then return string.format("%.1fk", quantity / 1000):gsub("%.0k$", "k") end
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
    local weeklyCap = tonumber(value.maxWeeklyQuantity)
    if weeklyCap and weeklyCap > 0 then
        local earned = tonumber(value.weeklyQuantity) or 0
        return "本周 " .. BreakUpLargeNumbers(earned) .. " / " .. BreakUpLargeNumbers(weeklyCap)
    end
    -- Some MoP Classic currencies, including 战火徽记, expose their active
    -- cap through maxQuantity rather than maxWeeklyQuantity. It is a holding
    -- cap, so label it separately instead of claiming it is weekly progress.
    local holdingCap = tonumber(value.maxQuantity)
    if holdingCap and holdingCap > 0 then
        return "持有 " .. BreakUpLargeNumbers(tonumber(value.quantity) or 0) .. " / " .. BreakUpLargeNumbers(holdingCap)
    end
    return nil
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
            local quantity = entry.source == "item" and (value.total or value.carried) or value.quantity
            if quantity ~= nil then total = total + quantity; confirmed = confirmed + 1 end
            if kind == "bank" then bankPending = true end
        else missing = missing + 1 end
    end
    return { quantity = total, confirmed = confirmed, missing = missing, bankPending = bankPending, complete = missing == 0 and not bankPending }
end
