-- Run from the repository root with Lua 5.1; no client sampling overhead.
dofile("YiboTaskHub/_NonRelease/Tests/BossTargetsSpec.lua")
local Core, Hub, Plans = YiboCore, YiboTaskHub, YAB.PlannedTargets
local checked = 0
local function Equal(actual, expected, label)
    checked = checked + 1
    assert(actual == expected, label .. ": " .. tostring(actual) .. " ~= " .. tostring(expected))
end
local request = { scope = { characterIDs = { "A" } } }
Plans:Query(request)
local projections, configurations = 0, 0
local project, call = Plans.Project, Core.Contracts.Call
Plans.Project = function(self, ...) projections = projections + 1; return project(self, ...) end
Core.Contracts.Call = function(self, owner, ref, method, ...)
    if ref.name == "task.boss-targets" then configurations = configurations + 1 end
    return call(self, owner, ref, method, ...)
end
Plans:Configuration({ "A" })
configurations = 0
for _ = 1, 200 do
    Plans:Observe()
    Plans:Query(request)
    Plans:Configuration({ "A" })
end
Equal(projections, 0, "200 unchanged observations/queries perform no account projection")
Equal(configurations, 0, "200 repeated role configurations perform no service query")
Plans:ScheduleChange()
Plans:Query(request)
Equal(projections, 1, "real invalidation rebuilds once")
Plans:Query(request)
Equal(projections, 1, "following read reuses projection")
Plans.Project, Core.Contracts.Call = project, call

-- Two independent sources, interleaved current and account scopes.
local counts, refs = {}, {}
assert(Core:RegisterAddon("PerfFixture", { requiredAPI = 11 }))
for _, name in ipairs({ "one", "two" }) do
    counts[name] = 0
    refs[name] = assert(Core.Contracts:Register("PerfFixture", {
        kind = "provider", name = "action.targets", providerID = "PerfFixture:" .. name,
        version = { major = 1, minor = 0 }, methods = {
        Normalize = function(r) local i=Core.Defaults:Copy(r.intent); i.repeatPolicy="recurring"; return {intent=i,title="Performance",identity=i.providerID..":"..i.scope.characterID} end,
        Evaluate = function(r)
            counts[name] = counts[name] + 1
            local coverage = {}; for _, goal in ipairs(r.goals) do coverage[goal.intent.scope.characterID] = { state = "known-empty" } end
            return { providerID = "PerfFixture:" .. name, sourceEpoch = "perf", revision = 1,
                generatedAt = GetServerTime(), evaluations = {} }
        end },
    }))
    for _, id in ipairs({"A","B"}) do assert(Hub.Goals:Add({ providerID="PerfFixture:"..name, objectID=name, scope={mode="character",characterID=id} })) end
end
Hub.Contracts:GetResults({ { id = "A" } })
Hub.Contracts:GetResults({ { id = "A" }, { id = "B" } })
for _ = 1, 200 do
    Hub.Contracts:GetResults({ { id = "A" } })
    Hub.Contracts:GetResults({ { id = "A" }, { id = "B" } })
end
Equal(counts.one, 2, "current/account scope alternation keeps source one cached")
Equal(counts.two, 2, "current/account scope alternation keeps source two cached")
Core.Contracts:NotifyChanged("PerfFixture", refs.one, { revision = 2 })
Hub.Contracts:GetResults({ { id = "A" } })
Equal(counts.one, 3, "changed source queried again")
Equal(counts.two, 2, "unrelated source stays cached")
local previousCall, requested = Core.Contracts.Call, nil
Core.Contracts.Call = function(self, owner, ref, method, r)
    if owner == Hub.NAME and ref.providerID == "PerfFixture:one" then requested = {}; for _, goal in ipairs(r.goals) do requested[#requested+1] = goal.intent.scope.characterID end end
    return previousCall(self, owner, ref, method, r)
end
Hub.Contracts:Invalidate("PerfFixture:one")
Core.AccountView.GetVisibleCharacters = function() return Core.Characters:GetAll() end
Hub.Presentation:Current()
Equal(#requested, 1, "HUD requests only the admitted current role")
Core.Contracts.Call = previousCall

-- Real Core identity projection with a deliberately large unrelated domain.
local stored = { id = "A", name = "角色", realm = "服务器", level = 90, domains = { inventory = { data = {} } } }
for i = 1, 10000 do stored.domains.inventory.data[i] = { itemID = i, count = 1 } end
Core.Database = { GetDB = function() return { characters = { byID = { A = stored } } } end }
dofile("YiboCore/Data/Characters.lua")
local copies, nativeCopy = 0, Core.Defaults.Copy
Core.Defaults.Copy = function(self, value) copies = copies + 1; return nativeCopy(self, value) end
for _ = 1, 200 do
    Equal(Core.Characters:Get("A", { identityOnly = true }).domains, nil, "identity excludes domains")
    Core.Characters:GetAll({ identityOnly = true })
end
Equal(copies, 0, "400 identity reads perform no deep copy")
local complete = Core.Characters:Get("A")
Equal(complete.domains.inventory.data[10000].itemID, 10000, "legacy full-record query preserved")
complete.domains.inventory.data[1].count = 99
Equal(stored.domains.inventory.data[1].count, 1, "full-record query remains detached")
Core.Defaults.Copy = nativeCopy

-- Actual Todo daily/special collectors: stable observations do not invalidate.
YiboTodoDB, C_Timer = nil, nil
dofile("YiboTodo/Tests/DailyQuestSmoke.lua")
local Todo, notifications = YiboTodo, 0
Todo.NotifyChanged = function() notifications = notifications + 1 end
local daily = Todo.Providers.Registry:Get("daily-quest")
GetNumQuestLogEntries = function() return 0 end
daily:Observe("perf"); daily:ObserveCooking("perf"); daily:ObserveLegacyActivities("perf")
local baseTime, elapsed = GetServerTime(), 0
local h, m = GetGameTime()
GetServerTime = function() return baseTime + elapsed end
GetGameTime = function()
    local seconds = h * 3600 + m * 60 + baseTime % 60 + elapsed
    return math.floor(seconds / 3600) % 24, math.floor(seconds / 60) % 60
end
notifications = 0
for i = 1, 200 do
    elapsed = i
    daily:Observe("perf"); daily:ObserveCooking("perf"); daily:ObserveLegacyActivities("perf")
end
Equal(notifications, 0, "200 unchanged daily observations send no notifications")
local definition = daily:GetDefinition()
local questID = definition.daily and definition.daily.questID or definition.stages[1].questID
GetNumQuestLogEntries = function() return 1 end
C_QuestLog.GetInfo = function() return { questID = questID, title = "日常", isComplete = false } end
daily:Observe("perf")
Equal(notifications, 1, "actual quest state change still notifies")
daily:Observe("perf")
Equal(notifications, 1, "repeated new state does not notify again")
dofile("YiboTodo/Tests/SpecialActivitySmoke.lua")
Todo, notifications = YiboTodo, 0
Todo.NotifyChanged = function() notifications = notifications + 1 end
local special = Todo.Providers.Registry:Get("special-activity")
special:ObserveCharacter("perf")
notifications = 0
for _ = 1, 200 do special:ObserveCharacter("perf") end
Equal(notifications, 0, "200 unchanged special observations send no notifications")
local hasCapability = Core.HasCapability
Core.HasCapability = function(self, name, version)
    if name == "character-identity" then return false end
    return hasCapability(self, name, version)
end
Hub.CoreIntegration.initialized = false
Equal(Hub.CoreIntegration:Initialize(), nil, "Task stops when identity capability is missing")
Plans:Shutdown()
Equal(Plans:Initialize(), nil, "Boss enhancement stops when identity capability is missing")
dofile("YiboTodo/CoreIntegration.lua")
Equal(Todo.CoreIntegration:Initialize(), nil, "Todo stops when identity capability is missing")
Core.HasCapability = hasCapability
print("TaskChainPerformance: " .. checked .. " checks passed")
