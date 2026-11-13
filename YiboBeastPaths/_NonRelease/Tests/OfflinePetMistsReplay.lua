-- Read a local probe SavedVariables file without printing identities or pets.
-- This only replays an existing observation; it does not prove completeness.
local saved = {}
local chunk = assert(loadfile(assert(arg[1], "probe path required")))
setfenv(chunk, saved)
chunk()
local db = assert(saved.YiboBeastPathsMistsPetProbeDB)
local sample
for _, record in pairs(db.characters or {}) do
    for _, candidate in ipairs(record.samples or {}) do
        if candidate.stableOpen and candidate.activeCount and candidate.stableCount
            and candidate.activeCount.values and candidate.stableCount.values
            and candidate.activeCount.values[1] == 4 and candidate.stableCount.values[1] == 65 then
            sample = candidate
        end
    end
end
assert(sample, "no matching previously recorded sample")
WOW_PROJECT_ID, WOW_PROJECT_MISTS_CLASSIC = 19, 19
NUM_PET_ACTIVE_SLOTS, NUM_PET_STABLE_SLOTS, NUM_PET_STABLE_PAGES = sample.bounds.active, sample.bounds.stable, 1
C_StableInfo = { GetNumActivePets = function() return 4 end, GetNumStablePets = function() return 65 end }
GetBuildInfo = function() return sample.version[1], sample.version[2] end
GetStablePetInfo = function(index)
    local slot = sample.slots[index]
    assert(slot and slot.info and slot.info.status == "ok")
    local values = slot.info.values or {}
    return values[1], values[2], values[3], values[4]
end
local ns = { YBP_TARGET_OK = true }
assert(loadfile("YiboBeastPaths/Mists/OfflinePetReader.lua"))("YiboBeastPaths", ns)
local candidate, state = ns.ReadOfflinePets()
if not candidate then
    local partial, nilIconName, levelNumber, familyString, zeroLevel, positiveLevel = 0, 0, 0, 0, 0, 0
    for _, slot in ipairs(sample.slots) do
        local values = slot.info and slot.info.values or {}
        if values[1] == nil and values[2] == nil then
            nilIconName = nilIconName + 1
            if values[3] ~= nil or values[4] ~= nil then
                partial = partial + 1
                if type(values[3]) == "number" then levelNumber = levelNumber + 1 end
                if values[3] == 0 then zeroLevel = zeroLevel + 1 end
                if type(values[3]) == "number" and values[3] > 0 then positiveLevel = positiveLevel + 1 end
                if type(values[4]) == "string" then familyString = familyString + 1 end
            end
        end
    end
    print("Unavailable candidate: nil-icon-name=" .. nilIconName .. " partial=" .. partial
        .. " numeric-level=" .. levelNumber .. " zero-level=" .. zeroLevel
        .. " positive-level=" .. positiveLevel .. " string-family=" .. familyString)
end
assert(candidate and state == "unverified")
assert(#candidate.active == 4 and #candidate.stable == 65)
print("MoP stored sample replay: active=4 stable=65, status=unverified")
