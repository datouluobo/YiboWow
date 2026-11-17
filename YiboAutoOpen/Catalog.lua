local Addon = _G.YiboAutoOpen
Addon.Catalog = Addon.Target.catalog
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
