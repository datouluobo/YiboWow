-- YiboCrafting Mists 1.3.0 / Forever 0.2.0 packaged replay (2026-11-22).
-- Run from repository root: lua _NonRelease/YiboCraftingRelease-20261122/PackagedReplay.lua
-- Loads the published Core ZIP contents (Core-<T>, Core13-<T>) and the addon ZIP
-- contents (Old-<T>, Clean-<T>, Overlay-<T>) in TOC order; synthetic client.
local Boot = dofile('_NonRelease/YiboCraftingRelease-20261122/PackagedHarness.lua')
local DIR = '_NonRelease/YiboCraftingRelease-20261122/'
local checks, counts = 0, {}
local function Check(value, label, group)
    checks = checks + 1; counts[group or 'misc'] = (counts[group or 'misc'] or 0) + 1
    assert(value, label)
end
local function Copy(v) if type(v) ~= 'table' then return v end; local r = {}; for k, x in pairs(v) do r[k] = Copy(x) end; return r end
local function HasMessage(env, pattern)
    for _, m in ipairs(env.TEST_MESSAGES) do if tostring(m):find(pattern) then return true end end
end
local versions = { Mists = '1.3.0', Forever = '0.2.0' }
local requiredAPI = { Mists = 14, Forever = 13 }
local coreVersions = { Mists = '1.13.0', Forever = '0.3.0' }
local stores = { Mists = 'YiboCraftingDB', Forever = 'YiboCraftingForeverDB' }
local otherSentinel = { Mists = { YiboCraftingForeverDB = { sentinel = 'forever' } }, Forever = { YiboCraftingDB = { sentinel = 'mists' } } }
local STAMP = 1792339000

-- Forever native profession fixture (same shape as _NonRelease/CraftingForever/Smoke.lua).
local function ForeverNative(env)
    env.IsLoggedIn = function() return true end
    env.GetProfessions = function() return 1, nil, 3, nil, nil, nil, 7 end
    env.GetProfessionInfo = function(index)
        local id = index == 1 and 197 or (index == 3 and 129 or 9123)
        return 'Profession' .. id, 1, 30, 75, nil, nil, id
    end
    env.ProfessionsFrame = { IsShown = function() return false end }
end
local fixtureGaps = {}
local function MistsNative(env)
    env.IsLoggedIn = function() return true end
    -- Fixture supplement: the shared FrameFixture lacks some widget methods used by
    -- the MoP page (EditBox:HasFocus, Button:Disable...).  Unknown methods become
    -- recorded no-ops so the page render check can run; names are reported.
    local methods = getmetatable(env.CreateFrame('Frame')).__index
    methods.HasFocus = methods.HasFocus or function(self) return self.focused == true end
    if not getmetatable(methods) then
        setmetatable(methods, { __index = function(_, name)
            if type(name) == 'string' and name:match('^[A-Z]') then fixtureGaps[name] = true; return function() end end
        end })
    end
end
local native = { Mists = MistsNative, Forever = ForeverNative }
local function Record(target, addon, id)
    if target == 'Mists' then
        local s = addon.Store:GetProfession(id, 171)
        return s and s.learnedRecipeIDs[2329] and s.learnedRecipeIDs[2330]
    end
    local c = addon.Store.db.characters[id]
    return c and c.professions[197] and c.professions[197].recipes[1001] and c.professions[197].recipes[1001].learned == true
end

-- 1. Previous-release store written by the previous package's own Store on its matching API13 Core.
local previous = {}
for _, target in ipairs({ 'Mists', 'Forever' }) do
    local r = Boot({ client = target, coreRoot = DIR .. 'Core13-' .. target, addonName = 'YiboCrafting',
        addonRoot = DIR .. 'Old-' .. target, saved = Copy(otherSentinel[target]), beforeAddon = native[target] })
    r.fire('PLAYER_ENTERING_WORLD')
    local addon, id = r.env.YiboCrafting, r.env.TEST_GUID
    Check(r.core.API_VERSION == 13 and addon.initialized, target .. ': previous release initializes on API13 Core', 'previous')
    if target == 'Mists' then
        Check(addon.Store:ApplyObservation(id, 171, { 2329, 2330 }, 'replay', 'partial'), 'Mists: previous release observation', 'previous')
        addon.Store.db.settings.previewColumns = { ['recipe-name'] = true }
    else
        Check(addon.Store:Commit(id, 197, { [1001] = { recipeID = 1001, name = 'Linen Tunic', learned = true, observedAt = STAMP } }, STAMP),
            'Forever: previous release observation', 'previous')
        addon.Store.db.settings.previewColumns.state = false
    end
    Check(Record(target, addon, id), target .. ': previous record readable', 'previous')
    previous[target] = { core = Copy(r.core.Database:GetDB()), addon = Copy(r.env[stores[target]]) }
end

local function Run(target, root, tag, coreRoot, coreLabel, upgrade)
    local saved = Copy(otherSentinel[target])
    local coreSaved
    if upgrade then saved[stores[target]] = Copy(previous[target].addon); coreSaved = Copy(previous[target].core) end
    local r = Boot({ client = target, coreRoot = coreRoot, coreSaved = coreSaved, addonName = 'YiboCrafting',
        addonRoot = root, saved = saved, beforeAddon = native[target] })
    local addon, core, env = r.env.YiboCrafting, r.core, r.env
    local t = tag .. coreLabel .. (upgrade and ' upgrade: ' or ' fresh: ')
    Check(addon.VERSION == versions[target], t .. 'package version ' .. tostring(addon.VERSION), 'init')
    Check(addon.initialized == true, t .. 'initialized: ' .. table.concat(env.TEST_MESSAGES, ' | '), 'init')
    Check(r.registrations.YiboCrafting == 1 and r.registrations.last.requiredAPI == requiredAPI[target], t .. 'registered once with requiredAPI ' .. requiredAPI[target], 'init')
    if upgrade then
        Check(Record(target, addon, env.TEST_GUID), t .. 'previous recipe record kept', 'saved')
        if target == 'Mists' then
            Check(addon.Store.db.settings.previewColumns['recipe-name'] == true and addon.Store.db.settings.previewColumns['recipe-state'] == nil, t .. 'previous settings kept', 'saved')
        else
            Check(addon.Store.db.settings.previewColumns.state == false, t .. 'previous settings kept', 'saved')
        end
    end
    r.fire('ADDON_LOADED', 'YiboCrafting'); r.fire('PLAYER_LOGIN'); core.Events:Fire('CORE_READY'); core:Initialize()
    r.fire('PLAYER_ENTERING_WORLD')
    Check(r.registrations.YiboCrafting == 1 and addon:Initialize(), t .. 'repeat ADDON_LOADED/PLAYER_LOGIN/CORE_READY keeps one registration', 'init')
    for name, value in pairs(otherSentinel[target]) do
        Check(env[name].sentinel == value.sentinel and next(env[name], next(env[name])) == nil, t .. 'other target store untouched', 'init')
    end
    core.AccountView:ShowPage('crafting')
    Check(not core.AccountView._pages.crafting.lastError, t .. 'page renders: ' .. tostring(core.AccountView._pages.crafting.lastError), 'init')
    Check(#env.TEST_MESSAGES == 0, t .. 'no messages/callback failures: ' .. table.concat(env.TEST_MESSAGES, ' | '), 'init')
    local reload = Boot({ client = target, coreRoot = coreRoot, coreSaved = Copy(core.Database:GetDB()), addonName = 'YiboCrafting',
        addonRoot = root, saved = { [stores[target]] = Copy(env[stores[target]]) }, beforeAddon = native[target] })
    Check(reload.env.YiboCrafting.initialized and reload.registrations.YiboCrafting == 1, t .. 'reload initializes once', 'saved')
    if upgrade then Check(Record(target, reload.env.YiboCrafting, reload.env.TEST_GUID), t .. 'reload restores record', 'saved') end
end

for _, target in ipairs({ 'Mists', 'Forever' }) do
    for _, kind in ipairs({ 'Clean', 'Overlay' }) do
        local root = DIR .. kind .. '-' .. target
        local tag = target .. '/' .. kind .. ' '
        for _, upgrade in ipairs({ false, true }) do
            Run(target, root, tag, DIR .. 'Core-' .. target, 'Core ' .. coreVersions[target], upgrade)
        end
        do
            local r = Boot({ client = target, coreRoot = DIR .. 'Core-' .. target, addonName = 'YiboCrafting', addonRoot = root })
            Check(r.core.VERSION == coreVersions[target] and r.core.API_VERSION == 14 and r.core:HasCapability('pixel-line', 1), tag .. 'published Core API14', 'init')
        end
        -- Wrong target: this package on the other declared client with that client's Core.
        local wrong = target == 'Mists' and 'Forever' or 'Mists'
        local w = Boot({ client = wrong, coreRoot = DIR .. 'Core-' .. wrong, addonName = 'YiboCrafting', addonRoot = root,
            saved = { [stores[wrong]] = { sentinel = 'own' } }, beforeAddon = native[wrong] })
        w.fire('PLAYER_ENTERING_WORLD')
        Check(w.env[stores[target]] == nil, tag .. 'on ' .. wrong .. ' does not create ' .. stores[target], 'wrong')
        Check(w.env[stores[wrong]].sentinel == 'own' and next(w.env[stores[wrong]], next(w.env[stores[wrong]])) == nil, tag .. 'on ' .. wrong .. ' leaves that client store untouched', 'wrong')
        Check(not w.registrations.YiboCrafting and not w.env.YiboCrafting.initialized, tag .. 'on ' .. wrong .. ' stops before registration', 'wrong')
        if target == 'Mists' then
            -- API13 Core (previous published Mists Core) is refused with the upgrade text.
            local o = Boot({ client = target, coreRoot = DIR .. 'Core13-' .. target, addonName = 'YiboCrafting', addonRoot = root,
                saved = Copy(otherSentinel[target]), beforeAddon = native[target] })
            Check(o.core.API_VERSION == 13 and o.core:IsInitialized(), tag .. 'API13 Core is ready', 'api13')
            Check(not o.env.YiboCrafting.initialized and not o.registrations.YiboCrafting, tag .. 'API13 Core refused before registration', 'api13')
            Check(o.env.YiboCraftingDB == nil, tag .. 'API13 refusal does not create the business store', 'api13')
            Check(HasMessage(o.env, 'API14') or HasMessage(o.env, '1%.13'), tag .. 'upgrade message: ' .. table.concat(o.env.TEST_MESSAGES, ' | '), 'api13')
        else
            -- Forever keeps minimum API13: also runs on the previous published Forever Core 0.2.4 (API13).
            for _, upgrade in ipairs({ false, true }) do
                Run(target, root, tag, DIR .. 'Core13-' .. target, 'Core 0.2.4/API13', upgrade)
            end
        end
    end
end
local order = { 'previous', 'init', 'saved', 'wrong', 'api13' }
local parts = {}
for _, k in ipairs(order) do parts[#parts + 1] = k .. '=' .. tostring(counts[k] or 0) end
local gapNames = {}
for name in pairs(fixtureGaps) do gapNames[#gapNames + 1] = name end
table.sort(gapNames)
print('PASS YiboCrafting packaged replay: ' .. checks .. ' checks (' .. table.concat(parts, ', ') .. '); Mists fixture no-op methods: ' .. (#gapNames > 0 and table.concat(gapNames, ',') or 'none'))
