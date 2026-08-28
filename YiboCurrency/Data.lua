local Addon, Core = _G.YiboCurrency, _G.YiboCore

local function Copy(entry)
    local result = {}
    for key, value in pairs(entry) do result[key] = value end
    return result
end

function Addon:GetCatalog()
    local list, known = {}, {}
    for _, entry in ipairs(self.Catalog) do list[#list + 1] = entry; known[entry.id] = true end
    for _, entry in ipairs(self:GetSettings().customItems or {}) do
        local copy = Copy(entry); copy.id = "item:" .. tostring(copy.itemID); copy.source = "item"; copy.expansion = copy.expansion or "自定义货币"; copy.category = copy.category or "物品代币"
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
    -- Core collects PLAYER_LOGIN before dependent addons finish registering
    -- their catalog. Trigger a scoped second pass so the first page already
    -- has stable-ID balances after /reload.
    if Core.DataDomains then Core.DataDomains:Dispatch("YIBO_CURRENCY_CATALOG_REGISTERED") end
end

function Addon:AddCustomItem(itemID, expansion, category)
    itemID = tonumber(itemID)
    if not itemID or itemID <= 0 or itemID % 1 ~= 0 then return nil, "itemID 必须是正整数。" end
    local id = "item:" .. tostring(itemID)
    for _, entry in ipairs(self:GetCatalog()) do if entry.id == id then return nil, "该 itemID 已在货币目录中。" end end
    local name, _, _, _, _, _, _, _, _, icon = GetItemInfo(itemID)
    if not name then return nil, "客户端尚未缓存该物品；请先在游戏内查看该物品后重试。" end
    local entry = { itemID = itemID, title = name, icon = icon, expansion = expansion or "自定义货币", category = category or "物品代币", source = "item", verified = true }
    self:GetSettings().customItems[#self:GetSettings().customItems + 1] = entry
    if Core.CurrencyCatalog then Core.CurrencyCatalog:RegisterItem(self.NAME, entry) end
    return entry
end

function Addon:IsVisible(entry) return self:GetSettings().visible[entry.id] ~= false end
function Addon:SetVisible(entry, value) self:GetSettings().visible[entry.id] = not not value end
function Addon:IsMonitored(entry) return self:GetSettings().monitored[entry.id] == true end
function Addon:SetMonitored(entry, value) self:GetSettings().monitored[entry.id] = not not value end

function Addon:GetValue(character, entry)
    if entry.source == "money" then
        local snapshot = Core.DataDomains:Get(character.id, "economy")
        if not snapshot or snapshot.state ~= "known" then return nil, snapshot and snapshot.state or "not-yet-scanned" end
        return { quantity = snapshot.data and snapshot.data.money }, "known"
    elseif entry.source == "item" then
        local snapshot = Core.DataDomains:Get(character.id, "economy-items")
        if not snapshot or snapshot.state ~= "known" then return nil, snapshot and snapshot.state or "not-yet-scanned" end
        return snapshot.data and snapshot.data.items and snapshot.data.items[entry.itemID], "known"
    end
    local snapshot = Core.DataDomains:Get(character.id, "economy")
    if not snapshot or snapshot.state ~= "known" then return nil, snapshot and snapshot.state or "not-yet-scanned" end
    if snapshot.data and snapshot.data.currencyState ~= "known" then return nil, snapshot.data.currencyState end
    return snapshot.data and snapshot.data.currencies and snapshot.data.currencies[entry.currencyID], "known"
end

function Addon:FormatValue(value, state)
    if state ~= "known" then return ({ ["not-yet-scanned"]="未扫描", unavailable="不可用", stale="已过期", error="错误" })[state] or "未知" end
    if not value then return "—" end
    if value.itemID then
        if value.bankKnown then return BreakUpLargeNumbers(value.total or 0) end
        return BreakUpLargeNumbers(value.carried or 0) .. "（银行未扫描）"
    end
    if value.quantity == nil then return "—" end
    if value.quantity > 9999 and value.quantity % 10000 == 0 and value.itemID == nil then
        local gold = math.floor(value.quantity / 10000); local silver = math.floor((value.quantity % 10000) / 100); local copper = value.quantity % 100
        return string.format("%d金 %d银 %d铜", gold, silver, copper)
    end
    return BreakUpLargeNumbers(value.quantity)
end
