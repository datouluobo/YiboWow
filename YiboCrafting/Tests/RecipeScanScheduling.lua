local handler, queue, reasons = nil, {}, {}
function CreateFrame()
    return { RegisterEvent = function() end, SetScript = function(_, _, callback) handler = callback end }
end
C_Timer = { After = function(_, callback) queue[#queue + 1] = callback end }
YiboCore = {}
YiboCrafting = {
    initialized = true,
    Collector = { Scan = function() end },
    RecipeStateScanner = { Start = function(_, reason) reasons[#reasons + 1] = reason end },
}
dofile("YiboCrafting/Bootstrap.lua")
local function Drain() while #queue > 0 do table.remove(queue, 1)() end end
handler(nil, "NEW_RECIPE_LEARNED")
handler(nil, "TRADE_SKILL_UPDATE")
handler(nil, "TRADE_SKILL_LIST_UPDATE")
Drain()
assert(#reasons == 1 and reasons[1] == "NEW_RECIPE_LEARNED", "coalescing must retain learning invalidation")
handler(nil, "SPELLS_CHANGED")
handler(nil, "TRADE_SKILL_UPDATE")
Drain()
assert(#reasons == 2 and reasons[2] == "SPELLS_CHANGED")
print("RecipeScanScheduling OK: event bursts retain spell-state invalidation")
