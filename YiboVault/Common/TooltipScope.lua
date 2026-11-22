local Addon, Core = _G.YiboVault, _G.YiboCore

function Addon.AccountPage:GetTooltipScope()
    local view = Core.AccountView
    local visible = view:GetVisibleCharacters()
    local characters = Core.CharacterSort:Sort(visible, view:GetEffectiveCharacterSort("vault-items"),
        Core.Characters:GetCurrentID(), view:GetCustomCharacterOrder())
    local current = Core.Characters:GetCurrent({ identityOnly = true })
    local realm = current and current.realm
    local allRealms = Addon.db and Addon.db.settings and Addon.db.settings.tooltipRealmScope == "all"
    local ids, included = {}, {}
    for _, character in ipairs(characters) do
        if allRealms or (realm and character.realm == realm)
            or (not realm and current and character.id == current.id) then
            ids[#ids + 1] = character.id
            included[#included + 1] = character
        end
    end
    return { mode = "characters", characterIDs = ids }, included, allRealms
end
