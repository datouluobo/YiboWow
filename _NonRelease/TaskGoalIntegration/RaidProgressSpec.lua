dofile("_NonRelease/TaskGoalIntegration/BossGoalsSpec.lua")
local Hub, Core, Plans = YiboTaskHub, YiboCore, YAB.PlannedTargets
GetLocale = function() return arg[1] or "zhCN" end
Core.Locale.initialized, Core.Locale.previewLanguage = false, nil
Core.Database.db.settings.language = arg[2] or "auto"
Core.Locale:Initialize()
assert(Plans:Initialize())
local checks, now, reset = 0, 100000, 105000
GetServerTime = function() return now end
C_DateAndTime.GetSecondsUntilWeeklyReset = function() return reset - now end
local function Equal(a, b, label)
    checks = checks + 1; assert(a == b, label .. ": " .. tostring(a) .. " ~= " .. tostring(b))
end
local function Normalize(scope, ids, characterID)
    return assert(Hub.Goals:Normalize({ providerID = "YiboAltoBoss:targets", targetType = "boss", objectID = "instance:580",
        scope = { mode = "character", characterID = characterID or "A" }, repeatPolicy = "recurring",
        conditions = { catalogID = "instance:580", difficultyID = 176, scope = scope or "boss", encounterIDs = ids or { "raid:580:kil" } } }))
end
local target = Normalize().intent.conditions
local record = YiboAltoBossDB.characters["星河-甲"]
record.instanceLockoutsObservedAt = now
record.targetLockoutCycles = { weekly = Plans:Period("weekly") }
record.instanceLockouts = { sw = { instanceID = 580, difficultyID = 176, locked = true,
    bossCount = 1, resetAt = reset, bosses = { { name = "Kalecgos", encounterID = "raid:580:kal", killed = false } } } }
local before = Plans:Progress("A", target)
Equal(before.state, "unknown", "one native record does not invent other kills")
Equal(before.reason, Core.Locale:Get("YiboAltoBoss", "GOAL.LOCKED_UNVERIFIED"), "reason distinguishes lockout from unverified boss")
local ref
for _, source in ipairs(Core.Contracts:List("action.targets", { major = 1, minMinor = 2 })) do if source.providerID == "YiboAltoBoss:targets" then ref = source end end
assert(ref)
local action = Normalize().actions[1]
local saved = assert(Core.Contracts:Call(Hub.NAME, ref, action.method, action.request))
Equal(type(saved.message), "string", "manual action returns localized result")
local progress = Plans:Progress("A", target)
Equal(progress.state, "completed", "manual confirmation completes selected final")
Equal(progress.evidenceSource, "manual", "manual source is explicit")
Equal(progress.reason, Core.Locale:Get("YiboAltoBoss", "GOAL.MANUAL_COMPLETE"), "manual result is labelled")
Equal(progress.freshness, "known", "human confirmation is current explicit evidence")
Equal(#record.instanceLockouts.sw.bosses, 1, "native snapshot remains intact")
Equal(record.instanceLockouts.sw.bosses[1].killed, false, "confirmation never marks blue dragon killed")
Equal(Plans:Progress("A", Normalize("all").intent.conditions).state, "unknown", "final confirmation does not complete the whole raid")
Equal(Plans:Progress("B", Normalize(nil, nil, "B").intent.conditions).state ~= "completed", true, "manual record is character scoped")
local actions = Normalize().actions
Equal(#actions, 2, "confirmed target offers revocation")
assert(Core.Contracts:Call(Hub.NAME, ref, actions[2].method, actions[2].request))
Equal(Plans:Progress("A", target).state, "unknown", "revocation restores unverified state")
local old = Normalize().actions[1].request
YiboAltoBossDB.plannedTargetSource.revision = YiboAltoBossDB.plannedTargetSource.revision + 1
Equal(Core.Contracts:Call(Hub.NAME, ref, "ConfirmCycle", old), nil, "changed source invalidates old confirmation")

-- Native capture uses exact instance/difficulty identity and success signals.
local mapID, kind, difficultyID = 580, "raid", 176
GetInstanceInfo = function() return "Sunwell", kind, difficultyID, "25", 25, 0, false, mapID end
local event, guid = "UNIT_DIED", "Creature-0-1-2-3-25315-000001"
CombatLogGetCurrentEventInfo = function() return now, event, nil, nil, nil, nil, nil, guid end
YAB.RaidEvents:Sync()
kind = "party"
Equal(YAB.RaidEvents:Observe("COMBAT_LOG_EVENT_UNFILTERED"), nil, "party deaths cannot complete raid goal")
kind, mapID = "raid", 564
Equal(YAB.RaidEvents:Observe("COMBAT_LOG_EVENT_UNFILTERED"), nil, "wrong instance is ignored")
mapID, guid = 580, "Creature-0-1-2-3-25316-000001"
Equal(YAB.RaidEvents:Observe("COMBAT_LOG_EVENT_UNFILTERED"), nil, "nearby creature ID is ignored")
guid, event = "Creature-0-1-2-3-25315-000001", "SPELL_DAMAGE"
Equal(YAB.RaidEvents:Observe("COMBAT_LOG_EVENT_UNFILTERED"), nil, "damage is not completion")
event = "UNIT_DIED"
Equal(YAB.RaidEvents:Observe("ENCOUNTER_END", 729, "Kil'jaeden", 176, 25, 0), nil, "failed encounter does not complete goal")
Equal(YAB.RaidEvents:Observe("ENCOUNTER_END", 729, "Kil'jaeden", 175, 10, 1), nil, "other difficulty success is ignored")
assert(YAB.RaidEvents:Observe("COMBAT_LOG_EVENT_UNFILTERED"))
progress = Plans:Progress("A", target)
Equal(progress.state, "completed", "precise final creature death supplies missing native record")
Equal(progress.evidenceSource, "encounter", "automatic evidence is labelled")
Equal(YAB.RaidEvents:Observe("COMBAT_LOG_EVENT_UNFILTERED"), nil, "same-cycle duplicate death is idempotent")
actions = Normalize().actions
assert(Core.Contracts:Call(Hub.NAME, ref, actions[1].method, actions[1].request))
actions = Normalize().actions
assert(Core.Contracts:Call(Hub.NAME, ref, actions[2].method, actions[2].request))
Equal(Plans:Progress("A", target).evidenceSource, "encounter", "revocation retains independently captured evidence")
local staleRequest = Normalize().actions[1].request
now, reset = 105001, 110000
Equal(Plans:Progress("A", target).state ~= "completed", true, "reset expires both evidence sources")
Equal(Core.Contracts:Call(Hub.NAME, ref, "ConfirmCycle", staleRequest), nil, "cross-cycle confirmation is rejected")
Equal(Plans:Progress("A", target).state ~= "completed", true, "reload-shaped old record does not revive")
assert(YAB.RaidEvents:Observe("BOSS_KILL", 2493, "Unlocalized final name"))
Equal(Plans:Progress("A", target).state, "completed", "native encounter identity resolves independently of display name")
Equal(Plans:Progress("A", Normalize("boss", { "raid:580:muru" }).intent.conditions).state ~= "completed", true, "final evidence does not leak to another boss")

-- Exercise the actual Hub-owned confirmation UI, including cancel and stale state.
record.raidProgress = {}
record.instanceLockoutsObservedAt = now
record.targetLockoutCycles.weekly = Plans:Period("weekly")
record.instanceLockouts.sw.resetAt = reset
Hub.AccountPage = Hub.AccountPage or {}
local goal = assert(Hub.Goals:Add(Normalize().intent))
local editor, frame = Hub.GoalEditor, CreateFrame("Frame")
editor.Create(frame)
editor:Configure(Hub.db.goals.byID[goal.id].intent, goal.id)
local confirmation
Core.ItemConfirmation = { Show = function(_, value) confirmation = value end }
editor.Refresh(frame, { characters = Core.Characters:GetAll() })
frame.actions.sourceActions[1].scripts.OnClick()
Equal(type(confirmation.text), "string", "manual action uses Core confirmation")
Equal(confirmation.IsCurrent(), true, "current scope and cycle accepted")
Equal(Plans:Progress("A", target).state, "unknown", "opening or cancelling dialog does not write progress")
confirmation.OnAccept()
Equal(Plans:Progress("A", target).state, "completed", "accept writes owner evidence")
local evaluation = YAB.GoalTargets:Evaluate({ goals = { Hub.db.goals.byID[goal.id] } })
Equal(evaluation.evaluations[goal.id].task.state, "completed", "Hub evaluation consumes same completion")
Equal(evaluation.evaluations[goal.id].task.reason, Core.Locale:Get("YiboAltoBoss", "GOAL.MANUAL_COMPLETE"), "Hub exposes manual provenance")
editor.Refresh(frame, { characters = Core.Characters:GetAll() })
frame.actions.sourceActions[2].scripts.OnClick()
editor.draft.conditions.encounterIDs = { "raid:580:muru" }
Equal(confirmation.IsCurrent(), false, "editing selected boss invalidates pending dialog")
editor:Configure(Hub.db.goals.byID[goal.id].intent, goal.id)
editor.Refresh(frame, { characters = Core.Characters:GetAll() })
frame.actions.sourceActions[2].scripts.OnClick(); confirmation.OnAccept()
Equal(Plans:Progress("A", target).state, "unknown", "UI revokes manual evidence")
Plans:Shutdown()
Equal(YAB.RaidEvents.started, false, "provider shutdown stops capture")
Equal(YAB.RaidEvents:Observe("BOSS_KILL", 729, "Kil'jaeden"), nil, "stopped source cannot capture")
assert(Plans:Initialize())
Equal(YAB.RaidEvents.started, true, "source restart is supported")
print("RaidProgressSpec: " .. checks .. " checks passed")
