local Probe = _G.YiboCraftingStage0Probe

function Probe:Help()
    self:Print("/yct scan - 记录当前专业窗口/登录时的配方列表")
    self:Print("/yct recipe <ID> - 记录指定配方的产物与材料")
    self:Print("/yct archaeology - 记录考古学项目列表（只读）")
    self:Print("/yct status - 查看本次会话样本数；/yct events on|off - 控制事件记录")
end

function Probe:Command(message)
    local command, argument = tostring(message or ""):match("^%s*(%S*)%s*(.-)%s*$")
    command = command and command:lower() or ""
    if command == "scan" then self:Snapshot("manual")
    elseif command == "recipe" then self:Recipe(argument)
    elseif command == "archaeology" then self:Archaeology()
    elseif command == "status" then
        local session = self.session or self:Initialize()
        self:Print(string.format("当前会话：%d 次扫描，%d 条事件，%d 个配方详情，%d 次考古快照。保存于 YiboCraftingStage0DB。", #session.snapshots, #session.events, #(session.recipeSamples or {}), #(session.archaeologySamples or {})))
    elseif command == "events" and (argument == "on" or argument == "off") then
        self.eventsEnabled = argument == "on"
        self:Print("事件记录已" .. (self.eventsEnabled and "开启" or "关闭"))
    else self:Help() end
end

SLASH_YIBOCRAFTINGPROBE1 = "/yct"
SlashCmdList.YIBOCRAFTINGPROBE = function(message) Probe:Command(message) end
