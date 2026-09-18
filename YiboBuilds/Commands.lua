SLASH_YIBOBUILDS1 = "/ybb"
SlashCmdList.YIBOBUILDS = function(message)
    local Addon = _G.YiboBuilds
    local command = string.lower((message or ""):match("^%s*(%S*)") or "")
    if command == "scan" then
        Addon.Snapshot:Capture("diagnostic")
        Addon:Print("已刷新当前角色构筑快照。")
    elseif command == "dump" then
        local current = Addon.Core and Addon.Core.Characters and Addon.Core.Characters:GetCurrent()
        local record = current and Addon.Snapshot:GetCharacter(current.id)
        Addon:Print(record and ("当前槽位：" .. tostring(record.lastActiveSlot)) or "当前角色尚无构筑快照。")
    else
        Addon:Print("/ybb scan 刷新当前构筑；/ybb dump 查看当前槽位。")
    end
end
