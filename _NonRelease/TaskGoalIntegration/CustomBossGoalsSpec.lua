-- Actual AltoBoss Core custom-NPC CRUD/kill rules and public goal contracts.
dofile("_NonRelease/TaskGoalIntegration/BossGoalsSpec.lua")
local Core, Hub, checks = YiboCore, YiboTaskHub, 0
local clock = GetServerTime()
GetServerTime = function() return clock end
C_Timer = nil
UnitName = function() return "星河" end
GetRealmName = function() return "甲" end
UnitLevel = function() return 90 end
UnitClass = function() return "法师", "MAGE" end
wipe = function(t) for k in pairs(t) do t[k] = nil end end
dofile("YiboAltoBoss/Core.lua")
YAB.PersistDB()
assert(YAB.PlannedTargets:Initialize())
local function Equal(a, b, label) checks = checks + 1; assert(a == b, label .. ": " .. tostring(a) .. " ~= " .. tostring(b)) end
local function Task(id)
    for _, task in ipairs(Hub.Snapshot:Build(Core.Characters:GetAll()).tasks) do if task.goalID == id then return task end end
end
local before = Hub.BossTargets:Catalog(true)
Equal(YAB.TargetCatalog:Get("custom:999001"), nil, "custom target initially absent")
assert(YAB.AddCustomTarget(999001, "测试稀有"))
local entry = assert(YAB.TargetCatalog:Get("custom:999001"))
Equal(entry.kind, "custom", "custom NPC appears in public catalog")
Equal(entry.reset, "respawn", "custom retains owner reset rule")
local catalog = assert(Hub.BossTargets:Catalog())
Equal(catalog ~= before, true, "adding NPC invalidates consumer catalog without reload")
local target = { catalogID = entry.id, scope = "all", encounterIDs = {} }
local intent = { providerID = YAB.GoalTargets.PROVIDER, scope = { mode = "character", characterID = "A" },
    conditions = target, repeatPolicy = "recurring" }
local cell, clicks = CreateFrame("Button"), 0
YAB.GoalTargets:Bind(cell, "星河-甲", target, function() clicks = clicks + 1; YAB.ToggleBossKill("星河-甲", entry.bossKey) end)
assert(Core.BusinessItemActions:SetOptions({ mode = "middle" }))
cell.scripts.OnClick(cell, "MiddleButton")
local goal = assert(Hub.Goals:Lookup(intent))
Equal(Task(goal.id).readiness, "actionable", "middle click adds custom goal")
Equal(clicks, 0, "adding preserves original business action")
Equal(YAB.PlannedTargets:Configuration({ "A" }).targets.A ~= nil, true, "shared configuration accepts custom kind")
cell.scripts.OnClick(cell, "MiddleButton")
Equal(Hub.Goals:Lookup(intent), nil, "second middle click removes exact custom goal")
assert(Core.BusinessItemActions:SetOptions({ mode = "ctrlLeft" }))
IsControlKeyDown = function() return true end
cell.scripts.OnClick(cell, "LeftButton")
goal = assert(Hub.Goals:Lookup(intent))
Equal(clicks, 0, "Ctrl-left consumes only goal action")
IsControlKeyDown = function() return false end
cell.scripts.OnClick(cell, "LeftButton")
Equal(clicks, 1, "plain left retains original mark operation")
Equal(Task(goal.id), nil, "actual manual kill completes custom goal")
local saved = Hub.db.goals.byID[goal.id]
Equal(#saved.history, 1, "completion recorded once")
local info = assert(YAB.GetKillInfo("星河-甲", entry.bossKey))
Equal(info.expiresAt, clock + 86400, "actual owner supplies 24-hour expiry")
Equal(YAB.PlannedTargets:Progress("A", target).validUntil, info.expiresAt, "projection uses owner expiry")
assert(Hub.BossTargets:Put("B", target))
local otherIntent = Core.Defaults:Copy(intent); otherIntent.scope.characterID = "B"
local other = assert(Hub.Goals:Lookup(otherIntent))
Equal(Task(other.id).readiness, "actionable", "kill does not leak across characters")
clock = info.expiresAt + 1
Equal(Task(goal.id).readiness, "actionable", "custom recurring goal returns after source expiry")
Equal(#saved.history, 1, "expiry never duplicates completion history")
assert(YAB.UpdateCustomTargetName(999001, "重命名稀有"))
YAB.NotifyCorePageChanged()
Equal(YAB.TargetCatalog:Get(entry.id).name, "重命名稀有", "rename refreshes source catalog")
Equal(Task(goal.id).title, "重命名稀有", "renamed custom goal refreshes Task")
-- Once goals use the same owner completion evidence but remain completed.
local onceIntent = Core.Defaults:Copy(intent); onceIntent.repeatPolicy = "once"
local once = assert(Hub.Goals:Add(onceIntent))
cell.scripts.OnClick(cell, "LeftButton")
Equal(Task(once.id), nil, "once custom goal completes")
Equal(Hub.db.goals.byID[once.id].state, "completed", "once completion persists")
clock = clock + 86401; Hub.Contracts:Invalidate(YAB.GoalTargets.PROVIDER)
Equal(Task(once.id), nil, "once goal stays completed after expiry")
assert(YAB.RemoveCustomTarget(999001))
Equal(YAB.TargetCatalog:Get(entry.id), nil, "removal refreshes source catalog")
Equal(Task(goal.id).readiness, "unknown", "removed NPC leaves saved goal unverified")
Equal(Hub.db.goals.byID[goal.id].state, "active", "NPC removal preserves user goal and history")
print("CustomBossGoalsSpec: " .. checks .. " checks passed")
