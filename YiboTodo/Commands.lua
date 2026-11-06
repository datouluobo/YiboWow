local Addon = _G.YiboTodo
SLASH_YIBOTODO1 = "/ytd"
SlashCmdList.YIBOTODO = function(input)
    input = string.lower(strtrim(input or ""))
    local command = string.match(input, "^(%S+)") or ""
    if command == "help" then
        Addon:Print(Addon:T("CHAT.HELP"))
    else Addon:OpenAccountPage() end
end
