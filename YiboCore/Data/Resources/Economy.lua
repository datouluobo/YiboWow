local Core = _G.YiboCore

Core.Resources:Register("YiboCore", {
    id = "money", domain = "economy", kind = "currency", title = "金币",
    Read = function(data) return data and data.money end,
    Format = function(value) return value and tostring(value) or nil end,
})
