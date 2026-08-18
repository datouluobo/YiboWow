local Core = _G.YiboCore

-- /yco is a player-facing shortcut.  Release builds deliberately do not
-- expose registry, character-cache, or runtime diagnostics through chat.
SLASH_YIBOCORE1 = "/yco"
SlashCmdList.YIBOCORE = function(message)
    message = string.lower(strtrim(message or ""))
    if message == "" and Core.AccountView then
        Core.AccountView:Toggle()
    elseif message == "settings" and Core.AccountView then
        Core.AccountView:ShowSettings()
    else
        Core:Print("命令: /yco [settings]")
    end
end
