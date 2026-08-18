local YAB = _G.YAB

local function Print(message)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage("|cffFFD84AYiboAltoBoss:|r " .. tostring(message))
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
        if not YAB.TrackingV3 then Print("TrackingV3 不可用。"); return end
        local enabled = argument == "on"
        YAB.TrackingV3:SetTraceEnabled(enabled)
        YAB.PersistDB()
        Print("状态转换跟踪：" .. (enabled and "开启" or "关闭"))
        return
    end
    if command == "selftest" then
        if not YAB.TrackingV3 then Print("TrackingV3 不可用。"); return end
        local passed, detail = YAB.TrackingV3:RunSelfTest()
        Print((passed and "自测通过：" or "自测失败：") .. tostring(detail))
        return
    end
    if command == "celestial" or command == "celestials" then
        local _, result = YAB.RecordBossManually(YAB.GetCurrentCharKey(), "celestials")
        Print(result)
        return
    end
    Print("支持 /yab debug [boss]、/yab trace on|off、/yab selftest、/yab celestial。")
end
