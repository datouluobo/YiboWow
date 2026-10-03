local Addon = _G.YiboMailStage0Probe

local function Trim(value)
    return tostring(value or ""):match("^%s*(.-)%s*$")
end

function Addon:PrintHelp()
    self:Print("/ymp mail - 手动采样当前邮箱或关闭后的残留 API")
    self:Print("/ymp watch on|off - 观察刷新、重复邮件与玩家手动操作")
    self:Print("/ymp events on|off - 记录邮箱事件")
    self:Print("/ymp status - 显示样本数量；/ymp clear - 清除本会话样本")
end

function Addon:HandleCommand(message)
    local command, rest = Trim(message):match("^(%S+)%s*(.-)$")
    command, rest = (command or "help"):lower(), Trim(rest):lower()
    if command == "help" or command == "" then self:PrintHelp()
    elseif command == "mail" then self:ProbeMail()
    elseif command == "watch" and rest == "on" then self:SetMailWatch(true)
    elseif command == "watch" and rest == "off" then self:SetMailWatch(false)
    elseif command == "events" and rest == "on" then self:SetEventLogging(true)
    elseif command == "events" and rest == "off" then self:SetEventLogging(false)
    elseif command == "status" then
        local summary = self:GetReportSummary()
        self:Print(string.format("当前会话：%d 个样本，%d 个事件。", summary.samples, summary.events))
        self:Print("/reload 后查看 WTF/Account/.../SavedVariables/YiboMailStage0Probe.lua。")
    elseif command == "clear" then self:ClearDiagnostics()
    else self:Print("未知命令：" .. command); self:PrintHelp() end
end

SLASH_YIBOMAILSTAGE0PROBE1 = "/ymp"
SlashCmdList.YIBOMAILSTAGE0PROBE = function(message) Addon:HandleCommand(message) end
