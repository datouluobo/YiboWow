local _, ns = ...

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
    local result = { active = {}, stable = {}, completeness = "unverified" }
    for i = 1, a + slots * pages do
        local ok, icon, name, level, family = pcall(_G.GetStablePetInfo, i)
        if not ok then return nil, "unavailable" end
        if icon ~= nil or name ~= nil then
            local group = i <= a and result.active or result.stable
            group[#group + 1] = { slotID = i, icon = icon, name = name, level = level, family = family }
        end
    end
    return result, "unverified"
end
