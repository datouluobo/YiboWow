local Addon=_G.YiboReputation
SLASH_YIBOREPUTATION1="/yrp"
SlashCmdList["YIBOREPUTATION"]=function(message)
 local command=tostring(message or ""):match("^%s*(%S*)"):lower()
 if command=="tree" then Addon:Print("声望悬停仅保留监控对比模式。") end
 if Addon.CoreIntegration and Addon.CoreIntegration.initialized then _G.YiboCore.AccountView:ShowPage("reputation",{autoFit=true}) else Addon:Print("YiboCore 尚未就绪。") end
end
