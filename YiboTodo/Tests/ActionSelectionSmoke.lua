_G.YiboTodo = nil
dofile("YiboTodo/Namespace.lua")
dofile("YiboTodo/Actions.lua")

local Addon = _G.YiboTodo
Addon.Now = function() return 1000 end
Addon.Core = { Characters = { GetCurrent = function() return { id = "current" } end } }

local calls = {}
Addon.Actions.api = {
    castSpell = function(spellID) calls[#calls + 1] = "cast:" .. spellID; return true end,
    openProfession = function(professionID) calls[#calls + 1] = "open:" .. professionID; return true end,
    selectRecipe = function(_, action) calls[#calls + 1] = "select:" .. tostring(action.selectSpellID); return true end,
}

local direct = { monitoringGroupID = "profession-cooldown", state = "actionable", professionID = 202, action = { actionMode = "direct-craft", actionStatus = "live-verified", castSpellID = 139176, selectSpellID = 139176, professionID = 202 } }
assert(Addon.Actions:Execute(direct, true), "profession recipe opens the native panel")
assert(calls[1] == "open:202" and calls[2] == "select:139176", "engineering opens and selects its recipe identity")

local pending = { monitoringGroupID = "profession-cooldown", state = "actionable", professionID = 171, action = { actionMode = "direct-craft", actionStatus = "pending-live-action-test", castSpellID = 114780, selectSpellID = 114780, professionID = 171, members = { { actionStatus = "pending-live-action-test", castSpellID = 114780, selectSpellID = 114780, learned = true } } } }
assert(Addon.Actions:Execute(pending, true), "all cooldowns use the same native-panel path")
assert(calls[3] == "open:171" and calls[4] == "select:114780", "alchemy opens and selects its recipe identity")

local unavailable = { monitoringGroupID = "profession-cooldown", state = "cooldown", professionID = 197, action = { fallbackMode = "open-and-select-recipe", selectSpellID = 125557 } }
assert(Addon.Actions:Execute(unavailable, true), "unavailable project opens profession")
assert(calls[5] == "open:197" and calls[6] == "select:125557", "unavailable project opens and selects recipe")
assert(not Addon.Actions:Execute(direct, false), "remote character project is read-only")

print("YiboTodo action selection smoke passed")
