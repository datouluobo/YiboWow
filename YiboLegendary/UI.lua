local Addon = _G.YiboLegendary
local UI = {}
Addon.UI = UI
local Theme = _G.YiboCore.UITheme
local C = Theme.Colors
local FormatNumber = BreakUpLargeNumbers or tostring

local STATUS = { completed = "已完成", in_progress = "进行中", available = "可接取", locked = "未解锁", unavailable = "阶段未开放" }
local STATUS_COLORS = {
    completed = { 0.22, 0.88, 0.48 },
    in_progress = { 1, 0.78, 0.34 },
    available = { 0.36, 0.9, 0.88 },
    locked = { 0.56, 0.64, 0.69 },
    unavailable = { 1, 0.48, 0.5 },
}

local ROW_HEIGHT = Theme.Table.rowHeight
-- A preview shell and its anchored table pass through UI-scale rounding.
-- Keep one small track of slack so columns whose measured sum exactly matches
-- the shell do not become a false extra page after that rounding.
local HOVER_LAYOUT_SLACK = Theme.Space.xs
-- The full account page should present its enabled business fields together.
-- Reserve the scrollbar gutter in its natural-width contract so all tracks
-- still fit after a long roster makes the vertical bar visible.
local MAIN_LAYOUT_SLACK = Theme.Geometry.scrollbarGutter
-- The compact summary line needs a little extra room for the shared 12px
-- assist style.  Keep that breathing room in the surface contract so a
-- mathematically exact 12-row page does not grow a false scrollbar and lose
-- a whole data column to its gutter.
local SUMMARY_LINE_HEIGHT = Theme.Font.assist + Theme.Space.xxs
-- A matrix column owns a track plus this documented inner padding on both
-- sides.  The same track value is used for header, body and sizing metrics.
local CELL_INSET = Theme.Table.cellInset
local CELL_PADDING = Theme.Table.cellPadding
-- Hover is a compact projection.  Keep its semantic first column readable,
-- then share whatever remains between enabled preview fields before asking
-- the common Core pager whether an unusually narrow screen still overflows.
local COLUMNS = {
    { id = "character", key = "character", title = "角色", width = 160, minWidth = 140, previewMinWidth = 160, previewMaxWidth = 210, defaultVisible = true },
    { id = "task", key = "task", title = "当前任务", width = 160, minWidth = 140, previewMinWidth = 150, previewMaxWidth = 220, defaultVisible = false },
    { id = "objective", key = "objective", title = "目标", width = 300, minWidth = 230, previewMinWidth = 180, previewMaxWidth = 360, defaultVisible = true },
    { id = "action", key = "action", title = "行动", width = 190, minWidth = 160, previewMinWidth = 180, previewMaxWidth = 320, defaultVisible = false },
}

local function CurrentSnapshot()
    local store = Addon:GetCharacterStore()
    return store and store.snapshot
end

local function CharacterLabel(character)
    return (character.name or "未知角色") .. "-" .. (character.realm or "未知服务器")
end

local function IsEligibleCharacter(character)
    return (character.level or 0) >= 90
end

local function SetTextColor(fontString, color)
    fontString:SetTextColor(color[1], color[2], color[3])
end

local function TooltipLine(text, color, wrap)
    return { text = text, color = color, wrap = wrap ~= false }
end

local function EstimateTextWidth(text)
    text = tostring(text or "")
    local width, index = 0, 1
    while index <= #text do
        local byte = text:byte(index)
        if byte < 0x80 then
            width = width + 7
            index = index + 1
        elseif byte < 0xE0 then
            width = width + 12
            index = index + 2
        elseif byte < 0xF0 then
            width = width + 12
            index = index + 3
        else
            width = width + 12
            index = index + 4
        end
    end
    return width
end

local function CurrentDefinition(current)
    return Addon.Data.byID[current.definitionId] or current.definition or {}
end

local function ObjectiveText(snapshot, current)
    local definition = CurrentDefinition(current)
    local objective
    if definition.valor then
        -- Always own this target's display.  Some Classic clients expose the
        -- task as available before their quest-log API resolves it, but the
        -- current task row must still show the cumulative 1,600-point target.
        objective = string.format("累计获得勇气点数%d/%d", tonumber(current.valorProgress) or 0, Addon.Data.VALOR_TARGET)
    else
        objective = current.log and #current.log.objectives > 0 and table.concat(current.log.objectives, "；")
            or (definition.objectiveByFaction and definition.objectiveByFaction[snapshot and snapshot.faction])
            or definition.objective
    end
    local reputationTarget = snapshot and snapshot.reputationTarget
    if reputationTarget then
        local reputation = snapshot.reputation
        local label = reputation and reputation.name or "黑王子"
        local currentRank = reputation and Addon.Data.REPUTATION_LABELS[reputation.rank] or "未查询"
        local targetRank = Addon.Data.REPUTATION_RANKS[reputationTarget.definition.reputation]
        local targetLabel = Addon.Data.REPUTATION_LABELS[targetRank] or "目标等级"
        local progress = string.format("%s：%s→%s", label, currentRank, targetLabel)
        if progress then objective = objective .. "；" .. progress end
    end
    return objective
end

local function TaskName(current)
    local definition = CurrentDefinition(current)
    return (current.log and current.log.title) or definition.name or "未知任务"
end

local function ClassColor(character)
    local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[character.class or ""]
    if color then
        return color.r, color.g, color.b
    end
    return 0.92, 0.96, 0.98
end

function UI:GetEligibleCharacters(characters)
    local eligible = {}
    for _, character in ipairs(characters or Addon.Core.Characters:GetAll()) do
        local store = Addon.db.byCharacter[character.id]
        if IsEligibleCharacter(character) and store and store.snapshot then
            eligible[#eligible + 1] = character
        end
    end
    return eligible
end

function UI:GetVisibleCharacters(characters)
    local visible = {}
    for _, character in ipairs(self:GetEligibleCharacters(characters)) do
        local store = Addon.db.byCharacter[character.id]
        visible[#visible + 1] = { character = character, snapshot = store.snapshot }
    end
    return visible
end

function UI:CreateText(parent, template, width, size)
    local text = parent:CreateFontString(nil, "OVERLAY", template)
    Theme:ApplyTextStyle(text, size or (template == "GameFontNormalLarge" and Theme.Font.title or Theme.Font.assist))
    text:SetJustifyH("LEFT")
    text:SetJustifyV("MIDDLE")
    text:SetWordWrap(false)
    text:SetWidth(width)
    return text
end

function UI:CreateHeader(parent)
    local header = CreateFrame("Frame", nil, parent)
    header:SetHeight(ROW_HEIGHT)
    header:SetPoint("TOPLEFT", Theme.Space.lg, -52)
    header:SetPoint("TOPRIGHT", -Theme.Space.lg, -52)
    header.bg = header:CreateTexture(nil, "BACKGROUND")
    header.bg:SetAllPoints(header)
    header.bg:SetColorTexture(C.chrome[1], C.chrome[2], C.chrome[3], 0.96)
    header.cells = {}
    local offset = CELL_INSET
    for _, column in ipairs(COLUMNS) do
        local text = self:CreateText(header, "GameFontNormalSmall", column.width - CELL_PADDING, Theme.Font.assist)
        text:SetPoint("LEFT", offset, 0)
        text:SetText(column.title)
        text:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
        header.cells[column.key] = text
        offset = offset + column.width
    end
    return header
end

function UI:CreateAccountPage(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints(parent)
    frame.summary = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    Theme:ApplyTextStyle(frame.summary, Theme.Font.assist)
    frame.summary:SetPoint("TOPLEFT", Theme.Space.lg, -Theme.Space.md)
    frame.summary:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
    frame.header = self:CreateHeader(frame)

    frame.scroll = Theme:CreateScrollFrame(frame)
    frame.scroll:SetPoint("TOPLEFT", Theme.Space.lg, -88)
    frame.scroll:SetPoint("BOTTOMRIGHT", -Theme.Space.lg, Theme.Space.md)
    frame.content = CreateFrame("Frame", nil, frame.scroll)
    frame.content:SetWidth(1)
    frame.scroll:SetScrollChild(frame.content)
    frame.scroll:HookScript("OnSizeChanged", function()
        if UI.details == frame and UI.accountContext then UI:ApplyColumnLayout() end
    end)
    frame.rows = {}
    self.details = frame
end

function UI:CreateRow(index)
    local frame = self.details
    local row = CreateFrame("Button", nil, frame.content)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 0, -((index - 1) * ROW_HEIGHT))
    row:SetPoint("TOPRIGHT", 0, -((index - 1) * ROW_HEIGHT))
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints(row)
    row.divider = row:CreateTexture(nil, "BORDER")
    row.divider:SetPoint("BOTTOMLEFT")
    row.divider:SetPoint("BOTTOMRIGHT")
    row.divider:SetHeight(1)
    row.divider:SetColorTexture(C.line[1], C.line[2], C.line[3], C.lineSoft[4])
    row.currentBorder = {}
    for _, edge in ipairs({ "top", "bottom", "left", "right" }) do
        local line = row:CreateTexture(nil, "BORDER")
        line:SetColorTexture(C.line[1], C.line[2], C.line[3], 0.82)
        row.currentBorder[edge] = line
    end
    row.currentBorder.top:SetPoint("TOPLEFT"); row.currentBorder.top:SetPoint("TOPRIGHT"); row.currentBorder.top:SetHeight(1)
    row.currentBorder.bottom:SetPoint("BOTTOMLEFT"); row.currentBorder.bottom:SetPoint("BOTTOMRIGHT"); row.currentBorder.bottom:SetHeight(1)
    row.currentBorder.left:SetPoint("TOPLEFT"); row.currentBorder.left:SetPoint("BOTTOMLEFT"); row.currentBorder.left:SetWidth(1)
    row.currentBorder.right:SetPoint("TOPRIGHT"); row.currentBorder.right:SetPoint("BOTTOMRIGHT"); row.currentBorder.right:SetWidth(1)
    row.cells = {}
    for _, column in ipairs(COLUMNS) do
        local text = self:CreateText(row, "GameFontNormalSmall", column.width - CELL_PADDING, Theme.Font.body)
        text:SetPoint("LEFT", CELL_INSET, 0)
        row.cells[column.key] = text
    end
    Theme:BindTooltip(row, nil, row.tooltipLines or {})
    frame.rows[index] = row
    return row
end

function UI:IsConfiguredColumnVisible(column)
    return not self.accountContext or self.accountContext:GetFieldVisible(column)
end

function UI:IsColumnVisible(column)
    if self.renderColumns then return self.renderColumns[column.id] == true end
    return self:IsConfiguredColumnVisible(column)
end

function UI:GetNaturalColumnWidths()
    local frame = self.details
    local widths = {}
    for _, column in ipairs(COLUMNS) do
        if self:IsConfiguredColumnVisible(column) then
            local width = EstimateTextWidth(column.title) + CELL_PADDING
            local headerCell = frame and frame.header and frame.header.cells[column.key]
            if headerCell and headerCell.GetStringWidth then width = math.max(width, headerCell:GetStringWidth() + CELL_PADDING) end
            for _, row in ipairs((frame and frame.rows) or {}) do
                local cell = row.cells[column.key]
                if row:IsShown() and cell and cell.GetStringWidth then width = math.max(width, cell:GetStringWidth() + CELL_PADDING) end
            end
            -- Row text must never decide a column's layout width.  In
            -- particular, a long current-task name used to consume an entire
            -- horizontal page and push the objective onto the next page.
            widths[column.id] = math.max(column.minWidth or 40, math.min(column.width or math.huge, math.ceil(width)))
        end
    end
    return widths
end

function UI:GetEstimatedColumnWidths(context, preview)
    local widths = {}
    for _, column in ipairs(COLUMNS) do
        if context:GetFieldVisible(column.id) then
            local minimum = preview and column.previewMinWidth or column.minWidth or 40
            local maximum = preview and column.previewMaxWidth or column.width or math.huge
            widths[column.id] = math.max(minimum, math.min(maximum, EstimateTextWidth(column.title) + CELL_PADDING))
        end
    end
    for _, item in ipairs(self:GetVisibleCharacters(context and context.characters)) do
        local snapshot, current = item.snapshot, item.snapshot.current
        local values = {
            character = CharacterLabel(item.character),
            task = current and TaskName(current) or "尚无可确定的下一任务",
            objective = current and ObjectiveText(snapshot, current) or "检查前置任务、声望或服务器阶段",
            action = current and Addon.Data:GetTableAction(current) or "等待条件满足",
        }
        if snapshot.readable == false then
            values.task = "无法读取任务完成状态"
            values.objective = "执行 /yle probe 检查客户端 API"
            values.action = "等待兼容性确认"
        elseif snapshot.completed then
            values.task = "传说披风任务线"
            values.objective = "已完成"
            values.action = "—"
        end
        for _, column in ipairs(COLUMNS) do
            if widths[column.id] and values[column.id] then
                local maximum = preview and column.previewMaxWidth or column.width or math.huge
                widths[column.id] = math.max(widths[column.id], math.min(maximum, EstimateTextWidth(values[column.id]) + CELL_PADDING))
            end
        end
    end
    return widths
end

function UI:ApplyColumnLayout()
    local frame = self.details
    local compactProjection = self.accountContext and self.accountContext.preview == true
    local inset = Theme:GetMatrixInsets(compactProjection)
    local measuredViewportWidth = frame.scroll:GetWidth() or 0
    -- ScrollFrame can retain its former scroll-child width for one or more
    -- layout passes.  The page frame is the authoritative surface: its two
    -- directional insets are exactly the anchors used by this table.
    -- Prefer that settled width whenever it is available, so neither a normal
    -- page nor a hover preview creates phantom field pages from stale width.
    local settledViewportWidth = (frame:GetWidth() or 0) - inset.left - inset.right
    local viewportWidth = settledViewportWidth > 1 and settledViewportWidth or measuredViewportWidth
    if viewportWidth <= 1 then return end
    local contentHeight = 0
    for _, row in ipairs(frame.rows or {}) do if row:IsShown() then contentHeight = contentHeight + ROW_HEIGHT end end
    -- Reserve the shared scrollbar gutter only when this exact table really
    -- overflows vertically.  A hidden scrollbar never consumes a field's
    -- width budget or creates an avoidable compact-preview page.
    local scrollbarGutter = contentHeight > (frame.scroll:GetHeight() or 0) and Theme.Geometry.scrollbarGutter or 0
    -- The scrollbar occupies Core's 16px gutter inside this viewport.  The
    -- remaining budget contains both matrix cell insets and column tracks.
    local columnBudget = math.max(1, viewportWidth - scrollbarGutter - CELL_PADDING)
    local naturalWidths = compactProjection and self:GetEstimatedColumnWidths(self.accountContext, true) or self:GetNaturalColumnWidths()
    local function ColumnWidth(column)
        if compactProjection then return naturalWidths[column.id] or column.previewMinWidth or column.minWidth or 40 end
        return math.max(column.minWidth or 40, naturalWidths[column.id] or column.width or 40)
    end
    local configuredColumns = {}
    for _, column in ipairs(COLUMNS) do
        if self:IsConfiguredColumnVisible(column) then
            configuredColumns[#configuredColumns + 1] = column
        end
    end
    local fixedColumns, pageableColumns = {}, {}
    for _, column in ipairs(configuredColumns) do
        if column.id == "character" then fixedColumns[#fixedColumns + 1] = column else pageableColumns[#pageableColumns + 1] = column end
    end
    local fixedWidth = 0
    for _, column in ipairs(fixedColumns) do fixedWidth = fixedWidth + ColumnWidth(column) end
    local function FieldWidth(column)
        return ColumnWidth(column)
    end
    local visiblePage, pageInfo
    if not compactProjection then
        -- A main window is allowed to grow and must compare every enabled
        -- business field side by side.  Its surface metrics include the
        -- necessary gutter above; only a compact hover may field-page.
        visiblePage = pageableColumns
        pageInfo = { page = 1, pages = 1, first = 1, last = #pageableColumns, total = #pageableColumns }
    else
        -- Hover tracks use their own content-aware bounds.  Paginate only if
        -- the safe screen area genuinely cannot contain that projection.
        visiblePage, pageInfo = Addon.Core.AccountView:GetColumnPageByWidth("legendary", "fields", pageableColumns, columnBudget, fixedWidth, FieldWidth)
    end
    if compactProjection and pageInfo.pages > 1 then
        local pagerWidth = Addon.Core.AccountView:GetColumnPagerWidth("字段", #pageableColumns)
        visiblePage, pageInfo = Addon.Core.AccountView:GetColumnPageByWidth("legendary", "fields", pageableColumns, math.max(1, columnBudget - pagerWidth), fixedWidth, FieldWidth)
    end
    local visibleColumns = {}
    for _, column in ipairs(fixedColumns) do visibleColumns[#visibleColumns + 1] = column end
    for _, column in ipairs(visiblePage) do visibleColumns[#visibleColumns + 1] = column end
    Addon.Core.AccountView:UpdateColumnPager(frame, "legendary", "fields", pageInfo, frame.header, "字段")

    self.renderColumns = {}
    for _, column in ipairs(visibleColumns) do self.renderColumns[column.id] = true end
    local usedWidth = 0
    for _, column in ipairs(visibleColumns) do
        column.yiboWidth = ColumnWidth(column)
        usedWidth = usedWidth + column.yiboWidth
    end
    -- The pager already explains which fields are on this page.  Fill the
    -- final visible track even on a paged result; otherwise a one-field last
    -- page looks like missing content and leaves most of the matrix blank.
    if #visibleColumns > 0 and usedWidth < columnBudget then
        visibleColumns[#visibleColumns].yiboWidth = visibleColumns[#visibleColumns].yiboWidth + (columnBudget - usedWidth)
    end
    local offset = CELL_INSET
    for _, column in ipairs(COLUMNS) do
        local visible = self:IsColumnVisible(column)
        local headerCell = frame.header.cells[column.key]
        headerCell:SetShown(visible)
        if visible then
            local width = column.yiboWidth
            headerCell:ClearAllPoints()
            headerCell:SetPoint("LEFT", offset, 0)
            headerCell:SetWidth(math.max(1, width - CELL_PADDING))
        end
        for _, row in ipairs(frame.rows) do
            local cell = row.cells[column.key]
            cell:SetShown(visible)
            if visible then
                local width = column.yiboWidth
                cell:ClearAllPoints()
                cell:SetPoint("LEFT", offset, 0)
                cell:SetWidth(math.max(1, width - CELL_PADDING))
            end
        end
        if visible then offset = offset + column.yiboWidth end
    end
    -- If an actual vertical bar is present, its gutter belongs to the
    -- viewport rather than the final data cell.  Normal views retain only
    -- their standard right inset.
    local contentWidth = math.max(1, offset + CELL_INSET)
    frame.content:SetWidth(contentWidth)
end

function UI:UpdateRow(row, character, snapshot, currentCharacter, index)
    row.character, row.snapshot = character, snapshot
    local current = snapshot.current
    local isCurrent = currentCharacter and character.id == currentCharacter.id
    if isCurrent then
        row.bg:SetColorTexture(C.current[1], C.current[2], C.current[3], 0.72)
    elseif index % 2 == 0 then
        row.bg:SetColorTexture(C.alternate[1], C.alternate[2], C.alternate[3], C.alternate[4])
    else
        row.bg:SetColorTexture(C.row[1], C.row[2], C.row[3], C.row[4])
    end
    for _, line in pairs(row.currentBorder) do line:SetShown(isCurrent) end
    local red, green, blue = ClassColor(character)
    row.cells.character:SetText((isCurrent and "● " or "") .. CharacterLabel(character))
    row.cells.character:SetTextColor(red, green, blue)
    row.tooltipLines = { TooltipLine(CharacterLabel(character), { red, green, blue }) }
    if snapshot.readable == false then
        row.cells.task:SetText("无法读取任务完成状态")
        row.cells.objective:SetText("执行 /yle probe 检查客户端 API")
        row.cells.action:SetText("等待兼容性确认")
        row.tooltipLines[#row.tooltipLines + 1] = TooltipLine("任务状态：无法读取；请执行 /yle probe", { 1, 0.48, 0.5 })
        for _, key in ipairs({ "task", "objective", "action" }) do row.cells[key]:SetTextColor(1, 0.48, 0.5) end
        return
    end
    if snapshot.completed then
        row.cells.task:SetText("传说披风任务线")
        row.cells.objective:SetText("已完成")
        row.cells.action:SetText("—")
        row.tooltipLines[#row.tooltipLines + 1] = TooltipLine("状态：已完成", { 0.22, 0.88, 0.48 })
        for _, key in ipairs({ "task", "objective", "action" }) do row.cells[key]:SetTextColor(0.22, 0.88, 0.48) end
        return
    end
    if not current then
        row.cells.task:SetText("尚无可确定的下一任务")
        row.cells.objective:SetText("检查前置任务、声望或服务器阶段")
        row.cells.action:SetText("等待条件满足")
        row.tooltipLines[#row.tooltipLines + 1] = TooltipLine("状态：尚无可确定的下一任务", { 0.56, 0.64, 0.69 })
        for _, key in ipairs({ "task", "objective", "action" }) do row.cells[key]:SetTextColor(0.56, 0.64, 0.69) end
        return
    end
    local statusColor = STATUS_COLORS[current.status] or STATUS_COLORS.locked
    row.cells.task:SetText(TaskName(current))
    row.cells.task:SetTextColor(0.92, 0.96, 0.98)
    local definition = CurrentDefinition(current)
    if definition.valor then
        local value = tostring(tonumber(current.valorProgress) or 0)
        -- FontString has no stable per-span weight support across Classic
        -- clients.  Use its native inline color markup instead of separate
        -- overlapping FontStrings, which can be clipped after a re-layout.
        row.cells.objective:SetText(string.format("累计获得勇气点数 |cff20e070%s|r|cffc2dbe0/%d|r", value, Addon.Data.VALOR_TARGET))
        row.cells.objective:SetTextColor(0.76, 0.86, 0.88)
    else
        row.cells.objective:SetText(ObjectiveText(snapshot, current))
        row.cells.objective:SetTextColor(0.76, 0.86, 0.88)
    end
    row.cells.action:SetText(Addon.Data:GetTableAction(current))
    row.cells.action:SetTextColor(0.36, 0.9, 0.88)
    row.tooltipLines[#row.tooltipLines + 1] = TooltipLine("状态：" .. (STATUS[current.status] or "未知"), statusColor)
    row.tooltipLines[#row.tooltipLines + 1] = TooltipLine("任务：" .. TaskName(current), { 0.92, 0.96, 0.98 })
    row.tooltipLines[#row.tooltipLines + 1] = TooltipLine("目标：" .. ObjectiveText(snapshot, current), { 0.76, 0.86, 0.88 })
    row.tooltipLines[#row.tooltipLines + 1] = TooltipLine("行动：" .. Addon.Data:GetTableAction(current), { 0.36, 0.9, 0.88 })
end

function UI:RefreshDetails(context)
    local frame = self.details
    if not frame then return end
    local previousScroll = frame.scroll:GetVerticalScroll() or 0
    self.accountContext = context
    local inset = Theme:GetMatrixInsets(context and context.preview)
    frame.header:ClearAllPoints()
    -- The summary is the only fixed page element.  Anchor the table to it so
    -- a hidden or resized summary can never leave the historical 52px gap.
    frame.header:SetPoint("TOPLEFT", frame.summary, "BOTTOMLEFT", 0, -Theme.Space.md)
    frame.header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -inset.right, 0)
    frame.scroll:ClearAllPoints()
    frame.scroll:SetPoint("TOPLEFT", frame.header, "BOTTOMLEFT", 0, -Theme.Space.xs)
    frame.scroll:SetPoint("BOTTOMRIGHT", -inset.right, inset.bottom)
    frame.summary:ClearAllPoints()
    frame.summary:SetPoint("TOPLEFT", frame, "TOPLEFT", inset.left, -inset.top)
    local currentCharacter = Addon.Core.Characters:GetCurrent()
    local visible = self:GetVisibleCharacters(context and context.characters)
    for index, item in ipairs(visible) do
        local row = frame.rows[index] or self:CreateRow(index)
        self:UpdateRow(row, item.character, item.snapshot, currentCharacter, index)
        row:Show()
    end
    for index = #visible + 1, #frame.rows do frame.rows[index]:Hide() end
    self:ApplyColumnLayout()
    local contentHeight = #visible * ROW_HEIGHT
    frame.content:SetHeight(math.max(1, contentHeight))
    frame.scroll:SetContentHeight(frame.content:GetHeight())
    local viewportHeight = frame.scroll:GetHeight() or 0
    frame.scroll:SetVerticalScroll(math.min(previousScroll, math.max(0, contentHeight - viewportHeight)))
    frame.scroll:RefreshScrollbar()
    frame.summary:SetText(string.format("已同步角色：|cff20e070%d|r    悬停行可查看完整文本", #visible))

    -- ShowPreview sizes the shell before this page instance exists.  WoW may
    -- therefore report its ScrollFrame width one layout pass late.  Reflow in
    -- the next frame with the settled viewport, so the Core pager receives
    -- the actual width rather than preserving an erroneous first-page split.
    if C_Timer and C_Timer.After and not frame.yiboLegendaryReflowQueued then
        frame.yiboLegendaryReflowQueued = true
        local refreshContext = context
        C_Timer.After(0, function()
            frame.yiboLegendaryReflowQueued = nil
            if UI.details == frame and UI.accountContext == refreshContext and frame:IsShown() then
                UI:ApplyColumnLayout()
            end
        end)
    end
end

function UI:ToggleDetails()
    Addon.Core.AccountView:Toggle("legendary")
end

function UI:GetPreviewColumns()
    return Addon.db and Addon.db.settings and Addon.db.settings.previewColumns or nil
end

function UI:SetPreviewFieldVisible(fieldID, visible)
    Addon.db.settings.previewColumns = Addon.db.settings.previewColumns or {}
    Addon.db.settings.previewColumns[fieldID] = not not visible
    if Addon.Core.AccountView then Addon.Core.AccountView:RefreshPage() end
end

function UI:GetPreviewSize(context)
    local metrics = self:GetSurfaceMetrics(context)
    return metrics.naturalContentWidth + Theme.Geometry.shellBorder * 2,
        metrics.naturalContentHeight + Theme.Geometry.titleBar + Theme.Geometry.shellBorder * 2
end

function UI:GetLayoutMetrics(context)
    local metrics = self:GetSurfaceMetrics(context)
    local geometry = Theme.Geometry
    local shellWidth = geometry.navigation + geometry.shellBorder * 2 + 1
    local shellHeight = geometry.titleBar + geometry.shellBorder * 2
    return {
        minWidth = metrics.minContentWidth + shellWidth,
        preferredWidth = metrics.naturalContentWidth + shellWidth,
        minHeight = metrics.minContentHeight + shellHeight,
        preferredHeight = metrics.naturalContentHeight + shellHeight,
        horizontalOverflow = metrics.horizontalOverflow,
        verticalOverflow = metrics.verticalOverflow,
    }
end

function UI:GetHoverMetrics(context)
    local metrics = self:GetSurfaceMetrics(context)
    return {
        minWidth = metrics.minContentWidth + Theme.Geometry.shellBorder * 2,
        preferredWidth = metrics.naturalContentWidth + Theme.Geometry.shellBorder * 2,
        minHeight = metrics.minContentHeight + Theme.Geometry.titleBar + Theme.Geometry.shellBorder * 2,
        preferredHeight = metrics.naturalContentHeight + Theme.Geometry.titleBar + Theme.Geometry.shellBorder * 2,
        horizontalOverflow = metrics.horizontalOverflow,
        verticalOverflow = metrics.verticalOverflow,
    }
end

function UI:GetSurfaceMetrics(context)
    local preview = context and context.preview == true
    local widths = self:GetEstimatedColumnWidths(context, preview)
    local width, minimumWidth, rows = 0, 0, #self:GetVisibleCharacters(context and context.characters)
    for _, column in ipairs(COLUMNS) do
        if context:GetFieldVisible(column.id) then
            if preview then
                -- Hover columns intentionally follow their own content-aware
                -- bounds.  Objectives and actions need more room than a task
                -- title; equal-width tracks were compact but unreadable.
                width = width + (widths[column.id] or column.previewMinWidth or column.minWidth or 40)
                minimumWidth = minimumWidth + (column.previewMinWidth or column.minWidth or 40)
            else
                width = width + (widths[column.id] or column.minWidth or 40)
                minimumWidth = minimumWidth + (column.minWidth or 40)
            end
        end
    end
    local inset = Theme:GetMatrixInsets(context.preview)
    local layoutSlack = preview and HOVER_LAYOUT_SLACK or MAIN_LAYOUT_SLACK
    -- Surface metrics describe the complete matrix: external directional
    -- insets plus the documented left/right cell insets around its tracks.
    -- Hover reserves a compact gap for UI-scale rounding; the full page
    -- reserves its scrollbar gutter so all enabled fields stay side by side.
    -- The layout fills either reserve into the final visible column.
    local naturalWidth = width + CELL_PADDING + inset.left + inset.right + layoutSlack
    if context and context.surfaceAvailableWidth then naturalWidth = math.min(naturalWidth, context.surfaceAvailableWidth) end
    return {
        minContentWidth = minimumWidth + CELL_PADDING + inset.left + inset.right + layoutSlack,
        naturalContentWidth = naturalWidth,
        minContentHeight = inset.top + SUMMARY_LINE_HEIGHT + Theme.Space.md + ROW_HEIGHT + Theme.Space.xs + ROW_HEIGHT + inset.bottom,
        naturalContentHeight = inset.top + SUMMARY_LINE_HEIGHT + Theme.Space.md + ROW_HEIGHT + Theme.Space.xs + rows * ROW_HEIGHT + inset.bottom,
        fixedLeftWidth = (preview and COLUMNS[1].previewMinWidth or COLUMNS[1].minWidth) + CELL_INSET,
        fixedTopHeight = ROW_HEIGHT,
        horizontalOverflow = "paginate",
        verticalOverflow = "content",
    }
end

function UI:GetMeasuredHeight()
    local frame = self.details
    if not (frame and frame.scroll and frame.content) then return nil end
    local chrome = (frame:GetHeight() or 0) - (frame.scroll:GetHeight() or 0)
    if chrome <= 0 then return nil end
    -- Keep only the summary, column header, rendered rows and the documented
    -- bottom inset.  The scroll viewport must not become artificial blank
    -- space when every synchronized character already fits on screen.
    return chrome + (frame.content:GetHeight() or 0) + Theme:GetMatrixInsets(UI.accountContext and UI.accountContext.preview).bottom
end

function UI:PrintStatus()
    local snapshot = CurrentSnapshot()
    local current = snapshot and snapshot.current
    Addon:Print(current and (TaskName(current) .. "：" .. STATUS[current.status]) or "尚无可确定的下一任务。")
end

function UI:Initialize()
    Addon.Core.AccountView:RegisterPage(Addon.NAME, {
        id = "legendary",
        title = "传说之路",
        order = 20,
        defaultEnabled = true,
        previewEnabled = true,
        scope = { mode = "realms", allTitle = "所有服务器" },
        characterFilter = {
            defaultExpression = "",
            GetExpression = function() return Addon.db.settings.levelExpr or "" end,
            SetExpression = function(expression)
                local valid, normalized, badToken = Addon.Core.LevelFilter:Validate(expression or "")
                if not valid then return false, badToken end
                Addon.db.settings.levelExpr = normalized
                if Addon.UI then Addon.UI:Refresh() end
                return true, normalized
            end,
        },
        HasCharacterSnapshot = function(character)
            local store = Addon.db and Addon.db.byCharacter and Addon.db.byCharacter[character.id]
            return IsEligibleCharacter(character) and store and store.snapshot ~= nil
        end,
        GetEligibleCharacters = function(characters, context)
            return UI:GetEligibleCharacters(characters, context)
        end,
        settings = {
            title = "传说之路",
            description = "统一配置页面显示、独立入口，以及主表和悬停预览字段。业务进度仍由本插件保存。",
        },
        fields = COLUMNS,
        GetPreviewFields = function() return UI:GetPreviewColumns() end,
        SetPreviewFieldVisible = function(fieldID, visible) UI:SetPreviewFieldVisible(fieldID, visible) end,
        GetSurfaceMetrics = function(context) return UI:GetSurfaceMetrics(context) end,
        GetMeasuredHeight = function() return UI:GetMeasuredHeight() end,
        Create = function(parent) UI:CreateAccountPage(parent) end,
        Refresh = function(_, context) UI:RefreshDetails(context) end,
        GetSummary = function(characters)
            return string.format("当前任务 %d 名角色", #UI:GetVisibleCharacters(characters))
        end,
        GetActions = function(characters)
            local actions = {}
            for _, item in ipairs(UI:GetVisibleCharacters(characters)) do
                local current = item.snapshot.current
                if current and (current.status == "available" or current.status == "in_progress") then
                    actions[#actions + 1] = {
                        priority = current.status == "available" and 2 or 1,
                        title = CharacterLabel(item.character),
                        text = Addon.Data:GetTableAction(current),
                    }
                end
            end
            return actions
        end,
    })
    Addon.Core.Entry:RegisterBusinessEntry(Addon.NAME, {
        id = "YiboLegendary",
        brokerName = "YiboLegendary",
        pageID = "legendary",
        text = "[Yibo] 传说之路",
        icon = "Interface\\AddOns\\YiboLegendary\\Media\\YiboLegendaryIcon-v1",
    })
end

function UI:Refresh()
    if Addon.Core.AccountView then Addon.Core.AccountView:RefreshPage() end
end
