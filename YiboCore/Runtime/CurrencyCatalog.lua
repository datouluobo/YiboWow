local Core = _G.YiboCore

-- Addons describe stable currency IDs and item-token IDs here.  Core keeps the
-- actual per-character facts in its neutral economy domains.
local Catalog = { _currencies = {}, _items = {} }
Core.CurrencyCatalog = Catalog

local function Register(bucket, owner, definition, kind)
    if type(owner) ~= "string" or owner == "" then return nil, "货币目录必须声明 owner。" end
    if type(definition) ~= "table" or type(definition.id) ~= "string" or definition.id == "" then
        return nil, "货币目录条目必须提供稳定 id。"
    end
    if bucket[definition.id] then return nil, kind .. " 已被 " .. bucket[definition.id].owner .. " 注册: " .. definition.id end
    bucket[definition.id] = { id = definition.id, owner = owner, title = definition.title, metadata = Core.Defaults:Copy(definition) }
    return bucket[definition.id]
end

function Catalog:RegisterCurrency(owner, definition)
    if not tonumber(definition and definition.currencyID) then return nil, "标准货币必须提供 currencyID。" end
    definition.id = definition.id or ("currency:" .. tostring(definition.currencyID))
    return Register(self._currencies, owner, definition, "标准货币")
end

function Catalog:RegisterItem(owner, definition)
    if not tonumber(definition and definition.itemID) then return nil, "物品代币必须提供 itemID。" end
    definition.id = definition.id or ("item:" .. tostring(definition.itemID))
    return Register(self._items, owner, definition, "物品代币")
end

local function Values(bucket)
    local result = {}
    for _, entry in pairs(bucket) do result[#result + 1] = Core.Defaults:Copy(entry.metadata) end
    table.sort(result, function(a, b) return a.id < b.id end)
    return result
end
function Catalog:GetCurrencies() return Values(self._currencies) end
function Catalog:GetItems() return Values(self._items) end

Core.Capabilities:Register("currency-catalog", 1)
