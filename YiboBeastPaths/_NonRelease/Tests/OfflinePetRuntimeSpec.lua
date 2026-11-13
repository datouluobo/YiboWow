local checks = 0
local function check(value) checks = checks + 1; assert(value) end
for _, target in ipairs({ "Retail", "Mists" }) do
    local ns, frames, readyCallback, counts = {}, {}, nil, { page = 0, entry = 0, cleanup = 0 }
    WOW_PROJECT_MAINLINE, WOW_PROJECT_MISTS_CLASSIC = 1, 19
    WOW_PROJECT_ID = target == "Retail" and 1 or 19
    local function widget()
        return setmetatable({}, { __index = function(t, key)
            if key == "SetScript" then return function(self, _, cb) self.callback = cb end end
            if key == "GetWidth" then return function() return 500 end end
            return function() end
        end })
    end
    CreateFrame = function() local f = widget(); frames[#frames + 1] = f; return f end
    UnitClass = function() return "Hunter", "HUNTER" end
    local db = { visible = true }
    YiboBeastPaths = { db = db }
    local core = { ready = false, Characters = {}, CharacterCleanup = {}, AccountView = {},
        Entry = {}, Locale = {}, Events = {}, UITheme = { Font = { body = 12 }, Colors = { text = {} } } }
    YiboCore = core
    function core:CheckAPIVersion(v) return v == 13 end
    function core:IsInitialized() return self.ready end
    function core:HasCapability() return true end
    function core:RegisterAddon() return {} end
    function core.Characters:GetCurrentID() return "id" end
    function core.Characters:GetCurrent() return {} end
    function core.Characters:GetAll() return {} end
    function core.Characters:FormatName() return "Hunter" end
    function core.CharacterCleanup:RegisterOwner(_, def) counts.cleanup = counts.cleanup + 1; return def end
    function core.AccountView:RegisterPage(_, def) counts.page = counts.page + 1; counts.definition = def; return def end
    function core.AccountView:UnregisterPage() return true end
    function core.AccountView:NotifyPageChanged() end
    function core.AccountView:GetScrollSurfaceWidth() return 500 end
    function core.AccountView:ShowPage() counts.shown = true end
    function core.AccountView:Toggle() counts.shown = true end
    function core.Entry:RegisterBusinessEntry(_, def) counts.entry = counts.entry + 1; return def end
    function core.Locale:Register() end
    function core.Locale:Get(_, key) return key end
    function core.Events:Register(_, _, callback) readyCallback = callback end
    function core.Events:Unregister() readyCallback = nil end
    function core.UITheme:CreateText() return widget() end
    function core.UITheme:CreateScrollFrame() return widget() end
    function core.UITheme:CreateBusinessTabs(_, _, onSelect) local tabs = widget(); tabs.onSelect = onSelect; return tabs end
    function core.UITheme:CreateInput() return widget() end
    function core.UITheme:CreateButton() return widget() end
    function core.UITheme:CreateDropdown() return widget() end
    ns.RegisterLocale = function() return true end
    ns.Text = function(key) return key end
    local maintenanceRefreshes = 0
    ns.CreateMaintenancePage = function(parent) parent.maintenanceCreated = true end
    ns.RefreshMaintenancePage = function() maintenanceRefreshes = maintenanceRefreshes + 1 end
    assert(loadfile("YiboBeastPaths/" .. target .. "/Target.lua"))("YiboBeastPaths", ns)
    for _, file in ipairs({ "OfflinePetSnapshot", "OfflinePetCapture", "OfflinePetCoreGate", "OfflinePetPage", "OfflinePetRenderer" }) do
        assert(loadfile("YiboBeastPaths/Common/" .. file .. ".lua"))("YiboBeastPaths", ns)
    end
    local captureOptions, originalNew = nil, ns.OfflinePetCapture.New
    ns.OfflinePetCapture.New = function(options) captureOptions = options; return originalNew(options) end
    local reads, queued = 0, {}
    local lastDelay
    C_Timer = { After = function(delay, callback) lastDelay = delay; queued[#queued + 1] = callback end }
    ns.ReadOfflinePets = function() reads = reads + 1; return { active = {}, stable = {}, completeness = "unverified" }, "unverified" end
    assert(loadfile("YiboBeastPaths/Common/OfflinePetRuntime.lua"))("YiboBeastPaths", ns)
    local runtime = frames[#frames]
    runtime.callback(runtime, "ADDON_LOADED", "YiboBeastPaths")
    check(readyCallback ~= nil and counts.page == 0 and db.offlinePets == nil)
    runtime.callback(runtime, "PET_STABLE_SHOW")
    check(reads == 0 and readyCallback ~= nil)
    core.ready = true; readyCallback()
    check(counts.page == 1 and counts.entry == 1 and counts.cleanup == 1 and reads == 1)
    check(ns.IsUnifiedPageReady())
    core.ready = false
    check(not ns.IsUnifiedPageReady())
    core.ready = true
    runtime.callback(runtime, "PLAYER_LOGIN")
    runtime.callback(runtime, "PET_STABLE_SHOW")
    check(counts.page == 1 and counts.entry == 1 and db.offlinePets == nil)
    check(captureOptions.Valid("id"))
    local otherDB = YiboBeastPaths.db
    YiboBeastPaths.db = {}
    check(not captureOptions.Valid("id"))
    YiboBeastPaths.db = otherDB
    queued = {}
    captureOptions.Schedule(function() end)
    check(lastDelay == 1.25 and #queued == 1)
    queued = {}
    local before = reads
    runtime.callback(runtime, "PET_STABLE_UPDATE")
    runtime.callback(runtime, "PET_STABLE_UPDATE")
    check(#queued == 1 and reads == before)
    queued[1](); queued = {}
    check(reads == before + 1)
    runtime.callback(runtime, "PET_STABLE_UPDATE")
    runtime.callback(runtime, "PET_STABLE_CLOSED")
    check(not captureOptions.Valid("id"))
    queued[1](); queued = {}
    check(reads == before + 1)
    runtime.callback(runtime, "PET_STABLE_UPDATE")
    check(#queued == 0)
    time = function() return 200 end
    db.offlinePets = { schema = 1, target = target, characters = { id = {
        active = { items = { { slotID = 1, name = "old active" } }, capturedAt = 100, completeness = "complete", coverage = "synthetic", sourceBuild = "fixture" },
        stable = { items = { { slotID = 6, name = "old stable" } }, capturedAt = 100, completeness = "complete", coverage = "synthetic", sourceBuild = "fixture" },
    } } }
    ns.ReadOfflinePets = function() return { active = {}, stable = {}, completeness = "unverified" }, "unverified" end
    runtime.callback(runtime, "PET_STABLE_SHOW")
    local record = db.offlinePets.characters.id
    queued[#queued]()
    check(record.lastAttempt.status == "unverified" and record.stable.capturedAt == 100
        and record.stable.items[1].name == "old stable")
    ns.ReadOfflinePets = function() error("read failed") end
    runtime.callback(runtime, "PET_STABLE_SHOW")
    check(record.lastAttempt.status == "unavailable" and record.active.capturedAt == 100)
    queued = {}
    ns.ReadOfflinePets = function() return { active = { { slotID = 1, name = "seen" } }, stable = {},
        completeness = "unverified", coverage = "candidate", sourceBuild = "fixture" }, "unverified" end
    runtime.callback(runtime, "PET_STABLE_SHOW")
    check(record.observation == nil and #queued == 1)
    queued[1]()
    check(record.observation and record.observation.active[1].name == "seen"
        and record.stable.items[1].name == "old stable")
    WOW_PROJECT_ID = 99
    record.lastAttempt.at = 199
    runtime.callback(runtime, "PET_STABLE_SHOW")
    check(record.lastAttempt.at == 199)
    WOW_PROJECT_ID = target == "Retail" and 1 or 19
    check(YiboBeastPaths:OpenOfflinePets() and counts.shown)
    local parent = widget()
    counts.definition.Create(parent, { preview = false })
    counts.definition.Refresh(parent, { characters = {} })
    check(parent.stableView.lines and #parent.stableView.lines == 1 and parent.maintenanceView.maintenanceCreated)
    parent.businessTabs.onSelect("maintenance")
    counts.definition.Refresh(parent, { characters = {} })
    check(maintenanceRefreshes == 1)
    local preview = widget()
    counts.definition.Create(preview, { preview = true })
    counts.definition.Refresh(preview, { characters = {}, preview = true })
    check(preview.lines and #preview.lines == 1 and rawget(preview, "businessTabs") == nil)
    db.offlinePets = "unknown future store"
    check(YiboBeastPaths:OpenOfflinePets("maintenance") and db.offlinePets == "unknown future store")
    counts.definition.Refresh(parent, { characters = {} })
    check(maintenanceRefreshes == 2)
end
print("OfflinePetRuntimeSpec: " .. checks .. " checks passed")
