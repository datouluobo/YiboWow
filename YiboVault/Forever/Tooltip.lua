local Addon, Core = _G.YiboVault, _G.YiboCore

function Addon:TooltipSourceSnapshotAvailable(source, locations, available)
    if source == "bags" or source == "bank" then
        if not next(locations) then return false end
        for _, state in pairs(locations) do
            if not available(state, source) then return false end
        end
        return true
    end
    local key = source == "equipment" and "equipment" or source == "auction" and "auction" or "inbox"
    return available(locations[key], source)
end

function Addon.AccountPage:GetTooltipScope()
    local view = Core.AccountView
    local characters = Core.CharacterSort:Sort(view:GetVisibleCharacters(), view:GetEffectiveCharacterSort("vault-items"),
        Core.Characters:GetCurrentID(), view:GetCustomCharacterOrder())
    local current = Core.Characters:GetCurrent({ identityOnly = true })
    local allRealms = Addon.db.settings.tooltipRealmScope == "all"
    local ids, included = {}, {}
    for _, character in ipairs(characters) do
        if allRealms or (current and character.realm == current.realm) then
            ids[#ids + 1], included[#included + 1] = character.id, character
        end
    end
    return { mode = "characters", characterIDs = ids }, included, allRealms
end

function Addon:QueryTooltip(scope, itemID)
    local currentID = Core.Characters:GetCurrentID()
    local currentIncluded = false
    for _, id in ipairs(scope.characterIDs) do
        if id == currentID then currentIncluded = true; break end
    end
    local result = currentIncluded and self.Items:Query({ scope = { mode = "characters", characterIDs = { currentID } }, itemID = itemID })
        or { records = {}, transitRecords = {}, coverage = {} }
    for _, id in ipairs(scope.characterIDs) do
        if id ~= currentID then
            for _, source in ipairs({ "bags", "equipment", "bank", "mail", "auction" }) do
                local states = self:GetCachedCharacterCoverage(id, source)
                result.coverage[source] = result.coverage[source] or {}
                result.coverage[source][id] = { locations = states }
                for _, record in ipairs(self:GetCachedCharacterRecords(id, source, itemID)) do
                    if record.mailStatus == "in-transit" then
                        result.transitRecords[#result.transitRecords + 1] = record
                    else
                        result.records[#result.records + 1] = record
                    end
                end
            end
        end
    end
    return result
end
