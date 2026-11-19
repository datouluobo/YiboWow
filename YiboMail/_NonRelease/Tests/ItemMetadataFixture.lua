-- Unit-test stand-in for the versioned Core metadata contract. Integration
-- behavior is tested with real Core manifests in Core/ItemMetadataSpec.
return function(_, id)
    if type(id) ~= "number" or id <= 0 or id % 1 ~= 0 then return nil end
    local name, link, quality, _, _, _, _, _, _, icon, _, classID, subclassID = GetItemInfo(id)
    return {itemID=id, name=name, link=link, quality=quality, icon=icon, classID=classID,
        subclassID=subclassID, state=name and "ready" or "unloaded"}
end
