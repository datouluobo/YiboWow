local Core = _G.YiboCore

-- Addons describe stable currency IDs and item-token IDs here.  Core keeps the
-- actual per-character facts in its neutral economy domains.
local Catalog = { _currencies = {}, _items = {} }
Core.CurrencyCatalog = Catalog

local function Register(bucket, owner, definition, kind)
    if type(owner) ~= "string" or owner == "" then return nil, Core:Text("CORE.CURRENCY_CATALOGS_MUST_DECLARE_OWNER") end
    if type(definition) ~= "table" or type(definition.id) ~= "string" or definition.id == "" then
        return nil, Core:Text("CORE.CURRENCY_CATALOG_ENTRIES_REQUIRE_A_STABLE_ID")
    end
    if bucket[definition.id] then return nil, kind .. Core:Text("CORE.IS_ALREADY_REGISTERED_BY") .. bucket[definition.id].owner .. Core:Text("CORE.PUNCTUATION") .. definition.id end
    bucket[definition.id] = { id = definition.id, owner = owner, title = definition.title, metadata = Core.Defaults:Copy(definition) }
    return bucket[definition.id]
end

function Catalog:RegisterCurrency(owner, definition)
    if not tonumber(definition and definition.currencyID) then return nil, Core:Text("CORE.STANDARD_CURRENCIES_REQUIRE_CURRENCYID") end
    definition.id = definition.id or ("currency:" .. tostring(definition.currencyID))
    return Register(self._currencies, owner, definition, Core:Text("CORE.STANDARD_CURRENCY"))
end

function Catalog:RegisterItem(owner, definition)
    if not tonumber(definition and definition.itemID) then return nil, Core:Text("CORE.ITEM_CURRENCIES_REQUIRE_ITEMID") end
    definition.id = definition.id or ("item:" .. tostring(definition.itemID))
    return Register(self._items, owner, definition, Core:Text("CORE.ITEM_CURRENCY"))
end

function Catalog:UnregisterItem(owner, itemID)
    local id = "item:" .. tostring(tonumber(itemID) or "")
    local entry = self._items[id]
    if not entry then return false, Core:Text("CORE.ITEM_CURRENCY_IS_NOT_IN_THE_CORE") end
    if entry.owner ~= owner then return false, Core:Text("CORE.ONLY_THE_REGISTERING_ADDON_CAN_REMOVE_THIS") end
    self._items[id] = nil
    return true
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
