local Addon = _G.YiboBuilds
if not Addon:HasCompatibleCore() then return end
SLASH_YIBOBUILDS1 = "/ybb"
SlashCmdList.YIBOBUILDS = function(message)
    local Addon = _G.YiboBuilds
    if not Addon.CoreIntegration.initialized then Addon:Print(Addon.STARTUP_REQUIREMENTS); return end
    local command = string.lower((message or ""):match("^%s*(%S*)") or "")
    if command == "scan" then
        Addon.Snapshot:Capture("diagnostic")
        Addon:Print(Addon:T("COMMAND.CURRENT_BUILD_SNAPSHOT_REFRESHED"))
    elseif command == "api" then
        local version, build = GetBuildInfo and GetBuildInfo()
        local socket = C_ItemSocketInfo or _G
        local container = C_Container or _G
        Addon:Print(Addon:T("COMMAND.CLIENT") .. tostring(version or "?") .. " build=" .. tostring(build or "?"))
        Addon:Print(Addon:T("COMMAND.SOCKETING") .. tostring(type(socket.SocketInventoryItem) == "function")
            .. Addon:T("COMMAND.PLACE_GEM") .. tostring(type(socket.ClickSocketButton) == "function")
            .. Addon:T("COMMAND.SOCKET_COUNT") .. tostring(type(socket.GetNumSockets) == "function")
            .. Addon:T("COMMAND.BAG_USE") .. tostring(type(container.UseContainerItem) == "function"))
        Addon:Print(Addon:T("COMMAND.RECIPE") .. tostring(type(IsSpellKnown) == "function")
            .. Addon:T("COMMAND.CAST") .. tostring(type(CastSpellByID) == "function")
            .. Addon:T("COMMAND.REAGENTS") .. tostring(type(GetTradeSkillReagentInfo) == "function")
            .. Addon:T("COMMAND.RECIPE_LINK") .. tostring(type(GetTradeSkillRecipeLink) == "function"))
    elseif command == "augment" then
        local trace = Addon.augmentActionTrace or {}
        if #trace == 0 then Addon:Print(Addon:T("COMMAND.NO_ENHANCEMENT_LOG_CLICK_AN_ENCHANT_CANDIDATE_FIRST")) end
        for _, line in ipairs(trace) do Addon:Print(line) end
    elseif command == "sockets" then
        Addon.Snapshot:Capture("socket-diagnostic")
        local current = Addon.Core and Addon.Core.Characters and Addon.Core.Characters:GetCurrent()
        local record = current and Addon.Snapshot:GetCharacter(current.id)
        local slot = record and record.slots and record.slots[record.lastActiveSlot or "primary"]
        local equipment = slot and slot.observedEquipment
        if not equipment or not equipment.slots then
            Addon:Print(Addon:T("COMMAND.NO_CURRENT_EQUIPMENT_SNAPSHOT_AVAILABLE"))
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
        Addon:Print(Addon:T("COMMAND.BLACKSMITH_ELIGIBLE") .. tostring(hasBlacksmith) .. Addon:T("COMMAND.RESCANNED_SOCKET_DATA_FOLLOWS"))
        for _, definition in ipairs({
            { id = 10, label = Addon:T("UI.HANDS") }, { id = 9, label = Addon:T("UI.WRIST") }, { id = 6, label = Addon:T("UI.WAIST") },
            { id = 16, label = Addon:T("UI.MAIN_HAND") }, { id = 17, label = Addon:T("UI.OFF_HAND") },
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
                            rawRows[#rawRows + 1] = tostring(line.socketType or "?") .. (line.gemIcon and Addon:T("COMMAND.GEM") or Addon:T("COMMAND.EMPTY"))
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
                definition.label, tostring(item and item.itemID or Addon:T("UI.EMPTY")),
                #sockets > 0 and table.concat(sockets, ",") or Addon:T("COMMAND.NONE"),
                tostring(item and item.blacksmithSockets and item.blacksmithSockets.state or Addon:T("COMMAND.NONE")),
                tostring(item and item.beltBuckle and item.beltBuckle.state or Addon:T("COMMAND.NONE"))))
            Addon:Print(string.format("%s tooltipRows=%d[%s] emptyStats=[%s]", definition.label,
                rawRowCount, table.concat(rawRows, ","), table.concat(emptyStats, ",")))
        end
    elseif command == "dump" then
        local current = Addon.Core and Addon.Core.Characters and Addon.Core.Characters:GetCurrent()
        local record = current and Addon.Snapshot:GetCharacter(current.id)
        Addon:Print(record and (Addon:T("COMMAND.CURRENT_SLOT") .. tostring(record.lastActiveSlot)) or Addon:T("COMMAND.NO_BUILD_SNAPSHOT_FOR_THE_CURRENT_CHARACTER"))
    else
        Addon:Print(Addon:T("COMMAND.YBB_SCAN_REFRESH_YBB_SOCKETS_INSPECT_SOCKETS_YBB_API_INSPECT_CLIE"))
    end
end
