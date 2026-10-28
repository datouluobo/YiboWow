local Core = _G.YiboCore
local globals = { IsSecret = "issecretvalue", CursorInfo = "GetCursorInfo", ClearCursor = "ClearCursor",
    MouseFoci = "GetMouseFoci", MouseFocus = "GetMouseFocus", CursorPosition = "GetCursorPosition",
    PlayerName = "UnitName", AddonEnableLegacy = "GetAddOnEnableState", LooseIcons = "GetLooseMacroIcons",
    LooseItemIcons = "GetLooseMacroItemIcons", MacroIcons = "GetMacroIcons", MacroItemIcons = "GetMacroItemIcons",
    MacroCount = "GetNumMacroIcons", MacroIcon = "GetMacroIconInfo", Combat = "InCombatLockdown",
    PopupShow = "StaticPopup_Show", PopupHide = "StaticPopup_Hide", StateDriver = "RegisterStateDriver" }
Core.Client:ConfigureSurface("Mists", Core._private.CreateClientSurface(function(key)
    if key == "ItemEvent" then return "GET_ITEM_INFO_RECEIVED" end
    if key == "ItemInfo" then return GetItemInfo or (C_Item and C_Item.GetItemInfo) end
    if key == "RequestItem" then return C_Item and C_Item.RequestLoadItemDataByID end
    if key == "BagSlots" then return C_Container and C_Container.GetContainerNumSlots or GetContainerNumSlots end
    if key == "BagItem" then return C_Container and C_Container.GetContainerItemID or GetContainerItemID end
    if key == "AddonInfo" then return C_AddOns and C_AddOns.GetAddOnInfo or GetAddOnInfo end
    if key == "AddonMetadata" then return C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata end
    if key == "AddonEnableModern" then return C_AddOns and C_AddOns.GetAddOnEnableState end
    return globals[key] and _G[globals[key]]
end, function()
    local ids = { 0, 1, 2, 3, 4 }
    -- Mists supports the backpack and four equipped bag slots.
    if NUM_BAG_SLOTS ~= nil and NUM_BAG_SLOTS ~= 4 then return nil, "unavailable" end
    return ids
end))
