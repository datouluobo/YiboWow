local Probe = _G.YiboCraftingStage0Probe
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
for _, event in ipairs({ "TRADE_SKILL_SHOW", "TRADE_SKILL_CLOSE", "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_UPDATE", "NEW_RECIPE_LEARNED", "SKILL_LINES_CHANGED", "SPELLS_CHANGED" }) do
    pcall(frame.RegisterEvent, frame, event)
end

local function DelayedScan(reason)
    local run = function() Probe:Snapshot(reason) end
    if C_Timer and type(C_Timer.After) == "function" then C_Timer.After(0.5, run) else run() end
end

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        if ... == "YiboCraftingStage0Probe" then Probe:Initialize() end
        return
    end
    if event == "PLAYER_LOGIN" then
        if not Probe.session then Probe:Initialize() end
        DelayedScan("login")
        Probe:Print("阶段 0 只读探针已加载；输入 /yct 查看命令。")
        return
    end
    Probe:AddEvent(event, ...)
    if event == "TRADE_SKILL_SHOW" then DelayedScan("trade-skill-show") end
end)
