local _, ns = ...
if not ns.YBP_TARGET_OK then return end

-- Candidate bounds depend on the native UI and may be modified by other UI
-- addons. An observation is never treated as complete without new evidence.
ns.ReadOfflinePets = function()
    if not (_G.WOW_PROJECT_MISTS_CLASSIC and _G.WOW_PROJECT_ID == _G.WOW_PROJECT_MISTS_CLASSIC) then
        return nil, "wrong-target"
    end
    local a, slots, pages = _G.NUM_PET_ACTIVE_SLOTS, _G.NUM_PET_STABLE_SLOTS, _G.NUM_PET_STABLE_PAGES
    if type(_G.GetStablePetInfo) ~= "function" or type(a) ~= "number" or type(slots) ~= "number"
        or type(pages) ~= "number" or a < 1 or a > 20 or slots < 1 or pages < 1
        or a % 1 ~= 0 or slots % 1 ~= 0 or pages % 1 ~= 0 or slots * pages > 1000 then
        return nil, "unavailable"
    end
    local api = _G.C_StableInfo or {}
    if type(api.GetNumActivePets) ~= "function" or type(api.GetNumStablePets) ~= "function" then
        return nil, "unavailable"
    end
    local okA, beforeA = pcall(api.GetNumActivePets)
    local okS, beforeS = pcall(api.GetNumStablePets)
    if not (okA and okS) or type(beforeA) ~= "number" or type(beforeS) ~= "number" then
        return nil, "unavailable"
    end
    local result = { active = {}, stable = {}, completeness = "unverified", coverage = "mists-slot-candidate" }
    for i = 1, a + slots * pages do
        local ok, icon, name, level, family = pcall(_G.GetStablePetInfo, i)
        if not ok then return nil, "unavailable" end
        -- Recorded MoP nil slots can report level 0 with no icon/name/family;
        -- this is only a candidate omission, never proof of an empty slot.
        if icon ~= nil or name ~= nil or (level ~= nil and level ~= 0) or family ~= nil then
            if (type(icon) ~= "number" and type(icon) ~= "string") or type(name) ~= "string"
                or type(level) ~= "number" or type(family) ~= "string" then return nil, "unavailable" end
            local group = i <= a and result.active or result.stable
            group[#group + 1] = { slotID = i, icon = icon, name = name, level = level, family = family }
        end
    end
    local okAfterA, afterA = pcall(api.GetNumActivePets)
    local okAfterS, afterS = pcall(api.GetNumStablePets)
    if not (okAfterA and okAfterS) or afterA ~= beforeA or afterS ~= beforeS
        or #result.active ~= afterA or #result.stable ~= afterS then return nil, "unavailable" end
    local version, build = GetBuildInfo()
    result.sourceBuild = tostring(version) .. "/" .. tostring(build)
    result.evidence = { activeCount = beforeA, stableCount = beforeS,
        activeSlots = a, stableSlots = slots * pages }
    return result, "unverified"
end
