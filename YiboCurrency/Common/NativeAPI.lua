-- Normalizes the currency APIs without owning timers, saved data or UI.
local Addon = _G.YiboCurrency
local NativeAPI = {}; NativeAPI.__index = NativeAPI
Addon.NativeAPI = NativeAPI

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local values = { pcall(fn, ...) }
    if not table.remove(values, 1) then return nil end
    return values
end

local function IsNumber(value)
    return not (type(issecretvalue) == "function" and issecretvalue(value)) and type(value) == "number"
end

function NativeAPI:New(api)
    return setmetatable({ api = api }, self)
end

-- Both verified targets expose this API family; target bootstrap remains
-- responsible for client identity and capability checks before invoking it.
function NativeAPI:ForClient(globals)
    local g = globals or _G
    local namespace = type(g.C_CurrencyInfo) == "table" and g.C_CurrencyInfo or {}
    return self:New({
        listSize = namespace.GetCurrencyListSize or g.GetCurrencyListSize,
        listInfo = namespace.GetCurrencyListInfo or g.GetCurrencyListInfo,
        listLink = namespace.GetCurrencyListLink or g.GetCurrencyListLink,
        detail = namespace.GetCurrencyInfo or g.GetCurrencyInfo,
    })
end

function NativeAPI:List()
    local api = self.api
    local count = Call(api.listSize)
    if not count or not IsNumber(count[1]) or count[1] < 0 or count[1] % 1 ~= 0 or type(api.listInfo) ~= "function" then
        return {}, false
    end
    local rows, complete = {}, count[1] <= 500
    for index = 1, math.min(count[1], 500) do
        local values = Call(api.listInfo, index)
        if not values then complete = false
        else
            local raw, name, icon, header, id = values[1]
            if type(raw) == "table" then
                name, icon, header, id = raw.name, raw.iconFileID, raw.isHeader, raw.currencyID
            else name, header, icon = raw, values[2], values[7] end
            if not header then
                local link = Call(api.listLink, index)
                if not (IsNumber(id) and id > 0) and link and type(link[1]) == "string" then
                    id = tonumber(link[1]:match("currency:(%d+)"))
                end
                if IsNumber(id) and id > 0 and type(name) == "string" and name ~= "" then
                    rows[#rows + 1] = { id = id, name = name, icon = icon }
                else complete = false end
            end
        end
    end
    return rows, complete
end

function NativeAPI:Detail(id)
    local values = Call(self.api.detail, id)
    if not values then return nil end
    local raw = values[1]
    if type(raw) == "table" then
        -- MoP has been observed returning currencyID=0 even for a successful
        -- query. A nonzero returned ID, when present, must still match.
        local returned = raw.currencyID
        if returned ~= nil and (not IsNumber(returned) or returned < 0 or returned % 1 ~= 0
            or (returned ~= 0 and returned ~= id)) then return nil end
        return { id = id, name = raw.name, icon = raw.iconFileID, quantity = raw.quantity }
    end
    return { id = id, name = raw, quantity = values[2], icon = values[3] }
end
