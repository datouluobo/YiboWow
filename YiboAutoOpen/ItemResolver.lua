local Addon = _G.YiboAutoOpen
local Resolver = {}; Addon.ItemResolver = Resolver
function Resolver:Resolve(raw)
    local core = Addon.Core or _G.YiboCore
    if Addon.Target and Addon.Target.id == "Mists" and not (core and core.IsInitialized and core:IsInitialized() and core.HasCapability and core:HasCapability("item-resolver", 1)) then return Addon.LegacyItemResolver:Resolve(raw) end
    local candidates = core.ItemResolver:Parse(raw, { allowName = true, includeBags = true,
        candidates = function() return Addon.Database:GetOrderedItems() end })
    if not candidates or #candidates == 0 then return nil, "not_found" end
    if #candidates == 1 then return candidates[1].itemID end
    local ids = {}; for _, item in ipairs(candidates) do ids[#ids + 1] = item.itemID end
    return nil, "ambiguous", ids
end
function Resolver:GetInfo(id)
    local core = Addon.Core or _G.YiboCore
    if Addon.Target and Addon.Target.id == "Mists" and not (core and core.IsInitialized and core:IsInitialized() and core.ItemResolver) then return Addon.LegacyItemResolver:GetInfo(id) end
    return core.ItemResolver:GetInfo(id)
end
