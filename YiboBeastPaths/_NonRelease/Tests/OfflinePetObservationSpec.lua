for _, target in ipairs({ "Retail", "Mists" }) do
    WOW_PROJECT_MAINLINE, WOW_PROJECT_MISTS_CLASSIC = 1, 19
    WOW_PROJECT_ID = target == "Retail" and 1 or 19
    local ns = { YBP_TARGET_OK = true }
    for _, name in ipairs({ "OfflinePetSnapshot", "OfflinePetCapture", "OfflinePetPage" }) do
        assert(loadfile("YiboBeastPaths/Common/" .. name .. ".lua"))("YiboBeastPaths", ns)
    end
    local db, queued, notified = {}, {}, 0
    local candidate = { completeness = "unverified", coverage = "candidate", sourceBuild = "fixture",
        active = { { slotID = 1, name = "pet" } }, stable = {} }
    local capture = ns.OfflinePetCapture.New({ target = target, SaveObservations = true,
        Root = function() return db end, Now = function() return 200 end,
        Read = function() return candidate, "unverified" end, Valid = function() return true end,
        Notify = function() notified = notified + 1 end,
        Schedule = function(fn) queued[#queued + 1] = fn end })
    assert(capture:Attempt("id") and db.offlinePets == nil)
    table.remove(queued, 1)()
    local record = db.offlinePets.characters.id
    assert(record.observation.completeness == "unverified" and record.observation.capturedAt == 200)
    local chars = { { id = "id", class = "HUNTER" } }
    local rows = ns.OfflinePetPage.Project(db, target, chars, function() return "Hunter" end)
    assert(#rows == 1 and rows[1].active.items[1].name == "pet" and rows[1].stable == nil)
    rows[1].active.items[1].name = "external"
    assert(record.observation.active[1].name == "pet")
    record.stable = { items = { { slotID = 6, name = "reliable" } }, capturedAt = 100,
        completeness = "complete", coverage = "verified", sourceBuild = "fixture" }
    assert(capture:Attempt("id")); table.remove(queued, 1)()
    assert(record.stable.items[1].name == "reliable" and record.stable.capturedAt == 100)
    rows = ns.OfflinePetPage.Project(db, target, chars, function() return "Hunter" end)
    assert(rows[1].stable.items[1].name == "reliable" and rows[1].active.completeness == "unverified")
    local old = record.observation
    candidate.active = {}
    assert(capture:Attempt("id")); table.remove(queued, 1)()
    assert(record.observation == old)
    candidate.active = { { slotID = 1, name = "pet" } }
    assert(capture:Attempt("id")); candidate.active[1].name = "changed"; table.remove(queued, 1)()
    assert(record.observation == old)
    WOW_PROJECT_ID = 99
    assert(not ns.OfflinePetSnapshot.SaveObservation(db, target, "id", candidate, 201))
    WOW_PROJECT_ID = target == "Retail" and 1 or 19
    assert(ns.OfflinePetSnapshot.Delete(db, target, "id", { replay = true, deletedAt = 150 }))
    assert(record.stable == nil and record.observation == old)
    assert(ns.OfflinePetSnapshot.Delete(db, target, "id", { replay = true, deletedAt = 250 }))
    assert(db.offlinePets.characters.id == nil and notified >= 2)
end
print("OfflinePetObservationSpec: both targets, unknown groups, history and deletion passed")
