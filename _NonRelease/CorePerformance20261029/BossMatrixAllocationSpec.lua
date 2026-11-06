-- Real Core copy function, AltoBoss catalog/Mists directory and cell renderer.
local baseline = arg and arg[1] == 'baseline'
local Boot = dofile('_NonRelease/CoreRetailR2/Harness.lua')
local env, core, fire, flush, load = Boot('Mists')
fire('ADDON_LOADED'); fire('PLAYER_LOGIN'); flush()
local bosses = {}
for _, key in ipairs({ 'ordos', 'celestials', 'nalak', 'oondasta', 'galleon', 'sha_of_anger' }) do
    bosses[#bosses + 1] = { key = key, name = key }
end
for i = 1, 3 do bosses[#bosses + 1] = { key = 'custom:' .. i, id = i, name = 'Custom ' .. i, isCustom = true } end
env.YAB = { CoreReady = true, GetAllBossList = function() return bosses end,
    ToggleBossKill = function() end, GetBossList = function() return bosses end }
env.YiboAltoBossDB = {}
local addon = env.YAB
load('YiboAltoBoss/Locale.lua'); load('YiboAltoBoss/LockoutLocale.lua')
load('YiboAltoBoss/Mists/RaidCatalog.lua')
addon.GetInstanceCatalog = function()
    local list = {}
    for mapID in pairs(addon.RaidCatalog) do list[#list + 1] = { mapID = mapID, name = 'Raid ' .. mapID, isRaid = true } end
    return list
end
load('YiboAltoBoss/Mists/TargetCatalogRuntime.lua')
load('YiboAltoBoss/Common/TargetCatalog.lua')
local catalog = addon.TargetCatalog
local definitions = catalog:Query().targets
local bindings = 0
addon.GoalTargets = { ref = 'fixture', Bind = function(_, cell, key, target, original)
    assert(type(target.catalogID) == 'string' and target.scope == 'all' and type(original) == 'function')
    bindings = bindings + 1
end }
load('YiboAltoBoss/AccountPage.lua')
local function Upvalue(fn, name)
    for i = 1, 100 do
        local key, value = debug.getupvalue(fn, i)
        if key == name then return value end
        if not key then break end
    end
    error('missing upvalue ' .. name)
end
local columns = Upvalue(addon.RefreshAccountPage, 'RefreshAccountPageByCharacterColumns')
local setStatus = Upvalue(columns, 'SetStatus')
local cell = core.UITheme:CreateButton(env.UIParent, 80, '')
local original, queries = catalog.Query, 0
catalog.Query = function(self) queries = queries + 1; return original(self) end
-- Warm native UI state and catalog before measuring refresh work.
setStatus(cell, 'available', 'Role', bosses[1]); bindings, queries = 0, 0
collectgarbage('collect'); collectgarbage('stop')
local before = collectgarbage('count')
for role = 1, 15 do
    for _, boss in ipairs(bosses) do setStatus(cell, 'available', 'Role' .. role, boss) end
end
local allocated = collectgarbage('count') - before
collectgarbage('restart')
print(string.format('catalog=%d targets; 15 roles x 9 bosses: full catalog copies=%d, cumulative allocation=%.1f KB', #definitions, queries, allocated))
assert(bindings == 135)
if not baseline then assert(queries == 0, 'matrix cell binding must not clone the full target directory') end
-- Index results retain the same first-match semantics as public sorted Query.
if not baseline then
    for _, boss in ipairs(bosses) do
        local expected
        for _, entry in ipairs(catalog:Query().targets) do if entry.bossKey == boss.key then expected = entry; break end end
        local indexed = catalog:GetByBossKey(boss.key)
        assert(indexed and expected and indexed.id == expected.id)
    end
    assert(catalog:GetByBossKey('missing') == nil)
    local snapshot = catalog:Query()
    snapshot.targets[1].name = 'changed'
    assert(catalog:Query().targets[1].name ~= 'changed', 'public Query remains isolated')
    local first = catalog:GetByBossKey('ordos')
    bosses[1].name = 'New name'
    catalog:Invalidate()
    assert(catalog:GetByBossKey('ordos').name == 'New name' and catalog:GetByBossKey('ordos') ~= first)
    local held = catalog:GetByBossKey('custom:3')
    table.remove(bosses)
    catalog:Invalidate()
    assert(held and catalog:GetByBossKey('custom:3') == nil, 'removed targets cannot survive invalidation')
end
print('PASS: actual cell binding, catalog ownership/isolation, first-match lookup, invalidation and removal')
