local Addon = _G.YiboTodo
local Probe = {}
Addon.Probe = Probe

function Probe:Run(verbose)
    local validation = Addon:ValidateCatalog()
    local detail = {
        at = Addon:Now(), interface = tonumber(select(4, GetBuildInfo and GetBuildInfo() or "")) or 0,
        locale = GetLocale and GetLocale() or "unknown", hasCTradeSkillUI = C_TradeSkillUI ~= nil,
        activeRecipes = #validation.activeRecipes, errors = validation.errors, warnings = validation.warnings,
    }
    Addon.db.diagnostics.lastProbe = detail
    Addon:Print(string.format("探针：Interface %s，正式条目 %d，目录错误 %d，候选 %d。", tostring(detail.interface), detail.activeRecipes, #detail.errors, #detail.warnings))
    if verbose then
        for _, code in ipairs(detail.errors) do Addon:Print("错误：" .. code) end
        for _, code in ipairs(detail.warnings) do Addon:Print("候选：" .. code) end
        Addon:Print("当前实现拒绝在未验证自有专业窗口来源时写入正式观察。")
    end
    return detail
end
