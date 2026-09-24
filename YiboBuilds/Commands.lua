SLASH_YIBOBUILDS1 = "/ybb"
SlashCmdList.YIBOBUILDS = function(message)
    local Addon = _G.YiboBuilds
    local command = string.lower((message or ""):match("^%s*(%S*)") or "")
    if command == "scan" then
        Addon.Snapshot:Capture("diagnostic")
        Addon:Print("已刷新当前角色构筑快照。")
    elseif command == "sockets" then
        Addon.Snapshot:Capture("socket-diagnostic")
        local current = Addon.Core and Addon.Core.Characters and Addon.Core.Characters:GetCurrent()
        local record = current and Addon.Snapshot:GetCharacter(current.id)
        local slot = record and record.slots and record.slots[record.lastActiveSlot or "primary"]
        local equipment = slot and slot.observedEquipment
        if not equipment or not equipment.slots then
            Addon:Print("没有可用的当前装备快照。")
            return
        end
        local hasBlacksmith = false
        if GetProfessions and GetProfessionInfo then
            for _, professionIndex in ipairs({ GetProfessions() }) do
                if professionIndex then
                    local _, _, skillLevel, _, _, _, skillLine = GetProfessionInfo(professionIndex)
                    if tonumber(skillLine) == 164 and (tonumber(skillLevel) or 0) >= 400 then hasBlacksmith = true end
                end
            end
        end
        Addon:Print("锻造准入=" .. tostring(hasBlacksmith) .. "；以下为重扫后的孔数据。")
        for _, definition in ipairs({
            { id = 10, label = "手" }, { id = 9, label = "腕" }, { id = 6, label = "腰" },
            { id = 16, label = "主手" }, { id = 17, label = "副手" },
        }) do
            local item = equipment.slots[tostring(definition.id)]
            local sockets = {}
            for index, gem in ipairs((item and item.gems) or {}) do
                sockets[#sockets + 1] = string.format("%d:%s/%s/%s", index,
                    gem.socketType or "?", gem.source or "?", gem.state or "?")
            end
            local rawRows, rawRowCount = {}, 0
            if C_TooltipInfo and C_TooltipInfo.GetInventoryItem then
                local ok, tooltip = pcall(C_TooltipInfo.GetInventoryItem, "player", definition.id)
                local socketLineType = Enum and Enum.TooltipDataLineType and Enum.TooltipDataLineType.GemSocket
                if ok and tooltip and tooltip.lines then
                    for _, line in ipairs(tooltip.lines) do
                        if socketLineType and line.type == socketLineType then
                            rawRowCount = rawRowCount + 1
                            rawRows[#rawRows + 1] = tostring(line.socketType or "?") .. (line.gemIcon and "+宝石" or "+空")
                        end
                    end
                end
            end
            local emptyStats = {}
            if item and item.itemLink and GetItemStats then
                local ok, stats = pcall(GetItemStats, item.itemLink)
                if ok and type(stats) == "table" then
                    for _, key in ipairs({ "EMPTY_SOCKET_META", "EMPTY_SOCKET_RED", "EMPTY_SOCKET_YELLOW", "EMPTY_SOCKET_BLUE", "EMPTY_SOCKET_PRISMATIC", "EMPTY_SOCKET_SHA_TOUCHED", "EMPTY_SOCKET_SHA" }) do
                        if stats[key] ~= nil then emptyStats[#emptyStats + 1] = key .. "=" .. tostring(stats[key]) end
                    end
                end
            end
            Addon:Print(string.format("%s item=%s sockets=%s forge=%s buckle=%s",
                definition.label, tostring(item and item.itemID or "空"),
                #sockets > 0 and table.concat(sockets, ",") or "无",
                tostring(item and item.blacksmithSockets and item.blacksmithSockets.state or "无"),
                tostring(item and item.beltBuckle and item.beltBuckle.state or "无")))
            Addon:Print(string.format("%s tooltipRows=%d[%s] emptyStats=[%s]", definition.label,
                rawRowCount, table.concat(rawRows, ","), table.concat(emptyStats, ",")))
        end
    elseif command == "dump" then
        local current = Addon.Core and Addon.Core.Characters and Addon.Core.Characters:GetCurrent()
        local record = current and Addon.Snapshot:GetCharacter(current.id)
        Addon:Print(record and ("当前槽位：" .. tostring(record.lastActiveSlot)) or "当前角色尚无构筑快照。")
    else
        Addon:Print("/ybb scan 刷新当前构筑；/ybb sockets 检查装备孔；/ybb dump 查看当前槽位。")
    end
end
