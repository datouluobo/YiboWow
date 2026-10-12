-- Historical action.todo envelope regression. The explicit-goal production path is tested in
-- _NonRelease/TaskGoalIntegration; this fixture deliberately omits the target library.
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
    function frame:HookScript(event, callback) self.scripts[event] = callback end
    function frame:SetText(text) self.text = text end
    function frame:SetTexture(texture) self.texturePath = texture end
    function frame:SetShown(shown) self.shown = shown end
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
Core.IsInitialized = function() return true end
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
Core.Capabilities:Register("account-entry", 2)
Core.Capabilities:Register("builtin-entry-bar", 1)

Core.Database = { GetDB = function() return { settings = {} } end }
dofile("YiboCore/UI/BusinessItemActions.lua")
assert(loadfile("YiboTaskHub/Namespace.lua"))("YiboTaskHub", {})
dofile("YiboTaskHub/Locales/zh.lua")
dofile("YiboTaskHub/Locales/en.lua")
for _, file in ipairs({ "Database", "Snapshot", "Contracts", "Presentation", "Preview", "AccountPage", "HUD", "Reminders", "Displays", "Settings", "CoreIntegration" }) do dofile("YiboTaskHub/" .. file .. ".lua") end
local Hub = YiboTaskHub
Core.Locale.previewLanguage = "en"
Equal(Hub:T("PAGE.TITLE"), "Action Hub", "Core session language selects TaskHub English resource")
Equal(Hub:T("SUMMARY.SOURCE_WORK", 3), "3 source tasks", "localized format parameters are applied")
Core.Locale.previewLanguage = nil
Hub.Database:Initialize()
Hub.db.goals = nil -- legacy envelope fixture; never the current default
Hub.Goals = { Initialize = function() return true end, Shutdown = function() end }
local baselineSubscriptions = #Core.Events._listeners.BUSINESS_CONTRACT_CHANGED
local baselineRegisteredSubscriptions = #Core.Events._listeners.BUSINESS_CONTRACT_REGISTERED
assert(Hub.CoreIntegration:Initialize())
Equal(pages.taskhub.previewEnabled, true, "O4 Core hover enabled")
Equal(entries.yth.pageID, "taskhub")
local registeredTaskHub = Core.Registry:Get("YiboTaskHub")
Equal(registeredTaskHub.requiredAPI, 13, "TaskHub declares API 13")
Equal(entries.yth.defaultChannels.minimap, false, "TaskHub minimap entry defaults off")
Equal(entries.yth.defaultChannels.broker, false, "TaskHub broker entry defaults off")
Equal(entries.yth.defaultChannels.builtinBar, false, "TaskHub built-in bar entry defaults off")
Equal(Hub.Snapshot:Build(characters).providerCount, 0, "missing source is not an exception")
assert(Hub.CoreIntegration:Initialize())
Equal(#Core.Events._listeners.BUSINESS_CONTRACT_CHANGED, baselineSubscriptions + 1, "idempotent subscriptions")

dofile("YiboTodo/Namespace.lua")
for _, file in ipairs({ "Database", "Catalog/ActivityCatalog", "Catalog/CooldownGroupCatalog", "Catalog/CooldownCatalog_MoP",
    "Catalog/Ruleset_50504", "Catalog/DailyActivityCatalog_MoP", "Catalog/Validator", "Model/Schedule", "Model/State", "Providers/Registry", "Providers/DailyQuest", "Model/Snapshot", "ActionTodo", "ActionNomi", "ActionContracts" }) do
    dofile("YiboTodo/" .. file .. ".lua")
end
local Todo = YiboTodo
Todo.Core = Core
Todo.Database:Initialize()
Todo:ValidateCatalog()
local monitored, nomiMonitored = true, false
Todo.Settings = { IsMonitoringGroupEnabled = function() return false end,
    IsMonitoringItemEnabled = function(_, _, groupID)
        return (monitored and groupID == Todo.ActionTodo.GROUP) or (nomiMonitored and groupID == Todo.ActionNomi.GROUP)
    end }
local function Observe(id, readyAt, learned, craftable)
    local record = Todo.Database:GetProvider(id, "profession-cooldown", true)
    record.lastSuccessAt, record.state = clock, "known"
    record.observations[Todo.ActionTodo.GROUP] = { sourceState = "known", observedAt = clock,
        recipes = { [143011] = { learned = learned ~= false, craftable = craftable ~= false, cooldownKnown = true, readyAt = readyAt } } }
end
Observe("C", 0)
Observe("D", clock + 600)
Core.Events:Register("BUSINESS_CONTRACT_CHANGED", "test-observer", function() notices = notices + 1 end)
assert(Core:RegisterAddon("YiboTodo", { requiredAPI = 10 }))
assert(Todo.ActionContracts:Initialize())
Equal(#Hub.Contracts.list, 2, "both late registrations discovered")
local first = Hub.Snapshot:Build(characters)
Equal(first.uniqueCount, 2)
Equal(#first.current, 1)
Equal(#first.others, 1)
Equal(first.current[1].task.readiness, "preparation", "zero cooldown does not prove materials")
Equal(first.others[1].task.readiness, "blocked", "offline cooldown remains waiting")
Equal(first.others[1].task.sourceState, Todo.Snapshot:GetCharacter("D").activities[Todo.ActionTodo.GROUP].state, "source view agreement")
Equal(first.uncoveredCount, 1, "unknown professions retained in coverage")
Equal(first.current[1].task.quantity, nil, "no invented output count")
local request = { scope = { characterIDs = { "C", "C", "U", "F" } } }
local result = Todo.ActionTodo:Query(request)
Equal(#result.data.tasks, 1, "explicit scope and repeated role dedup")
Equal(result.coverage.F.state, "known-empty")
Equal(result.coverage.U.state, "not-yet-scanned")
Equal(Todo.ActionTodo:Query({}), nil, "scope required")
Equal(#Todo.ActionTodo:Query({ scope = { characterIDs = {} } }).data.tasks, 0, "empty scope stays empty")
local epoch, revision, identity = result.sourceEpoch, result.revision, first.current[1].task.identity
result.data.tasks[1].title = "tampered"
Equal(Todo.ActionTodo:Query(request).data.tasks[1].title, "神纹布", "public snapshot copied")
Equal(Todo.ActionTodo:Query(request).revision, revision, "query without change is stable")
Todo.ActionTodo.value = nil
Equal(Todo.ActionTodo:Query(request).sourceEpoch, epoch, "projection reload keeps epoch")
Equal(Todo.ActionTodo:Query(request).revision, revision, "projection reload keeps revision")
Observe("C", clock + 1000)
Todo.AccountPage = { RefreshProjectIcon = function() return true end }
Todo:NotifyChanged(true, {})
Equal(notices, 1, "source change emitted before fast UI return")
Equal(Hub.Snapshot:Build(characters).current[1].task.readiness, "blocked", "completion observation invalidates consumer")
Equal(Todo.ActionTodo:Query(request).revision > revision, true)
Equal(Hub.Snapshot:Build(characters).current[1].task.identity, identity, "same cycle stable identity")
Todo:NotifyChanged(); Equal(notices, 1, "unchanged facts do not re-broadcast")

clock, hour, minute = clock + 120, 7, 1
Hub.Contracts:Invalidate()
local expired = Hub.Snapshot:Build(characters)
Equal(expired.current[1].task.readiness, "preparation", "source reset projects estimated preparation")
Equal(expired.current[1].task.freshness.state, "known")
Equal(expired.current[1].task.identity ~= identity, true, "source owns new daily cycle")
Equal(expired.current[1].task.freshness.observedAt, 100000, "query does not refresh observation time")
monitored = false; Todo:NotifyChanged()
Equal(Hub.Snapshot:Build(characters).uniqueCount, 0, "monitoring off removes task")
monitored = true
Todo.Database:GetProvider("C", "profession-cooldown", false).observations[Todo.ActionTodo.GROUP] = nil
Todo:NotifyChanged()
local unobserved = Hub.Snapshot:Build(characters)
Equal(unobserved.current[1].task.freshness.observedAt, nil, "other recipe scan not inherited")
Equal(unobserved.current[1].task.readiness, "unknown")
Observe("C", 0, false); Todo:NotifyChanged()
Equal(Todo.ActionTodo:Query(request).data.tasks[1].reason, "配方未学习", "unlearned reason retained")
Observe("C", 0); domains.C.data.primaryProfessions[1].skillLevel = 481; Todo:NotifyChanged()
Equal(Todo.ActionTodo:Query(request).data.tasks[1].reason, "专业技能不足")
domains.C.data.primaryProfessions[1].skillLevel = 600

-- Coalesce source changes. A query committing a new revision before the
-- deferred notification must not prevent other cached consumers invalidating.
local timers = {}
C_Timer = { After = function(delay, callback) timers[#timers + 1] = { at = clock + delay, callback = callback } end }
local function FlushDue()
    local pending = timers; timers = {}
    for _, timer in ipairs(pending) do
        if timer.at <= clock then timer.callback() else timers[#timers + 1] = timer end
    end
end
local beforeNotices = notices
Observe("C", 0); Todo:NotifyChanged(); Todo:NotifyChanged()
Todo.ActionTodo:Query(request)
FlushDue()
Equal(notices, beforeNotices + 1, "query before deferred commit still notifies")
local beforeRefresh = refreshes
Hub.Contracts:GetResults(characters)
Hub.Contracts:Invalidate()
Hub.Contracts:GetResults(characters)
local boundary = Hub.Contracts.nextChange
clock = boundary + 1; hour, minute = 7, 2
FlushDue()
Equal(refreshes > beforeRefresh + 1, true, "same boundary timer rescheduled after invalidation")
Equal(Hub.Snapshot:Build(characters).current[1].task.readiness, "preparation", "timer expiry re-queries estimated preparation")
Equal(Todo.Snapshot:GetCharacter("C").activities[Todo.ActionTodo.GROUP].state, "estimated", "zero cooldown expires in source model too")
FlushDue() -- Drain next-frame source notifications before removing the timer API.
C_Timer = nil

-- Migrate only the owner's records, then rebuild against new Core IDs.
local migrated = Todo.Database:MoveCharacterData("C", "C-new")
Equal(migrated, true, "source identity migration")
characters[1].id, domains["C-new"], domains.C = "C-new", domains.C, nil
currentID = "C-new"
Todo:NotifyChanged()
Core.Events:Fire("CHARACTER_ID_CHANGED", "C", "C-new")
local migratedView = Hub.Snapshot:Build(characters)
Equal(migratedView.current[1].task.execution.characterID, "C-new")
Equal(migratedView.byCharacter.C, nil, "old role removed from projection")
-- Restore the fixture IDs before exercising generic candidate contracts.
Todo.Database:MoveCharacterData("C-new", "C")
characters[1].id, domains.C, domains["C-new"], currentID = "C", domains["C-new"], nil, "C"
Todo:NotifyChanged(); Hub.Contracts:Invalidate()

-- Second real source: the actual Nomi daily provider and source model. All
-- monitored roles have a projection; qualification is never fabricated.
local function Work(view, id, source)
    for _, row in ipairs(view.byCharacter[id] or {}) do
        if row.task.providerID == source then return row.task end
    end
end
local log = {}
GetNumQuestLogEntries = function() return #log end
GetQuestLogTitle = function(index)
    local entry = log[index]
    return entry and entry.label, 90, nil, false, false, entry and entry.complete or false, 1, entry and entry.id
end
local nomiProvider = assert(Todo.Providers.Registry:Get("daily-quest"))
local clothMeta = Todo.ActionTodo:GetMetadata()
local clothEpoch, clothRevision = clothMeta.sourceEpoch, clothMeta.revision
assert(Todo.ActionContracts:Initialize())
Equal(#Hub.Contracts.list, 2, "repeat initialization does not duplicate either source")
nomiMonitored = true; Todo:NotifyChanged()
local nomiView = Hub.Snapshot:Build(characters)
Equal(nomiView.providerCount, 2, "two actual source providers")
Equal(nomiView.uniqueCount, 6, "cloth and Nomi coexist without identity collision")
for _, id in ipairs({ "C", "D", "F", "U" }) do
    local task = assert(Work(nomiView, id, Todo.ActionNomi.PROVIDER))
    Equal(task.readiness, "unknown", "unconfirmed Nomi eligibility " .. id)
    Equal(task.freshness.observedAt, nil, "no fabricated observation " .. id)
    Equal(task.quantity, nil, "Nomi has no manufactured quantity " .. id)
end
Hub.db.settings.sourceFilter = Todo.ActionNomi.PROVIDER
local nomiRows = Hub.AccountPage:Filter(nomiView)
Equal(#nomiRows, 4, "real source filter")
Equal(Hub.AccountPage:Stats(nomiRows), 4, "Nomi account unique count")
Hub.db.settings.sourceFilter = "all"
local nomiRequest = { scope = { characterIDs = { "F", "F", "absent" } } }
local nomiResult = Todo.ActionNomi:Query(nomiRequest)
Equal(#nomiResult.data.tasks, 1, "Nomi explicit scope and role dedup")
Equal(nomiResult.coverage.absent.state, "not-yet-scanned")
Equal(Todo.ActionNomi:Query({}), nil, "Nomi requires scope")
Equal(#Todo.ActionNomi:Query({ scope = { characterIDs = {} } }).data.tasks, 0)
nomiResult.data.tasks[1].title = "tampered"
Equal(Todo.ActionNomi:Query(nomiRequest).data.tasks[1].title, "诺米", "Nomi result copied")
Equal(Todo.ActionNomi:Query({ scope = { characterIDs = { [2] = "F" } } }), nil, "Nomi rejects sparse scope")
assert(nomiProvider:Observe("U"))
Equal(Todo.ActionNomi:Query({ scope = { characterIDs = { "U" } } }).coverage.U.state, "partial", "empty quest scan does not prove eligibility")
Equal(Work(Hub.Snapshot:Build(characters), "U", Todo.ActionNomi.PROVIDER).readiness, "unknown")
local registryGet = Todo.Providers.Registry.Get
Todo.Providers.Registry.Get = function(self, id) if id ~= "daily-quest" then return registryGet(self, id) end end
Todo:NotifyChanged()
Equal(Todo.ActionNomi:Query(nomiRequest).coverage.F.state, "unavailable", "missing daily source is not known empty")
Equal(Hub.Snapshot:Build(characters).uniqueCount, 2, "missing Nomi leaves healthy cloth source")
Todo.Providers.Registry.Get = registryGet
Todo:NotifyChanged()

log = { { id = 31333, label = "第2课", complete = false } }
local beforeNomiNotices = notices
assert(nomiProvider:Observe("F"))
Equal(notices, beforeNomiNotices + 1, "Nomi-only change notifies one source")
nomiView = Hub.Snapshot:Build(characters)
local fNomi = assert(Work(nomiView, "F", Todo.ActionNomi.PROVIDER))
Equal(fNomi.readiness, "actionable", "Nomi needs no tailoring qualification")
Equal(fNomi.reason, "可处理")
Equal(fNomi.sourceState, Todo.Snapshot:GetCharacter("F").nomiProjects[1].state, "Nomi source state agreement")
Equal(fNomi.sourceTitle, "诺米日常", "filter title distinguishes real sources")
Equal(fNomi.title, "诺米·第2课：方便面", "known lesson shown compactly")
local nomiIdentity, observationAt = fNomi.identity, fNomi.freshness.observedAt
log = { { id = 31334, label = "第3课", complete = true } }
assert(nomiProvider:Observe("F"))
fNomi = assert(Work(Hub.Snapshot:Build(characters), "F", Todo.ActionNomi.PROVIDER))
Equal(fNomi.identity, nomiIdentity, "lesson update retains daily task identity")
Equal(fNomi.sourceState, "in-progress")
Equal(fNomi.reason, "待交付", "objective completion is not hand-in")
Equal(Hub.AccountPage:Status(fNomi), "待交付", "generic page displays source-owned action status")
Equal(fNomi.state, "active")
assert(nomiProvider:RecordTurnIn("F", 31334))
Equal(Work(Hub.Snapshot:Build(characters), "F", Todo.ActionNomi.PROVIDER), nil, "hand-in removes only F's Nomi work")
Equal(Hub.Snapshot:Build(characters).uniqueCount, 5)
Equal(Todo.ActionNomi:Query({ scope = { characterIDs = { "F" } } }).data.tasks[1].state, "completed", "source retains completed fact")
assert(nomiProvider:Observe("F"))
Equal(Work(Hub.Snapshot:Build(characters), "F", Todo.ActionNomi.PROVIDER), nil, "stale quest log cannot undo hand-in")
Equal(Todo.ActionTodo:GetMetadata().sourceEpoch, clothEpoch, "second source preserves first epoch")
Equal(Todo.ActionTodo:GetMetadata().revision, clothRevision, "Nomi-only updates do not revise cloth")
local nomiEpoch, nomiRevision = Todo.ActionNomi:GetMetadata().sourceEpoch, Todo.ActionNomi:GetMetadata().revision
Todo.ActionNomi.value = nil
Equal(Todo.ActionNomi:Query(nomiRequest).sourceEpoch, nomiEpoch, "Nomi reload preserves epoch")
Equal(Todo.ActionNomi:Query(nomiRequest).revision, nomiRevision, "Nomi reload preserves revision")
assert(nomiProvider:RecordTurnIn("U", 31820))
Equal(nomiProvider:GetEligibility("U"), nil, "graduation alone is not ongoing eligibility")

-- Source daily rollover restores only proven repeatable eligibility. It is
-- not a new observation and does not require a current-role login scan.
clock = clock + 86400
local resetView = Hub.Snapshot:Build(characters)
fNomi = assert(Work(resetView, "F", Todo.ActionNomi.PROVIDER))
Equal(fNomi.reason, "可接取", "offline proven eligibility resets to offered work")
Equal(fNomi.readiness, "actionable")
Equal(fNomi.questID, nil, "do not invent the next rotating lesson")
Equal(fNomi.freshness.observedAt, observationAt, "historical qualification timestamp retained")
Equal(fNomi.freshness.state, "known", "source ongoing eligibility is not an expired daily observation")
Equal(fNomi.identity ~= nomiIdentity, true, "new source cycle creates a new task identity")
Equal(Work(resetView, "U", Todo.ActionNomi.PROVIDER).readiness, "unknown", "graduation does not grant tomorrow's qualification")
Equal(fNomi.sourceState, Todo.Snapshot:GetCharacter("F").nomiProjects[1].state)
currentID = "F"; Hub.Contracts:Invalidate()
Equal(Work(Hub.Snapshot:Build(characters), "F", Todo.ActionNomi.PROVIDER).execution.characterID, "F", "Nomi role switching")
Equal(#Hub.Snapshot:Build(characters).current, 1, "non-tailor current role sees Nomi work")
currentID = "C"
local clothBeforeDisable = Todo.ActionTodo:GetMetadata().revision
nomiMonitored = false; Todo:NotifyChanged()
Equal(Hub.Snapshot:Build(characters).uniqueCount, 2, "Nomi disabled leaves cloth work")
Equal(Todo.ActionNomi:Query(nomiRequest).coverage.F.state, "known-empty")
Equal(Todo.ActionTodo:GetMetadata().revision, clothBeforeDisable, "Nomi monitoring does not invalidate first source revision")
-- Delayed callbacks from a retired lifecycle cannot notify a new registration.
local retiredTimers = {}
C_Timer = { After = function(_, callback) retiredTimers[#retiredTimers + 1] = callback end }
nomiMonitored = true; Todo:NotifyChanged()
Todo.ActionContracts:Shutdown()
Equal(Hub.Snapshot:Build(characters).providerCount, 0, "both real sources removed")
assert(Todo.ActionContracts:Initialize())
Equal(#Hub.Contracts.list, 2, "both real sources rediscovered")
local noticesAfterRestart = notices
for _, callback in ipairs(retiredTimers) do callback() end
Equal(notices, noticesAfterRestart, "retired deferred notification ignored")
C_Timer = nil
nomiMonitored = false; Todo:NotifyChanged()

-- Generic sources demonstrate cross-role/candidate projection only, not an
-- implemented manufacturing or dispatch workflow.
assert(Core:RegisterAddon("Fixture", { requiredAPI = 11 }))
local generation, completed = 1, false
local function Generic()
    local task = { itemKey = "one", title = "共享工作", businessRef = { capability = "action.todo", providerID = "Fixture:one", sourceEpoch = "fixture", key = "one" },
        execution = { mode = "open", candidateCharacterIDs = { "C", "D", "D" } }, beneficiary = { mode = "character", characterID = "F" },
        state = completed and "completed" or "active", readiness = "actionable", temporal = { kind = "persistent" }, freshness = { state = "known" } }
    return task
end
local function QueryGeneric(r)
    local coverage = {}; for _, id in ipairs(r.scope.characterIDs) do coverage[id] = { state = "known" } end
    return { providerID = "Fixture:one", sourceEpoch = "fixture", revision = generation, generatedAt = clock, sourceTitle = "测试来源", status = "ready",
        coverage = coverage, data = { tasks = { Generic(), Generic() } } }
end
local fixtureRef = assert(Core.Contracts:Register("Fixture", { name = "action.todo", kind = "provider", providerID = "Fixture:one", version = { major = 1, minor = 0 }, methods = { Query = QueryGeneric } }))
local candidates = Hub.Snapshot:Build(characters)
Equal(candidates.candidateCount, 1, "duplicate task/candidates count once")
local cCandidate, dCandidate = 0, 0
for _, row in ipairs(candidates.current) do if row.candidate then cCandidate = cCandidate + 1; Equal(row.task.beneficiary.characterID, "F") end end
for _, row in ipairs(candidates.others) do if row.candidate then dCandidate = dCandidate + 1 end end
Equal(cCandidate, 1); Equal(dCandidate, 1)
Equal(candidates.byCharacter.F, nil, "beneficiary does not become executor")
local pageRows = Hub.AccountPage:Filter(candidates)
Hub.db.settings.sourceFilter = "Fixture:one"
local filteredRows = Hub.AccountPage:Filter(candidates)
local filteredCount, filteredCandidates = Hub.AccountPage:Stats(filteredRows)
Equal(filteredCount, 1, "filtered account total remains unique")
Equal(filteredCandidates, 1)
Hub.db.settings.sourceFilter = "all"
local start, finish, page, pagesCount = Hub.AccountPage:Slice(pageRows, 1, 180)
Equal(pagesCount > 1, true, "small viewport paginates")
Equal(finish - start + 1, 1, "height budget limits visible tasks")
local ui = Frame(); ui:SetSize(1040, 420)
local context = { characters = characters, scope = "all", surfaceAvailableWidth = 1040 }
Hub.AccountPage.Create(ui); Hub.AccountPage.Refresh(ui, context)
Equal(ui.rows[1].backdrop, nil, "rows do not have adjacent boxed borders")
Equal(ui.rows[1].rule.height, 1, "one shared bottom divider")
Equal(ui.rows[1].cells[1].text, "星河", "character uses Core formatting")
Equal(ui.rows[1].identities[1].label.text, "星河", "identity reuses Core shared character control")
local todoRow
for _, row in ipairs(ui.rows) do if row.task and row.task.nextAction and row.task.nextAction.pageID == "todo" then todoRow = row; break end end
assert(todoRow); todoRow.action.scripts.OnClick(todoRow.action)
Equal(Core.lastPage, "todo", "source page navigation")
local priorDeletionRefresh = refreshes
Core.Events:Fire("CHARACTER_CACHE_DELETED", "F")
Equal(refreshes > priorDeletionRefresh, true, "actual cleanup event invalidates center")
currentID = "D"; Hub.Contracts:Invalidate()
Equal(Hub.Snapshot:Build(characters).current[1].character.id, "D", "login role reprojection")
completed, generation = true, generation + 1
Core.Contracts:NotifyChanged("Fixture", fixtureRef, { revision = generation })
Equal(Hub.Snapshot:Build(characters).candidateCount, 0, "source completion clears all candidate projections")
assert(Core.Contracts:Unregister("Fixture", fixtureRef))
Equal(#Hub.Contracts.list, 2, "unregistration removes source")
Equal(Hub.Snapshot:Build(characters).candidateCount, 0)
assert(Core:RegisterAddon("Broken", { requiredAPI = 11 }))
local brokenRef = assert(Core.Contracts:Register("Broken", { name = "action.todo", kind = "provider", providerID = "Broken:one", version = { major = 1, minor = 0 }, methods = { Query = function() error("broken") end } }))
Equal(#Hub.Snapshot:Build(characters).errors, 1, "exception isolated")
Equal(Hub.Snapshot:Build(characters).uniqueCount > 0, true, "healthy source survives")
Core.Contracts:Unregister("Broken", brokenRef)
local malformedRef = assert(Core.Contracts:Register("Broken", { name = "action.todo", kind = "provider", providerID = "Broken:one", version = { major = 1, minor = 0 }, methods = { Query = function() return { data = { tasks = { 1 } } } end } }))
Equal(#Hub.Snapshot:Build(characters).errors, 1, "malformed result isolated")
Core.Contracts:Unregister("Broken", malformedRef)
local futureRef = assert(Core.Contracts:Register("Broken", { name = "action.todo", kind = "provider", providerID = "Broken:future", version = { major = 2, minor = 0 }, methods = { Query = function() error("must not be called") end } }))
Equal(#Hub.Snapshot:Build(characters).errors, 0, "incompatible major not called")
Core.Contracts:Unregister("Broken", futureRef)
Todo.ActionContracts:Shutdown()
Equal(Hub.Snapshot:Build(characters).providerCount, 0, "source disabled clears cached state")
local checkAPI = Core.CheckAPIVersion
Core.CheckAPIVersion = function(_, minimum) return minimum < 11 end
Equal(Todo.ActionContracts:Initialize(), nil, "old Core stops new source integration")
Hub.CoreIntegration.initialized = false
Core.CheckAPIVersion = function(_, minimum) return minimum <= 12 end
local initResult, initError = Hub.CoreIntegration:Initialize()
Equal(initResult, nil, "API 12 Core stops center initialization")
Equal(initError:find("API 13", 1, true) ~= nil, true, "API 12 failure explains required upgrade")
Equal(registeredTaskHub.requiredAPI, 13, "registered TaskHub minimum remains API 13")
Core.CheckAPIVersion = checkAPI
local hasCapability = Core.HasCapability
Core.HasCapability = function(self, name, version)
    if name == "localization" then return false end
    return hasCapability(self, name, version)
end
Hub.CoreIntegration.initialized = false
initResult = Hub.CoreIntegration:Initialize()
Equal(initResult, nil, "missing localization capability stops TaskHub")
Core.HasCapability = function(self, name, version)
    if name == "builtin-entry-bar" then return false end
    return hasCapability(self, name, version)
end
Hub.CoreIntegration.initialized = false
initResult = Hub.CoreIntegration:Initialize()
Equal(initResult, nil, "missing API 13 entry channel capability stops TaskHub")
Core.HasCapability = hasCapability
local isInitialized = Core.IsInitialized
Core.IsInitialized = function() return false end
Hub.CoreIntegration.initialized = false
initResult = Hub.CoreIntegration:Initialize()
Equal(initResult, nil, "TaskHub waits for initialized Core language and entry services")
Core.IsInitialized = isInitialized
Hub.Contracts:Shutdown()
Equal(#Core.Events._listeners.BUSINESS_CONTRACT_REGISTERED, baselineRegisteredSubscriptions, "Task cleanup preserves Core feedback subscription")
Equal(_G.YiboTaskHubDB.tasks, nil, "source tasks not persisted")
print("ActionIntegrationSpec: " .. checks .. " checks passed")
