-- Run from the repository root with Lua 5.1.
local queue, calls, commits, notifications = {}, 0, {}, 0
local clock, domainAvailable, failID = 0, true, nil
local owned = { { id = 197 } }
local learned = { [1] = true }
function GetTime() clock = clock + 0.001; return clock end
function IsPlayerSpell(id)
    calls = calls + 1
    if id == failID then error("query failure") end
    return learned[id] == true
end
C_Timer = { After = function(_, callback) queue[#queue + 1] = callback end }
YiboCore = {
    Characters = { GetCurrentID = function() return "Player-test" end },
    DataDomains = { Get = function()
        if domainAvailable then return { state = "known", data = { professions = owned } } end
    end },
}
local recipes = {}
for id = 1, 230 do recipes[id] = {} end
YiboCrafting = {
    RecipeCatalog = { catalogVersion = "test-r1", professions = { [197] = recipes } },
    Store = { ApplyRecipeSpellSnapshot = function(_, characterID, professionID, states, version, count)
        assert(characterID == "Player-test" and professionID == 197 and count == 230)
        local actual = 0
        for _ in pairs(states) do actual = actual + 1 end
        assert(actual == count, "partial snapshots must never commit")
        commits[#commits + 1] = { states = states, version = version }
        return true, true
    end },
    NotifyPageChanged = function() notifications = notifications + 1 end,
}
dofile("YiboCrafting/RecipeStateScanner.lua")
local scanner = YiboCrafting.RecipeStateScanner
local function Drain()
    local limit = 0
    while #queue > 0 do
        limit = limit + 1; assert(limit < 100, "timer loop")
        table.remove(queue, 1)()
    end
end
scanner:Start("PLAYER_LOGIN")
assert(calls == 100 and #commits == 0)
scanner:Start("TRADE_SKILL_UPDATE")
Drain()
assert(calls == 230 and #commits == 1 and notifications == 1)
assert(commits[1].states[1] == true and commits[1].states[2] == false)
assert(scanner.lastScan.state == "complete" and scanner.lastScan.batches == 3)
for _ = 1, 30 do scanner:Start("TRADE_SKILL_LIST_UPDATE") end
assert(calls == 230, "filter/list updates must reuse the session scan")
learned[2] = true
scanner:Start("NEW_RECIPE_LEARNED"); Drain()
assert(#commits == 2 and commits[2].states[2] == true)
failID = 120
scanner:Start("TRADE_SKILL_SHOW"); Drain()
assert(scanner.lastScan.state == "failed" and #commits == 2)
failID = nil
YiboCrafting.RecipeCatalog.catalogVersion = "test-r2"
scanner:Start("TRADE_SKILL_UPDATE"); Drain()
assert(#commits == 3 and commits[3].version == "test-r2")
scanner:Start("SPELLS_CHANGED"); scanner:Cancel(); Drain()
assert(#commits == 3 and scanner.lastScan.state == "cancelled")
domainAvailable = false
scanner:Start("PLAYER_LOGIN")
domainAvailable = true
scanner:Start("SPELLS_CHANGED")
local before = calls
Drain()
assert(calls == before + 130 and #commits == 4, "stale retry must not restart a newer scan")
print("RecipeStateScanner OK: atomic snapshots, event reuse, learning refresh, failure retention, version change, cancellation and stale retry")
