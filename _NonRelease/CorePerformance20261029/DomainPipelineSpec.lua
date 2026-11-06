-- Lua 5.1, workspace root. Measures real domain runtimes with GC paused.
local baseline = arg and arg[1] == 'baseline'
GetServerTime = function() return 1000 end
dofile('YiboCore/Bootstrap.lua')
dofile('YiboCore/Util/Defaults.lua')
dofile('YiboCore/Runtime/Capabilities.lua')
dofile('YiboCore/_NonRelease/Tests/LoadLocale.lua')
dofile('YiboCore/Runtime/Events.lua')
dofile('YiboCore/Runtime/Registry.lua')
local core = YiboCore
core.IsInitialized = function() return true end
assert(core.Registry:Register(core.NAME, { requiredAPI = 13 }))
local record = { id = 'C', name = 'Name', realm = 'Realm', domains = {} }
core.Database = { GetDB = function() return { characters = { byID = { C = record } } } end }
core.Client = { ReadGUID = function() return 'C' end }
dofile('YiboCore/Data/Characters.lua')
dofile('YiboCore/Runtime/DataDomains.lua')
dofile('YiboCore/Data/DomainStore.lua')
dofile('YiboCore/Data/Profile.lua')
local data = { rows = {} }
for i = 1, 1000 do data.rows[i] = { id = i, count = i } end
local state = 'known'
assert(core.DataDomains:Register(core.NAME, { id = 'large', version = 1, events = { PULSE = true },
    Collect = function() return data, state end }))
local copies, originalCopy = 0, core.Defaults.Copy
core.Defaults.Copy = function(self, value)
    if value == record.domains.large then copies = copies + 1 end
    return originalCopy(self, value)
end
local function Measure(label, callback, expected)
    collectgarbage('collect'); collectgarbage('stop')
    copies = 0
    local before = collectgarbage('count')
    for i = 1, 100 do callback(i) end
    local kb = collectgarbage('count') - before
    collectgarbage('restart')
    print(string.format('%s: domain copies=%d, allocation=%.1f KB', label, copies, kb))
    if not baseline then assert(copies == expected, label .. ' unnecessary domain copy') end
end
assert(core.DataDomains:Dispatch('PULSE') == 1)
Measure('state-only', function() assert(core.DataDomains:GetState('C', 'large') == 'known') end, 0)
Measure('unchanged dispatch', function() assert(core.DataDomains:Dispatch('PULSE') == 1) end, 0)
Measure('changed dispatch without projector', function(i)
    data.rows[1].count = i + 1000
    core.DataDomains:Dispatch('PULSE')
end, 0)
-- Input ownership and detached public return values must remain unchanged.
data.rows[1].count = -1
assert(core.DomainStore:Get('C', 'large').data.rows[1].count == 1100)
local snapshot, changed = core.DomainStore:Commit('C', 'large', data, 'known')
assert(changed); snapshot.data.rows[1].count = 99
local again, unchanged = core.DomainStore:Commit('C', 'large', data, 'known')
assert(not unchanged and again.data.rows[1].count == -1)
again.data.rows[1].count = 88
assert(core.DomainStore:Get('C', 'large').data.rows[1].count == -1)
assert(core.DomainStore:GetState('C', 'missing') == nil)
for _, failed in ipairs({ 'error', 'stale', 'unavailable', 'not-yet-scanned' }) do
    state = failed; core.DataDomains:Dispatch('PULSE')
    assert(core.DomainStore:GetState('C', 'large') == failed)
    assert(core.DomainStore:Get('C', 'large').data.rows[1].count == -1)
end
-- Real legacy projection still receives an isolated domain snapshot.
local projected = 0
assert(core.DataDomains:Register(core.NAME, { id = 'projected', version = 1, events = { PROJECT = true },
    Collect = function() return { value = 7 }, 'known' end,
    ProjectLegacy = function(target, values, domain)
        assert(domain.state == 'known'); target.profile = { value = values.value }
        values.value = 900; projected = projected + 1
    end }))
core.DataDomains:Dispatch('PROJECT')
assert(projected == 1 and record.profile.value == 7)
assert(core.DomainStore:Get('C', 'projected').data.value == 7)
-- Legacy listeners retain a full snapshot, and burst updates stay coalesced.
local timers, notifications = {}, 0
C_Timer = { After = function(_, callback) timers[#timers + 1] = callback end }
core.Events:Register('CHARACTER_PROFILE_UPDATED', 'test', function(_, id, value)
    assert(id == 'C' and value.domains.large and value.profile.value == 7)
    value.domains.large.data.rows[1].count = 111; notifications = notifications + 1
end)
state = 'known'; core.DataDomains:Dispatch('PULSE')
data.rows[1].count = 2; core.DataDomains:Dispatch('PULSE')
assert(#timers == 1)
timers[1](); assert(notifications == 1 and record.domains.large.data.rows[1].count == 2)
-- A collector for a different event must not force a full current-character read.
assert(core.Profile:RegisterCollector('filtered', function() error('wrong event') end, { OTHER = true }))
local reads, getCurrent = 0, core.Characters.GetCurrent
core.Characters.GetCurrent = function(self, options)
    if not (options and options.identityOnly) then reads = reads + 1 end
    return getCurrent(self, options)
end
core.Profile:RefreshCurrent('UNRELATED')
print('unmatched legacy event: full character reads=' .. reads)
if not baseline then assert(reads == 0) end
local collectorCalls = 0
assert(core.Profile:RegisterCollector('matching', function(target, reason, now)
    assert(target == record and reason == 'MATCH' and now == 1000)
    target.legacyValue = 17; collectorCalls = collectorCalls + 1
end, { MATCH = true }))
core.Profile:RefreshCurrent('MATCH')
assert(collectorCalls == 1 and record.legacyValue == 17 and record.observedAt.collectors.matching == 1000)
if not baseline then assert(reads == 0, 'matching legacy collector only needs identity to locate its mutable record') end
print('PASS: domain state, dispatch, input/output isolation, failure retention, projection and legacy notifications')
