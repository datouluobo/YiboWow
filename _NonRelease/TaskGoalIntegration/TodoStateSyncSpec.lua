-- Actual source, goal consumer and notification contracts; controlled clock.
dofile("_NonRelease/TaskGoalIntegration/GoalSourcesSpec.lua")
local Core, Todo, Hub, checks = YiboCore, YiboTodo, YiboTaskHub, 0
C_Timer = nil -- Deliver source notifications synchronously in this fixture.
Core.DataDomains.Get = function(_, characterID, domainID)
    if domainID == "professions" and (characterID == "C" or characterID == "D") then
        return { state = "known", data = { primaryProfessions = { { id = 197, skillLevel = 600, name = "裁缝" } } } }
    end
end
GetGameTime = function() return 6, 59 end
-- The fixture's old-Core rejection check clears the local registration handle.
for _, descriptor in ipairs(Core.Contracts:List("action.targets", { major = 1 })) do
    if descriptor.providerID == Todo.GoalTargets.PROVIDER then Todo.GoalTargets.ref = descriptor.registrationRef end
end
local function Equal(a, b, label) checks = checks + 1; assert(a == b, label .. ": " .. tostring(a) .. " ~= " .. tostring(b)) end
dofile("YiboTodo/ActionContracts.lua")
assert(Todo.ActionContracts:Initialize())
local id = Todo.ActionTodo.GROUP
local intent = Todo.GoalTargets:Intent({ groupID = id }, "C")
local goal = assert(Hub.Goals:Lookup(intent))
Hub.Contracts:Invalidate()
local record = Todo.Database:GetProvider("C", "profession-cooldown", false)
local observation = record.observations[id]
local initial = Todo:Now()
observation.observedAt = initial
observation.recipes[143011].readyAt = 0
Todo.Settings.IsMonitoringItemEnabled = function() return true end
Todo:NotifyChanged()
local function Task()
    for _, row in ipairs(Hub.Snapshot:Build(Core.Characters:GetAll()).current) do
        if row.task.goalID == goal.id then return row.task end
    end
end
Equal(Task().readiness, "preparation", "confirmed available state reaches goal consumer")
local project = Todo.Snapshot:GetCharacter("C").activities[id]
local exact = Todo.Snapshot:BuildTarget("C", id).activities[id]
Equal(exact.state, project.state, "account and exact source state agree")
Equal(exact.icon, project.icon, "account and exact source icon agree")
Equal(exact.monitoringGroupID, project.monitoringGroupID, "exact source keeps profession action metadata")
Equal(#exact.action.members, #project.action.members, "exact source keeps shared recipe members")
Equal(exact.action.selectSpellID, project.action.selectSpellID, "same recipe selection in both surfaces")
-- Reproduce saved client observations: learned/craftable, nil cooldown API.
observation.recipes[143011].cooldownKnown = false
observation.recipes[143011].readyAt = nil
local silkID = "mop.tailoring.imperial-silk"
local silkIntent = Todo.GoalTargets:Intent({ groupID = silkID }, "C")
local silk = assert(Hub.Goals:Add(silkIntent))
record.observations[silkID] = { sourceState = "known", observedAt = initial,
    recipes = { [125557] = { learned = true, craftable = true, cooldownKnown = false } } }
Todo:NotifyChanged()
Equal(Todo.Snapshot:GetCharacter("C").activities[id].state, "actionable", "Todo accepts learned recipe without numeric cooldown")
Equal(Task().readiness, "preparation", "Task preserves Todo actionable preparation")
Equal(Task().confidence, "profession", "missing cooldown remains explicitly unconfirmed")
Equal(Task().state, "active", "no numeric cooldown never proves completion")
dofile("YiboTaskHub/Presentation.lua")
dofile("YiboTaskHub/Preview.lua")
dofile("YiboTaskHub/AccountPage.lua")
local context = { characters = Core.Characters:GetAll() }
local preview = Hub.Preview:Build(context)
local found = {}
for _, group in ipairs(preview.groups) do if group.character.id == "C" then
    for _, pair in ipairs(group.entries) do if pair.row.task.goalID == goal.id or pair.row.task.goalID == silk.id then
        found[pair.row.task.goalID] = true
        Equal(pair.members, nil, "each cloth remains individual in preview")
        Equal(pair.row.task.readiness, "preparation", "preview uses synchronized source readiness")
    end end
end end
Equal(found[goal.id] and found[silk.id], true, "preview shows both cloths")
Equal(Hub.AccountPage:Status(Task()), Core.Locale:Get("YiboTaskHub", "TEXT.READY_COOLDOWN_TO_CONFIRM.BC16D3"), "status explains missing cooldown")
-- Unknown current targets also keep their individual icon and source reason.
observation.sourceState, record.observations[silkID].sourceState = "unknown", "unknown"
Todo:NotifyChanged()
preview = Hub.Preview:Build(context)
local unverified = 0
for _, group in ipairs(preview.groups) do if group.character.id == "C" then
    for _, pair in ipairs(group.entries) do if pair.row.task.goalID == goal.id or pair.row.task.goalID == silk.id then
        Equal(pair.members, nil, "unknown current goal is not folded by preview")
        unverified = unverified + 1
    end end
end end
Equal(unverified, 2, "both unverified cloth goals remain visible")
observation.sourceState, record.observations[silkID].sourceState = "known", "known"
assert(Hub.Goals:Update(silk.id, Hub.db.goals.byID[silk.id].revision, { state = "removed" }))
observation.recipes[143011].cooldownKnown = true
-- Reuse the consumer cache: only the source notification may invalidate it.
observation.recipes[143011].readyAt = initial + 60
Todo:NotifyChanged(true, { groupID = id })
Equal(Task(), nil, "new cooldown observation immediately removes actionable work")
local history = #Hub.db.goals.byID[goal.id].history
Equal(history > 0, true, "confirmed cooldown supplies completion evidence")
GetServerTime = function() return initial + 120 end
GetGameTime = function() return 7, 1 end
Todo:NotifyChanged()
local resetTask = assert(Task())
Equal(resetTask.sourceState, "estimated", "daily reset retains estimated source state")
Equal(resetTask.confidence, "estimated", "reset does not invent confirmed cooldown scan")
Equal(resetTask.readiness, "preparation", "reset estimate remains visible preparation")
Equal(resetTask.freshness.state, "known", "derived preparation is current until next reset")
Equal(resetTask.freshness.observedAt, initial, "reset never refreshes observation time")
Equal(#Hub.db.goals.byID[goal.id].history, history, "estimated preparation is never completion evidence")
Equal(Todo.Snapshot:GetCharacter("C").activities[id].state, resetTask.sourceState, "Todo and Task agree after reset")
-- Actual professional observation after opening the panel upgrades confidence.
observation.observedAt = Todo:Now()
observation.recipes[143011].readyAt = 0
Todo:NotifyChanged()
Equal(Task().confidence, "confirmed", "new profession scan upgrades estimate")
Equal(Task().readiness, "preparation", "confirmed preparation stays visible")
dofile("YiboTodo/Providers/ProfessionCooldown.lua")
local provider = Todo.Providers.Registry:Get("profession-cooldown")
assert(provider:RecordSuccessfulCraft("C", 143011))
Todo:NotifyChanged()
Equal(Task(), nil, "successful craft immediately synchronizes completion")
local lockout = record.observations[id].recipes[143011].readyAt
provider.Collect = function()
    return { [id] = { sourceState = "known", observedAt = Todo:Now(), recipes = {
        [143011] = { learned = true, craftable = true, cooldownKnown = true, readyAt = Todo:Now() } } } }
end
assert(provider:CollectForCurrentCharacter("C"))
Equal(record.observations[id].recipes[143011].readyAt, lockout, "lagging zero scan cannot undo successful craft")
Equal(Task(), nil, "lagging profession event cannot reopen completed work")
GetServerTime = function() return initial + 86520 end
GetGameTime = function() return 7, 1 end
assert(provider:CollectForCurrentCharacter("C"))
Equal(Todo.Snapshot:BuildTarget("C", id).activities[id].state, "actionable", "new cycle accepts actual zero cooldown scan")
record.observations[id] = nil
Todo:NotifyChanged()
Equal(Task().readiness, "unknown", "never-scanned recipe remains unverified")
local other = Todo.Snapshot:BuildTarget("D", id).activities[id]
Equal(other.state, "unknown", "current observation never leaks to another character")
print("TodoStateSyncSpec: " .. checks .. " checks passed")
