local Addon = _G.YiboTodo
SLASH_YIBOTODO1 = "/ytd"
SlashCmdList.YIBOTODO = function(input)
    input = string.lower(strtrim(input or ""))
    local command = string.match(input, "^(%S+)") or ""
    if command == "probe" then
        local questIDs = {}
        for value in string.gmatch(input, "%d+") do questIDs[#questIDs + 1] = tonumber(value) end
        local resetQuestBaseline = string.match(input, "^probe%s+reset%s*$") ~= nil
        local farmCaptureMode = string.match(input, "^probe%s+farm%-reset%s*$") and "start" or nil
        if string.match(input, "^probe%s+farm%-finish%s*$") then farmCaptureMode = "finish" end
        Addon:Print("已收到 probe 命令，开始执行只读诊断。")
        if not Addon.Probe or type(Addon.Probe.Run) ~= "function" then
            Addon:Print("探针模块未加载：请检查错误提示与 YiboTodo.toc 中的 Probe.lua。")
            return
        end
        local ok, err = xpcall(function() Addon.Probe:Run(true, questIDs, resetQuestBaseline, farmCaptureMode) end, function(message) return tostring(message) end)
        if not ok then Addon:Print("探针执行失败：" .. tostring(err)) end
    elseif command == "help" then
        Addon:Print("命令：/ytd（打开账号页）；/ytd probe [任务ID …]；/ytd probe reset；/ytd probe farm-reset；/ytd probe farm-finish；/ytd status；/ytd validate。")
    elseif input == "validate" then local result = Addon:ValidateCatalog(); Addon:Print(string.format("目录校验：%d 错误，%d 候选提示。", #result.errors, #result.warnings))
    elseif input == "status" then
        local current = Addon.Core and Addon.Core.Characters:GetCurrent(); local provider = current and Addon.Database:GetProvider(current.id, "profession-cooldown", false)
        Addon:Print(provider and string.format("专业冷却：%s，最近成功扫描 %s。", provider.state or "unknown", date("%Y-%m-%d %H:%M", provider.lastSuccessAt or 0)) or "当前角色尚无专业冷却扫描。")
        local farmProvider = current and Addon.Providers.Registry:Get("farm-operation-observation")
        local farmDay, farm
        if farmProvider then farmDay, farm = farmProvider:GetCurrentDay(current.id, Addon:Now()) end
        Addon:Print(farmDay and string.format("农场操作（低保真）：今日 %d 次，最近观察 %s。", #(farmDay.operations or {}), date("%Y-%m-%d %H:%M", farmDay.observedAt or 0)) or (farm and "农场操作（低保真）：今日尚未记录。" or "农场操作 Provider 未加载。"))
        local projected = current and Addon.Snapshot:GetCharacter(current.id)
        Addon:Print(projected and string.format("农场列投影：%s。", #(projected.farmProjects or {}) > 0 and "已显示记录" or "当前为无记录") or "农场列投影：当前角色不在账号快照。")
        for _, activityID in ipairs({ "mop.halfhill.cooking-daily", "wlk.cooking-daily", "tbc.cooking-daily" }) do
            local enabled = Addon.Settings and Addon.Settings.IsMonitoringItemEnabled and Addon.Settings:IsMonitoringItemEnabled("cooking-daily", activityID)
            Addon:Print(string.format("烹饪监控 %s：%s。", activityID, enabled and "已启用" or "已关闭"))
        end
    else Addon:OpenAccountPage() end
end
