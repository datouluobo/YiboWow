-- YiboReputation Mists 1.8.0 / Forever 0.2.0 packaged replay (2026-11-22).
-- Run from repository root: lua _NonRelease/YiboReputationRelease-20261122/PackagedReplay.lua
-- Loads the published Core ZIP contents (Core-<T>, Core13-<T>) and the addon ZIP
-- contents (Old-<T>, Clean-<T>, Overlay-<T>) in TOC order; synthetic client.
local Boot = dofile('_NonRelease/YiboReputationRelease-20261122/PackagedHarness.lua')
local DIR = '_NonRelease/YiboReputationRelease-20261122/'
local checks, counts = 0, {}
local function Check(value, label, group)
    checks = checks + 1; counts[group or 'misc'] = (counts[group or 'misc'] or 0) + 1
    assert(value, label)
end
local function Copy(v) if type(v) ~= 'table' then return v end; local r = {}; for k, x in pairs(v) do r[k] = Copy(x) end; return r end
local function Serialize(value)
    if type(value) == 'string' then return string.format('%q', value) end
    if type(value) ~= 'table' then return tostring(value) end
    local keys, parts = {}, { '{' }
    for k in pairs(value) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    for _, k in ipairs(keys) do parts[#parts + 1] = '[' .. Serialize(k) .. ']=' .. Serialize(value[k]) .. ',' end
    return table.concat(parts) .. '}'
end
local function HasMessage(env, pattern)
    for _, m in ipairs(env.TEST_MESSAGES) do if tostring(m):find(pattern) then return true end end
end
local versions = { Mists = '1.8.0', Forever = '0.2.0' }
local coreVersions = { Mists = '1.13.0', Forever = '0.3.0' }
local stores = { Mists = 'YiboReputationDB', Forever = 'YiboReputationForeverDB' }
local otherSentinel = { Mists = { YiboReputationForeverDB = { sentinel = 'forever' } }, Forever = { YiboReputationDB = { sentinel = 'mists' } } }

-- Native reputation fixtures for each client.
local function MistsNative(value)
    return function(env)
        env.IsLoggedIn = function() return true end
        env.GetNumFactions = function() return 2 end
        env.GetFactionInfo = function(index)
            if index == 1 then return 'Pandaria', '', 0, 0, 0, 0, false, false, true, false, false, false, false, 1245 end
            return 'Shado-Pan', '', 5, 3000, 9000, value, false, true, false, false, true, false, true, 1270
        end
        env.GetFactionInfoByID = function(id) if id == 1270 then return env.GetFactionInfo(2) end end
    end
end
local function ForeverNative(value)
    return function(env)
        env.IsLoggedIn = function() return true end
        local row = { factionID = 72, name = 'Stormwind', reaction = 5, currentReactionThreshold = 3000,
            nextReactionThreshold = 9000, currentStanding = value, isHeader = false, isHeaderWithRep = false, isAccountWide = false }
        env.C_Reputation = { GetNumFactions = function() return 1 end, GetFactionDataByIndex = function() return row end,
            GetFactionDataByID = function(id) if id == 72 then return row end end }
    end
end
local native = { Mists = MistsNative, Forever = ForeverNative }

local function Initialized(target, addon)
    if target == 'Mists' then return addon and addon.CoreIntegration and addon.CoreIntegration.initialized == true end
    return addon and addon.initialized == true
end

-- 1. Previous-release store: the previous package on its matching published API13 Core.
local previous = {}
for _, target in ipairs({ 'Mists', 'Forever' }) do
    local saved = Copy(otherSentinel[target])
    local r = Boot({ client = target, coreRoot = DIR .. 'Core13-' .. target, addonName = 'YiboReputation',
        addonRoot = DIR .. 'Old-' .. target, saved = saved, beforeAddon = native[target](4500) })
    r.fire('PLAYER_ENTERING_WORLD'); r.flush()
    local addon = r.env.YiboReputation
    Check(r.core.API_VERSION == 13 and Initialized(target, addon), target .. ': previous release initializes on API13 Core', 'previous')
    if target == 'Mists' then
        local snap = addon:GetSnapshot(r.env.TEST_GUID)
        Check(snap and snap.data.factions[1270].value == 4500, 'Mists: previous release recorded a reputation snapshot', 'previous')
        local s = addon:GetSettings(); s.monitoredFactionIDs[1] = 1270; s.showFriendshipTotal = true
    else
        Check(addon.Store:Get(r.env.TEST_GUID).factions[72].value == 4500, 'Forever: previous release recorded a reputation snapshot', 'previous')
        Check(addon.Store:ToggleWatched(r.env.TEST_GUID, 72), 'Forever: previous release watch setting', 'previous')
    end
    previous[target] = { core = Copy(r.core.Database:GetDB()), addon = Copy(r.env[stores[target]]) }
end

-- 2. Clean install and overlay of the new package on the published API14 Core.
for _, target in ipairs({ 'Mists', 'Forever' }) do
    for _, kind in ipairs({ 'Clean', 'Overlay' }) do
        local root = DIR .. kind .. '-' .. target
        local tag = target .. '/' .. kind .. ': '
        for _, upgrade in ipairs({ false, true }) do
            local saved = Copy(otherSentinel[target])
            local coreSaved
            if upgrade then saved[stores[target]] = Copy(previous[target].addon); coreSaved = Copy(previous[target].core) end
            local r = Boot({ client = target, coreRoot = DIR .. 'Core-' .. target, coreSaved = coreSaved, addonName = 'YiboReputation',
                addonRoot = root, saved = saved, beforeAddon = native[target](4600) })
            local addon, core, env = r.env.YiboReputation, r.core, r.env
            local t = tag .. (upgrade and 'upgrade: ' or 'fresh: ')
            Check(core.VERSION == coreVersions[target] and core.API_VERSION == 14 and core:HasCapability('pixel-line', 1), t .. 'published Core API14', 'init')
            Check(addon.VERSION == versions[target], t .. 'package version ' .. tostring(addon.VERSION), 'init')
            Check(Initialized(target, addon), t .. 'initialized', 'init')
            Check(r.registrations.YiboReputation == 1 and r.registrations.last.requiredAPI == 14, t .. 'registered once with requiredAPI 14', 'init')
            if upgrade then
                if target == 'Mists' then
                    local snap = addon:GetSnapshot(env.TEST_GUID)
                    Check(snap and snap.data.factions[1270].value == 4500, t .. 'previous snapshot kept before rescan', 'saved')
                    local s = addon:GetSettings()
                    Check(s.monitoredFactionIDs[1] == 1270 and s.showFriendshipTotal == true, t .. 'previous settings kept', 'saved')
                else
                    Check(addon.Store:Get(env.TEST_GUID).factions[72].value == 4500, t .. 'previous snapshot kept before rescan', 'saved')
                    Check(addon.Store.db.settings.watchedFactionIDs[1] == 72, t .. 'previous watch setting kept', 'saved')
                end
            end
            -- Repeated lifecycle signals do not register again.
            r.fire('ADDON_LOADED', 'YiboReputation'); core.Events:Fire('CORE_READY'); core:Initialize()
            r.fire('PLAYER_ENTERING_WORLD'); r.flush()
            Check(r.registrations.YiboReputation == 1, t .. 'repeat ADDON_LOADED/CORE_READY/Core:Initialize keeps one registration', 'init')
            if target == 'Mists' then
                Check(addon:GetSnapshot(env.TEST_GUID).data.factions[1270].value == 4600, t .. 'rescan updates the snapshot', 'init')
            else
                Check(addon.Store:Get(env.TEST_GUID).factions[72].value == 4600, t .. 'rescan updates the snapshot', 'init')
            end
            for name, value in pairs(otherSentinel[target]) do
                Check(env[name].sentinel == value.sentinel and next(env[name], next(env[name])) == nil, t .. 'other target store untouched', 'init')
            end
            core.AccountView:ShowPage('reputation'); r.flush()
            Check(not core.AccountView._pages.reputation.lastError, t .. 'page renders', 'init')
            Check(#env.TEST_MESSAGES == 0, t .. 'no messages/callback failures: ' .. table.concat(env.TEST_MESSAGES, ' | '), 'init')
            -- Reload: saved copies restore on a fresh session.
            local reload = Boot({ client = target, coreRoot = DIR .. 'Core-' .. target, coreSaved = Copy(core.Database:GetDB()),
                addonName = 'YiboReputation', addonRoot = root,
                saved = { [stores[target]] = Copy(env[stores[target]]) }, beforeAddon = function() end })
            local ra = reload.env.YiboReputation
            Check(Initialized(target, ra) and reload.registrations.YiboReputation == 1, t .. 'reload initializes once', 'saved')
            if target == 'Mists' then
                Check(ra:GetSnapshot(reload.env.TEST_GUID).data.factions[1270].value == 4600, t .. 'reload restores snapshot', 'saved')
            else
                Check(ra.Store:Get(reload.env.TEST_GUID).factions[72].value == 4600, t .. 'reload restores snapshot', 'saved')
            end
        end
        -- 3. Wrong target: this package on the other declared client with that client's Core.
        local wrong = target == 'Mists' and 'Forever' or 'Mists'
        local ws = { [stores[wrong]] = { sentinel = 'own' } }
        local w = Boot({ client = wrong, coreRoot = DIR .. 'Core-' .. wrong, addonName = 'YiboReputation', addonRoot = root, saved = ws })
        w.fire('PLAYER_ENTERING_WORLD'); w.flush()
        Check(w.env[stores[target]] == nil, tag .. 'on ' .. wrong .. ' does not create ' .. stores[target], 'wrong')
        Check(w.env[stores[wrong]].sentinel == 'own' and next(w.env[stores[wrong]], next(w.env[stores[wrong]])) == nil, tag .. 'on ' .. wrong .. ' leaves that client store untouched', 'wrong')
        Check(not w.registrations.YiboReputation and not Initialized(target, w.env.YiboReputation), tag .. 'on ' .. wrong .. ' stops before registration', 'wrong')
        Check(#w.env.TEST_MESSAGES == 1, tag .. 'on ' .. wrong .. ' prints exactly one wrong-manifest message: ' .. table.concat(w.env.TEST_MESSAGES, ' | '), 'wrong')
        -- 2026-11-22 rebuild: this package's real previous store present on the wrong client stays byte-identical.
        do
            local own = Copy(previous[target].addon); local ownText = Serialize(own)
            local wp = Boot({ client = wrong, coreRoot = DIR .. 'Core-' .. wrong, addonName = 'YiboReputation', addonRoot = root,
                saved = { [stores[target]] = own } })
            wp.fire('PLAYER_ENTERING_WORLD'); wp.flush()
            Check(wp.env[stores[target]] == own and Serialize(own) == ownText and not wp.registrations.YiboReputation,
                tag .. 'on ' .. wrong .. ' previous ' .. stores[target] .. ' byte-identical', 'wrong')
        end
        -- 4. API13 Core (previous published Core package of the same target) is refused.
        local saved = Copy(otherSentinel[target])
        local o = Boot({ client = target, coreRoot = DIR .. 'Core13-' .. target, addonName = 'YiboReputation', addonRoot = root, saved = saved,
            beforeAddon = native[target](4500) })
        o.fire('PLAYER_ENTERING_WORLD'); o.flush()
        local oa = o.env.YiboReputation
        Check(o.core.API_VERSION == 13 and o.core:IsInitialized(), tag .. 'API13 Core is ready', 'api13')
        Check(not Initialized(target, oa) and not o.registrations.YiboReputation, tag .. 'API13 Core refused before registration', 'api13')
        Check(HasMessage(o.env, 'API14'), tag .. 'upgrade message names API14: ' .. table.concat(o.env.TEST_MESSAGES, ' | '), 'api13')
        if target == 'Forever' then
            Check(o.env.YiboReputationForeverDB == nil, tag .. 'API13 refusal does not create the business store', 'api13')
        else
            local db = o.env.YiboReputationDB
            Check(not (db and db.characters and next(db.characters)), tag .. 'API13 refusal records no reputation snapshot', 'api13')
            Check(db == nil, tag .. 'API13 refusal does not create YiboReputationDB (no pre-Core defaults)', 'api13')
            counts.api13MistsDefaults = (db and db.settings) and 'settings defaults created (pre-Core EnsureDB)' or 'no store'
        end
        -- API13 Core with the real previous-release store: byte-identical after refusal (both targets).
        do
            local ps = Copy(otherSentinel[target]); ps[stores[target]] = Copy(previous[target].addon)
            local psText = Serialize(ps[stores[target]])
            local p = Boot({ client = target, coreRoot = DIR .. 'Core13-' .. target, addonName = 'YiboReputation', addonRoot = root,
                saved = ps, beforeAddon = native[target](4700) })
            p.fire('PLAYER_ENTERING_WORLD'); p.flush()
            Check(not Initialized(target, p.env.YiboReputation) and not p.registrations.YiboReputation, tag .. 'API13 with previous store refused', 'api13')
            Check(Serialize(p.env[stores[target]]) == psText, tag .. 'API13 previous ' .. stores[target] .. ' byte-identical', 'api13')
        end
    end
end
local order = { 'previous', 'init', 'saved', 'wrong', 'api13' }
local parts = {}
for _, k in ipairs(order) do parts[#parts + 1] = k .. '=' .. tostring(counts[k] or 0) end
print('PASS YiboReputation packaged replay: ' .. checks .. ' checks (' .. table.concat(parts, ', ') .. '); Mists API13 store: ' .. tostring(counts.api13MistsDefaults))
