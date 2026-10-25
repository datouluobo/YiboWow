-- Source directory, actual Core contracts, Hub editor and complete in-Hub flow.
dofile("_NonRelease/TaskGoalIntegration/BossGoalsSpec.lua")
local Hub, Core, Catalog = YiboTaskHub, YiboCore, YAB.TargetCatalog
assert(YAB.PlannedTargets:Initialize())
-- The miniature journal fixture uses a synthetic map. Supply every real
-- legacy map explicitly for the production directory inventory checks.
local instanceList = YAB.GetInstanceCatalog
YAB.GetInstanceCatalog = function()
    local list = Core.Defaults:Copy(instanceList())
    for mapID in pairs(YAB.RaidCatalog) do
        local found
        for _, item in pairs(list) do if item.mapID == mapID or (not item.key:match("^ej:") and item.instanceID == mapID) then found = true end end
        if not found then list["fixture:" .. mapID] = { key = "legacy:" .. mapID, instanceID = mapID,
            mapID = mapID, isRaid = true, name = Core.Locale:Get("YiboAltoBoss", "INSTANCE." .. mapID) } end
    end
    return list
end
GetLocale = function() return arg[1] or "zhCN" end
Core.Locale.initialized, Core.Locale.previewLanguage = false, nil
Core.Database.db.settings.language = arg[2] or "auto"
Core.Locale:Initialize()
local checks = 0
local function Equal(a, b, label)
    checks = checks + 1; assert(a == b, label .. ": " .. tostring(a) .. " ~= " .. tostring(b))
end
local function Field(value, key)
    for _, f in ipairs(value.fields) do if f.id == key then return f end end
    error("missing field " .. key)
end
local function Intent(raw)
    return { providerID = "YiboAltoBoss:targets", objectID = raw.catalogID, targetType = "boss",
        scope = { mode = "character", characterID = "A" }, repeatPolicy = "recurring", conditions = raw }
end
-- Reproduce the player's existing one-boss directory before the first query.
YiboAltoBossDB.targetLegacyDirectories = { [580] = { nextID = 1, difficulties = { [4] = {
    name = "25", encounters = { { id = "legacy:580:1", name = "Kalecgos" } } } } } }
Catalog:Invalidate()
local sw = assert(Catalog:Get("instance:580"))
local difficulty = sw.difficulties[1]
Equal(#difficulty.encounters, 6, "one-boss saved directory expands to complete Sunwell")
Equal(difficulty.encounters[1].id, "legacy:580:1", "existing boss goal identity retained")
Equal(difficulty.finalEncounterID, "raid:580:kil", "Sunwell explicitly declares Kiljaeden")
Equal(difficulty.encounters[6].id, difficulty.finalEncounterID, "complete list contains final boss")
local partial = { instanceID = 580, difficultyID = 4, bossCount = 1, bosses = { { name = "Kalecgos" } } }
Equal(Catalog:ObserveLegacyLockout(partial), false, "partial lockout cannot replace directory")
Catalog:Invalidate()
Equal(#Catalog:Get("instance:580").difficulties[1].encounters, 6, "partial lockout cannot shrink directory")
-- Every maintained legacy raid is selectable with zero observed lockouts.
local expectedCounts = { [580] = 6, [564] = 9, [534] = 5, [550] = 4, [548] = 6, [544] = 1, [565] = 2,
    [532] = 12, [724] = 4, [631] = 12, [649] = 5, [249] = 1, [603] = 14, [616] = 1, [615] = 1,
    [533] = 15, [624] = 4, [531] = 9, [509] = 6, [469] = 8, [409] = 10 }
for mapID, count in pairs(expectedCounts) do
    local static = YAB.RaidCatalog[mapID]
    local entry = assert(Catalog:Get("instance:" .. mapID))
    Equal(entry.complete, true, "static raid complete " .. mapID)
    Equal(#entry.difficulties, #static.difficulties, "difficulty choices before first visit " .. mapID)
    for _, d in ipairs(entry.difficulties) do
        Equal(#d.encounters, count, "complete boss set " .. mapID .. ":" .. d.id)
        Equal(type(d.finalEncounterID), "string", "explicit final identity " .. mapID)
    end
end
local raw = { catalogID = "instance:580", scope = "all", encounterIDs = {} }
local pending = assert(Hub.Goals:Normalize(Intent(raw)))
Equal(pending.needsConfiguration, true, "missing choice keeps configuration open")
Equal(#Field(pending, "difficultyID").options, 1, "difficulty exists without lockout")
raw.difficultyID = 4
local whole = assert(Hub.Goals:Normalize(Intent(raw)))
local created = assert(Hub.Goals:Add(Intent(raw)))
raw.scope = "final"
local final = assert(Hub.Goals:Normalize(Intent(raw)))
Equal(final.intent.conditions.encounterIDs[1], "raid:580:kil", "final shortcut persists Kiljaeden")
Equal(#Field(final, "scope").options, 3, "declared final exposes shortcut")
local record = YiboAltoBossDB.characters["星河-甲"]
record.instanceLockoutsObservedAt = GetServerTime()
record.targetLockoutCycles = { weekly = YAB.PlannedTargets:Period("weekly") }
record.instanceLockouts = { sw = { instanceID = 580, difficultyID = 176, resetAt = GetServerTime() + 5000, bosses = {} } }
for i, boss in ipairs(difficulty.encounters) do record.instanceLockouts.sw.bosses[i] = { encounterID = boss.id, killed = i ~= 1 } end
Equal(YAB.PlannedTargets:Progress("A", final.intent.conditions).state, "completed", "skipped blue dragon does not block selected final")
Equal(YAB.PlannedTargets:Progress("A", whole.intent.conditions).state, "ready", "whole still requires all bosses")
assert(Hub.Goals:Update(created.id, Hub.db.goals.byID[created.id].revision, { intent = Intent(raw) }))
Equal(Hub.db.goals.byID[created.id].intent.conditions.encounterIDs[1], "raid:580:kil", "existing goal editable in place")
raw.scope, raw.encounterIDs = "boss", {}
pending = assert(Hub.Goals:Normalize(Intent(raw)))
Equal(pending.needsConfiguration, true, "empty boss selection not saved")
Equal(#Field(pending, "encounterIDs").options, 6, "all six bosses offered")
raw.encounterIDs = { difficulty.encounters[5].id, difficulty.encounters[6].id }
Equal(#assert(Hub.Goals:Normalize(Intent(raw))).intent.conditions.encounterIDs, 2, "multiple selected bosses")
record.instanceLockouts.sw.bosses = { { encounterID = "legacy:580:1", killed = false } }
Equal(YAB.PlannedTargets:Progress("A", final.intent.conditions).state, "unknown", "missing progress stays unknown rather than false completion")
-- API signature compatibility and tier selection use the actual adapter.
local nativeQuery, valid, selectTier, currentTier = EJ_GetEncounterInfoByIndex, EJ_IsValidInstanceDifficulty, EJ_SelectTier, EJ_GetCurrentTier
local tier = 4
EJ_GetCurrentTier = function() return tier end
EJ_SelectTier = function(value) tier = value end
EJ_IsValidInstanceDifficulty = function(id) return tier == 1 and valid(id) end
EJ_GetEncounterInfoByIndex = function(index, id)
    local name, description, journal, section, link, instance = nativeQuery(index, id)
    return name, description, journal, section, link, instance
end
Catalog:Invalidate()
local journal = Catalog:Get("journal:123")
Equal(journal.complete, true, "missing native encounter ID does not erase journal list")
Equal(#journal.difficulties[1].encounters, 2, "journal list retained")
Equal(journal.difficulties[1].encounters[1].id, "journal-encounter:10001", "journal identity stays namespaced")
Equal(tier, 4, "journal tier restored")
Equal(journal.difficulties[1].finalEncounterID, nil, "undeclared final is not inferred from last row")
EJ_GetEncounterInfoByIndex, EJ_IsValidInstanceDifficulty, EJ_SelectTier, EJ_GetCurrentTier = nativeQuery, valid, selectTier, currentTier
Catalog:Invalidate()
-- Full UI path begins at Hub Add Goal and stays on the Hub page.
dofile("YiboCore/UI/Input.lua")
UIParent = CreateFrame("Frame"); UIParent:SetSize(1280, 720)
local create = CreateFrame
CreateFrame = function(...)
    local frame = create(...)
    function frame:GetText() return self.text or "" end
    function frame:GetFrameLevel() return 1 end
    function frame:GetChecked() return self.checked end
    return frame
end
Hub.AccountPage = Hub.AccountPage or {}
Hub.AccountPage.CharacterLabel = function(_, character) return character.name end
Hub.BossTargets.catalog = nil
local editor, management = Hub.GoalEditor, CreateFrame("Frame")
editor.Create(management)
editor.adding, editor.draft, editor.copyID = true, nil, nil
editor.Refresh(management, { characters = Core.Characters:GetAll() })
local entries, index = editor:Entries()
for i, e in ipairs(entries) do if e.targetType == "boss" then index = i end end
Equal(type(index), "number", "enabled source exposes boss-or-instance entry")
Core.lastPage = Hub.PAGE_ID
management.addControls.buttons[index].scripts.OnClick()
Equal(Core.lastPage, Hub.PAGE_ID, "entry remains on Hub page")
Equal(Hub.AccountPage.activeTab, "targets", "entry opens Hub target catalog")
dofile("YiboTaskHub/Common/TargetsPage.lua")
local frame = CreateFrame("Frame")
Hub.TargetsPage.Create(frame)
frame.characterID, frame.query, frame.filterValue = "A", "SWP", "instance"
local context = { characters = Core.Characters:GetAll() }
Hub.TargetsPage.Refresh(frame, context)
Equal(#frame.rightRows > 0, true, "Hub searches source catalog")
frame.rightRows[1].main.scripts.OnClick()
Equal(frame.mode, "editor", "Hub selects the instance")
Equal(frame.draft.difficultyID, 176, "single verified difficulty selected automatically")
Equal(#frame.difficulty.options, 1, "Hub difficulty control populated")
frame.scope.onValueChanged("boss")
Equal(frame.save.enabled, false, "empty selected set cannot be saved")
Equal(#frame.rightRows >= 6, true, "Hub lists all six bosses")
frame.rightRows[6].check.scripts.OnClick()
Equal(#frame.draft.encounterIDs, 1, "Hub selects a single boss")
frame.rightRows[5].check.scripts.OnClick()
Equal(#frame.draft.encounterIDs, 2, "Hub selects multiple bosses")
frame.scope.onValueChanged("final")
Equal(frame.save.enabled, true, "Hub can save declared final")
-- Use another role to isolate this addition from the existing edited goal.
frame.characterID = "D"
frame.save.scripts.OnClick()
Equal(frame.mode, "catalog", "save completes inside Hub")
local found
for _, goal in ipairs(Hub.BossTargets:List("D")) do if goal.catalogID == "instance:580" then found = goal end end
Equal(found and found.encounterIDs[1], "raid:580:kil", "Hub saves exact final boss")
-- Source removal hides both add entry and shortcut; re-registration restores them.
YAB.PlannedTargets:Shutdown()
editor.adding, editor.draft = nil, nil
editor.Refresh(management, context)
Equal(management.boss.shown, false, "absent source hides Hub shortcut")
for _, e in ipairs(editor:Entries()) do Equal(e.targetType ~= "boss", true, "absent source hides add entry") end
local incompatible = assert(Core.Contracts:Register("Spec", { name = "action.targets", kind = "provider", providerID = "Spec:incompatible",
    version = { major = 2, minor = 0 }, methods = { GetEntry = function() return { title = "Spec", pageID = "spec", targetType = "boss" } end } }))
editor.Refresh(management, context)
Equal(management.boss.shown, false, "incompatible source cannot expose the entry")
Core.Contracts:Unregister("Spec", incompatible)
assert(YAB.PlannedTargets:Initialize())
editor.Refresh(management, context)
Equal(management.boss.shown, true, "late source restores Hub shortcut")
local source, oldCatalog, oldPage = YAB.GoalTargets, YAB.TargetCatalog, Hub.TargetsPage
for _, path in ipairs({ "YiboAltoBoss/GoalTargets.lua", "YiboAltoBoss/TargetCatalog.lua", "YiboTaskHub/GoalEditor.lua", "YiboTaskHub/TargetsPage.lua" }) do dofile(path) end
Equal(YAB.GoalTargets, source, "residual provider inert")
Equal(YAB.TargetCatalog, oldCatalog, "residual catalog inert")
Equal(Hub.TargetsPage, oldPage, "residual target page inert")
for _, owner in ipairs({ "YiboTaskHub", "YiboAltoBoss" }) do
    for key in pairs(Core.Locale.resources[owner].zh) do
        if key:find("GOAL.", 1, true) == 1 or key:find("RAID.", 1, true) == 1 then
            Equal(type(Core.Locale.resources[owner].en[key]), "string", "new resources have English equivalents")
        end
    end
end
print("BossGoalEditorSpec: " .. checks .. " checks passed")
