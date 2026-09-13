local Addon = _G.YiboTodo
SLASH_YIBOTODO1 = "/ytd"
SlashCmdList.YIBOTODO = function(input)
    input = string.lower(strtrim(input or ""))
    local command = string.match(input, "^(%S+)") or ""
    if command == "probe" then
        local specialKind, specialMode = string.match(input, "^probe%s+([a-z]+)%-([a-z]+)%s*$")
        if specialKind ~= "nat" and specialKind ~= "brilltron" and specialKind ~= "brewfest" then specialKind, specialMode = nil, nil end
        if specialMode ~= "start" and specialMode ~= "snapshot" and specialMode ~= "finish" then specialKind, specialMode = nil, nil end
        if not Addon.Probe or type(Addon.Probe.StartSpecial) ~= "function" then
            Addon:Print("探针模块未加载：请检查错误提示与 YiboTodo.toc 中的 Probe.lua。")
            return
        end
        if specialKind then
            local operation = specialMode == "start" and Addon.Probe.StartSpecial
                or specialMode == "snapshot" and Addon.Probe.SnapshotSpecial
                or Addon.Probe.FinishSpecial
            local ok, err = xpcall(function() operation(Addon.Probe, specialKind) end, function(message) return tostring(message) end)
            if not ok then Addon:Print("专项探针执行失败：" .. tostring(err)) end
            return
        end
        Addon:Print("用法：/ytd probe nat-start|snapshot|finish；/ytd probe brilltron-start|snapshot|finish；/ytd probe brewfest-start|snapshot|finish。")
    elseif command == "help" then
        Addon:Print("命令：/ytd（打开账号页）；/ytd nomi-debug；/ytd action-debug；/ytd probe nat-start|snapshot|finish；/ytd probe brilltron-start|snapshot|finish；/ytd probe brewfest-start|snapshot|finish；/ytd status；/ytd validate。")
    elseif input == "nomi-debug" then
        local itemID = 86425
        local items = _G.C_Item
        local itemCount
        if items and type(items.GetItemCount) == "function" then itemCount = items.GetItemCount(itemID)
        elseif type(GetItemCount) == "function" then itemCount = GetItemCount(itemID) end
        local itemName = GetItemInfo and GetItemInfo(itemID)
        local inCombat = InCombatLockdown and InCombatLockdown() or false
        local action = Addon.nomiActionDiagnostic
        Addon:Print(string.format("诺米动作诊断：战斗锁定=%s；物品=%s（ID=%d）；背包数量=%s。", tostring(inCombat), tostring(itemName), itemID, tostring(itemCount)))
        Addon:Print(string.format("物品 API：C_Item.UseItemByName=%s；UseItemByName=%s。", tostring(items and type(items.UseItemByName) == "function"), tostring(type(UseItemByName) == "function")))
        if not action then
            Addon:Print("安全按钮：尚未渲染；请先打开账号待办并确保诺米图标可见，再执行此命令。")
        else
            Addon:Print(string.format("安全按钮：角色=%s；受保护=%s；当前角色=%s；通用=%s / %s；左键=%s / %s。", tostring(action.characterID), tostring(action.protected), tostring(action.isCurrentCharacter), tostring(action.type), tostring(action.item), tostring(action.type1), tostring(action.item1)))
        end
    elseif input == "action-debug" then
        local actions = Addon.professionActionDiagnostics
        if not actions or #actions == 0 then
            Addon:Print("商业动作诊断：尚未渲染；请先打开账号待办并确保当前角色的商业图标可见，再执行此命令。")
            return
        end
        Addon:Print(string.format("商业动作诊断：战斗锁定=%s；已渲染 %d 个当前角色图标。", tostring(InCombatLockdown and InCombatLockdown() or false), #actions))
        table.sort(actions, function(left, right) return tostring(left.label) < tostring(right.label) end)
        for _, action in ipairs(actions) do
            Addon:Print(string.format("%s：状态=%s；法术=%s（ID=%s）；专业=%s；专业已载入=%s；左键=%s；左键宏=%s；右键宏=%s；受保护=%s。", tostring(action.label), tostring(action.state), tostring(action.spellName), tostring(action.spellID), tostring(action.professionName), tostring(action.professionLoaded), tostring(action.type1), tostring(action.macrotext1), tostring(action.macrotext2), tostring(action.protected)))
        end
    elseif input == "validate" then local result = Addon:ValidateCatalog(); Addon:Print(string.format("目录校验：%d 错误，%d 候选提示。", #result.errors, #result.warnings))
    elseif input == "status" then
        local capture = Addon.Probe and Addon.Probe.specialCapture
        Addon:Print(capture and string.format("专项探针进行中：%s，已有 %d 个快照、%d 条关键事件。", capture.label or capture.kind, #(capture.snapshots or {}), #(capture.eventTrace or {})) or "当前没有进行中的专项探针。")
    else Addon:OpenAccountPage() end
end
