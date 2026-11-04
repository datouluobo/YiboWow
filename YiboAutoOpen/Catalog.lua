local Addon = _G.YiboAutoOpen
Addon.Catalog = {
    version = 1,
    defaultOrder = { 39883,44751,45724,199210,200239,200238,45328,46007,44113,52676,44663,54535,37586,54516,20393,34077,45072,34863,35348,33857,33844,25419,25423,35512,54536,52340,72201,90735,86623,87391,92960,95601,95602,90839,90840,98133,93724,95469,104272,104273 },
    -- These clams are spell-use items on MoP Classic. Calling their use action
    -- from an addon is forbidden, while ordinary container items remain safe.
    manualOnly = { [52340] = true, [24476] = true },
    excludedFromCatalog = { [24476] = true },
    migrations = {},
}
function Addon.Catalog:IsManualOnly(itemID)
    return self.manualOnly[tonumber(itemID)] == true
end

function Addon.Catalog:IsExcludedFromCatalog(itemID)
    return self.excludedFromCatalog[tonumber(itemID)] == true
end

function Addon.Catalog:GetGameObjectID(sourceGUID)
    if type(sourceGUID) ~= "string" or not sourceGUID:match("^GameObject%-") then return false end
    local objectID = tonumber(sourceGUID:match("^GameObject%-%d+%-%d+%-%d+%-%d+%-(%d+)%-"))
    return objectID
end
