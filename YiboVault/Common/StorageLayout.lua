local Addon = _G.YiboVault
local Layout = {}
local GRID_OVERSCAN_ROWS, GRID_MINIMUM_VISIBLE_ROWS = 2, 6
Addon.StorageLayout = Layout

function Layout:GridColumns(width, size, gap, inset)
    local usable = math.max(size, width - 2 * inset)
    return math.max(1, math.floor((usable + gap) / (size + gap)))
end

function Layout:GridOffset(width, columns, column, size, gap, inset, spread)
    if columns <= 1 then return inset end
    local pitch = spread and math.max(0, width - 2 * inset - size) / (columns - 1) or size + gap
    return inset + math.floor((column - 1) * pitch + 0.5)
end

function Layout:GridHeight(count, columns, rowHeight, inset)
    return 2 * inset + math.ceil(count / columns) * rowHeight
end

function Layout:HideCellTooltip(cell)
    if GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(cell) then
        GameTooltip._yiboVaultGuildKey = nil
        GameTooltip:Hide()
    end
end

function Layout:ClearReusedCellTooltip(cell, previous, record)
    if previous and (not record or previous.sourceID ~= record.sourceID
        or previous.itemID ~= record.itemID or previous.itemLink ~= record.itemLink) then
        self:HideCellTooltip(cell)
    end
end

function Layout:HideGridCells(cells, first)
    for index = first or 1, #cells do
        local cell = cells[index]
        cell.slotIndex = nil
        cell:Hide()
    end
end

function Layout:RenderGrid(scroll, content, cells, count, geometry, create, update)
    local width = math.max(1, (scroll:GetWidth() or 0) - (geometry.widthInset or 0))
    local size, gap, inset, rowHeight = geometry.size, geometry.gap, geometry.inset, geometry.rowHeight
    local columns = self:GridColumns(width, size, gap, inset)
    local contentHeight = self:GridHeight(count, columns, rowHeight, inset)
    local viewportHeight = scroll:GetHeight() or 0
    -- A shrinking result can still have the old scroll offset until Core's scrollbar refresh.
    local scrollTop = math.max(0, math.min(scroll:GetVerticalScroll() or 0, contentHeight - viewportHeight))
    local firstRow = math.max(1, math.floor(scrollTop / rowHeight) + 1 - GRID_OVERSCAN_ROWS)
    local lastRow = math.min(math.ceil(count / columns),
        math.ceil((scrollTop + math.max(viewportHeight, rowHeight * GRID_MINIMUM_VISIBLE_ROWS)) / rowHeight) + GRID_OVERSCAN_ROWS)
    local index = 0
    for row = firstRow, lastRow do
        for column = 1, columns do
            local slot = (row - 1) * columns + column
            if slot > count then break end
            index = index + 1
            local cell = cells[index] or create(content)
            cells[index], cell.slotIndex = cell, slot
            update(cell, slot)
            cell:ClearAllPoints()
            cell:SetPoint("TOPLEFT", content, "TOPLEFT",
                self:GridOffset(width, columns, column, size, gap, inset, geometry.spread),
                -inset - (row - 1) * rowHeight)
            cell:Show()
        end
    end
    self:HideGridCells(cells, index + 1)
    content:SetSize(width, math.max(1, contentHeight))
    scroll:SetContentHeight(contentHeight)
end

function Layout:HideTabs(buttons, first)
    for index = first or 1, #buttons do
        local button = buttons[index]
        button.tabKey, button.tabEnabled = nil, false
        button:Hide()
    end
end

function Layout:PlaceTabs(buttons, tabs, selected, anchor, width, columns, gap, height, top)
    local buttonWidth = math.max(1, (width - (columns - 1) * gap) / columns)
    for index, tab in ipairs(tabs) do
        local button = buttons[index]
        button.tabKey, button.tabEnabled = tab.id, tab.enabled == true
        button.label:SetText(tab.label)
        button:SetState(not button.tabEnabled and "disabled" or tab.id == selected and "selected" or "default")
        button:SetWidth(buttonWidth)
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT",
            ((index - 1) % columns) * (buttonWidth + gap), -top - math.floor((index - 1) / columns) * (height + gap))
        button:Show()
    end
    self:HideTabs(buttons, #tabs + 1)
end
