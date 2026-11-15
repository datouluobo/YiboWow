-- Read an existing YBP SavedVariables file without printing identities or pets.
local env = {}
local chunk = assert(loadfile(assert(arg[1], "SavedVariables path required")))
setfenv(chunk, env); chunk()
local store = assert(env.YiboBeastPathsDB and env.YiboBeastPathsDB.offlinePets)
local observations, pets, displays, creatures = 0, 0, 0, 0
for _, record in pairs(store.characters or {}) do
    local sample = type(record) == "table" and record.observation
    if type(sample) == "table" then
        observations = observations + 1
        for _, group in ipairs({ sample.active or {}, sample.stable or {} }) do
            for _, pet in ipairs(group) do
                pets = pets + 1
                if type(pet.displayID) == "number" and pet.displayID > 0 then displays = displays + 1 end
                if type(pet.creatureID) == "number" and pet.creatureID > 0 then creatures = creatures + 1 end
            end
        end
    end
end
print("target=" .. tostring(store.target) .. " observations=" .. observations .. " pets=" .. pets
    .. " displayIDs=" .. displays .. " creatureIDs=" .. creatures)
