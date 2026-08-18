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

local ROW_HEIGHT = Theme.Size.standard
local ADAPTIVE_HIDE_ORDER = { "action", "task" }
local COLUMNS = {
    { id = "character", key = "character", title = "角色", width = 200, minWidth = 145, defaultVisible = true },
    { id = "task", key = "task", title = "当前任务", width = 220, minWidth = 150, defaultVisible = true },
    { id = "objective", key = "objective", title = "目标", width = 400, minWidth = 260, defaultVisible = true },
    { id = "action", key = "action", title = "行动", width = 300, minWidth = 220, defaultVisible = true },
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
    if definition.valor and current.valorProgress ~= nil then
        objective = string.format("累计获得勇气点数：%s/%s", FormatNumber(current.valorProgress), FormatNumber(Addon.Data.VALOR_TARGET))
    else
        objective = current.log and #current.log.objectives > 0 and table.concat(current.log.objectives, "；") or definition.objective
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

function UI:CreateText(parent, template, width)
    local text = parent:CreateFontString(nil, "OVERLAY", template)
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
    header:SetPoint("TOPRIGHT", -38, -52)
    header.bg = header:CreateTexture(nil, "BACKGROUND")
    header.bg:SetAllPoints(header)
    header.bg:SetColorTexture(C.chrome[1], C.chrome[2], C.chrome[3], 0.96)
    header.cells = {}
    local offset = 10
    for _, column in ipairs(COLUMNS) do
        local text = self:CreateText(header, "GameFontNormalSmall", column.width - 8)
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
    frame.summary:SetPoint("TOPLEFT", Theme.Space.lg, -Theme.Space.md)
    frame.summary:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
    frame.header = self:CreateHeader(frame)

    frame.scroll = Theme:CreateScrollFrame(frame)
    frame.scroll:SetPoint("TOPLEFT", Theme.Space.lg, -88)
    frame.scroll:SetPoint("BOTTOMRIGHT", -38, Theme.Space.md)
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
        local text = self:CreateText(row, "GameFontNormalSmall", column.width - 8)
        text:SetPoint("LEFT", 10, 0)
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
            local width = EstimateTextWidth(column.title) + 20
            local headerCell = frame and frame.header and frame.header.cells[column.key]
            if headerCell and headerCell.GetStringWidth then width = math.max(width, headerCell:GetStringWidth() + 20) end
            for _, row in ipairs((frame and frame.rows) or {}) do
                local cell = row.cells[column.key]
                if row:IsShown() and cell and cell.GetStringWidth then width = math.max(width, cell:GetStringWidth() + 20) end
            end
            widths[column.id] = math.max(column.minWidth or 40, math.ceil(width))
        end
    end
    return widths
end

function UI:GetEstimatedColumnWidths(context)
    local widths = {}
    for _, column in ipairs(COLUMNS) do
        if context:GetFieldVisible(column.id) then
            widths[column.id] = math.max(column.minWidth or 40, EstimateTextWidth(column.title) + 20)
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
                widths[column.id] = math.max(widths[column.id], EstimateTextWidth(values[column.id]) + 20)
            end
        end
    end
    return widths
end

function UI:ApplyColumnLayout()
    local frame = self.details
    local viewportWidth = (frame.scroll:GetWidth() or 0) - 2
    if viewportWidth <= 0 then viewportWidth = (frame:GetWidth() or 0) - 22 end
    if viewportWidth <= 0 then viewportWidth = 420 end
    local availableWidth = math.max(1, viewportWidth - 18)
    local naturalWidths = self:GetNaturalColumnWidths()
    local visibleColumns, preferredWidth = {}, 0
    for _, column in ipairs(COLUMNS) do
        if self:IsConfiguredColumnVisible(column) then
            visibleColumns[#visibleColumns + 1] = column
            preferredWidth = preferredWidth + (naturalWidths[column.id] or column.width)
        end
    end

    local function RequiredWidth()
        local width = 0
        for _, column in ipairs(visibleColumns) do width = width + (naturalWidths[column.id] or column.minWidth or 40) end
        return width
    end
    for _, columnID in ipairs(ADAPTIVE_HIDE_ORDER) do
        if RequiredWidth() <= availableWidth then break end
        for index = #visibleColumns, 1, -1 do
            if visibleColumns[index].id == columnID then
                preferredWidth = preferredWidth - (naturalWidths[visibleColumns[index].id] or visibleColumns[index].width)
                table.remove(visibleColumns, index)
                break
            end
        end
    end

    self.renderColumns = {}
    for _, column in ipairs(visibleColumns) do self.renderColumns[column.id] = true end
    preferredWidth = 0
    for _, column in ipairs(visibleColumns) do preferredWidth = preferredWidth + (naturalWidths[column.id] or column.width) end
    local scale = math.min(1, availableWidth / math.max(1, preferredWidth))
    local offset = 10
    for _, column in ipairs(COLUMNS) do
        local visible = self:IsColumnVisible(column)
        local headerCell = frame.header.cells[column.key]
        headerCell:SetShown(visible)
        if visible then
            local width = math.max(column.minWidth or 40, math.floor((naturalWidths[column.id] or column.width) * scale))
            headerCell:ClearAllPoints()
            headerCell:SetPoint("LEFT", offset, 0)
            headerCell:SetWidth(width - 8)
        end
        for _, row in ipairs(frame.rows) do
            local cell = row.cells[column.key]
            cell:SetShown(visible)
            if visible then
                local width = math.max(column.minWidth or 40, math.floor((naturalWidths[column.id] or column.width) * scale))
                cell:ClearAllPoints()
                cell:SetPoint("LEFT", offset, 0)
                cell:SetWidth(width - 8)
            end
        end
        if visible then offset = offset + math.max(column.minWidth or 40, math.floor((naturalWidths[column.id] or column.width) * scale)) end
    end
    local contentWidth = math.max(1, math.min(viewportWidth, offset + 18))
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
    row.cells.objective:SetText(ObjectiveText(snapshot, current))
    row.cells.objective:SetTextColor(0.76, 0.86, 0.88)
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
    local viewportHeight = frame.scroll:GetHeight() or 500
    frame.content:SetHeight(math.max(contentHeight, viewportHeight))
    frame.scroll:SetContentHeight(frame.content:GetHeight())
    frame.scroll:SetVerticalScroll(math.min(previousScroll, math.max(0, contentHeight - viewportHeight)))
    frame.scroll:RefreshScrollbar()
    frame.summary:SetText(string.format("已同步角色：|cff20e070%d|r    悬停行可查看完整文本", #visible))
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
    local rows = #self:GetVisibleCharacters(context and context.characters)
    local widths = self:GetEstimatedColumnWidths(context)
    local width = 80
    for _, column in ipairs(COLUMNS) do
        if context:GetFieldVisible(column.id) then width = width + (widths[column.id] or column.width) end
    end
    -- AccountView 的标题栏、摘要、表头和底部留白共占约 160 像素。
    -- 预览固定最多 20 行，必须让每一行在首屏完整出现，不能依赖滚动条。
    return math.max(420, width), math.max(150, 160 + (rows * ROW_HEIGHT))
end

function UI:GetLayoutMetrics(context)
    local widths = self:GetEstimatedColumnWidths(context)
    local width = 0
    for _, column in ipairs(COLUMNS) do
        if context:GetFieldVisible(column.id) then width = width + (widths[column.id] or column.width or column.minWidth or 54) end
    end
    local rows = #self:GetVisibleCharacters(context and context.characters)
    return {
        minWidth = math.max(582, width + 60),
        preferredWidth = math.max(582, width + 60),
        minHeight = 383,
        preferredHeight = math.max(383, 104 + (rows * ROW_HEIGHT)),
        horizontalOverflow = "content",
        verticalOverflow = "content",
    }
end

function UI:GetHoverMetrics(context)
    local width, height = self:GetPreviewSize(context)
    return {
        minWidth = 420,
        preferredWidth = width,
        minHeight = 150,
        preferredHeight = height,
        horizontalOverflow = "content",
        verticalOverflow = "content",
    }
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
        GetPreviewSize = function(context) return UI:GetPreviewSize(context) end,
        GetHoverMetrics = function(context) return UI:GetHoverMetrics(context) end,
        GetLayoutMetrics = function(context) return UI:GetLayoutMetrics(context) end,
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
