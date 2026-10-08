-- Run from workspace root with Lua 5.1. Exercises actual public runtimes.
local timers, frames = {}, {}
C_Timer = { After = function(delay, callback) timers[#timers + 1] = { delay, callback } end }
local function Flush()
    local pending = timers; timers = {}
    table.sort(pending, function(a, b) return a[1] < b[1] end)
    for _, timer in ipairs(pending) do timer[2]() end
end
function CreateFrame()
    local frame = { scripts = {}, RegisterEvent = function() end,
        SetScript = function(self, name, callback) self.scripts[name] = callback end }
    frames[#frames + 1] = frame; return frame
end
GetServerTime = function() return 1000 end
GetTime = function() return 100 end
dofile('YiboCore/Bootstrap.lua')
dofile('YiboCore/Util/Defaults.lua')
dofile('YiboCore/Runtime/Capabilities.lua')
dofile('YiboCore/Runtime/Events.lua')
dofile('YiboCore/Runtime/Registry.lua')
dofile('YiboCore/Runtime/Contracts.lua')
local core = YiboCore
local errors = 0
core.Print = function() errors = errors + 1 end
assert(core.Registry:Register('Owner', { requiredAPI = 9 }))
assert(core.Registry:Register('Consumer', { requiredAPI = 9 }))
local backing = { count = 7 }
local definition = { name = 'test.items', kind = 'service', providerID = 'Owner:items', version = { major = 1, minor = 0 },
    methods = { Read = function(request) request.count = 88; return backing end,
        Fail = function() error('failure') end } }
local notifications = 0
local callback = function(_, descriptor) descriptor.name = 'tampered'; error('listener failure') end
core.Events:Register('BUSINESS_CONTRACT_REGISTERED', 'bad', callback)
core.Events:Register('BUSINESS_CONTRACT_REGISTERED', 'bad', callback)
core.Events:Register('BUSINESS_CONTRACT_REGISTERED', 'good', function(_, descriptor)
    assert(descriptor.name == 'test.items'); notifications = notifications + 1
end)
local ref = assert(core.Contracts:Register('Owner', definition))
assert(core.Contracts:Register('Owner', definition) == ref and notifications == 1 and errors == 1)
assert(not core.Contracts:Register('Consumer', definition))
local descriptor = assert(core.Contracts:Resolve('test.items', { major = 1 }))
assert(not core.Contracts:Resolve('test.items', { major = 2 }))
local request = { count = 1 }
local result = assert(core.Contracts:Call('Consumer', descriptor, 'Read', request))
result.count = 90
assert(request.count == 1 and backing.count == 7)
local _, code = core.Contracts:Call('Consumer', descriptor, 'Fail', {})
assert(code == 'provider-error')
assert(core.Contracts:Unregister('Owner', ref))
_, code = core.Contracts:Call('Consumer', descriptor, 'Read', {})
assert(code == 'unregistered')
core.Events:Unregister('BUSINESS_CONTRACT_REGISTERED', 'bad')
core.Events:Unregister('BUSINESS_CONTRACT_REGISTERED', 'good')
assert(core.Contracts:Register('Owner', definition) ~= ref)

local currentReads = 0
core.Characters = { GetCurrent = function() currentReads = currentReads + 1; return { id = 'A' } end }
core.DataDomains = { Dispatch = function() return true end }
dofile('YiboCore/Data/Profile.lua')
assert(core.Profile:RefreshCurrent('BAG_UPDATE_DELAYED') and currentReads == 0)

core.UITheme = { Colors = {} }
dofile('YiboCore/UI/AccountView.lua')
local view, shown, refreshes = core.AccountView, true, 0
view.frame = { IsShown = function() return shown end }
view.activePageID = 'A'
view.RefreshPage = function() refreshes = refreshes + 1 end
for i = 1, 20 do view:NotifyPageChanged('A') end
view:NotifyPageChanged('B'); assert(#timers == 1 and refreshes == 0)
Flush(); assert(refreshes == 1)
view:NotifyPageChanged('A'); shown = false; Flush(); assert(refreshes == 1)
shown = true; view:NotifyPageChanged('A'); view.activePageID = 'B'; Flush(); assert(refreshes == 1)
view.frame.preview, view.previewPageID = true, 'A'; view:NotifyPageChanged('A'); Flush(); assert(refreshes == 2)

local loaded, loads, callbacks = {}, 0, 0
GetItemInfo = function(id) return loaded[id] end
C_Item = { RequestLoadItemDataByID = function() loads = loads + 1 end }
dofile('YiboCore/Runtime/ItemResolver.lua')
local resolverFrame = frames[#frames]
assert(not resolverFrame.scripts.OnUpdate)
local function Ready(info) assert(info.state == 'ready'); callbacks = callbacks + 1 end
core.ItemResolver:Request(123, Ready)
core.ItemResolver:Request(123, Ready)
assert(loads == 1 and resolverFrame.scripts.OnUpdate)
loaded[123] = 'Ready'
resolverFrame.scripts.OnUpdate(resolverFrame, 0.1)
assert(callbacks == 2 and not resolverFrame.scripts.OnUpdate)
local failed = 0
core.ItemResolver:Request(124, function(info) assert(info.state == 'failed'); failed = failed + 1 end, { timeout = 0.2 })
resolverFrame.scripts.OnUpdate(resolverFrame, 0.2)
assert(failed == 1 and not resolverFrame.scripts.OnUpdate)

YAB = {}
dofile('YiboAltoBoss/InstanceLockouts.lua')
local bossFrame, requests, scans = frames[#frames], 0, 0
YAB.RecordNormalInstanceEntry = function() end
YAB.RefreshInstanceLockouts = function() scans = scans + 1 end
RequestRaidInfo = function() requests = requests + 1 end
INSTANCE_RESET_SUCCESS = '%s reset.'
bossFrame.scripts.OnEvent(nil, 'PLAYER_LOGIN')
bossFrame.scripts.OnEvent(nil, 'ZONE_CHANGED_NEW_AREA')
assert(#timers == 1); Flush(); assert(requests == 1)
bossFrame.scripts.OnEvent(nil, 'UPDATE_INSTANCE_INFO'); Flush()
assert(requests == 1 and scans == 1 and #timers == 0)
bossFrame.scripts.OnEvent(nil, 'CHAT_MSG_SYSTEM', 'Unrelated system message')
assert(#timers == 0)
bossFrame.scripts.OnEvent(nil, 'CHAT_MSG_SYSTEM', 'Dungeon reset.')
assert(#timers == 1); timers = {}

SlashCmdList = {}
dofile('YiboLegendary/Bootstrap.lua')
local legendary, builds, draws, total = YiboLegendary, 0, 0, 0
legendary.Core = { Characters = { GetCurrent = function() return { id = 'A' } end } }
legendary.db = { byCharacter = {}, settings = {} }
legendary.Data = { TrackValorProgress = function(_, _, id, _, delta)
    if id == 396 then total = total + (delta or 0) end
    return { earned = total }
end }
legendary.Model = { BuildSnapshot = function(_, _, _, _, progress) builds = builds + 1; return { progress = progress.earned } end }
legendary.UI = { Refresh = function() draws = draws + 1 end }
legendary:QueueRefresh('CURRENCY_DISPLAY_UPDATE', 396, 10, 3)
legendary:QueueRefresh('CURRENCY_DISPLAY_UPDATE', 396, 12, 2)
legendary:QueueRefresh('QUEST_LOG_UPDATE')
assert(#timers == 1 and total == 5 and builds == 0)
Flush(); assert(builds == 1 and draws == 1 and legendary.db.byCharacter.A.snapshot.progress == 5)
legendary:QueueRefresh('QUEST_LOG_UPDATE'); Flush(); assert(builds == 2 and draws == 1)

YiboBuilds = {}
dofile('YiboBuilds/Snapshot.lua')
local captured = {}
YiboBuilds.Snapshot.Capture = function(_, reason, _, parts) captured[#captured + 1] = { reason, parts } end
YiboBuilds.Snapshot:ScheduleEquipmentCapture()
YiboBuilds.Snapshot:ScheduleCapture('glyphs', 0.1, { glyphs = true })
Flush()
assert(#captured == 1 and captured[1][2].equipment and captured[1][2].glyphs)
Flush(); assert(#captured == 2 and captured[2][2].equipment and not captured[2][2].glyphs)
dofile('YiboVault/Namespace.lua')
dofile('YiboVault/Collector.lua')
local equipmentScans = 0
YiboVault.ScanEquipment = function() equipmentScans = equipmentScans + 1 end
YiboVault:OnEvent('UNIT_INVENTORY_CHANGED', 'target'); assert(#timers == 0)
YiboVault:OnEvent('UNIT_INVENTORY_CHANGED', 'player')
YiboVault:OnEvent('PLAYER_EQUIPMENT_CHANGED', 1)
assert(#timers == 1); Flush(); assert(equipmentScans == 1)

local tooltipDraws, domainReads, cursor = 0, 0, 160
core.UITheme.Colors.text = { 1, 1, 1 }
core.DataDomains.Get = function() domainReads = domainReads + 1; error('hover must use the render snapshot') end
YiboReputation = {
    GetFactionData = function(_, snapshot) return snapshot end,
    FormatCompact = function() return '1K' end,
    FormatReputation = function(_, snapshot) return snapshot.detail end,
}
dofile('YiboReputation/MonitoredPreview.lua')
local showTooltip
for index = 1, 30 do
    local name, value = debug.getupvalue(YiboReputation.RefreshMonitoredPreview, index)
    if not name then break end
    if name == 'ShowMonitoredTooltip' then showTooltip = value end
end
assert(showTooltip)
GetCursorPosition = function() return cursor end
GameTooltip = { shown = false, Hide = function(self) self.shown = false end,
    IsShown = function(self) return self.shown end,
    SetOwner = function() end, ClearLines = function() tooltipDraws = tooltipDraws + 1 end,
    AddLine = function() end, Show = function(self) self.shown = true end }
local row = { GetLeft = function() return 0 end,
    monitoredTooltip = { nameWidth = 150, cellWidth = 80, factionID = 1,
        characters = { { id = 'A' }, { id = 'B' } }, snapshots = { A = { detail = '1000/3000' }, B = { detail = '2000/3000' } } } }
for i = 1, 100 do showTooltip(row) end
assert(tooltipDraws == 1 and domainReads == 0)
cursor = 240; showTooltip(row); assert(tooltipDraws == 2 and domainReads == 0)
row.monitoredTooltipColumn = nil; showTooltip(row); assert(tooltipDraws == 3)
print('PASS: service lifecycle/isolation; page burst/visibility; shared item idle/timeout; raid response loop; lossless currency deltas; equipment settle/filter/coalescing; stationary reputation hover reuses snapshot and tooltip')
