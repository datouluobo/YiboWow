if _G.YAB and _G.YAB.CoreReady == false then return end
local Core = _G.YiboCore
local YAB = _G.YAB
local Theme = Core.UITheme
local C = Theme.Colors

local TAB_H = 34
local CELL_W = 88
local ROW_H = 24

function YAB.GetBusinessTabHeight() return TAB_H end

function YAB.CreateBusinessTabs(parent, active)
    local tabs = CreateFrame("Frame", nil, parent)
    tabs:SetHeight(TAB_H)
    tabs:SetPoint("TOPLEFT", 0, 0)
    tabs:SetPoint("TOPRIGHT", 0, 0)
    tabs:SetFrameLevel((parent:GetFrameLevel() or 0) + 5)
    tabs.buttons = {}
    -- Legacy bridge textures are always hidden; Core still owns their thickness.
    tabs.leftBridge = tabs:CreateTexture(nil, "OVERLAY")
    Theme:ApplyPixelRule(tabs.leftBridge, "horizontal")
    tabs.rightBridge = tabs:CreateTexture(nil, "OVERLAY")
    Theme:ApplyPixelRule(tabs.rightBridge, "horizontal")
    for index, def in ipairs(YAB.BusinessTabs) do
        local button = CreateFrame("Button", nil, tabs, "BackdropTemplate")
        button:SetSize(def.width, TAB_H)
        button:SetPoint("TOPLEFT", 8 + (index - 1) * (def.width + 2), 0)
        -- Tabs are separated by a 2-unit gap, so each keeps its own frame.
        Theme:ApplyPixelBackdrop(button, { background = true })
        button.label = Theme:CreateText(button, Theme.Font.body, C.text, "CENTER")
        button.label:SetPoint("CENTER")
        button:SetScript("OnClick", function()
            YAB.SetAccountBusinessPage(def.page)
            if Core.AccountView and Core.AccountView.ShowPage then Core.AccountView:ShowPage(def.page) end
        end)
        button:SetScript("OnEnter", function(self) if self.active ~= true then self:SetBackdropColor(C.toolbar[1], C.toolbar[2], C.toolbar[3], 1) end end)
        button:SetScript("OnLeave", function(self) self:SetBackdropColor(self.active and C.chrome[1] or C.bg[1], self.active and C.chrome[2] or C.bg[2], self.active and C.chrome[3] or C.bg[3], 1) end)
        button.tabBottom = button:CreateTexture(nil, "OVERLAY")
        button.tabBottom:SetPoint("BOTTOMLEFT", 1, 0)
        button.tabBottom:SetPoint("BOTTOMRIGHT", -1, 0)
        button.tabBottom:SetHeight(2)
        button.label:SetText(def.title)
        tabs.buttons[def.id] = button
    end
    -- Render the rule from a frame above every tab so button backdrops cannot
    -- replace it with a different bottom border or leave a gap.
    tabs.lineOverlay = CreateFrame("Frame", nil, tabs)
    tabs.lineOverlay:SetAllPoints(tabs)
    tabs.lineOverlay:SetFrameLevel(tabs:GetFrameLevel() + 20)
    tabs.lineOverlay.left = tabs.lineOverlay:CreateTexture(nil, "OVERLAY")
    Theme:ApplyPixelRule(tabs.lineOverlay.left, "horizontal", { color = { C.accent[1], C.accent[2], C.accent[3], 1 } })
    tabs.lineOverlay.right = tabs.lineOverlay:CreateTexture(nil, "OVERLAY")
    Theme:ApplyPixelRule(tabs.lineOverlay.right, "horizontal", { color = { C.accent[1], C.accent[2], C.accent[3], 1 } })
    tabs.lineOverlay.activeGap = tabs.lineOverlay:CreateTexture(nil, "OVERLAY")
    tabs.lineOverlay.activeGap:SetHeight(2)
    tabs.lineOverlay.activeGap:SetColorTexture(C.chrome[1], C.chrome[2], C.chrome[3], 1)
    -- The rule overlaps the active tab's 1px side border and the gap stays
    -- inside it, so both offsets are one physical pixel, not one UI unit.
    -- Core re-runs this after every pixel-size change; it reads the tab that
    -- is active at that time.
    local function AnchorActiveGeometry()
        local activeButton = tabs.activeButton
        local px = Theme:GetPixelSize(activeButton, 1)
        tabs.lineOverlay.left:ClearAllPoints()
        tabs.lineOverlay.left:SetPoint("BOTTOMLEFT", tabs, "BOTTOMLEFT", 0, 0)
        tabs.lineOverlay.left:SetPoint("BOTTOMRIGHT", activeButton, "BOTTOMLEFT", px, 0)
        tabs.lineOverlay.right:ClearAllPoints()
        tabs.lineOverlay.right:SetPoint("BOTTOMLEFT", activeButton, "BOTTOMRIGHT", -px, 0)
        tabs.lineOverlay.right:SetPoint("BOTTOMRIGHT", tabs, "BOTTOMRIGHT", 0, 0)
        tabs.lineOverlay.activeGap:ClearAllPoints()
        tabs.lineOverlay.activeGap:SetPoint("BOTTOMLEFT", activeButton, "BOTTOMLEFT", px, 0)
        tabs.lineOverlay.activeGap:SetPoint("BOTTOMRIGHT", activeButton, "BOTTOMRIGHT", -px, 0)
    end
    function tabs:SetActive(id)
        local activeButton
        for key, button in pairs(self.buttons) do
            button.active = key == id
            local active = button.active
            if active then activeButton = button end
            button:SetBackdropColor(active and C.chrome[1] or C.bg[1], active and C.chrome[2] or C.bg[2], active and C.chrome[3] or C.bg[3], 1)
            button:SetBackdropBorderColor(active and C.accent[1] or C.matrixLine[1], active and C.accent[2] or C.matrixLine[2], active and C.accent[3] or C.matrixLine[3], 1)
            button.label:SetTextColor(active and C.text[1] or C.muted[1], active and C.text[2] or C.muted[2], active and C.text[3] or C.muted[3])
            -- The rule is rendered above all tabs and remains continuous;
            -- active state is communicated by the tab's fill and outline.
            button.tabBottom:Hide()
        end
        self.activeButton = activeButton
        Theme:SetPixelAnchor(self, AnchorActiveGeometry)
        self.lineOverlay.left:Show()
        self.lineOverlay.right:Show()
        self.lineOverlay.activeGap:Show()
        self.leftBridge:Hide()
        self.rightBridge:Hide()
    end
    tabs:SetActive(active)
    return tabs
end

local function Text(parent, size, color, justify)
    return Theme:CreateText(parent, size or Theme.Font.body, color or C.text, justify or "LEFT")
end

local function CharacterInfo(key)
    local identity = YAB.GetCharacterIdentity(key)
    return YAB.FormatCharacterName(key, "current"), identity and identity.realm or "", identity and identity.class
end

local function CharacterColor(key)
    local _, _, class = CharacterInfo(key)
    local color = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    return color or C.text
end

local function Release(pool, start)
    for index = start or 1, #pool do pool[index]:Hide() end
end

local function HeaderCell(parent, x, width, title, secondary, inset)
    local header = Theme:CreateMatrixHeader(parent)
    header:SetWidth(width)
    header:SetPoint("TOPLEFT", x, 0)
    Theme:SetMatrixHeader(header, title, { secondary = secondary, inset = inset })
    return header
end

local function StatusCell(parent, index, x, column, charKey, definition, view, width, data)
    local cell = parent.cells[index] or CreateFrame("Button", nil, parent, "BackdropTemplate")
    parent.cells[index] = cell
    cell:Show()
    cell:SetSize(width, ROW_H)
    cell:SetPoint("TOPLEFT", x, 0)
    cell:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    -- Cells in one row touch horizontally (rows keep a 2-unit gap), so each
    -- cell owns its top, bottom and right edge and only the first draws left.
    Theme:CreatePixelBorder(cell, { color = C.matrixLine, sides = { top = true, right = true, bottom = true, left = index == 1 } })
    local status, label
    if data then status, label = data.status, data.label else status, label = view.status(charKey, column) end
    local color = status == "clear" and C.success or (status == "locked" or status == "progress") and C.accent or C.muted
    cell:SetBackdropColor(color[1] * 0.18, color[2] * 0.18, color[3] * 0.18, 0.95)
    cell.text = cell.text or Text(cell, Theme.Font.body, color, "CENTER")
    cell.text:SetAllPoints()
    cell.text:SetText(label)
    Theme:BindTooltip(cell, column.plannedCatalogID and column.name or nil, view.tooltip(charKey, column, parent.preview))
    if view.goalActions and Core.BusinessItemActions then Core.BusinessItemActions:Unbind(cell) end
    if view.goalActions and YAB.GoalTargets and YAB.GoalTargets.ref then
        if definition then YAB.GoalTargets:Bind(cell, charKey, { catalogID = definition.id, difficultyID = column.plannedDifficultyID or column.difficultyID, scope = "all", encounterIDs = {} }, nil, true) end
    end
    if view.activate then
        if not parent.preview and view.canActivate(charKey) then
            cell:SetScript("OnClick", function() view.activate(charKey, column) end)
        else
            cell:SetScript("OnClick", nil)
        end
    end
end

function YAB.CreateProgressPage(parent, view)
    parent:SetClipsChildren(true)
    parent.businessTabs = YAB.CreateBusinessTabs(parent, view.tab)
    parent.header = CreateFrame("Frame", nil, parent)
    parent.header:SetHeight(Theme.Table.headerHeight)
    parent.scroll = Theme:CreateScrollFrame(parent); parent.scroll:BindScrollbarGutter(parent.header)
    parent.body = CreateFrame("Frame", nil, parent.scroll); parent.scroll:SetScrollChild(parent.body)
    parent.headers, parent.rows = {}, {}
    if view.empty or view.compactEmpty then
        parent.empty = Text(parent.body, Theme.Font.body, C.muted)
        parent.empty:SetPoint("TOPLEFT", 6, -4)
    end
    return parent
end

function YAB.RefreshProgressPage(instance, context, view, compact)
    if not (context and context.preview and view.empty) then YAB.SetAccountBusinessPage(view.id) end
    local inset = Theme:GetMatrixInsets(context and context.preview)
    local keys = YAB.GetAccountCharacterKeys(context)
    local allColumns = compact and compact.columns or view.columns(context)
    local tableTop = TAB_H + (compact and compact.filterRowHeight or 0)
    instance.businessTabs:SetActive(view.tab)
    instance.header:ClearAllPoints()
    instance.header:SetPoint("TOPLEFT", inset.left, -tableTop)
    instance.header:SetPoint("TOPRIGHT", -inset.right, -tableTop)
    instance.body:ClearAllPoints()
    instance.scroll:ClearAllPoints(); instance.scroll:SetPoint("TOPLEFT", instance.header, "BOTTOMLEFT", 0, -Theme.Space.xs)
    instance.scroll:SetPoint("BOTTOMRIGHT", instance, "BOTTOMRIGHT", -inset.right, inset.bottom)
    instance.body:SetPoint("TOPLEFT", instance.scroll, "TOPLEFT", 0, 0)
    local characterTitle = Core.Locale:Get("YiboAltoBoss", "UI.CHARACTER")
    local availableWidth = math.max(
        1,
        Core.AccountView:GetScrollSurfaceWidth(context, instance, #keys * (ROW_H + 2),
            tableTop + Theme.Table.headerHeight + Theme.Space.xs + inset.bottom) - inset.left - inset.right
    )
    local columns, pageInfo, charWidth
    local widths, titles, values, names = {}, {}, {}, {}
    local cellInset = compact and Theme.Geometry.compactColumnInset
    if compact then
        for index, key in ipairs(keys) do
            names[index] = YAB.FormatCharacterName(key, context.scope == "all" and "all" or "current")
        end
        charWidth = Theme:GetCompactColumnWidth(characterTitle, names)
        local widest = 0
        for _, column in ipairs(allColumns) do
            local samples, byCharacter = {}, {}
            local title = compact.title(column)
            for index, key in ipairs(keys) do
                local status, label = view.status(key, column)
                label = compact.label(status, label)
                samples[index], byCharacter[key] = label, { status = status, label = label }
            end
            local width = Theme:GetCompactColumnWidth(title, samples)
            widths[column], titles[column], values[column] = width, title, byCharacter
            widest = math.max(widest, width)
        end
        charWidth = math.min(charWidth, math.max(1, availableWidth - widest))
        for column, width in pairs(widths) do widths[column] = math.min(width, math.max(1, availableWidth - charWidth)) end
        columns, pageInfo = Core.AccountView:GetColumnPageByWidth(
            view.id, compact.pageKey, allColumns, availableWidth, charWidth, function(column) return widths[column] end
        )
    else
        charWidth = math.max(150, Theme:MeasureText(Theme.Font.body, characterTitle) + Theme.Space.lg * 2)
        columns, pageInfo = Core.AccountView:GetColumnPage(view.id, "instances", allColumns, availableWidth, charWidth, CELL_W)
    end
    local definitions = {}
    if view.goalActions and #keys > 0 and #columns > 0 and YAB.GoalTargets and YAB.GoalTargets.ref then
        local targets = YAB.TargetCatalog:Query().targets
        for index, column in ipairs(columns) do
            for _, definition in ipairs(targets) do
                if definition.kind == "instance" and (definition.id == column.plannedCatalogID
                    or definition.mapID and definition.mapID == column.instanceID) then
                    definitions[index] = definition
                    break
                end
            end
        end
    end
    -- Pagination shares the tab row so no separate status strip interrupts
    -- the active tab's connection to the matrix header.
    Core.AccountView:UpdateColumnPager(instance, view.id, compact and compact.pageKey or "instances", pageInfo, instance.businessTabs, view.title())
    Release(instance.headers)
    local compactEmpty = compact and #allColumns == 0
    local empty = compactEmpty or view.empty and (#allColumns == 0 or #keys == 0)
    if instance.empty then
        instance.empty:SetText(compactEmpty and view.compactEmpty() or empty and view.empty(#allColumns == 0, context) or "")
        instance.empty:SetShown(empty == true)
        instance.empty:SetWidth(math.max(1, availableWidth - 12))
    end
    if not empty then
        instance.headers[1] = HeaderCell(instance.header, 0, charWidth, characterTitle, nil, cellInset)
    end
    local offsets, tableWidth = {}, charWidth
    for index, column in ipairs(empty and {} or columns) do
        local abbreviation = column.abbreviation or (view.tab == "lockouts" and "INST")
        local header = HeaderCell(
            instance.header,
            tableWidth,
            widths[column] or CELL_W,
            titles[column] or column.shortName or column.name,
            not compact and abbreviation and ("(" .. abbreviation .. ")") or nil,
            cellInset
        )
        offsets[index] = tableWidth
        tableWidth = tableWidth + (widths[column] or CELL_W)
        Theme:BindTooltip(header, abbreviation and string.format("%s (%s)", column.name, abbreviation) or column.name)
        instance.headers[index + 1] = header
    end
    local y = 0
    Release(instance.rows)
    for rowIndex, charKey in ipairs(empty and {} or keys) do
        local row = instance.rows[rowIndex] or CreateFrame("Frame", nil, instance.body)
        instance.rows[rowIndex] = row
        row:Show()
        row:SetHeight(ROW_H)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -y)
        row:SetPoint("TOPRIGHT", 0, -y)
        row.cells = row.cells or {}
        row.preview = context and context.preview
        local name = names[rowIndex] or YAB.FormatCharacterName(charKey, context and context.scope == "all" and "all" or "current")
        row.label = row.label or Text(row, Theme.Font.body, C.text, "LEFT")
        row.label:ClearAllPoints()
        row.label:SetPoint("LEFT", cellInset or Theme.Table.cellPadding, 0)
        row.label:SetWidth(math.max(1, charWidth - (cellInset or Theme.Table.cellPadding) * 2))
        row.label:SetText(name)
        if compact then
            row:EnableMouse(true)
            Theme:BindTooltip(row, name)
        elseif row.tooltipTitle then
            row:EnableMouse(false)
            Theme:ClearTooltip(row)
        end
        local color = CharacterColor(charKey)
        row.label:SetTextColor(color.r or color[1], color.g or color[2], color.b or color[3])
        for index, column in ipairs(columns) do
            StatusCell(row, index, offsets[index], column, charKey, definitions[index], view,
                widths[column] or CELL_W, values[column] and values[column][charKey])
        end
        Release(row.cells, #columns + 1)
        y = y + ROW_H + 2
    end
    if empty then y = ROW_H end
    Release(instance.rows, (empty and 0 or #keys) + 1)
    instance.body:SetSize(math.max(1, tableWidth), math.max(1, y))
    instance.scroll:SetContentHeight(math.max(1, y)); instance.scroll:RefreshScrollbar()
    instance.renderedContentHeight = tableTop + Theme.Table.headerHeight
        + Theme.Space.xs + math.max(1, y) + inset.bottom
end

function YAB.GetProgressSurfaceMetrics(context, view)
    local columns = view.columns(context)
    local keys = YAB.GetAccountCharacterKeys(context)
    local inset = Theme:GetMatrixInsets(context and context.preview)
    local empty = view.empty and (#columns == 0 or #keys == 0)
    local charWidth = empty and 340 or 150
    local columnCount = empty and 0 or #columns
    local height = TAB_H + Theme.Table.headerHeight + Theme.Space.xs
        + math.max(1, #keys) * (ROW_H + 2) + inset.bottom
    return {
        naturalContentWidth = inset.left + charWidth + columnCount * CELL_W + inset.right,
        minContentWidth = inset.left + charWidth + math.min(1, columnCount) * CELL_W + inset.right,
        naturalContentHeight = height,
        minContentHeight = TAB_H + Theme.Table.headerHeight + Theme.Space.xs + ROW_H + inset.bottom,
        scrollContentHeight = #keys * (ROW_H + 2),
        scrollFixedHeight = TAB_H + Theme.Table.headerHeight + Theme.Space.xs + inset.bottom,
        fixedTopHeight = TAB_H,
        horizontalOverflow = "paginate",
        verticalOverflow = "content",
    }
end

-- Core calls this after the page has rendered.  Keeping the measurement in
-- the page makes the window height follow the actual character-row matrix,
-- including rows that were filtered or added after the first layout pass.
function YAB.GetProgressMeasuredHeight(instance, context, view)
    if instance and instance.renderedContentHeight then return instance.renderedContentHeight end
    return YAB.GetProgressSurfaceMetrics(context, view).naturalContentHeight
end

function YAB.GetProgressHoverMetrics(context, view)
    local metrics = YAB.GetProgressSurfaceMetrics(context, view)
    return {
        minWidth = metrics.minContentWidth + Theme.Geometry.shellBorder * 2,
        preferredWidth = metrics.naturalContentWidth + Theme.Geometry.shellBorder * 2,
        minHeight = metrics.minContentHeight + Theme.Geometry.titleBar + Theme.Geometry.shellBorder * 2,
        preferredHeight = metrics.naturalContentHeight + Theme.Geometry.titleBar + Theme.Geometry.shellBorder * 2,
        scrollContentHeight = metrics.scrollContentHeight, scrollFixedHeight = metrics.scrollFixedHeight,
        horizontalOverflow = "paginate",
        verticalOverflow = "content",
    }
end
