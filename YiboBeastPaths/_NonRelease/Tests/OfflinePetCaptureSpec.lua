WOW_PROJECT_ID, WOW_PROJECT_MISTS_CLASSIC, WOW_PROJECT_MAINLINE = 19, 19, 1
local ns = { YBP_TARGET_OK = true }
assert(loadfile("YiboBeastPaths/Common/OfflinePetSnapshot.lua"))("YiboBeastPaths", ns)
assert(loadfile("YiboBeastPaths/Common/OfflinePetCapture.lua"))("YiboBeastPaths", ns)
local target, current, valid, scheduled, notifications = "Mists", "id", true, {}, 0
local db = { offlinePets = { schema = 1, target = target, characters = { id = {
    active = { items = { { slotID = 1, name = "previous active" } }, capturedAt = 100, completeness = "complete", coverage = "synthetic", sourceBuild = "fixture" },
    stable = { items = { { slotID = 6, name = "previous stable" } }, capturedAt = 100, completeness = "complete", coverage = "synthetic", sourceBuild = "fixture" },
} } } }
local sample = { active = { { slotID = 1, name = "active" } },
    stable = { { slotID = 6, name = "stable" } }, completeness = "complete",
    coverage = "synthetic", sourceBuild = "fixture" }
local opts = {
    target = target, Root = function() return db end, Now = function() return 200 end,
    Read = function() return sample, "unverified" end,
    Valid = function(id) return valid and id == current end,
    Notify = function() notifications = notifications + 1 end,
    Schedule = function(callback) scheduled[#scheduled + 1] = callback end,
}
local frozen = ns.OfflinePetCapture.New(opts)
assert(not frozen:Attempt("id") and #scheduled == 0)
assert(db.offlinePets.characters.id.stable.items[1].name == "previous stable")
assert(db.offlinePets.characters.id.lastAttempt.status == "unverified")
-- The verifier below is a synthetic test double, never installed in production.
opts.VerifiedPolicy = function(observation) return observation.active[1].slotID == 1 end
local capture = ns.OfflinePetCapture.New(opts)
local priorAttempt = db.offlinePets.characters.id.lastAttempt
opts.Read = function() capture:Invalidate(); return sample, "unverified" end
assert(not capture:Attempt("id") and #scheduled == 0)
assert(db.offlinePets.characters.id.lastAttempt == priorAttempt)
opts.Read = function() return sample, "unverified" end
assert(capture:Attempt("id")); local first = table.remove(scheduled, 1)
capture:Invalidate(); first()
assert(db.offlinePets.characters.id.stable.items[1].name == "previous stable")
assert(capture:Attempt("id")); local changed = table.remove(scheduled, 1)
sample = { active = { { slotID = 2, name = "changed" } }, stable = { { slotID = 6, name = "stable" } },
    completeness = "complete", coverage = "synthetic", sourceBuild = "fixture" }
changed()
assert(db.offlinePets.characters.id.stable.items[1].name == "previous stable")
-- A reused native table must not make a changed second read look identical.
sample = { active = { { slotID = 1, name = "active" } }, stable = { { slotID = 6, name = "stable" } },
    completeness = "complete", coverage = "synthetic", sourceBuild = "fixture" }
assert(capture:Attempt("id")); local reused = table.remove(scheduled, 1)
sample.stable[1].name = "mutated in place"; reused()
assert(db.offlinePets.characters.id.stable.items[1].name == "previous stable")
sample = { active = { { slotID = 1, name = "active" } }, stable = { { slotID = 6, name = "stable" } },
    completeness = "complete", coverage = "synthetic", sourceBuild = "fixture" }
assert(capture:Attempt("id")); local good = table.remove(scheduled, 1); good()
assert(db.offlinePets.characters.id.stable.items[1].name == "stable")
assert(db.offlinePets.characters.id.active.capturedAt == 200 and db.offlinePets.characters.id.stable.capturedAt == 200)
local afterGood = notifications
good()
assert(notifications == afterGood)
local readCount = 0
opts.Read = function()
    readCount = readCount + 1
    if readCount == 2 then capture:Invalidate() end
    return sample, "unverified"
end
local beforeReentrant = db.offlinePets.characters.id
assert(capture:Attempt("id")); local reentrant = table.remove(scheduled, 1); reentrant()
assert(db.offlinePets.characters.id == beforeReentrant)
opts.Read = function() return sample, "unverified" end
assert(capture:Attempt("id")); local expired = table.remove(scheduled, 1)
valid = false; expired()
assert(db.offlinePets.characters.id.stable.items[1].name == "stable")
assert(not capture:Attempt("id"))
valid = true
opts.Schedule = function() error("timer unavailable") end
assert(not capture:Attempt("id"))
assert(db.offlinePets.characters.id.stable.items[1].name == "stable")
assert(db.offlinePets.characters.id.lastAttempt.status == "unavailable")
print("OfflinePetCaptureSpec: unknown gate, atomic pair and invalidation passed")
