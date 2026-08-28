local Addon = _G.YiboTodo
SLASH_YIBOTODO1 = "/ytd"
SlashCmdList.YIBOTODO = function(input)
    input = string.lower(strtrim(input or ""))
    if input == "probe" then Addon.Probe:Run(true)
    elseif input == "validate" then local result = Addon:ValidateCatalog(); Addon:Print(string.format("目录校验：%d 错误，%d 候选提示。", #result.errors, #result.warnings))
    elseif input == "status" then
        local current = Addon.Core and Addon.Core.Characters:GetCurrent(); local provider = current and Addon.Database:GetProvider(current.id, "profession-cooldown", false)
        Addon:Print(provider and string.format("专业冷却：%s，最近成功扫描 %s。", provider.state or "unknown", date("%Y-%m-%d %H:%M", provider.lastSuccessAt or 0)) or "当前角色尚无专业冷却扫描。")
    else Addon:OpenAccountPage() end
end
