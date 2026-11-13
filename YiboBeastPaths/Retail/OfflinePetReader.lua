local _, ns = ...
if not ns.YBP_TARGET_OK then return end

local function call(fn, ...)
    if type(fn) ~= "function" then return false end
    return pcall(fn, ...)
end

local function normalize(list)
    if type(list) ~= "table" then return nil end
    local rows, seen = {}, {}
    for _, pet in pairs(list) do
        if type(pet) ~= "table" or type(pet.slotID) ~= "number" or pet.slotID < 1
            or pet.slotID % 1 ~= 0 or seen[pet.slotID] or type(pet.name) ~= "string"
            or (type(pet.icon) ~= "number" and type(pet.icon) ~= "string")
            or type(pet.level) ~= "number" or type(pet.familyName) ~= "string" then return nil end
        seen[pet.slotID] = true
        rows[#rows + 1] = { slotID = pet.slotID, name = pet.name, icon = pet.icon,
            level = pet.level, family = pet.familyName }
    end
    table.sort(rows, function(a, b) return a.slotID < b.slotID end)
    return rows
end

-- Candidate reads cannot prove completeness; retain only scalar business fields.
ns.ReadOfflinePets = function()
    if not (_G.WOW_PROJECT_MAINLINE and _G.WOW_PROJECT_ID == _G.WOW_PROJECT_MAINLINE) then
        return nil, "wrong-target"
    end
    local api = _G.C_StableInfo or {}
    local okAt, atStable = call(api.IsAtStableMaster)
    local okBeforeA, beforeActive = call(api.GetNumActivePets)
    local okBeforeS, beforeStable = call(api.GetNumStablePets)
    local okA, rawActive = call(api.GetActivePetList)
    local okS, rawStable = call(api.GetStabledPetList)
    local okAC, activeCount = call(api.GetNumActivePets)
    local okSC, stableCount = call(api.GetNumStablePets)
    local okAfter, stillAtStable = call(api.IsAtStableMaster)
    if not (okAt and atStable == true and okBeforeA and okBeforeS and okA and okS and okAC and okSC
        and okAfter and stillAtStable == true)
        or type(activeCount) ~= "number" or type(stableCount) ~= "number"
        or beforeActive ~= activeCount or beforeStable ~= stableCount then return nil, "unavailable" end
    local active, stable = normalize(rawActive), normalize(rawStable)
    if not active or not stable or #active ~= activeCount or #stable ~= stableCount then
        return nil, "unavailable"
    end
    local occupied = {}
    for _, pet in ipairs(active) do occupied[pet.slotID] = true end
    for _, pet in ipairs(stable) do
        if occupied[pet.slotID] then return nil, "unavailable" end
    end
    local constants = _G.Constants and Constants.PetConsts_PostCata or {}
    local extraIndex = type(constants.EXTRA_PET_STABLE_SLOT) == "number"
        and constants.EXTRA_PET_STABLE_SLOT + 1 or nil
    local bonusOK, bonus = call(api.IsBonusPetSlotAvailable)
    local version, build = GetBuildInfo()
    local evidence = { activeCount = activeCount, stableCount = stableCount, extraIndex = extraIndex }
    if bonusOK and type(bonus) == "boolean" then evidence.bonusAvailable = bonus end
    return { active = active, stable = stable, completeness = "unverified",
        sourceBuild = tostring(version) .. "/" .. tostring(build),
        coverage = "retail-list-candidate", evidence = evidence }, "unverified"
end
