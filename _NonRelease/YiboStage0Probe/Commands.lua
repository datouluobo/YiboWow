local Addon = _G.YiboStage0Probe

local function Trim(value)
    return tostring(value or ""):match("^%s*(.-)%s*$")
end

function Addon:PrintHelp()
    self:Print("/ysp status - 显示当前会话样本数量")
    self:Print("/ysp events on|off - 开启或关闭事件记录")
    self:Print("/ysp bags | equipment | bank | guildbank | auction | mail")
    self:Print("/ysp guildbank all - 不切换 UI，顺序请求全部可访问页签")
    self:Print("/ysp auction query - 手动重发本人上架查询（打开拍卖行时已自动查询）")
    self:Print("/ysp snapshot - 读取当前可安全读取的所有来源")
    self:Print("/ysp clear - 清除当前会话的诊断样本与事件")
end

function Addon:PrintStatus()
    local summary = self:GetReportSummary()
    self:Print(string.format("当前会话：%d 个样本，%d 个事件。", summary.samples, summary.events))
    local kinds = {}
    for kind, count in pairs(summary.kinds) do kinds[#kinds + 1] = kind .. "=" .. count end
    table.sort(kinds)
    if #kinds > 0 then self:Print(table.concat(kinds, "，")) end
    self:Print("结果保存在 WTF/Account/.../SavedVariables/YiboStage0Probe.lua（退出或 /reload 后落盘）。")
end

function Addon:ProbeSnapshot()
    self:ProbeBags()
    self:ProbeEquipment()
    if self:IsBankOpen() then self:ProbeBank() end
    if self:IsFrameShown("GuildBankFrame") then self:ProbeGuildBank() end
    if self:IsFrameShown("AuctionHouseFrame") then self:ProbeAuction(false) end
    if self:IsFrameShown("MailFrame") then self:ProbeMail() end
end

function Addon:HandleCommand(message)
    local command, rest = Trim(message):match("^(%S+)%s*(.-)$")
    command = command and command:lower() or "help"
    rest = Trim(rest):lower()
    if command == "help" or command == "" then self:PrintHelp()
    elseif command == "status" then self:PrintStatus()
    elseif command == "events" and rest == "on" then self:SetEventLogging(true)
    elseif command == "events" and rest == "off" then self:SetEventLogging(false)
    elseif command == "bags" then self:ProbeBags()
    elseif command == "equipment" or command == "equip" then self:ProbeEquipment()
    elseif command == "bank" then self:ProbeBank()
    elseif command == "guildbank" and rest == "all" then self:ProbeAllGuildBankTabs()
    elseif command == "guildbank" then self:ProbeGuildBank()
    elseif command == "auction" then self:ProbeAuction(rest == "query")
    elseif command == "mail" then self:ProbeMail()
    elseif command == "snapshot" then self:ProbeSnapshot()
    elseif command == "clear" then self:ClearDiagnostics()
    else self:Print("未知命令：" .. tostring(command)); self:PrintHelp() end
end

SLASH_YIBOSTAGE0PROBE1 = "/ysp"
SlashCmdList.YIBOSTAGE0PROBE = function(message) Addon:HandleCommand(message) end
