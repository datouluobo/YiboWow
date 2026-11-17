local _, ns = ...

-- Candidate reads are diagnostic only. Completeness and extra-slot semantics
-- are not verified, so this reader never supplies a commit policy.
ns.ReadOfflinePets = function()
    if not (_G.WOW_PROJECT_MAINLINE and _G.WOW_PROJECT_ID == _G.WOW_PROJECT_MAINLINE) then
        return nil, "wrong-target"
    end
    local api = _G.C_StableInfo
    if not (api and type(api.GetActivePetList) == "function"
        and type(api.GetStabledPetList) == "function") then return nil, "unavailable" end
    local okA, active = pcall(api.GetActivePetList)
    local okS, stable = pcall(api.GetStabledPetList)
    if not okA or not okS or type(active) ~= "table" or type(stable) ~= "table" then
        return nil, "unavailable"
    end
    return { active = ns.OfflinePetSnapshot.Copy(active), stable = ns.OfflinePetSnapshot.Copy(stable),
        completeness = "unverified" }, "unverified"
end
