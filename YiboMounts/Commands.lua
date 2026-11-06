local _, NS = ...

SLASH_YIBOMOUNTS1 = "/ymt"
SlashCmdList.YIBOMOUNTS = function()
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage(NS:L("PROBE_MOVED")) end
end
