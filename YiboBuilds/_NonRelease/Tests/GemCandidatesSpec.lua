-- Run from repository root: lua YiboBuilds/_NonRelease/Tests/GemCandidatesSpec.lua
local Setup = dofile("YiboBuilds/_NonRelease/Tests/Core13Host.lua")
local function Find(fn, wanted, seen)
    seen = seen or {}
    if seen[fn] then return end
    seen[fn] = true
    for i = 1, 100 do
        local name, value = debug.getupvalue(fn, i)
        if not name then break end
        if name == wanted then return value end
        if type(value) == "function" then
            local found = Find(value, wanted, seen)
            if found then return found end
        end
    end
end
local checks = 0
local function Check(value, message)
    checks = checks + 1
    assert(value, message)
end
for _, language in ipairs({ "zh", "en" }) do
    Setup(language)
    dofile("YiboBuilds/AccountPage.lua")
    local gems, page = YiboBuilds.Gems, YiboBuilds.AccountPage
    local items = {
        {52182, 4, false}, -- Jasper: screenshot regression
        {52192, 4, false}, -- Dream Emerald: transmutable raw gem
        {76139, 4, false}, -- Wild Jade
        {76640, 4, true},  -- Misty Wild Jade
        {23094, 0, true},  -- Older cut gem
        {76694, 0, true},  -- Brilliant Primordial Ruby: red gem in a blue chest socket
        {23098, 5, true},  -- Cut orange gem in a blue chest socket
        {22459, 8, true},  -- Non-jewelcrafting prismatic gem
        {76884, 6, true},  -- Meta
        {89873, 9, true},  -- Sha-touched, no cut recipe
        {99999999, 4, false}, -- Unknown data must not guess
    }
    local byID = {}
    for _, item in ipairs(items) do byID[item[1]] = item end
    GetItemInfo = function(link)
        local id = type(link) == "number" and link or tonumber(link:match("item:(%d+)"))
        local item = byID[id]
        if not item then return end
        return "Gem " .. id, nil, nil, nil, nil, nil, nil, nil, "", 123, nil, 3, item[2]
    end
    local function Slots(bag) return bag == 0 and #items or 0 end
    local function Link(_, slot) return "item:" .. items[slot][1] end
    C_Container = { GetContainerNumSlots = Slots, GetContainerItemLink = Link,
        GetContainerItemInfo = function(_, slot) return {stackCount = slot + 1} end }
    for _, socketType in ipairs({"red", "yellow", "blue", "prismatic", "meta", "sha", "unknown"}) do
        local candidates = gems:BagCandidates(socketType)
        for _, candidate in ipairs(candidates) do
            local item = byID[tonumber(candidate.link:match("item:(%d+)"))]
            Check(item[3], "uncut or unknown item offered: " .. candidate.link)
            Check(candidate.count == candidate.bagSlot + 1, "bag count lost")
        end
    end
    local ordinaryIDs
    for _, socketType in ipairs({"red", "yellow", "blue", "prismatic"}) do
        local available = gems:BagCandidates(socketType)
        Check(#available == 5, "all ordinary sockets must offer the same five cut gems: " .. socketType)
        local ids = {}
        for _, candidate in ipairs(available) do
            local id = tonumber(candidate.link:match("item:(%d+)"))
            ids[id] = true
            Check(page:IsGoalTargetApplicable({gems = {{socketType = socketType}}},
                {kind = "gem", enhancementID = id, socketIndex = 1}), "cross-color goal rejected")
        end
        Check(ids[76694] and ids[23098], "red and orange gems must remain selectable for blue sockets")
        if ordinaryIDs then
            for id in pairs(ordinaryIDs) do Check(ids[id], "left/right ordinary candidates differ") end
        end
        ordinaryIDs = ids
        Check(not gems:MatchesSocket(76884, 6, socketType), "meta gem offered in ordinary socket")
        Check(not gems:MatchesSocket(89873, 9, socketType), "sha gem offered in ordinary socket")
    end
    Check(#gems:BagCandidates("meta") == 1, "meta socket retains meta gem only")
    Check(#gems:BagCandidates("sha") == 1, "sha socket retains special gem")
    Check(#gems:BagCandidates("unknown") == 0, "unknown socket must not guess")
    for _, item in ipairs(items) do
        local socketType = item[2] == 6 and "meta" or item[2] == 9 and "sha" or "prismatic"
        Check(page:IsGoalTargetApplicable({gems = {{socketType = socketType}}},
            {kind = "gem", enhancementID = item[1], socketIndex = 1}) == item[3], "goal filter mismatch")
    end
    -- Raw gems can also be created by learned transmutation recipes.
    YiboBuilds.CraftSources = {
        [52192] = {gemSubclass = 4, recipes = {1}, skills = {[1] = {755, 1}}},
        [76640] = {gemSubclass = 4, recipes = {2}, skills = {[2] = {755, 1}}},
        [76694] = {gemSubclass = 0, recipes = {3}, skills = {[3] = {755, 1}}},
    }
    GetProfessions = function() return 1 end
    GetProfessionInfo = function() return "Profession", nil, 600, nil, nil, nil, 755 end
    IsSpellKnown = function() return true end
    local craft = assert(Find(page.Refresh, "CraftGemCandidates"))("blue")
    Check(#craft == 2, "craft list must include cross-color cut gems and exclude raw recipe outputs")
    for _, candidate in ipairs(craft) do Check(candidate.itemID ~= 52192, "craft list contains raw gem") end
    -- Legacy container APIs preserve counts and the same filtering.
    C_Container = nil
    GetContainerNumSlots, GetContainerItemLink = Slots, Link
    GetContainerItemInfo = function(_, slot) return 123, slot + 1 end
    local legacy = gems:BagCandidates("blue")
    Check(#legacy == 5 and legacy[1].count > 1, "legacy bag filtering/counts")
    GetItemInfo = function() return nil end
    Check(#gems:BagCandidates("blue") == 0, "uncached item must not guess")
    GetContainerNumSlots, GetContainerItemLink, GetContainerItemInfo = nil, nil, nil
end
print("GemCandidatesSpec passed: " .. checks .. " checks (zh/en)")
