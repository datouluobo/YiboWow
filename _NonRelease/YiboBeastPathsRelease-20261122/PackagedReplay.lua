-- YiboBeastPaths 1.10.0 (universal Retail/Mists bundle) packaged replay (2026-11-22).
-- Run from repository root: lua _NonRelease/YiboBeastPathsRelease-20261122/PackagedReplay.lua
-- Loads the published Core ZIP contents (Core-<T>, Core13-Mists) and the addon ZIP
-- contents (Old-Universal, Clean-Universal, Overlay-Universal).  Each client loads
-- the TOC it selects from the bundle (Mists: _Mists.toc, Retail: _Mainline.toc);
-- synthetic client (see Native.lua for the map/world-map limits).
local Boot = dofile('_NonRelease/YiboBeastPathsRelease-20261122/PackagedHarness.lua')
local DIR = '_NonRelease/YiboBeastPathsRelease-20261122/'
local Native = dofile(DIR .. 'Native.lua')
local checks, counts, gaps = 0, {}, {}
local function Check(value, label, group)
    checks = checks + 1; counts[group or 'misc'] = (counts[group or 'misc'] or 0) + 1
    assert(value, label)
end
local function Copy(v) if type(v) ~= 'table' then return v end; local r = {}; for k, x in pairs(v) do r[k] = Copy(x) end; return r end
local function HasMessage(env, pattern)
    for _, m in ipairs(env.TEST_MESSAGES) do if tostring(m):find(pattern, 1, true) then return true end end
end
local TOC = { Mists = 'YiboBeastPaths_Mists.toc', Retail = 'YiboBeastPaths_Mainline.toc' }
local coreVersions = { Mists = '1.13.0', Retail = '0.2.0' }
local PAGE = 'yibo-beastpaths-offline-pets'

local function Run(o)
    local pageCalls, settingsCalls = {}, {}
    local r = Boot({ client = o.client, coreRoot = o.coreRoot, coreSaved = o.coreSaved, addonName = 'YiboBeastPaths',
        addonRoot = o.addonRoot, toc = o.toc or TOC[o.client], saved = o.saved, afterFile = Native.AfterFile,
        beforeAddon = function(env, core)
            Native.Setup(env)
            if o.patchCore then o.patchCore(core) end
            if core and core.AccountView then
                local registerPage = core.AccountView.RegisterPage
                core.AccountView.RegisterPage = function(self, owner, definition)
                    pageCalls[definition.id] = (pageCalls[definition.id] or 0) + 1
                    return registerPage(self, owner, definition)
                end
            end
            if core and core.RegisterSettingsPanel then
                local registerSettings = core.RegisterSettingsPanel
                core.RegisterSettingsPanel = function(self, owner, definition)
                    settingsCalls[definition.id] = (settingsCalls[definition.id] or 0) + 1
                    return registerSettings(self, owner, definition)
                end
            end
        end })
    r.fire('PLAYER_ENTERING_WORLD'); r.flush()
    for name in pairs(r.env.TEST_FIXTURE_GAPS or {}) do gaps[name] = true end
    r.pageCalls, r.settingsCalls = pageCalls, settingsCalls
    return r
end
local function PageCount(core)
    local n = 0
    for id in pairs(core.AccountView._pages or {}) do if id == PAGE then n = n + 1 end end
    return n
end
local function Fixture(id, target)
    return { schema = 1, target = target, characters = { [id] = {
        active = { capturedAt = 100, completeness = 'complete', coverage = 'synthetic', sourceBuild = 'fixture',
            items = { { slotID = 1, name = 'Pet', family = 'Wolf', displayID = 123, creatureID = 50998 } } },
        stable = { capturedAt = 100, completeness = 'complete', coverage = 'synthetic', sourceBuild = 'fixture',
            items = { { slotID = 6, name = 'Stable pet', family = 'Cat', icon = 456 } } },
        lastAttempt = { status = 'unverified', at = 200 } } } }
end

-- 1. Previous release (1.9.1 bundle) stores.  Mists: previous published API13 Core.
-- Retail: no API13 Retail Core was published, so 1.9.1 runs on Core Retail 0.2.0.
local previous = {}
for _, client in ipairs({ 'Mists', 'Retail' }) do
    local coreRoot = client == 'Mists' and DIR .. 'Core13-Mists' or DIR .. 'Core-Retail'
    local r = Run({ client = client, coreRoot = coreRoot, addonRoot = DIR .. 'Old-Universal' })
    local ybp, core = r.env.YiboBeastPaths, r.core
    Check(ybp and ybp.db and core.Registry:Get('YiboBeastPaths') and core.Registry:Get('YiboBeastPaths').version == '1.9.1'
        and core.Registry:Get('YiboBeastPaths').requiredAPI == 13, client .. ': previous 1.9.1 registers with requiredAPI 13', 'previous')
    ybp.db.selectedPet, ybp.db.visible = 50998, false
    ybp.db.offlinePets = Fixture(r.env.TEST_GUID, client)
    Check(r.ns.OfflinePetSnapshot.CheckStore(ybp.db, client), client .. ': previous release accepts the offline pet store', 'previous')
    previous[client] = { core = Copy(core.Database:GetDB()), db = Copy(r.env.YiboBeastPathsDB), debug = Copy(r.env.YiboBeastPathsDebugDB) }
end

for _, client in ipairs({ 'Mists', 'Retail' }) do
    for _, kind in ipairs({ 'Clean', 'Overlay' }) do
        local root = DIR .. kind .. '-Universal'
        local tag = client .. '/' .. kind .. ' '
        -- Default hint TOC alone (client without suffix match) starts nothing.
        do
            local h = Run({ client = client, coreRoot = DIR .. 'Core-' .. client, addonRoot = root, toc = 'YiboBeastPaths.toc' })
            Check(#h.loaded == 1 and h.loaded[1]:match('TocHint') and h.env.YiboBeastPaths == nil and h.env.YiboBeastPathsDB == nil
                and not h.registrations.YiboBeastPaths, tag .. 'default hint TOC loads only TocHint and writes nothing', 'wrong')
        end
        for _, upgrade in ipairs({ false, true }) do
            local t = tag .. (upgrade and 'upgrade: ' or 'fresh: ')
            local saved = upgrade and { YiboBeastPathsDB = Copy(previous[client].db), YiboBeastPathsDebugDB = Copy(previous[client].debug) } or nil
            local r = Run({ client = client, coreRoot = DIR .. 'Core-' .. client, addonRoot = root, saved = saved,
                coreSaved = upgrade and Copy(previous[client].core) or nil })
            local ybp, core, env = r.env.YiboBeastPaths, r.core, r.env
            Check(core.VERSION == coreVersions[client] and core.API_VERSION == 14 and core:HasCapability('pixel-line', 1), t .. 'published Core API14', 'init')
            Check(#r.loaded == 35 and r.loaded[1] == (client == 'Mists' and 'Mists\\Target.lua' or 'Retail\\Target.lua'), t .. 'client-selected TOC loads its target chain', 'init')
            local entry = core.Registry:Get('YiboBeastPaths')
            Check(ybp and ybp.db == env.YiboBeastPathsDB and entry and entry.version == '1.10.0' and entry.requiredAPI == 14, t .. 'registered 1.10.0 with requiredAPI 14', 'init')
            Check(r.pageCalls[PAGE] == 1 and PageCount(core) == 1, t .. 'offline pet page registered once', 'init')
            local settingsTotal = 0; for _, n in pairs(r.settingsCalls) do settingsTotal = settingsTotal + n end
            Check(settingsTotal <= 1, t .. 'settings registered at most once (' .. settingsTotal .. ')', 'init')
            r.fire('ADDON_LOADED', 'YiboBeastPaths'); r.fire('ADDON_LOADED', 'YiboCore'); r.fire('PLAYER_LOGIN')
            core.Events:Fire('CORE_READY'); core:Initialize(); r.flush()
            local again = 0; for _, n in pairs(r.settingsCalls) do again = again + n end
            Check(r.pageCalls[PAGE] == 1 and PageCount(core) == 1 and again == settingsTotal, t .. 'repeated lifecycle signals add no page/settings registration', 'init')
            if upgrade then
                Check(ybp.db.selectedPet == 50998 and ybp.db.visible == false, t .. 'previous route settings kept', 'saved')
                Check(ybp.db.offlinePets.characters[env.TEST_GUID].stable.items[1].name == 'Stable pet', t .. 'previous offline pet record kept', 'saved')
            else
                Check(ybp.db.selectedPet == 50812 and ybp.db.visible == true, t .. 'fresh defaults', 'init')
            end
            Check(ybp:OpenOfflinePets() ~= false, t .. 'offline pet page opens', 'init')
            r.flush()
            Check(not core.AccountView._pages[PAGE].lastError, t .. 'offline pet page renders: ' .. tostring(core.AccountView._pages[PAGE].lastError), 'init')
            Check(#env.TEST_MESSAGES == 0, t .. 'no messages/callback failures: ' .. table.concat(env.TEST_MESSAGES, ' | '), 'init')
            local reload = Run({ client = client, coreRoot = DIR .. 'Core-' .. client, addonRoot = root,
                coreSaved = Copy(core.Database:GetDB()), saved = { YiboBeastPathsDB = Copy(env.YiboBeastPathsDB), YiboBeastPathsDebugDB = Copy(env.YiboBeastPathsDebugDB) } })
            Check(reload.pageCalls[PAGE] == 1 and reload.env.YiboBeastPaths.db.selectedPet == ybp.db.selectedPet
                and (not upgrade or reload.env.YiboBeastPaths.db.offlinePets.characters[reload.env.TEST_GUID]), t .. 'reload restores and registers once', 'saved')
        end
        -- Wrong target: the other client's TOC from the bundle forced onto this client.
        local other = client == 'Mists' and 'Retail' or 'Mists'
        local w = Run({ client = client, coreRoot = DIR .. 'Core-' .. client, addonRoot = root, toc = TOC[other],
            saved = { YiboBeastPathsDB = { sentinel = 'own' } } })
        Check(w.env.YiboBeastPaths == nil and w.env.YiboBeastPathsDebugDB == nil, tag .. TOC[other] .. ' creates no addon object/debug store', 'wrong')
        Check(w.env.YiboBeastPathsDB.sentinel == 'own' and next(w.env.YiboBeastPathsDB, next(w.env.YiboBeastPathsDB)) == nil, tag .. TOC[other] .. ' leaves the store untouched', 'wrong')
        Check(not w.registrations.YiboBeastPaths and not w.pageCalls[PAGE], tag .. TOC[other] .. ' stops before Core registration', 'wrong')
        -- API13 Core refused (Mists: real published 1.12.14 package; Retail: Core 0.2.0
        -- with CheckAPIVersion/API_VERSION downgraded to 13 -- synthetic, no API13 Retail Core exists).
        local a = Run({ client = client, coreRoot = client == 'Mists' and DIR .. 'Core13-Mists' or DIR .. 'Core-Retail', addonRoot = root,
            patchCore = client == 'Retail' and function(core)
                core.API_VERSION = 13
                core.CheckAPIVersion = function(_, required) return (tonumber(required) or 1) <= 13, 13 end
            end or nil })
        Check(a.core.API_VERSION == 13 and a.core:IsInitialized(), tag .. 'API13 Core ready (' .. (client == 'Mists' and 'published 1.12.14' or 'synthetic downgrade') .. ')', 'api13')
        Check(a.env.YiboBeastPaths and a.env.YiboBeastPaths.db, tag .. 'routes still start without the Core enhancement', 'api13')
        Check(not a.registrations.YiboBeastPaths and not a.pageCalls[PAGE] and next(a.settingsCalls) == nil, tag .. 'API13 Core refused before registration', 'api13')
        Check(a.env.YiboBeastPathsDB.offlinePets == nil, tag .. 'API13 refusal writes no offline pet store', 'api13')
        a.env.SlashCmdList.YIBOBEASTPATHS('debug'); a.env.SlashCmdList.YIBOBEASTPATHS('stable')
        Check(HasMessage(a.env, 'API14') and #a.env.TEST_MESSAGES == 2, tag .. 'upgrade messages: ' .. table.concat(a.env.TEST_MESSAGES, ' | '), 'api13')
    end
end
local order = { 'previous', 'init', 'saved', 'wrong', 'api13' }
local parts = {}
for _, k in ipairs(order) do parts[#parts + 1] = k .. '=' .. tostring(counts[k] or 0) end
local gapNames = {}; for name in pairs(gaps) do gapNames[#gapNames + 1] = name end; table.sort(gapNames)
print('PASS YiboBeastPaths packaged replay: ' .. checks .. ' checks (' .. table.concat(parts, ', ') .. '); fixture no-op methods: '
    .. (#gapNames > 0 and table.concat(gapNames, ',') or 'none'))
