local Core = _G.YiboCore

-- /yco is a player-facing shortcut.  Release builds deliberately do not
-- expose registry, character-cache, or runtime diagnostics through chat.
SLASH_YIBOCORE1 = "/yco"
SlashCmdList.YIBOCORE = function(message)
    if not Core:IsInitialized() then
        Core:Print(Core:Text("CORE.CLIENT_NOT_READY"))
        return
    end
    message = string.lower(strtrim(message or ""))
    if message == "" and Core.AccountView then
        Core.AccountView:Toggle()
    elseif message == "settings" and Core.AccountView then
        Core.AccountView:ShowSettings()
    else
        Core:Print(Core:Text("CORE.COMMAND_YCO_SETTINGS"))
    end
end
