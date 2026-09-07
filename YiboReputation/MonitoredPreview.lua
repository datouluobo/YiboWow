local Addon, Core = _G.YiboReputation, _G.YiboCore
local Theme = Core.UITheme

local function Text(parent, size, color, justify)
    return Theme:CreateText(parent, size, color, justify or "LEFT")
end

local function Snapshot(character)
    return Core.DataDomains:Get(character.id, "reputation")
end

local function Data(character, factionID)
    return Addon:GetFactionData(Snapshot(character), factionID)
end

local function ShowMonitoredTooltip(row)
    local context = row.monitoredTooltip
    if not context then return end
    local scale = (row.GetEffectiveScale and row:GetEffectiveScale()) or 1
    local cursorX = (GetCursorPosition and GetCursorPosition() or 0) / scale
    local relative = cursorX - (row:GetLeft() or cursorX)
    if relative < context.nameWidth then GameTooltip:Hide(); return end
    local character = context.characters[context.first + math.floor((relative - context.nameWidth) / context.cellWidth)]
    local data = character and Data(character, context.factionID)
    local compact, detail = data and Addon:FormatCompact(data), data and Addon:FormatReputation(data)
    if not detail or compact == detail or not detail:find("/", 1, true) then GameTooltip:Hide(); return end
    GameTooltip:SetOwner(row, "ANCHOR_CURSOR"); GameTooltip:ClearLines()
    GameTooltip:AddLine(detail, Theme.Colors.text[1], Theme.Colors.text[2], Theme.Colors.text[3]); GameTooltip:Show()
end

function Addon:CreateMonitoredPreview(parent)
    parent.monitoredRows, parent.monitoredHeaders = {}, {}
    parent.monitoredDetail = Text(parent, Theme.Font.assist, Theme.Colors.muted, "LEFT")
    parent.monitoredCurrentOutline = Theme:CreateCurrentCharacterOutline(parent)
    parent.monitoredPagerAnchor = CreateFrame("Frame", nil, parent)
end

function Addon:RefreshMonitoredPreview(parent, context)
    local factionIDs = self:GetSettings().monitoredFactionIDs
    parent.monitoredDetail:Hide()
    if #factionIDs == 0 then
        parent.monitoredCurrentOutline:Hide()
        for _, row in ipairs(parent.monitoredRows) do row:Hide() end
        for _, header in ipairs(parent.monitoredHeaders) do header:Hide() end
        return
    end

    local inset, nameWidth = Theme:GetMatrixInsets(true), 150
    local availableWidth = math.max(1, (tonumber(context.surfaceAvailableWidth) or parent:GetWidth() or 1) - inset.left - inset.right)
    local cellWidth = Theme:GetCharacterMatrixColumnWidth(context)
    local current = Core.Characters:GetCurrent()
    local shown, pageInfo = Core.AccountView:GetColumnPage("reputation", "monitored", context.characters, availableWidth, nameWidth, cellWidth, current and current.id)
    local columns = { { width = nameWidth } }
    for _ = 1, #shown do columns[#columns + 1] = { width = cellWidth } end

    local headerHeight, y = Theme:GetCharacterHeaderHeight(context), inset.top
    local currentHeader, currentColumnX
    for index = 0, #shown do
        local character = index > 0 and shown[index] or nil
        local width, x = index == 0 and nameWidth or cellWidth, inset.left + (index == 0 and 0 or nameWidth + (index - 1) * cellWidth)
        local header = parent.monitoredHeaders[index + 1] or Theme:CreateMatrixHeader(parent)
        parent.monitoredHeaders[index + 1] = header
        header:ClearAllPoints(); header:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y); header:SetSize(width, headerHeight)
        if character then
            Theme:SetCharacterHeader(header, character, context)
            if current and character.id == current.id then currentHeader, currentColumnX = header, x end
        else
            Theme:SetMatrixHeader(header, "声望", { height = headerHeight, justify = "LEFT", inset = Theme.Space.xxs })
            header:SetScript("OnEnter", nil); header:SetScript("OnLeave", nil)
        end
        header:Show()
    end
    for index = #shown + 2, #parent.monitoredHeaders do parent.monitoredHeaders[index]:Hide() end
    y = y + headerHeight

    for rowIndex, factionID in ipairs(factionIDs) do
        local row = parent.monitoredRows[rowIndex] or CreateFrame("Button", nil, parent, "BackdropTemplate")
        parent.monitoredRows[rowIndex] = row
        row:SetSize(nameWidth + #shown * cellWidth, Theme.Table.previewRowHeight)
        row:ClearAllPoints(); row:SetPoint("TOPLEFT", parent, "TOPLEFT", inset.left, -y)
        row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        local tone = Theme:GetDataRowColor(rowIndex)
        row:SetBackdropColor(tone[1], tone[2], tone[3], 1); row:SetBackdropBorderColor(Theme.Colors.matrixLine[1], Theme.Colors.matrixLine[2], Theme.Colors.matrixLine[3], Theme.Colors.matrixLine[4])
        Theme:ApplyDataColumnTints(row, columns, Theme.Table.previewRowHeight)
        row.cells = row.cells or {}
        local values = { self:GetFactionName(factionID) }
        for _, character in ipairs(shown) do
            values[#values + 1] = self:FormatSnapshotValue(Snapshot(character), Data(character, factionID), "compact", self:GetFactionState(Snapshot(character), factionID))
        end
        local x = 0
        for columnIndex, value in ipairs(values) do
            local width = columns[columnIndex].width
            local cell = row.cells[columnIndex] or Text(row, Theme.Font.assist, Theme.Colors.text, columnIndex == 1 and "LEFT" or "CENTER")
            row.cells[columnIndex] = cell
            cell:ClearAllPoints(); cell:SetPoint("LEFT", row, "LEFT", x + Theme.Table.cellInset, 0); cell:SetWidth(width - Theme.Table.cellInset * 2); cell:SetText(value)
            if columnIndex > 1 then
                local data = Data(shown[columnIndex - 1], factionID)
                local color = data and self:GetReputationColor(data) or Theme.Colors.muted
                cell:SetTextColor(color[1], color[2], color[3])
            else cell:SetTextColor(Theme.Colors.text[1], Theme.Colors.text[2], Theme.Colors.text[3]) end
            cell:Show(); x = x + width
        end
        for index = #values + 1, #row.cells do row.cells[index]:Hide() end
        row.monitoredTooltip = { characters = context.characters, first = pageInfo.first, nameWidth = nameWidth, cellWidth = cellWidth, factionID = factionID }
        row:SetScript("OnEnter", function(control) control.monitoredTooltipTracking = true; ShowMonitoredTooltip(control) end)
        row:SetScript("OnUpdate", function(control) if control.monitoredTooltipTracking then ShowMonitoredTooltip(control) end end)
        row:SetScript("OnLeave", function(control) control.monitoredTooltipTracking = false; GameTooltip:Hide() end)
        row:Show(); y = y + Theme.Table.previewRowHeight
    end
    for index = #factionIDs + 1, #parent.monitoredRows do parent.monitoredRows[index]:Hide() end
    Theme:UpdateCurrentCharacterColumnOutline(parent.monitoredCurrentOutline, currentHeader, parent, 0, cellWidth, currentHeader ~= nil, currentColumnX)
    parent.monitoredPagerAnchor:ClearAllPoints(); parent.monitoredPagerAnchor:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -inset.right, -inset.top); parent.monitoredPagerAnchor:SetSize(1, 1)
    Core.AccountView:UpdateColumnPager(parent, "reputation", "monitored", pageInfo, parent.monitoredPagerAnchor, "角色")
end
