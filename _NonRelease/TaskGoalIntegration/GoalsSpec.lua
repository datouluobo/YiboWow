-- Run from workspace root with Lua 5.1. Actual Core contracts and Todo model;
-- the game directory/profession domain and frame geometry are controlled inputs.
local clock, hour, minute, checks = 100000, 6, 59, 0
GetServerTime = function() return clock end
time, date = GetServerTime, os.date
GetGameTime = function() return hour, minute end
STANDARD_TEXT_FONT = "font"
SlashCmdList = {}
local function Frame(parent)
    local frame = { parent = parent, width = 1040, height = 420, scripts = {}, shown = true }
    function frame:SetSize(w, h) self.width, self.height = w, h end
    function frame:SetWidth(w) self.width = w end
    function frame:SetHeight(h) self.height = h end
    function frame:GetWidth() return self.width end
    function frame:GetHeight() return self.height end
    function frame:GetParent() return self.parent end
    function frame:SetPoint(...) self.point = { ... } end
    function frame:SetScript(event, callback) self.scripts[event] = callback end
    function frame:GetScript(event) return self.scripts[event] end
    function frame:HookScript(event, callback) local old = self.scripts[event]; self.scripts[event] = function(...) if old then old(...) end; callback(...) end end
    function frame:SetText(text) self.text = text end
    function frame:SetShown(shown) self.shown = shown end
    function frame:IsShown() return self.shown end
    function frame:Show() self.shown = true end
    function frame:Hide() self.shown = false end
    function frame:SetEnabled(enabled) self.enabled = enabled end
    function frame:SetBackdrop(value) self.backdrop = value end
    function frame:CreateFontString() return Frame(self) end
    function frame:CreateTexture() return Frame(self) end
    return setmetatable(frame, { __index = function(_, key)
        if key:match("^[A-Z]") then return function() end end
    end })
end
CreateFrame = function(_, _, parent) return Frame(parent) end
local function Equal(a, b, label)
    checks = checks + 1
    assert(a == b, (label or "value") .. ": " .. tostring(a) .. " ~= " .. tostring(b))
end
dofile("YiboCore/Bootstrap.lua")
dofile("YiboCore/Util/Defaults.lua")
dofile("YiboCore/Runtime/Capabilities.lua")
dofile("YiboCore/_NonRelease/Tests/LoadLocale.lua")
dofile("YiboCore/Runtime/Events.lua")
dofile("YiboCore/Runtime/Registry.lua")
dofile("YiboCore/Runtime/Contracts.lua")
dofile("YiboCore/UI/Theme.lua")
dofile("YiboCore/Runtime/ItemResolver.lua")
local Core = YiboCore
local notices = 0
Core.Print = function() end
local characters = { { id = "C", name = "星河", realm = "测试" }, { id = "D", name = "暮光", realm = "测试" },
    { id = "F", name = "云帆", realm = "测试" }, { id = "U", name = "未知", realm = "测试" } }
local currentID = "C"
Core.Characters = {
    GetAll = function() return Core.Defaults:Copy(characters) end,
    GetCurrent = function() for _, c in ipairs(characters) do if c.id == currentID then return Core.Defaults:Copy(c) end end end,
    Get = function(_, id) for _, c in ipairs(characters) do if c.id == id then return Core.Defaults:Copy(c) end end end,
    FormatName = function(_, c) return c and c.name end,
}
local domains = {
    C = { state = "known", data = { primaryProfessions = { { id = 197, skillLevel = 600, name = "裁缝" } } } },
    D = { state = "known", data = { primaryProfessions = { { id = 197, skillLevel = 600, name = "裁缝" } } } },
    F = { state = "known", data = { primaryProfessions = { { id = 171, skillLevel = 600, name = "炼金" } } } },
}
Core.DataDomains = { Get = function(_, id) return Core.Defaults:Copy(domains[id]) end }
local pages, entries, refreshes = {}, {}, 0
Core.AccountView = {
    SetPageScope = function() end,
    RegisterPage = function(_, _, page) pages[page.id] = page; return page end,
    NotifyPageChanged = function() refreshes = refreshes + 1 end,
    ShowPage = function(_, id) Core.lastPage = id end,
    GetVisibleCharacters = function() return Core.Defaults:Copy(characters) end,
}
Core.Entry = { RegisterBusinessEntry = function(_, _, definition) entries[definition.id] = definition; return definition end }
Core.Capabilities:Register("account-view", 2)
Core.Capabilities:Register("character-name-format", 1)
Core.Capabilities:Register("character-identity", 1)
Core.Capabilities:Register("account-character-admission", 1)
Core.Capabilities:Register("account-surface-budget", 1)


local timers = {}
C_Timer = { After = function(delay, fn) timers[#timers+1] = { delay = delay, fn = fn } end }
Core.Database = { db = { settings = {} }, GetDB = function(self) return self.db end }
dofile("YiboCore/UI/BusinessItemActions.lua")
assert(loadfile("YiboTaskHub/Namespace.lua"))("YiboTaskHub", {})
local Hub = YiboTaskHub
for _, name in ipairs({ "Database", "Common/Goals", "BossTargets", "Snapshot", "Contracts", "GoalContracts" }) do dofile("YiboTaskHub/" .. name .. ".lua") end
Hub.Core = Core
assert(Core:RegisterAddon(Hub.NAME, { version = "test", requiredAPI = 12 }))
assert(Core:RegisterAddon("Spec", { version = "test", requiredAPI = 12 }))
Hub.GoalEditor = { Locate = function(_, id) Hub.located = id; return true end, Configure = function(_, intent) Hub.configuring = intent; return true end }
assert(Hub.Database:Initialize()); assert(Hub.Goals:Initialize()); Hub.Contracts:Initialize()
local calls, fresh, sourceEpoch, complete, cycle = 0, true, "epoch:1", false, "day:1"
local provider = { name = "action.targets", kind = "provider", providerID = "Spec:targets", version = { major = 1, minor = 0 }, methods = {
    Normalize = function(r)
        local i = Core.Defaults:Copy(r.intent)
        if i.objectID == "invalid" then return nil, "bad-object" end
        if not i.scope or not i.scope.characterID then return { needsConfiguration = true, fields = {} } end
        i.repeatPolicy = i.repeatPolicy or "once"
        return { intent = i, title = i.objectID, identity = i.objectID .. ":" .. i.scope.characterID .. ":" .. i.repeatPolicy }
    end,
    Evaluate = function(r)
        calls = calls + 1
        local result = { sourceEpoch = sourceEpoch, revision = 1, sourceTitle = "Spec", evaluations = {} }
        for _, g in ipairs(r.goals) do
            result.evaluations[g.id] = { task = { title = g.title, state = complete and "completed" or "active", readiness = complete and "not-applicable" or "actionable",
                execution = { mode = "self", characterID = g.intent.scope.characterID }, beneficiary = { mode = "character", characterID = g.intent.scope.characterID },
                temporal = { kind = "daily", cycleKey = cycle, nextChangeAt = clock + 30 }, freshness = { state = fresh and "known" or "stale", observedAt = clock, validUntil = clock+30 } } }
        end
        return result
    end,
} }
local ref = assert(Core.Contracts:Register("Spec", provider))
Equal(Hub.Snapshot:Build(characters).uniqueCount, 0, "new empty")
Equal(calls, 0, "empty avoids source queries")
local function Intent(name, policy, id) return { providerID = "Spec:targets", targetType = "test", objectID = name, scope = { mode = "character", characterID = id or "C" }, conditions = {}, repeatPolicy = policy or "once" } end
local a = assert(Hub.Goals:Add(Intent("one")))
Equal(#Hub.Goals:List(), 1)
Equal(assert(Hub.Goals:Add(Intent("one"))).id, a.id, "dedup")
Equal(assert(Hub.Goals:Add(Intent("one"))).existing, true)
Equal(Hub.Snapshot:Build(characters).uniqueCount, 1)
Equal(calls, 1)
Hub.Snapshot:Build(characters); Equal(calls, 1, "cached query")
local copy = Hub.Goals:List(); copy[1].state = "removed"; Equal(Hub.Goals:List()[1].state, "active", "defensive copy")
local saved = Hub.db.goals.byID[a.id]
Equal(Hub.Goals:Update(a.id, saved.revision + 1, { state = "paused" }), nil, "stale edit rejected")
Equal(Hub.Goals:Add(Intent("invalid")), nil, "failure leaves store untouched")
Equal(#Hub.Goals:List(), 1)
assert(Hub.Goals:Update(a.id, saved.revision, { state = "paused" }))
Equal(Hub.Snapshot:Build(characters).uniqueCount, 0); Equal(calls, 1, "paused avoids progress")
saved = Hub.db.goals.byID[a.id]; assert(Hub.Goals:Update(a.id, saved.revision, { state = "active" }))
fresh = false; Hub.Contracts:Invalidate(); Equal(Hub.Snapshot:Build(characters).tasks[1].readiness, "unknown", "stale unknown")
complete = true; Hub.Contracts:Invalidate(); local staleCompletion = Hub.Snapshot:Build(characters)
Equal(Hub.db.goals.byID[a.id].state, "active", "stale cannot complete")
Equal(staleCompletion.tasks[1].readiness, "unknown", "stale completion cannot disappear from pending work")
fresh = true; Hub.Contracts:Invalidate(); Equal(Hub.Snapshot:Build(characters).uniqueCount, 0); Equal(Hub.db.goals.byID[a.id].state, "completed")
Equal(#Hub.db.goals.byID[a.id].history, 1)
Equal(Hub.Goals:List(false, { omitHistory = true })[1].history, nil, "progress projection excludes completion history")
Equal(#Hub.Goals:List()[1].history, 1, "management retains completion history")
complete = false; Hub.Contracts:Invalidate(); Equal(Hub.Snapshot:Build(characters).uniqueCount, 0, "once stays complete")
Equal(Hub.Goals:Add(Intent("one")).id, a.id, "completed duplicate locates")
saved = Hub.db.goals.byID[a.id]; Equal(Hub.Goals:Update(a.id, saved.revision, { state = "active" }), nil, "reopen explicit")
assert(Hub.Goals:Update(a.id, saved.revision, { state = "active", reopen = true }))
local recurring = assert(Hub.Goals:Add(Intent("daily", "recurring")))
complete = true; Hub.Contracts:Invalidate(); Hub.Snapshot:Build(characters)
Equal(Hub.db.goals.byID[recurring.id].state, "active", "recurring retains config")
Equal(#Hub.db.goals.byID[recurring.id].history, 1)
Hub.Contracts:Invalidate(); Hub.Snapshot:Build(characters); Equal(#Hub.db.goals.byID[recurring.id].history, 1, "same cycle history once")
cycle, complete = "day:2", false; Hub.Contracts:Invalidate(); Equal(Hub.Snapshot:Build(characters).uniqueCount, 1, "next cycle reopens work")
local maintain = assert(Hub.Goals:Add(Intent("stock", "maintain")))
complete = true; Hub.Contracts:Invalidate(); Hub.Snapshot:Build(characters)
Equal(Hub.db.goals.byID[maintain.id].state, "active")
complete = false; Hub.Contracts:Invalidate(); Equal(Hub.Snapshot:Build(characters).uniqueCount, 2, "maintain shortage reopens")
assert(Core.Contracts:Unregister("Spec", ref)); Equal(Hub.Snapshot:Build(characters).tasks[1].readiness, "unknown", "missing retains goals")
ref = assert(Core.Contracts:Register("Spec", provider)); Equal(Hub.Snapshot:Build(characters).tasks[1].readiness, "actionable", "late source resumes")
sourceEpoch = "epoch:2"; Hub.Contracts:Invalidate(); Equal(Hub.Snapshot:Build(characters).tasks[1].readiness, "unknown", "epoch change does not rebind")
saved = Hub.db.goals.byID[recurring.id]; assert(Hub.Goals:Update(saved.id, saved.revision, { intent = saved.intent }))
Equal(Hub.Snapshot:Build(characters).byCharacter.C[1].task.readiness, "actionable", "explicit revalidation")
local before = #Hub.Goals:List(); Hub.Database:Initialize(); Equal(#Hub.Goals:List(), before, "reload keeps goals")
local originalDB = YiboTaskHubDB
YiboTaskHubDB = { schemaVersion = 3, bossTargets = { sourceEpoch = "legacy", revision = 5, nextID = 7, byCharacter = {
 C = { { id = "target:7", catalogID = "instance:1", title = "Raid", scope = "boss", encounterIDs = { 1, 3 }, difficultyID = 4, active = false, kind = "instance" } } } } }
assert(Hub.Database:Initialize())
Equal(#Hub.Goals:List(), 1, "migrate explicit Boss only")
local migrated = Hub.Goals:List()[1]
Equal(migrated.legacyBossID, "target:7"); Equal(migrated.state, "paused"); Equal(migrated.intent.conditions.encounterIDs[2], 3)
assert(Hub.Database:Initialize()); Equal(#Hub.Goals:List(), 1, "idempotent migration")
Equal(#Hub.db.goalMigration.legacyBossTargets.C, 1, "migration backup")
YiboTaskHubDB = { schemaVersion = 3, bossTargets = { byCharacter = { C = { { catalogID = "x" } } } } }
Equal(Hub.Database:Initialize(), nil, "failed migration stops")
Equal(YiboTaskHubDB.schemaVersion, 3, "failed migration does not stamp schema")
Equal(YiboTaskHubDB.goals, nil, "failed migration atomic")
YiboTaskHubDB = originalDB; assert(Hub.Database:Initialize())
local control = CreateFrame("Button")
local intent = Intent("gesture")
assert(Core.BusinessItemActions:Bind(control, { owner = "Spec", GetIntent = function() return intent end, reservedButtons = { LeftButton = true } }))
Equal(Core.BusinessItemActions:Handle(control, "LeftButton"), false, "original click preserved")
Equal(Core.BusinessItemActions:Handle(control, "MiddleButton"), true, "default middle")
local count = #Hub.Goals:List(); Core.BusinessItemActions:Handle(control, "MiddleButton"); Equal(#Hub.Goals:List(), count - 1, "second gesture removes target")
Equal(Hub.located, nil, "middle cancel keeps original surface open")
Equal(Core.BusinessItemActions:Handle(control, "MiddleButton"), true, "third gesture adds again")
Equal(#Hub.Goals:List(), count, "toggle restores one target")
Core.BusinessItemActions:Invoke(control)
Equal(Hub.located ~= nil, true, "explicit menu still locates duplicate")
Hub.located = nil
Equal(Core.BusinessItemActions:SetGesture({ button = "LeftButton", ctrl = true }), nil, "reserved conflict")
assert(Core.BusinessItemActions:SetGesture({ button = "Button4", ctrl = true }))
IsControlKeyDown = function() return true end
Equal(Core.BusinessItemActions:Handle(control, "Button4"), true, "configured gesture")
intent = Intent("recycled", nil, "D")
assert(Core.BusinessItemActions:Bind(control, { owner = "Spec", GetIntent = function() return intent end }))
control.yiboItemMenu.scripts.OnClick(); Equal(Hub.Goals:List()[#Hub.Goals:List()].intent.scope.characterID, "D", "menu gets current context")
Core.BusinessItemActions:Unbind(control); Equal(Core.BusinessItemActions:Handle(control, "Button4"), false, "unbound safe")
local menu = control.yiboItemMenu; Core.BusinessItemActions:Bind(control, { owner = "Spec", GetIntent = function() return Intent("new") end }); Equal(control.yiboItemMenu, menu, "reuse menu no allocation leak")
-- Public copy uses a revision-bound preview and stages all targets atomically.
local original = assert(Hub.Goals:Add(Intent("copy-source", "recurring", "C")))
local preview = assert(Hub.Goals:PreviewCopy({ original.id }, { "D" }))
Equal(preview.added, 1); Equal(preview.existing, 0)
assert(Hub.Goals:ApplyCopy(preview.token))
Equal(Hub.Goals:PreviewCopy({ original.id }, { "D" }).existing, 1, "copy dedup")
local oldPreview = assert(Hub.Goals:PreviewCopy({ original.id }, { "U" }))
Hub.Goals:Add(Intent("revision-changes"))
Equal(Hub.Goals:ApplyCopy(oldPreview.token), nil, "stale copy rejected")
Equal(Hub.Goals:Lookup(Intent("copy-source", "recurring")).id, original.id, "public exact lookup")
Equal(Hub.Goals:Lookup(Intent("copy-source", "once")), nil, "different completion mode must not mark added")
local lookups, originalLookup = 0, Hub.Goals.Lookup
Hub.Goals.Lookup = function(self, ...) lookups = lookups + 1; return originalLookup(self, ...) end
Core.BusinessItemActions:Bind(control, { owner = "Spec", GetIntent = function() return Intent("copy-source", "recurring") end })
Equal(lookups, 0, "matrix render performs no per-cell goal lookup")
Equal(control.yiboItemMenu.shown, false, "add button hidden at rest")
GetMouseFocus = function() return control end
Core.BusinessItemActions:RefreshHover()
Equal(lookups, 1, "lookup deferred until hover")
Equal(control.yiboItemMenu.label.text, "", "added menu does not depend on checkmark font glyph")
Equal(control.yiboItemMenu.addedCheck.shown, true, "hover reflects exact goal with native check texture")
control:SetScript("OnEnter", function() end)
local neighbor = Frame()
Core.BusinessItemActions:Bind(neighbor, { owner = "Spec", menuPlacement = "right", GetIntent = function() return Intent("neighbor") end })
GetMouseFocus = function() return neighbor end
Core.BusinessItemActions:RefreshHover()
Equal(control.yiboItemMenu.shown, false, "moving to another source hides old button")
Equal(neighbor.yiboItemMenu.shown, true, "hover survives replaced native tooltip scripts")
Equal(neighbor.yiboItemMenu.point[1], "TOPLEFT", "product button sits outside original icon")
GetMouseFocus = function() return neighbor.yiboItemMenu end
Core.BusinessItemActions:RefreshHover()
Equal(neighbor.yiboItemMenu.shown, true, "moving onto add button preserves source")
Core.BusinessItemActions:Unbind(neighbor)
GetMouseFocus = function() return control end
Core.BusinessItemActions:RefreshHover()
GetMouseFocus = function() return nil end
Core.BusinessItemActions:RefreshHover()
timers[#timers].fn()
Equal(control.yiboItemMenu.shown, false, "add button closes after hover")
Hub.Goals.Lookup = originalLookup
-- Persistent item membership is broader than the exact configured target.
local Actions = Core.BusinessItemActions
local member = assert(Hub.Goals:Add(Intent("membership", "once", "C")))
local partialIntent = { providerID = "Spec:targets", objectID = "membership", scope = { mode = "character", characterID = "C" } }
Actions:Bind(control, { owner = "Spec", GetIntent = function() return partialIntent end })
Actions:RefreshMarkers()
Equal(control.yiboGoalMarkerH.shown, true, "saved item has persistent corner marker")
Equal(control.yiboItemMenu.shown, false, "persistent marker does not require visible add button")
partialIntent.scope.characterID = "D"; Actions:Bind(control, { owner = "Spec", GetIntent = function() return partialIntent end })
Equal(control.yiboGoalMarkerH.shown, false, "recycled control clears previous marker immediately")
Actions:RefreshMarkers(); Equal(control.yiboGoalMarkerH.shown, false, "another role is not marked")
partialIntent.scope.characterID = nil; Actions:RefreshMarkers()
Equal(control.yiboGoalMarkerH.shown, true, "role-free row reflects saved item membership")
local g = Hub.db.goals.byID[member.id]; assert(Hub.Goals:Update(member.id, g.revision, { state = "paused" }))
Actions:RefreshMarkers(); Equal(Actions.bindings[control].itemStatus.paused, 1, "paused goal remains visibly added")
g = Hub.db.goals.byID[member.id]; assert(Hub.Goals:Update(member.id, g.revision, { state = "removed" }))
Actions:RefreshMarkers(); Equal(control.yiboGoalMarkerH.shown, false, "removal clears persistent marker")
local configuringBefore, countBefore = Hub.configuring, #Hub.Goals:List()
Actions:Invoke(control, { keepOpen = true })
Equal(Hub.configuring, configuringBefore, "incomplete gesture does not navigate to editor")
Equal(#Hub.Goals:List(), countBefore, "incomplete gesture cannot fake a saved goal")
local markerCalls, oldItems = 0, Hub.Goals.LookupItems
Hub.Goals.LookupItems = function(self, ...) markerCalls = markerCalls + 1; return oldItems(self, ...) end
Actions.markersQueued = false
local timersBefore = #timers
for i = 1, 5 do Actions:Bind(control, { owner = "Spec", GetIntent = function() return Intent("gesture") end }) end
local markerTimers = 0
for i = timersBefore + 1, #timers do if timers[i].delay == 0 then markerTimers = markerTimers + 1 end end
Equal(markerTimers, 1, "many bindings schedule one membership batch")
timers[#timers].fn(); Equal(markerCalls, 1, "one service call covers visible bindings")
Hub.Goals.LookupItems = oldItems
Actions:Unbind(control); Equal(control.yiboGoalMarkerH.shown, false, "unbinding hides membership marker")
-- Twenty role goals share exactly one source batch per unchanged scope.
local many = {}; for i = 1, 20 do
    local id = "many:" .. i; many[i] = { id = id, name = id, realm = "test" }
    assert(Hub.Goals:Add(Intent("twenty", "recurring", id)))
end
local beforeCalls = calls
local batched = Hub.Contracts:GetGoalResults(many)
Equal(#batched[1].result.data.tasks, 20); Equal(calls, beforeCalls + 1, "one source batch for 20 roles")
Hub.Contracts:GetGoalResults(many); Equal(calls, beforeCalls + 1, "repeat projection cached")
Hub.Contracts:GetGoalResults({ many[1] }); Equal(calls, beforeCalls + 2, "current-role batch")
Hub.Contracts:GetGoalResults(many); Equal(calls, beforeCalls + 2, "main and current scopes do not evict each other")
-- Major-incompatible sources retain user goals as unknown.
assert(Core.Contracts:Unregister("Spec", ref))
local incompatible = Core.Defaults:Copy({ name = "action.targets", kind = "provider", providerID = "Spec:targets", version = { major = 2, minor = 0 } })
incompatible.methods = provider.methods
local badRef = assert(Core.Contracts:Register("Spec", incompatible))
Equal(Hub.Contracts:GetGoalResults(many)[1].result.data.tasks[1].readiness, "unknown")
assert(Core.Contracts:Unregister("Spec", badRef)); ref = assert(Core.Contracts:Register("Spec", provider))
Actions:Bind(control, { owner = "Spec", GetIntent = function() return Intent("copy-source", "recurring") end })
Actions:RefreshMarkers(); Equal(control.yiboGoalMarkerH.shown, true, "marker visible before Task removal")
Core.Contracts:Unregister(Hub.NAME, Hub.Goals.ref)
Actions:RefreshMarkers(); Equal(control.yiboGoalMarkerH.shown, false, "missing Task clears membership feedback")
Equal(Core.BusinessItemActions:Invoke(control), nil, "Task missing safe")
print("TaskGoalIntegration: " .. checks .. " checks passed")
