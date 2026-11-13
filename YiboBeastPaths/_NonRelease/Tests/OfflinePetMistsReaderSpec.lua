WOW_PROJECT_ID, WOW_PROJECT_MISTS_CLASSIC = 19, 19
NUM_PET_ACTIVE_SLOTS, NUM_PET_STABLE_SLOTS, NUM_PET_STABLE_PAGES = 1, 1, 1
C_StableInfo = { GetNumActivePets = function() return 1 end, GetNumStablePets = function() return 0 end }
GetBuildInfo = function() return "fixture", "fixture" end
local malformed = true
GetStablePetInfo = function(slot)
    if slot == 1 then return 1, "pet", 10, "family" end
    if malformed then return nil, nil, 10, "family" end
    return nil, nil, 0, nil
end
local ns = { YBP_TARGET_OK = true }
assert(loadfile("YiboBeastPaths/Mists/OfflinePetReader.lua"))("YiboBeastPaths", ns)
local sample, status = ns.ReadOfflinePets()
assert(sample == nil and status == "unavailable")
malformed = false
sample, status = ns.ReadOfflinePets()
assert(sample and status == "unverified" and #sample.active == 1 and #sample.stable == 0)
print("OfflinePetMistsReaderSpec: incomplete slot rejected; empty candidate remains unverified")
