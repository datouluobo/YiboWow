if _G.YAB and _G.YAB.CoreReady == false then return end
local YAB = _G.YAB

local function Print(message)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(_G.YiboCore.Locale:Get("YiboAltoBoss", "CHAT.PREFIX") .. tostring(message))
    end
end

SLASH_YIBOALTOBOSS1 = "/yab"
SlashCmdList["YIBOALTOBOSS"] = function(message)
    YAB.CheckForReset()
    local command, argument = tostring(message or ""):match("^%s*(%S*)%s*(.-)%s*$")
    command = tostring(command or ""):lower()
    argument = tostring(argument or ""):lower()
    if command == "debug" then
        local bosses = YAB.GetBossList()
        local allBosses = YAB.GetAllBossList()
        local names = {}
        for _, boss in ipairs(bosses) do names[#names + 1] = tostring(boss.key) .. "=" .. tostring(boss.name) end
        Print("bossList " .. tostring(#bosses) .. "/" .. tostring(#allBosses) .. " -> " .. table.concat(names, ", "))
        local display = YiboAltoBossDB.display or {}
        local groups = display.groups or {}
        Print("groups world_boss=" .. tostring(groups.world_boss) .. " warbringer=" .. tostring(groups.warbringer) .. " custom=" .. tostring(groups.custom))
        if YAB.TrackingV3 then
            local bossKey = argument ~= "" and argument or nil
            for _, line in ipairs(YAB.TrackingV3:GetDebugSummary(bossKey)) do Print(line) end
        end
        return
    end
    if command == "trace" then
        if not YAB.TrackingV3 then Print(_G.YiboCore.Locale:Get("YiboAltoBoss", "UI.TRACKINGV3_IS_UNAVAILABLE")); return end
        local enabled = argument == "on"
        YAB.TrackingV3:SetTraceEnabled(enabled)
        YAB.PersistDB()
        Print(_G.YiboCore.Locale:Get("YiboAltoBoss", "UI.STATE_TRANSITION_TRACING") .. (enabled and _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.ON") or _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.OFF")))
        return
    end
    if command == "selftest" then
        if not YAB.TrackingV3 then Print(_G.YiboCore.Locale:Get("YiboAltoBoss", "UI.TRACKINGV3_IS_UNAVAILABLE")); return end
        local passed, detail = YAB.TrackingV3:RunSelfTest()
        Print((passed and _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.SELF_CHECK_PASSED") or _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.SELF_CHECK_FAILED")) .. tostring(detail))
        return
    end
    if command == "celestial" or command == "celestials" then
        local _, result = YAB.RecordBossManually(YAB.GetCurrentCharKey(), "celestials")
        Print(result)
        return
    end
    if command == "holiday" then
        if not YAB.Holiday then Print(_G.YiboCore.Locale:Get("YiboAltoBoss", "UI.SEASONAL_BOSS_MODULE_IS_UNAVAILABLE")) return end
        local bosses = YAB.Holiday:GetActiveBosses()
        if #bosses == 0 then Print(_G.YiboCore.Locale:Get("YiboAltoBoss", "UI.NO_SEASONAL_BOSS_IS_CONFIRMED_ACTIVE")) return end
        for _, boss in ipairs(bosses) do
            local status, record = YAB.Holiday:GetStatus(YAB.GetCurrentCharKey(), boss)
            local queue = YAB.Holiday:GetQueueState(boss)
            Print(boss.name .. _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.STATUS_3") .. tostring(status) .. _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.QUEUE_2") .. tostring(queue.state) .. _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.SOURCE_2") .. tostring(record and record.source or "—"))
        end
        return
    end
    Print(_G.YiboCore.Locale:Get("YiboAltoBoss", "COMMANDS.HELP"))
end
