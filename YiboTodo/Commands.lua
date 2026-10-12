local Addon = _G.YiboTodo
SLASH_YIBOTODO1 = "/ytd"
SlashCmdList.YIBOTODO = function(input)
    input = string.lower(strtrim(input or ""))
    local command = string.match(input, "^(%S+)") or ""
    if command == "probe" then
        local specialKind, specialMode = string.match(input, "^probe%s+([a-z]+)%-([a-z]+)%s*$")
        if specialKind ~= "nat" and specialKind ~= "brilltron" then specialKind, specialMode = nil, nil end
        if specialMode ~= "start" and specialMode ~= "snapshot" and specialMode ~= "finish" then specialKind, specialMode = nil, nil end
        if not Addon.Probe or type(Addon.Probe.StartSpecial) ~= "function" then
            Addon:Print(Addon:T("CHAT.PROBE_MISSING"))
            return
        end
        if specialKind then
            local operation = specialMode == "start" and Addon.Probe.StartSpecial
                or specialMode == "snapshot" and Addon.Probe.SnapshotSpecial
                or Addon.Probe.FinishSpecial
            local ok, err = xpcall(function() operation(Addon.Probe, specialKind) end, function(message) return tostring(message) end)
            if not ok then Addon:Print(Addon:T("CHAT.PROBE_FAILED", tostring(err))) end
            return
        end
        Addon:Print(Addon:T("CHAT.PROBE_USAGE"))
    elseif command == "help" then
        Addon:Print(Addon:T("CHAT.HELP"))
    elseif input == "nomi-debug" then
        local itemID = 86425
        local items = _G.C_Item
        local itemCount
        if items and type(items.GetItemCount) == "function" then itemCount = items.GetItemCount(itemID)
        elseif type(GetItemCount) == "function" then itemCount = GetItemCount(itemID) end
        local itemName = GetItemInfo and GetItemInfo(itemID)
        local inCombat = InCombatLockdown and InCombatLockdown() or false
        local action = Addon.nomiActionDiagnostic
        Addon:Print(Addon:T("CHAT.NOMI_DIAG", tostring(inCombat), tostring(itemName), itemID, tostring(itemCount)))
        Addon:Print(Addon:T("CHAT.ITEM_API", tostring(items and type(items.UseItemByName) == "function"), tostring(type(UseItemByName) == "function")))
        if not action then
            Addon:Print(Addon:T("CHAT.SECURE_MISSING"))
        else
            Addon:Print(Addon:T("CHAT.SECURE_INFO", tostring(action.characterID), tostring(action.protected), tostring(action.isCurrentCharacter), tostring(action.type), tostring(action.item), tostring(action.type1), tostring(action.item1)))
        end
    elseif input == "action-debug" then
        local actions = Addon.professionActionDiagnostics
        if not actions or #actions == 0 then
            Addon:Print(Addon:T("CHAT.CRAFT_MISSING"))
            return
        end
        Addon:Print(Addon:T("CHAT.CRAFT_COUNT", tostring(InCombatLockdown and InCombatLockdown() or false), #actions))
        table.sort(actions, function(left, right) return tostring(left.label) < tostring(right.label) end)
        for _, action in ipairs(actions) do
            Addon:Print(Addon:T("CHAT.CRAFT_INFO", tostring(action.label), tostring(action.state), tostring(action.spellName), tostring(action.spellID), tostring(action.professionName), tostring(action.professionLoaded), tostring(action.type1), tostring(action.macrotext1), tostring(action.macrotext2), tostring(action.protected)))
        end
    elseif input == "validate" then local result = Addon:ValidateCatalog(true); Addon:Print(Addon:T("CHAT.CATALOG_RESULT", #result.errors, #result.warnings))
    elseif input == "status" then
        local capture = Addon.Probe and Addon.Probe.specialCapture
        Addon:Print(capture and Addon:T("CHAT.STATUS_ACTIVE", capture.label or capture.kind, #(capture.snapshots or {}), #(capture.eventTrace or {})) or Addon:T("CHAT.STATUS_NONE"))
    else Addon:OpenAccountPage() end
end
