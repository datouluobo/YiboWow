-- Run from repository root with Lua 5.1. Measures actual Core overview callbacks.
local calls = 0
YiboAltoBossDB = { knownChars = {}, characters = {} }
YiboCore = { Locale = { Get = function(_, _, key) return key == 'UI.BOSS_KILLS_D_D' and '%d/%d' or key end }, Characters = {
 ResolveLegacyKey = function(_, key) return key end, FormatName = function(_, c) return c.id end } }
local bosses, chars = {}, {}
for i=1,30 do bosses[i] = { key = tostring(i), name = tostring(i) } end
for i=1,20 do local id='C'..i; chars[i]={id=id}; YiboAltoBossDB.knownChars[id]={} end
YAB = { GetBossList = function() calls=calls+1; local list={}; for _, b in ipairs(bosses) do list[#list+1]=b end; table.sort(list,function(a,b) return a.key<b.key end); return list end,
 IsBossKilled = function() return false end, GetBossKillStatus = function() return 'killed' end }
dofile('YiboAltoBoss/CoreIntegration.lua')
local function upvalue(fn, wanted)
 for i=1,100 do local name,value=debug.getupvalue(fn,i); if not name then break end; if name==wanted then return value end end
 error('missing '..wanted)
end
local summary=upvalue(YAB.CoreIntegration.Initialize,'GetSummary')
local actions=upvalue(YAB.CoreIntegration.Initialize,'GetActions')
local start=os.clock()
for i=1,1000 do assert(summary(chars)=='0/600'); assert(#actions(chars)==0) end
print(string.format('overview: 1000 iterations, 20 characters, 30 bosses: %.3f s, GetBossList calls=%d',os.clock()-start,calls))
assert(calls == 2000, 'each callback builds the boss list once')
calls = 0
assert(summary({}) == '0/0' and #actions({}) == 0 and calls == 0, 'empty scope does not build a list')
YAB.GetBossKillStatus = function(_, key) return key == '1' and 'available' or 'killed' end
local result = actions(chars)
assert(#result == 20 and result[1].text == 'UI.AVAILABLE1', 'available action is preserved')
