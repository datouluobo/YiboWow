-- Real event owner and goal consumer across the source-owned midnight boundary.
dofile("_NonRelease/TaskGoalIntegration/GoalSourcesSpec.lua")
local Todo, Hub, Core, checks = YiboTodo, YiboTaskHub, YiboCore, 0
C_Timer = nil
local clock = Todo:Now()
GetServerTime = function() return clock end
GetGameTime = function() return 23, 59 end
local open = true
C_Calendar = { GetNumDayEvents = function() return open and 1 or 0 end,
    GetDayEvent = function() return { title = "Darkmoon Faire" } end }
dofile("YiboTodo/Catalog/SpecialActivityCatalog_MoP.lua")
dofile("YiboTodo/Mists/Darkmoon.lua")
dofile("YiboTodo/Providers/SpecialActivity.lua")
dofile("YiboTaskHub/Presentation.lua")
dofile("YiboTaskHub/Preview.lua")
dofile("YiboTaskHub/AccountPage.lua")
local function Equal(a, b, label) checks = checks + 1; assert(a == b, label .. ": " .. tostring(a) .. " ~= " .. tostring(b)) end
local provider = Todo.Providers.Registry:Get("special-activity")
local ids = { "mop.darkmoon-faire.29513", "mop.darkmoon-faire.29512" }
local goals = {}
for _, characterID in ipairs({ "C", "D" }) do for _, id in ipairs(ids) do
    goals[#goals + 1] = assert(Hub.Goals:Add(Todo.GoalTargets:Intent({ groupID = id }, characterID)))
end end
local context, frame = { characters = Core.Characters:GetAll() }, {}
local function Rows()
    local value = Hub.Snapshot:Build(context.characters)
    return Hub.AccountPage:Retain(Hub.AccountPage:Filter(value), frame, context), value
end
local function EventCount(rows)
    local count = 0
    for _, pair in ipairs(rows) do for _, goal in ipairs(goals) do if pair.row.task.goalID == goal.id then count = count + 1 end end end
    return count
end
local rows = Rows()
Equal(EventCount(rows), 4, "open event appears for current and other character")
-- Finish one task while the view stays open; normal completion is retained.
assert(provider:RecordTurnIn("C", 29513))
Hub.Contracts:Invalidate(Todo.GoalTargets.PROVIDER)
rows = Rows()
Equal(EventCount(rows), 4, "completion remains in the open view")
Equal(Hub.db.goals.byID[goals[1].id].lastCompletedCycle ~= nil, true, "source completion recorded")
local histories = {}; for _, g in ipairs(goals) do histories[g.id] = #Hub.db.goals.byID[g.id].history end
-- No user reopen or explicit invalidation: the cached event boundary expires.
clock = clock + 61; GetGameTime = function() return 0, 0 end; open = false
rows = Rows()
Equal(EventCount(rows), 0, "midnight closure removes active and retained completed event rows")
Equal(provider:GetProject("C", Todo.Catalog.specialActivities[ids[1]], clock), nil, "Todo view hides closed event")
local exact = Todo.Snapshot:BuildTarget("C", ids[1]).nomiProjects[1]
Equal(exact.state, "not-applicable", "exact query distinguishes closure from missing data")
local preview = Hub.Preview:Build(context)
Equal(EventCount(preview.rows), 0, "preview hides closed event")
for _, g in ipairs(goals) do
    Equal(Hub.db.goals.byID[g.id].state, "active", "goal survives event closure")
    Equal(#Hub.db.goals.byID[g.id].history, histories[g.id], "closure never adds completion history")
end
-- Next event, same saved goals. Owner determines the new weekly cycle.
clock = clock + 35 * 86400; open = true
rows = Rows()
Equal(EventCount(rows), 4, "next event restores saved goals without re-adding")
local oldGet = Todo.Providers.Registry.Get
Todo.Providers.Registry.Get = function(self, id) if id ~= "special-activity" then return oldGet(self, id) end end
Hub.Contracts:Invalidate(Todo.GoalTargets.PROVIDER)
rows = Rows()
Equal(EventCount(rows), 4, "missing source is unverified rather than silently hidden")
Todo.Providers.Registry.Get = oldGet
print("EventGoalsSpec: " .. checks .. " checks passed")
