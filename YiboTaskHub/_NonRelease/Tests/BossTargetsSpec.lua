-- Actual Core contracts, target persistence, source collector and both views.
dofile("YiboTaskHub/_NonRelease/Tests/ActionIntegrationSpec.lua")
local Hub, Core = YiboTaskHub, YiboCore
local checks, now, timers = 0, 1791504000, {}
local function Equal(a, b, label)
    checks = checks + 1; assert(a == b, (label or "value") .. ": " .. tostring(a) .. " ~= " .. tostring(b))
end
GetServerTime = function() return now end
time, date = os.time, os.date
C_Timer = { After = function(delay, callback) timers[#timers + 1] = { at = now + delay, callback = callback } end }
local function Flush()
    for _ = 1, 8 do
        local pending = timers; timers = {}
        local ran = false
        for _, timer in ipairs(pending) do if timer.at <= now then timer.callback(); ran = true else timers[#timers + 1] = timer end end
        if not ran then return end
    end
    error("notification loop")
end
local characters = { { id = "A", name = "星河", realm = "甲", level = 90 }, { id = "B", name = "星河", realm = "乙", level = 90 },
    { id = "C", name = "暮光", realm = "甲", level = 90 }, { id = "D", name = "新角色", realm = "甲", level = 20 } }
Core.Characters.GetAll = function() return Core.Defaults:Copy(characters) end
Core.Characters.Get = function(_, id) for _, c in ipairs(characters) do if c.id == id then return Core.Defaults:Copy(c) end end end
Core.Characters.GetCurrent = function() return Core.Characters:Get("A") end
Core.Characters.ResolveLegacyKey = function(_, key) return ({ ["星河-甲"] = "A", ["星河-乙"] = "B", ["暮光-甲"] = "C", ["新角色-甲"] = "D" })[key] end
local nativeCreate = CreateFrame
CreateFrame = function(...)
    local frame = nativeCreate(...)
    function frame:GetText() return self.text or "" end
    function frame:GetFrameLevel() return 1 end
    function frame:GetChecked() return self.checked end
    local createFont = frame.CreateFontString
    function frame:CreateFontString(...)
        local font = createFont(self, ...)
        function font:GetText() return self.text or "" end
        function font:GetStringWidth() return #self:GetText() * 5 end
        return font
    end
    function frame:HookScript(event, callback)
        local previous = self.scripts[event]
        self.scripts[event] = function(...) if previous then previous(...) end; callback(...) end
    end
    return frame
end
dofile("YiboCore/UI/Input.lua")
UIParent = CreateFrame("Frame"); UIParent:SetSize(1280, 720)
dofile("YiboTaskHub/Common/Goals.lua"); dofile("YiboTaskHub/GoalContracts.lua"); dofile("YiboTaskHub/Common/GoalEditor.lua")
YiboTaskHubDB = { schemaVersion = 2, settings = { hudEnabled = false, sourceFilter = "kept" } }
assert(Hub.Database:Initialize())
Equal(Hub.db.schemaVersion, 4); Equal(Hub.db.settings.hudEnabled, false); Equal(Hub.db.settings.sourceFilter, "kept")
assert(Hub.Goals:Initialize())
dofile("YiboTaskHub/BossTargets.lua")
local Targets = Hub.BossTargets
assert(Targets:Initialize()); assert(Targets:Initialize())
assert(Hub.Contracts:Initialize())
Equal(Core.Contracts:Resolve("task.boss-targets", { major = 1 }).providerID, Hub.NAME .. ":boss-targets", "idempotent registration")
Equal(Targets:Catalog(), nil, "missing source")
Equal(Targets:Put("A", { catalogID = "world:galleon", scope = "all" }), nil)

local weekly = now + 5000
local daily = now + 3000
C_DateAndTime = { GetSecondsUntilWeeklyReset = function() return weekly - now end }
GetQuestResetTime = function() return daily - now end
local flags = {}
C_QuestLog = { IsQuestFlaggedCompleted = function(id) return flags[id] == true end }
local saved = {}
GetNumSavedInstances = function() return #saved end
GetSavedInstanceInfo = function(index)
    local item = saved[index]
    return item.name, 999, item.reset or weekly - now, item.difficultyID, true, item.extended, 0, true, 10, item.difficultyName or "10人普通", 2, 0, false, item.mapID
end
GetSavedInstanceEncounterInfo = function(index, i)
    local boss = saved[index].bosses[i]
    if boss then return boss.name, 0, boss.killed, false end
end
GetDifficultyInfo = function(id) return ({ [1] = "普通", [3] = "10人普通", [4] = "25人普通", [5] = "10人英雄" })[id] end
local selectedInstance, selectedDifficulty = 777, 4
EJ_GetNumTiers = function() return 1 end
EJ_GetCurrentTier = function() return 1 end
EJ_SelectTier = function() end
EJ_GetTierInfo = function() return "巫妖王之怒" end
EJ_GetInstanceByIndex = function(i, raid) if i == 1 and raid then return 123 end end
EJ_GetInstanceInfo = function() return "冰冠堡垒", nil, nil, nil, nil, nil, 99999, nil, true, 9631 end
EJ_SelectInstance = function(id) selectedInstance = id end
EJ_GetCurrentInstance = function() return selectedInstance end
EJ_SetDifficulty = function(id) selectedDifficulty = id end
EJ_GetDifficulty = function() return selectedDifficulty end
EJ_IsValidInstanceDifficulty = function(id) return id == 3 or id == 4 or id == 5 end
EJ_GetEncounterInfoByIndex = function(i)
    if i <= 2 then return ({ "玛洛加尔领主", "巫妖王" })[i], "description", 10000 + i, 0, nil, 123, 900 + i end
end
GetRealZoneText = function(mapID) if mapID == 9631 then return "冰冠堡垒" end end
YAB = {
    GetCurrentCharKey = function() return "星河-甲" end,
    GetCurrentRealm = function() return "甲" end,
    PersistDB = function() end,
    NotifyCorePageChanged = function() if YAB.PlannedTargets then YAB.PlannedTargets:ScheduleChange() end end,
    GetAllBossList = function() return { { key = "galleon", name = "炮舰" }, { key = "sha_of_anger", name = "怒之煞" },
        { key = "ordos", name = "斡耳朵斯" }, { key = "celestials", name = "四天神" }, { key = "nalak", name = "纳拉克" }, { key = "oondasta", name = "乌达斯塔" } } end,
    GetBossList = function() return { { key = "sha_of_anger", name = "怒之煞" } } end,
    GetAccountCharacterKeys = function(context)
        local keys = {}; for key in pairs(YiboAltoBossDB.knownChars) do keys[#keys + 1] = key end; return keys
    end,
}
YiboAltoBossDB = { settings = { lockoutColumns = {} }, knownChars = { ["星河-甲"] = {}, ["星河-乙"] = {}, ["暮光-甲"] = {}, ["新角色-甲"] = {} },
    characters = { ["星河-甲"] = {}, ["星河-乙"] = {}, ["暮光-甲"] = {}, ["新角色-甲"] = {} } }
dofile("YiboAltoBoss/Locale.lua")
dofile("YiboCore/_NonRelease/Tests/LoadCalendar.lua")
dofile("YiboAltoBoss/HolidayBoss.lua")
dofile("YiboAltoBoss/LockoutLocale.lua")
dofile("YiboAltoBoss/DungeonBossCatalog.lua")
dofile("YiboAltoBoss/DungeonRuns.lua")
dofile("YiboAltoBoss/InstanceLockouts.lua")
dofile("YiboAltoBoss/Mists/RaidCatalog.lua")
dofile("YiboAltoBoss/Mists/TargetCatalogRuntime.lua")
dofile("YiboAltoBoss/Common/TargetCatalog.lua")
dofile("YiboAltoBoss/PlannedTargets.lua")
dofile("YiboAltoBoss/Common/GoalTargets.lua")
dofile("YiboAltoBoss/Common/TargetProjection.lua")
assert(Core:RegisterAddon("YiboAltoBoss", { requiredAPI = 13 }))
local Plans = YAB.PlannedTargets
local originalAPI = Core.API_VERSION
Core.API_VERSION = 10; Equal(Plans:Initialize(), nil, "low API stops optional integration"); Core.API_VERSION = originalAPI
assert(Plans:Initialize()); Flush()
local catalog = assert(Targets:Catalog())
local instance
for _, entry in ipairs(catalog.targets) do if entry.id == "journal:123" then instance = entry end end
assert(instance)
Equal(instance.mapID, 9631, "journal vs map identity"); Equal(instance.encounters[1].id, 901, "journal vs dungeon encounter identity")
Equal(selectedInstance, 777, "journal selection restored"); Equal(selectedDifficulty, 4)
Equal(Targets:Matches(instance, "Icecrown Citadel"), true); Equal(Targets:Matches(instance, "i c c"), true)
Equal(Targets:Matches(instance, "冰冠"), true); Equal(Targets:Matches(instance, "巫妖王"), true)
Equal(Targets:Matches(instance, "The Lich King"), true); Equal(Targets:Matches(instance, "LK"), true)
Equal(Targets:EncounterMatch(instance, "LK"), "巫妖王", "parent search shows matching encounter")
Equal(Targets:Matches(instance, "not-present"), false)
catalog.targets[1].name = "tampered"; Equal(Targets:Catalog(true).targets[1].name == "tampered", false, "copied catalog")
local function Boss(id) return { catalogID = "world:" .. (id or "galleon"), scope = "all", active = true } end
local function Dungeon(encounters, difficulty, scope)
    return { catalogID = "journal:123", difficultyID = difficulty or 3, scope = scope or "boss", encounterIDs = encounters or { 901 }, active = true }
end
assert(Targets:Put("A", Boss()))
assert(Targets:Put("A", Dungeon({ 901, 901 })))
Equal(#Targets:List("A"), 2); Equal(#Targets:List("A")[2].encounterIDs, 1, "duplicate encounters dedup")
Equal(Targets:Put("A", Dungeon({ 10001 })), nil, "journal ID rejected as encounter")
Equal(Targets:Put("A", Dungeon({ 901 }, 88)), nil, "unknown difficulty rejected")
Equal(Targets:Put("missing", Boss()), nil)
assert(Targets:Put("B", Dungeon({ 902 })))
local bGoal = Targets:List("B")[1]
assert(Targets:Edit("B", bGoal.id, false))
local pending = assert(Targets:PreviewCopy("A", { "B", "C", "B" }))
Equal(pending.added, 3); Equal(pending.merged, 1); Equal(pending.pausedDifferences, 1)
Equal(#Targets:List("C"), 0, "preview has no side effects")
assert(Targets:ApplyCopy(pending))
Equal(Targets:List("B")[1].active, false, "destination pause preserved")
Equal(#Targets:List("B")[1].encounterIDs, 2, "partial boss overlap merges")
Equal(#Targets:List("C"), 2)
Equal(Targets:ApplyCopy(pending), nil, "stale preview rejected")
local reverse = assert(Targets:PreviewCopy("B", { "A" })); assert(Targets:ApplyCopy(reverse))
Equal(#Targets:List("A")[2].encounterIDs, 2, "reverse merge adds missing encounter")
Equal(Targets:List("A")[2].active, true, "source pause never overwrites destination")
local cGoal = Targets:List("C")[2]
assert(Targets:Edit("C", cGoal.id, false))
Equal(Targets:List("A")[2].active, true, "copy remains independent")
local expansion = assert(Targets:PreviewCopy("A", { "B" }))
assert(Targets:Put("A", Dungeon({}, 3, "all")))
Equal(Targets:ApplyCopy(expansion), nil, "atomic stale write prevention")
local allPreview = assert(Targets:PreviewCopy("A", { "B" }))
Equal(allPreview.merged, 1, "whole dungeon expands subset"); assert(Targets:ApplyCopy(allPreview))
Equal(Targets:List("B")[1].scope, "all"); Equal(Targets:List("B")[1].active, false)
local copied = Targets:Query({ scope = { characterIDs = { "A" } } })
copied.targets.A[1].title = "tampered"; Equal(Targets:List("A")[1].title, "炮舰", "public target snapshot isolated")
Equal(Targets:Query({}), nil); Equal(Targets:Query({ scope = { characterIDs = { [2] = "A" } } }), nil)
Equal(Targets:Query("bad"), nil); Equal(Plans:Query("bad"), nil)

local function Query(ids) return assert(Plans:Query({ scope = { characterIDs = ids or { "A", "B", "C", "D" } } })) end
Flush()
local value = Query()
local valid, validationError = Hub.Snapshot:ValidateResult(value, Core.Contracts:List("action.todo", { major = 1 })[1], { "A", "B", "C", "D" })
Equal(valid, true, "action.todo contract valid " .. tostring(validationError))
Equal(value.data.tasks[1].readiness, "actionable", "observed world opportunity")
Equal(Hub.Snapshot:Build(characters).providerCount, 1, "actual aggregator discovers source")
Equal(value.coverage.D.state, "known-empty", "new role gets no implicit plans")
Equal(Plans:Progress("B", Targets:List("B")[2]).state, "unknown", "offline absence is not ready")
assert(Targets:Put("D", Boss()))
Plans:Observe(); Flush()
Equal(Plans:Progress("D", Targets:List("D")[1]).state, "unknown", "unobserved low-level role")
local worldGoal = Targets:List("A")[1]
flags[32098] = true; Plans:Observe(); Flush()
Equal(Plans:Progress("A", worldGoal).state, "completed")
Equal(#Hub.Snapshot:Build(characters).byCharacter.A, 1, "completed world task leaves active list")
Equal(Plans:Progress("B", Targets:List("B")[2]).state, "unknown", "role completion independent")
local request = { scope = { characterIDs = { "A" } } }
local completed = Query({ "A" }); local revision = completed.revision
Query({ "A" }); Equal(Query({ "A" }).revision, revision, "read-only query stable revision")
Equal(Query({ "B" }).revision, revision, "source revision independent of requested scope")
Equal(Query({ "missing" }).coverage.missing.state, "unavailable", "unknown role is not an empty observed role")
local queryBroadcasts = 0
Core.Events:Register("BUSINESS_CONTRACT_CHANGED", "boss-test", function(_, descriptor)
    if descriptor.providerID == Plans.PROVIDER then queryBroadcasts = queryBroadcasts + 1 end
end)
Query({ "A" }); Equal(queryBroadcasts, 0, "query emits no broadcasts")
local observations = YiboAltoBossDB.characters["星河-甲"].targetObservations.galleon.observedAt
now = weekly + 60; weekly = weekly + 604800; daily = now + 86400
local stale = Plans:Progress("A", worldGoal)
Equal(stale.state, "unknown"); Equal(stale.freshness, "stale"); Equal(stale.observedAt, observations, "read does not refresh evidence")
Equal(Query({ "A" }).revision > revision, true, "cycle transition advances source revision on read")
flags[32098] = false; Plans:Observe(); Flush(); Equal(Plans:Progress("A", worldGoal).state, "ready")

local dungeon = Targets:List("A")[2]
saved = { { name = "冰冠堡垒", mapID = 9631, difficultyID = 4, bosses = { { name = "玛洛加尔领主", id = 901, killed = true }, { name = "巫妖王", id = 902, killed = true } } } }
YAB.RefreshInstanceLockouts(); Flush()
Equal(Plans:Progress("A", dungeon).state, "ready", "wrong difficulty cannot complete goal")
saved[1].difficultyID = 3; saved[1].bosses[2].killed = false
YAB.RefreshInstanceLockouts(); Flush()
local p = Plans:Progress("A", dungeon)
Equal(p.state, "ready"); Equal(p.killed, 1); Equal(p.total, 2)
local selected = Dungeon({ 901 }); selected.id = "selected"
Equal(Plans:Progress("A", selected).state, "completed", "selected boss done before entire dungeon")
saved[1].bosses[2].killed = true; YAB.RefreshInstanceLockouts(); Flush(); Equal(Plans:Progress("A", dungeon).state, "completed")
saved[1].bosses[2].name = "未识别首领"; YAB.RefreshInstanceLockouts(); Flush(); Equal(Plans:Progress("A", dungeon).state, "unknown", "missing encounter evidence")
saved[1].bosses[2].name = "巫妖王"; saved[1].extended = true; saved[1].reset = 604800
YAB.RefreshInstanceLockouts(); Flush(); Equal(Plans:Progress("A", dungeon).state, "completed", "source confirms extended lockout")
Equal(Hub.Snapshot:Build(characters).byCharacter.A and #Hub.Snapshot:Build(characters).byCharacter.A or 0, 1, "completed dungeon removed; world remains active")
local context = { characters = characters, scope = "all" }
local function AutoColumns()
    local count = 0; for _, column in ipairs(YAB.GetLockoutColumns(context)) do if column.plannedCatalogID then count = count + 1 end end; return count
end
Equal(AutoColumns(), 1, "planned exact-difficulty union")
local projection
for _, col in ipairs(YAB.GetLockoutColumns(context)) do if col.plannedCatalogID then projection = col end end
Equal(YAB.GetLockoutStatus("星河-甲", projection), "clear")
Equal(YAB.GetLockoutStatus("星河-乙", projection), "not-applicable", "paused destination not forced into matrix")
Equal(Plans:IsPlanned("星河-甲", "galleon"), true)
local kills = Core.Defaults:Copy(YiboAltoBossDB.characters["星河-甲"].instanceLockouts)
assert(Targets:SetAutoDisplay(false)); Flush()
Equal(AutoColumns(), 0); Equal(#Targets:List("A"), 2); Equal(#YAB.GetBossList(), 1, "manual world display retained")
Equal(YiboAltoBossDB.characters["星河-甲"].instanceLockouts["9631:3"].bosses[1].killed, kills["9631:3"].bosses[1].killed, "kills preserved")
Equal(Plans:Progress("A", dungeon).state, "completed", "display setting does not affect tasks")
assert(Targets:SetAutoDisplay(true)); Flush(); Equal(AutoColumns(), 1)
local rolePlans = #Targets:List("C")
Core.Events:Fire("CHARACTER_CACHE_DELETED", "C"); Flush(); Equal(#Targets:List("C"), rolePlans, "cache deletion preserves explicit user goals")
local unavailableCount = #Targets:List("A")
Plans:Shutdown(); Equal(Targets:Catalog(), nil); Equal(#Targets:List("A"), unavailableCount)
assert(Plans:Initialize()); Flush(); Equal(Targets:Catalog() ~= nil, true, "source re-registration")
Targets:Shutdown(); Flush(); Equal(AutoColumns(), 0, "goal service removed withdraws projection")
local incompatible = assert(Core.Contracts:Register(Hub.NAME, { kind = "service", name = "task.boss-targets", providerID = Hub.NAME .. ":future",
    version = { major = 2, minor = 0 }, methods = { Query = function() error("must not call") end } }))
Equal(Query().coverage.A.state, "unavailable", "incompatible major ignored")
Core.Contracts:Unregister(Hub.NAME, incompatible); assert(Targets:Initialize()); Flush(); Equal(AutoColumns(), 1)

-- Old raids bootstrap a complete directory from an actual complete scan.
saved = { { name = "红玉圣殿", mapID = 724, difficultyID = 3, bosses = {
    { name = "哈里昂", killed = true }, { name = "测试守卫", killed = false } } } }
YAB.RefreshInstanceLockouts(); Flush()
local legacy = YAB.TargetCatalog:Get("instance:724")
Equal(legacy.complete, true, "complete legacy scan opens directory")
Equal(type(legacy.encounters[1].id), "string", "legacy business key distinct from native IDs")
local stableLegacyID = legacy.encounters[1].id
assert(Targets:Put("A", { catalogID = "instance:724", difficultyID = 3, scope = "boss", encounterIDs = { stableLegacyID } }))
Equal(Plans:Progress("A", Targets:List("A")[3]).state, "completed")
YAB.RefreshInstanceLockouts(); Flush(); Equal(YAB.TargetCatalog:Get("instance:724").encounters[1].id, stableLegacyID)
local epoch = Hub.db.bossTargets.sourceEpoch
assert(Hub.Database:Initialize()); Equal(Hub.db.bossTargets.sourceEpoch, epoch, "reload preserves epoch and plans")
Equal(#Targets:List("A"), 3)
characters[4].id = "E"; Core.Events:Fire("CHARACTER_ID_CHANGED", "D", "E", characters[4]); Flush()
Equal(#Targets:List("D"), 0); Equal(#Targets:List("E"), 1, "Core identity migration preserves configured role")

-- Calendar uncertainty, manual visibility, daily completion and rollover.
local previousNow, previousWeekly, previousDaily = now, weekly, daily
now = os.time({ year = 2026, month = 9, day = 25, hour = 12 })
weekly, daily = now + 5000, now + 3000
assert(Targets:Put("A", { catalogID = "holiday:coren-direbrew", scope = "all" }))
local holiday = Targets:List("A")[4]
Equal(Plans:Progress("A", holiday).state, "unknown", "calendar missing is unknown")
C_Calendar = { GetNumDayEvents = function() return 1 end, GetDayEvent = function() return { title = "Brewfest" } end }
GetLFGDungeonRewards = function() return false end
YiboAltoBossDB.settings.showHolidayBosses = false
Plans:Observe(); Flush(); Equal(Plans:Progress("A", holiday).state, "ready", "manual holiday visibility independent")
flags[25483] = true; Plans:Observe(); Flush(); Equal(Plans:Progress("A", holiday).state, "completed")
now = now + 86400; flags[25483] = false
Equal(Plans:Progress("A", holiday).state, "unknown", "daily reset does not reuse completion")
Plans:Observe(); Flush(); Equal(Plans:Progress("A", holiday).state, "ready")
now, weekly, daily = previousNow, previousWeekly, previousDaily
Equal(Plans:Progress("A", holiday).state, "dormant", "off-season goal dormant")
local offSeason
for _, task in ipairs(Query({ "A" }).data.tasks) do if task.title == holiday.title then offSeason = task end end
Equal(offSeason.state, "paused", "off-season goals do not prompt action")

local beforeBulk = #Targets:List("B")
Equal(Targets:PutMany("B", { Boss("nalak"), { catalogID = "missing", scope = "all" } }), nil)
Equal(#Targets:List("B"), beforeBulk, "bulk add validation is atomic")
assert(Targets:PutMany("B", { Boss("nalak"), Boss("oondasta") })); Equal(#Targets:List("B"), beforeBulk + 2)

dofile("YiboTaskHub/Common/TargetsPage.lua")
dofile("YiboTaskHub/TargetTabs.lua")
local frame = CreateFrame("Frame"); frame:SetSize(1040, 530)
Hub.AccountPage.Create(frame)
Hub.AccountPage.activeTab = "targets"; Hub.AccountPage.Refresh(frame, context)
Equal(frame.targets.shown, true); Equal(frame.overview.shown, false)
Equal(frame.targets.role.options[1].value, "A", "Core IDs drive role selection")
local targetFrame = frame.targets
targetFrame.copyTo.scripts.OnClick(); Equal(targetFrame.mode, "copy-to")
targetFrame.selectedRoles.B = true; targetFrame.preview.scripts.OnClick(); Equal(targetFrame.pending ~= nil, true)
targetFrame.apply.scripts.OnClick(); Equal(targetFrame.pending, nil)
targetFrame.copyFrom.scripts.OnClick(); Equal(targetFrame.mode, "copy-from", "reverse copy available with nonempty current plan")
targetFrame.sourceID = "B"; targetFrame.preview.scripts.OnClick(); Equal(targetFrame.pending ~= nil, true)
targetFrame.apply.scripts.OnClick()
targetFrame.cancel.scripts.OnClick(); Equal(targetFrame.mode, "catalog")
targetFrame.query = "ICC"; Hub.TargetsPage.Refresh(targetFrame, context)
Equal(targetFrame.rightRows[1].label.text:find("冰冠", 1, true) ~= nil, true)
targetFrame.rightRows[1].main.scripts.OnClick(); Equal(targetFrame.mode, "editor")
targetFrame.difficulty.onValueChanged(3)
targetFrame.scope.onValueChanged("boss")
targetFrame.rightRows[1].check.scripts.OnClick()
Equal(#targetFrame.draft.encounterIDs, 1, "encounter selection persists in draft")
targetFrame.save.scripts.OnClick(); Equal(targetFrame.mode, "catalog")
targetFrame.query, targetFrame.filterValue = "", "world"; Hub.TargetsPage.Refresh(targetFrame, context)
targetFrame.rightRows[1].check.scripts.OnClick(); Equal(targetFrame.saveSelected.shown, true, "batch world selection")
targetFrame.saveSelected.scripts.OnClick(); Equal(targetFrame.saveSelected.shown, false)
local preview = { characters = characters, scope = "all", preview = true }
Hub.AccountPage.Refresh(frame, preview)
Equal(frame.tabs.shown, false); Equal(frame.targets.shown, false, "hover cannot edit plans")
Hub.AccountPage.activeTab = "targets"
local metrics = Hub.AccountPage.GetSurfaceMetrics(context); Equal(metrics.horizontalOverflow, "none")

-- Both Boss matrix directions use the actual shared source-status renderer.
dofile("YiboAltoBoss/AccountPage.lua")
local render
for index = 1, 100 do
    local name, value = debug.getupvalue(YAB.RefreshAccountPage, index)
    if not name then break end
    if name == "SetStatus" then render = value; break end
end
assert(render, "actual Boss status renderer")
local cell = Core.UITheme:CreateButton(CreateFrame("Frame"), 88, "")
local galleon = { key = "galleon", name = "炮舰" }
flags[32098] = true; Plans:Observe(); Flush()
render(cell, "available", "星河-甲", galleon)
Equal(cell.label:GetText(), "已完成·目标", "matrix and action source share completion even when manual tracking was off")
Equal(type(cell.scripts.OnClick), "function", "verified status supports the additive goal gesture")
flags[32098] = false; Plans:Observe(); Flush()
render(cell, "killed", "星河-甲", galleon)
Equal(cell.label:GetText(), "待刷取·目标", "manual kill label does not replace reward evidence")
YiboAltoBossDB.characters["星河-甲"].targetObservations.galleon = nil
render(cell, "available", "星河-甲", galleon)
Equal(cell.label:GetText(), "待核实·目标", "unknown remains unknown in source matrix")
assert(Targets:SetAutoDisplay(false)); Flush()
render(cell, "killed", "星河-甲", galleon)
Equal(cell.label:GetText(), "已击杀", "display off restores manual status")
assert(Targets:SetAutoDisplay(true)); Flush()
local beforeQueryNotice = queryBroadcasts
flags[32098] = true; Plans:Observe(); Query({ "A" })
Equal(queryBroadcasts, beforeQueryNotice, "query commit before deferred notification stays silent")
Flush(); Equal(queryBroadcasts > beforeQueryNotice, true, "committed revision still notifies other consumers")
Targets:Shutdown(); Hub.Contracts:Shutdown()
local hasCapability = Core.HasCapability
Core.HasCapability = function(self, name, version) if name == "basic-input" then return false end; return hasCapability(self, name, version) end
Hub.CoreIntegration.initialized = false
Equal(Hub.CoreIntegration:Initialize(), nil, "Task needs Core shared-input capability")
Equal(Targets.ref, nil, "failed startup cannot publish target service")
Core.HasCapability = hasCapability
assert(Hub.CoreIntegration:Initialize()); Flush()
Equal(Targets.ref ~= nil, true, "actual startup registers target service")
Equal(#Hub.Contracts.list, 1, "actual startup discovers Boss provider")
print("BossTargetsSpec: " .. checks .. " checks passed")
