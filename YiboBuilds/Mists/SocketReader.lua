local Addon = _G.YiboBuilds
if not Addon:HasCompatibleCore() then return end
local Reader = {}
Addon.SocketReader = Reader
local enchantScanTooltip

local function SocketTypeFromTooltipLine(value)
    value = type(value) == "string" and value:lower() or ""
    if value:find("多彩插槽", 1, true) or value:find("meta socket", 1, true) then return "meta" end
    if value:find("红色插槽", 1, true) or value:find("red socket", 1, true) then return "red" end
    if value:find("黄色插槽", 1, true) or value:find("yellow socket", 1, true) then return "yellow" end
    if value:find("蓝色插槽", 1, true) or value:find("blue socket", 1, true) then return "blue" end
    if value:find("棱彩插槽", 1, true) or value:find("prismatic socket", 1, true) then return "prismatic" end
    if value:find("染煞", 1, true) or value:find("sha-touched", 1, true) or value:find("sha touched", 1, true) then return "sha" end
    -- Some client builds localize the socket label differently.  Never lose a
    -- real socket merely because its colour name is unfamiliar; only the
    -- socket-bonus line is not itself a socket.
    if (value:find("插槽", 1, true) and not value:find("插槽奖励", 1, true)) or value:find(" socket", 1, true) then return "unknown" end
    return nil
end

-- Item links retain inserted gems but do not tell us whether an empty field is
-- a genuine empty socket.  The native tooltip is authoritative for that
-- distinction, including the prismatic socket granted by a belt buckle.
local SOCKET_STAT_KEYS = {
    -- GetItemStats table keys are the constant names themselves, not the
    -- localized values of the corresponding globals.
    { key = "EMPTY_SOCKET_META", socketType = "meta" },
    { key = "EMPTY_SOCKET_RED", socketType = "red" },
    { key = "EMPTY_SOCKET_YELLOW", socketType = "yellow" },
    { key = "EMPTY_SOCKET_BLUE", socketType = "blue" },
    { key = "EMPTY_SOCKET_PRISMATIC", socketType = "prismatic" },
    { keys = { "EMPTY_SOCKET_SHA_TOUCHED", "EMPTY_SOCKET_SHA" }, socketType = "sha" },
}

local function SocketStatCount(stats, definition)
    local count = tonumber(stats[definition.key]) or 0
    for _, key in ipairs(definition.keys or {}) do
        -- The client exposes both names for the Sha-touched socket in some
        -- builds. They are aliases for one physical socket, not additive.
        count = math.max(count, tonumber(stats[key]) or 0)
    end
    return count
end

local SOCKET_CODES = { m = "meta", r = "red", y = "yellow", b = "blue", p = "prismatic", s = "sha", u = "unknown" }
local function NativeLayout(itemLink)
    local itemID = itemLink and tonumber(itemLink:match("item:(%d+)"))
    return itemID and Addon.SocketCatalog and Addon.SocketCatalog[itemID]
end

function Reader:NativeCount(itemLink)
    local layout = NativeLayout(itemLink)
    if layout then return #layout end
    if itemLink and type(GetItemStats) == "function" then
        local ok, stats = pcall(GetItemStats, itemLink)
        if ok and type(stats) == "table" then
            local count = 0
            for _, definition in ipairs(SOCKET_STAT_KEYS) do count = count + SocketStatCount(stats, definition) end
            return count
        end
    end
    return 0
end

local function PreserveNativeOrder(slotID, itemLink, sockets)
    local layout = NativeLayout(itemLink)
    if not layout then return sockets end
    local ordered, hasNativePrismatic = {}, false
    for index = 1, #layout do
        local socketType = SOCKET_CODES[layout:sub(index, index)] or "unknown"
        ordered[index] = socketType
        hasNativePrismatic = hasNativePrismatic or socketType == "prismatic"
    end
    -- Added sockets follow the base sockets in the item-link gem fields.
    for index = #layout + 1, #sockets do ordered[index] = sockets[index] end
    local extraSocketSlot = slotID == (INVSLOT_WAIST or 6) or slotID == (INVSLOT_WRIST or 9)
        or slotID == (INVSLOT_HAND or 10) or slotID == (INVSLOT_MAINHAND or 16) or slotID == (INVSLOT_OFFHAND or 17)
    if extraSocketSlot and not hasNativePrismatic then
        for _, socketType in ipairs(sockets) do
            if socketType == "prismatic" then
                -- A tooltip can report only the added socket while omitting
                -- every filled base socket. Keep the added socket after them.
                ordered[#layout + 1] = "prismatic"
                break
            end
        end
    end
    return ordered
end

function Reader:Read(slotID, itemLink)
    local function Add(sockets, value)
        local socketType = SocketTypeFromTooltipLine(value)
        if socketType then sockets[#sockets + 1] = socketType end
    end
    local apiSockets = {}
    if C_TooltipInfo and C_TooltipInfo.GetInventoryItem then
        local ok, tooltip = pcall(C_TooltipInfo.GetInventoryItem, "player", slotID)
        if ok and tooltip and tooltip.lines then
            for _, line in ipairs(tooltip.lines) do
                local socketLineType = Enum and Enum.TooltipDataLineType and Enum.TooltipDataLineType.GemSocket
                if socketLineType and line.type == socketLineType then
                    local socketType = SocketTypeFromTooltipLine(line.socketType)
                    if not socketType and type(line.socketType) == "string" then
                        local normalized = line.socketType:lower():gsub("[^%a]", "")
                        local known = { red = "red", yellow = "yellow", blue = "blue", meta = "meta", prismatic = "prismatic", shatouched = "sha", sha = "sha" }
                        socketType = known[normalized]
                    end
                    if socketType then apiSockets[#apiSockets + 1] = socketType
                    else
                        -- A GemSocket line is evidence of a real socket even
                        -- when this client returns a numeric/unrecognized
                        -- socketType. Empty sockets have no gemIcon either.
                        apiSockets[#apiSockets + 1] = "unknown"
                    end
                else
                    Add(apiSockets, line.leftText)
                    if line.rightText ~= line.leftText then Add(apiSockets, line.rightText) end
                end
            end
        end
    end
    local sockets = apiSockets
    if CreateFrame then
        if not enchantScanTooltip then
            enchantScanTooltip = CreateFrame("GameTooltip", "YiboBuildsSocketScanTooltip", UIParent, "GameTooltipTemplate")
        end
        enchantScanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
        enchantScanTooltip:ClearLines()
        enchantScanTooltip:SetInventoryItem("player", slotID)
        local frameSockets = {}
        for index = 1, enchantScanTooltip:NumLines() do
            local line = _G["YiboBuildsSocketScanTooltipTextLeft" .. index]
            Add(frameSockets, line and line:GetText())
        end
        enchantScanTooltip:Hide()
        -- TooltipInfo is incomplete for socket lines on some MoP clients. The
        -- hidden GameTooltip has the same text the player sees, so prefer the
        -- source that found more sockets.
        if #frameSockets > #sockets then sockets = frameSockets end
    end

    local isWeaponSlot = slotID == (INVSLOT_MAINHAND or 16) or slotID == (INVSLOT_OFFHAND or 17)
    if isWeaponSlot then
        local uniqueSha, shaSeen = {}, false
        for _, socketType in ipairs(sockets) do
            -- Sha-touched weapons have one dedicated socket. Some MoP client
            -- tooltip paths report that same empty socket twice.
            if socketType ~= "sha" or not shaSeen then
                uniqueSha[#uniqueSha + 1] = socketType
                if socketType == "sha" then shaSeen = true end
            end
        end
        sockets = uniqueSha
    end

    -- GetItemStats supplies base-item socket counts. Use it to fill native
    -- socket rows omitted by a client tooltip, while preserving every row the
    -- tooltip reported because profession-added sockets can exceed that base.
    if itemLink and type(GetItemStats) == "function" then
        local ok, stats = pcall(GetItemStats, itemLink)
        if ok and type(stats) == "table" then
            local expected = {}
            local expectedTotal = 0
            for _, definition in ipairs(SOCKET_STAT_KEYS) do
                local count = SocketStatCount(stats, definition)
                if isWeaponSlot and definition.socketType == "sha" then count = math.min(count, 1) end
                expected[definition.socketType] = count
                expectedTotal = expectedTotal + count
            end
            if expectedTotal > 0 then
                local complete, observed = {}, {}
                local unknownCount, extraPrismaticIndex = 0, nil
                for _, socketType in ipairs(sockets) do
                    complete[#complete + 1] = socketType
                    if socketType == "unknown" then
                        unknownCount = unknownCount + 1
                    else
                        observed[socketType] = (observed[socketType] or 0) + 1
                    end
                end
                -- Blacksmith adds its prismatic socket after the base item
                -- sockets. If this client reports that row but omits a native
                -- empty socket row, restore the native row before the added
                -- socket so item-link gem indexes still line up.
                local isExtraSocketSlot = slotID == (INVSLOT_WAIST or 6)
                    or slotID == (INVSLOT_WRIST or 9) or slotID == (INVSLOT_HAND or 10)
                if isExtraSocketSlot and (expected.prismatic or 0) == 0 then
                    for index, socketType in ipairs(complete) do
                        if socketType == "prismatic" then extraPrismaticIndex = index; break end
                    end
                end
                local missingRows = {}
                local unknownCanStandForNative = unknownCount
                for _, definition in ipairs(SOCKET_STAT_KEYS) do
                    local missing = math.max(0, (expected[definition.socketType] or 0) - (observed[definition.socketType] or 0))
                    local representedByUnknown = math.min(unknownCanStandForNative, missing)
                    unknownCanStandForNative = unknownCanStandForNative - representedByUnknown
                    for _ = 1, missing - representedByUnknown do missingRows[#missingRows + 1] = definition.socketType end
                end
                if #missingRows > 0 then
                    local insertAt = extraPrismaticIndex or (#complete + 1)
                    for index = #missingRows, 1, -1 do table.insert(complete, insertAt, missingRows[index]) end
                end
                sockets = complete
            end
        end
    end
    return PreserveNativeOrder(slotID, itemLink, sockets)
end
