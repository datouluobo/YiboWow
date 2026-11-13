WOW_PROJECT_ID, WOW_PROJECT_MISTS_CLASSIC, WOW_PROJECT_MAINLINE = 19, 19, 1
local ns = { YBP_TARGET_OK = true }
assert(loadfile("YiboBeastPaths/Common/OfflinePetSnapshot.lua"))("YiboBeastPaths", ns)
local S = ns.OfflinePetSnapshot
assert(loadfile("YiboBeastPaths/Common/OfflinePetCoreGate.lua"))("YiboBeastPaths", ns)
assert(loadfile("YiboBeastPaths/Common/OfflinePetPage.lua"))("YiboBeastPaths", ns)
local ready, reason = ns.CheckOfflinePetCore(nil)
assert(not ready and reason == "missing")
local core = { CheckAPIVersion = function() return false end, IsInitialized = function() return true end,
    HasCapability = function() return true end, RegisterAddon = function() end }
ready, reason = ns.CheckOfflinePetCore(core)
assert(not ready and reason == "upgrade")
core.CheckAPIVersion = function() return true end
core.IsInitialized = function() return false end
ready, reason = ns.CheckOfflinePetCore(core)
assert(not ready and reason == "not-ready")
core.IsInitialized = function() return true end
core.HasCapability = function(_, name) return name ~= "character-cleanup" end
ready, reason = ns.CheckOfflinePetCore(core)
assert(not ready and reason == "upgrade")
core.HasCapability = function() return true end
for _, object in ipairs({ "Characters", "CharacterCleanup", "AccountView", "Entry", "Locale", "Events", "UITheme" }) do
    core[object] = setmetatable({}, { __index = function() return function() end end })
end
core.UITheme.Font, core.UITheme.Colors = {}, {}
assert(ns.CheckOfflinePetCore(core))
local registrations = { page = 0, entry = 0, cleanup = 0 }
core.CharacterCleanup.RegisterOwner = function(_, _, definition)
    registrations.cleanup = registrations.cleanup + 1; registrations.owner = definition; return definition
end
core.AccountView.RegisterPage = function(_, _, definition)
    registrations.page = registrations.page + 1; registrations.definition = definition; return definition
end
core.Entry.RegisterBusinessEntry = function(_, _, definition)
    registrations.entry = registrations.entry + 1; return definition
end
local root = { visible = true }
local candidate = { active = { { slotID = 1, name = "a" } }, stable = { { slotID = 6, name = "b" } }, capturedAt = 100,
    completeness = "complete", coverage = "synthetic", sourceBuild = "fixture" }
assert(not S.Commit(root, "Mists", "id", candidate))
assert(root.offlinePets == nil and root.visible)
local incomplete = { active = {}, stable = {}, capturedAt = 100, completeness = "unverified" }
assert(not S.Commit(root, "Mists", "id", incomplete, function() return true end))
assert(root.offlinePets == nil)
candidate.active[1].unsupported = function() end
assert(not S.Commit(root, "Mists", "id", candidate, function() return true end))
assert(root.offlinePets == nil)
candidate.active[1].unsupported = nil
candidate.capturedAt = 0 / 0
assert(not S.Commit(root, "Mists", "id", candidate, function() return true end))
candidate.capturedAt = 100
candidate.stable[3] = { slotID = 7, name = "gap" }
assert(not S.Commit(root, "Mists", "id", candidate, function() return true end))
candidate.stable[3] = nil
candidate.stable[3] = { slotID = 7, name = "gap" }
candidate.stable[4] = { slotID = 8, name = "gap" }
candidate.stable[6] = { slotID = 9, name = "gap" }
assert(not S.Commit(root, "Mists", "id", candidate, function() return true end))
candidate.stable[3], candidate.stable[4], candidate.stable[6] = nil, nil, nil
candidate.stable[1].slotID = 1
assert(not S.Commit(root, "Mists", "id", candidate, function() return true end))
assert(root.offlinePets == nil)
candidate.stable[1].slotID = 6
local corrupt = { offlinePets = { schema = 1, target = "Mists", characters = { id = { futureField = "preserve" } } } }
assert(not S.Commit(corrupt, "Mists", "id", candidate, function() return true end))
assert(corrupt.offlinePets.characters.id.futureField == "preserve")
assert(not S.Delete(corrupt, "Mists", "id", { replay = true, deletedAt = 101 }))
assert(corrupt.offlinePets.characters.id.futureField == "preserve")
assert(not S.RecordAttempt(root, "Mists", "id", "unavailable", 105))
assert(root.offlinePets == nil)
assert(not S.Commit(root, "Mists", "id", candidate, function() error("policy failure") end))
assert(not S.Commit(root, "Mists", "id", candidate, function() WOW_PROJECT_ID = 1; return true end))
assert(root.offlinePets == nil)
WOW_PROJECT_ID = 19
WOW_PROJECT_ID = 1
assert(not S.Commit(root, "Mists", "id", candidate, function() return true end))
assert(root.offlinePets == nil)
WOW_PROJECT_ID = 19
assert(S.Commit(root, "Mists", "id", candidate, function() return true end))
root.offlinePets.characters.id.stable.futureField = "preserve"
assert(not S.Commit(root, "Mists", "id", candidate, function() return true end))
assert(root.offlinePets.characters.id.stable.futureField == "preserve")
root.offlinePets.characters.id.stable.futureField = nil
local priorActive, priorStable = root.offlinePets.characters.id.active, root.offlinePets.characters.id.stable
candidate.capturedAt = 99
assert(not S.Commit(root, "Mists", "id", candidate, function() return true end))
assert(root.offlinePets.characters.id.active == priorActive and root.offlinePets.characters.id.stable == priorStable)
candidate.capturedAt = 100
assert(S.RecordAttempt(root, "Mists", "id", "unavailable", 105))
assert(root.offlinePets.characters.id.active == priorActive and root.offlinePets.characters.id.stable == priorStable)
assert(priorActive.capturedAt == 100 and priorStable.capturedAt == 100)
assert(not S.RecordAttempt(root, "Retail", "id", "unavailable", 106))
assert(not S.RecordAttempt(root, "Mists", "id", "verified", 106))
assert(S.RecordAttempt(root, "Mists", "id", "unverified", 107))
local fixtureGroup = root.offlinePets.characters.id.stable
fixtureGroup.completeness = nil
assert(not S.IsCompleteGroup(fixtureGroup))
assert(not S.RecordAttempt(root, "Mists", "id", "unavailable", 108))
assert(#ns.OfflinePetPage.Eligible(root, "Mists", { { id = "id", class = "HUNTER" } }) == 0)
fixtureGroup.completeness = "complete"
local savedItems = fixtureGroup.items
fixtureGroup.items = {}
assert(S.IsCompleteGroup(fixtureGroup)) -- Synthetic policy, not client evidence.
fixtureGroup.items = savedItems
local activeGroup = root.offlinePets.characters.id.active
activeGroup.completeness = nil
local unknownRows = ns.OfflinePetPage.Project(root, "Mists", { { id = "id", class = "HUNTER" } }, function() return "name" end)
assert(#unknownRows == 1 and unknownRows[1].active == nil)
activeGroup.completeness = "complete"
local view = ns.OfflinePetPage.New(core, root, "Mists", {
    Create = function() end, Refresh = function() end, GetSurfaceMetrics = function() return {} end,
}, function(key) return key end)
assert(view:Start() and view:Start())
assert(registrations.page == 1 and registrations.entry == 1 and registrations.cleanup == 1)
local failedPages, removed = 0, 0
core.AccountView.RegisterPage = function(_, _, definition) failedPages = failedPages + 1; return definition end
core.AccountView.UnregisterPage = function() removed = removed + 1; return true end
core.CharacterCleanup.RegisterOwner = function() return true end
core.Entry.RegisterBusinessEntry = function() return nil, "failed" end
local failed = ns.OfflinePetPage.New(core, root, "Mists", {
    Create = function() end, Refresh = function() end, GetSurfaceMetrics = function() return {} end,
}, function(key) return key end)
assert(not failed:Start() and not failed.active and removed == 1 and failedPages == 1)
assert(not failed:Start() and removed == 2 and failedPages == 2)
local visible = { { id = "id", class = "HUNTER" }, { id = "none", class = "HUNTER" },
    { id = "id", class = "MAGE" } }
local rows = ns.OfflinePetPage.Project(root, "Mists", visible, function() return "name" end)
assert(#rows == 1 and rows[1].name == "name")
assert(rows[1].lastAttempt.status == "unverified" and rows[1].lastAttempt.at == 107)
rows[1].lastAttempt.status = "modified"
assert(root.offlinePets.characters.id.lastAttempt.status == "unverified")
rows[1].stable.items[1].name = "consumer mutation"
assert(root.offlinePets.characters.id.stable.items[1].name == "b")
candidate.stable[1].name = "changed"
assert(root.offlinePets.characters.id.stable.items[1].name == "b")
assert(not S.Commit(root, "Retail", "id", candidate, function() return true end))
assert(not S.Commit(root, "Mists", "id", candidate, function() return false end))
local record = root.offlinePets.characters.id
record.active.capturedAt = 200
record.stable.capturedAt = nil
assert(not S.Delete(root, "Mists", "id", { replay = true, deletedAt = 150 }))
assert(record.active and record.stable)
record.stable.capturedAt = 100
assert(S.Delete(root, "Mists", "id", { replay = true, deletedAt = 150 }))
assert(record.active and not record.stable)
assert(not S.Delete(root, "Mists", "id", { replay = true }))
assert(not S.Delete(root, "Mists", "id", { replay = true, deletedAt = 0 / 0 }))
assert(S.Delete(root, "Mists", "id", {}))
assert(root.offlinePets.characters.id == nil)
for _, target in ipairs({ "Retail", "Mists" }) do
    ns = { YBP_TARGET_OK = true }; assert(loadfile("YiboBeastPaths/Common/OfflinePetSnapshot.lua"))("YiboBeastPaths", ns)
    assert(loadfile("YiboBeastPaths/" .. target .. "/OfflinePetReader.lua"))("YiboBeastPaths", ns)
    WOW_PROJECT_ID, WOW_PROJECT_MAINLINE, WOW_PROJECT_MISTS_CLASSIC = 99, 1, 19
    local value, reason = ns.ReadOfflinePets()
    assert(value == nil and reason == "wrong-target")
    if target == "Retail" then
        WOW_PROJECT_ID = 1
        GetBuildInfo = function() return "12.1.5", "70783" end
        C_StableInfo = { IsAtStableMaster = function() return true end,
            GetActivePetList = function() return { { slotID = 1, name = "pet", icon = 123, level = 1, familyName = "family" } } end,
            GetStabledPetList = function() return {} end,
            GetNumActivePets = function() return 1 end, GetNumStablePets = function() return 0 end }
    else
        WOW_PROJECT_ID = 19
        GetBuildInfo = function() return "5.5.4", "70631" end
        NUM_PET_ACTIVE_SLOTS, NUM_PET_STABLE_SLOTS, NUM_PET_STABLE_PAGES = 1, 1, 1
        GetStablePetInfo = function(i) if i == 1 then return 123, "pet", 1, "family" end end
        C_StableInfo = { GetNumActivePets = function() return 1 end, GetNumStablePets = function() return 0 end }
    end
    value, reason = ns.ReadOfflinePets()
    assert(reason == "unverified" and value.completeness == "unverified")
    local untouched = {}
    assert(not ns.OfflinePetSnapshot.Commit(untouched, target, "id", value))
    assert(untouched.offlinePets == nil)
    C_StableInfo.GetNumActivePets = function() return 2 end
    value, reason = ns.ReadOfflinePets()
    assert(value == nil and reason == "unavailable")
    local calls = 0
    C_StableInfo.GetNumActivePets = function() calls = calls + 1; return calls == 1 and 1 or 2 end
    value, reason = ns.ReadOfflinePets()
    assert(value == nil and reason == "unavailable")
    if target == "Retail" then
        C_StableInfo.GetNumActivePets = function() return 1 end
        C_StableInfo.GetNumStablePets = function() return 1 end
        C_StableInfo.GetStabledPetList = function()
            return { { slotID = 1, name = "other", icon = 456, level = 1, familyName = "family" } }
        end
        value, reason = ns.ReadOfflinePets()
        assert(value == nil and reason == "unavailable")
    end
end
print("OfflinePetSnapshotSpec: protected snapshots and target guards passed")
