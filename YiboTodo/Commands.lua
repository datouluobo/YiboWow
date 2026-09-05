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
        -- Farm capture has its own compact output: only the captured spell
        -- IDs, counts and names are useful for catalog review.
        local verbose = farmCaptureMode == nil
        local ok, err = xpcall(function() Addon.Probe:Run(verbose, questIDs, resetQuestBaseline, farmCaptureMode) end, function(message) return tostring(message) end)
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
        if farmDay then
            local details = {}
            for _, operation in ipairs(farmDay.operations or {}) do
                local kind = operation.kind == "plant" and "播种" or operation.kind == "till" and "翻地" or operation.kind == "harvest" and "收获" or tostring(operation.kind)
                local typeText = operation.plantType == "single" and "单个种子" or operation.plantType == "bundle" and "直接购买种子包" or operation.plantType == "exchange" and "30种子兑换种子包" or nil
                details[#details + 1] = typeText and (kind .. "（" .. typeText .. "，spell=" .. tostring(operation.spellID) .. "）") or (kind .. "（spell=" .. tostring(operation.spellID or "未知") .. "）")
            end
            Addon:Print(string.format("农场操作（低保真）：今日 %d 次，最近观察 %s；明细：%s。", #(farmDay.operations or {}), date("%Y-%m-%d %H:%M", farmDay.observedAt or 0), #details > 0 and table.concat(details, "、") or "无"))
        else
            Addon:Print(farm and "农场操作（低保真）：今日尚未记录。" or "农场操作 Provider 未加载。")
        end
        local projected = current and Addon.Snapshot:GetCharacter(current.id)
        Addon:Print(projected and string.format("农场列投影：%s。", #(projected.farmProjects or {}) > 0 and "已显示记录" or "当前为无记录") or "农场列投影：当前角色不在账号快照。")
        for _, activityID in ipairs({ "mop.halfhill.cooking-daily", "wlk.cooking-daily", "tbc.cooking-daily" }) do
            local enabled = Addon.Settings and Addon.Settings.IsMonitoringItemEnabled and Addon.Settings:IsMonitoringItemEnabled("cooking-daily", activityID)
            Addon:Print(string.format("烹饪监控 %s：%s。", activityID, enabled and "已启用" or "已关闭"))
        end
    else Addon:OpenAccountPage() end
end
