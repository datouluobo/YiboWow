-- Retired in Core 1.12.4: kept for source history; not loaded by the TOC.
-- Currency owns collection. Frozen Core records remain available via DataDomains:Get.
do return end

local Core = _G.YiboCore

Core.Resources:Register("YiboCore", {
    id = "money", domain = "economy", kind = "currency", title = Core:Text("CORE.GOLD"),
    Read = function(data) return data and data.money end,
    Format = function(value) return value and tostring(value) or nil end,
})

Core.Locale:BindText(Core.Resources:Get("money"), "title", "CORE.GOLD")
