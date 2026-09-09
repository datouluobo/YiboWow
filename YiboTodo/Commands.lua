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
        Addon:Print("用法：/ytd probe nat-start|snapshot|finish；/ytd probe brilltron-start|snapshot|finish。")
    elseif command == "help" then
        Addon:Print("命令：/ytd（打开账号页）；/ytd probe nat-start|snapshot|finish；/ytd probe brilltron-start|snapshot|finish；/ytd status；/ytd validate。")
    elseif input == "validate" then local result = Addon:ValidateCatalog(); Addon:Print(string.format("目录校验：%d 错误，%d 候选提示。", #result.errors, #result.warnings))
    elseif input == "status" then
        local capture = Addon.Probe and Addon.Probe.specialCapture
        Addon:Print(capture and string.format("专项探针进行中：%s，已有 %d 个快照、%d 条关键事件。", capture.label or capture.kind, #(capture.snapshots or {}), #(capture.eventTrace or {})) or "当前没有进行中的专项探针。")
    else Addon:OpenAccountPage() end
end
