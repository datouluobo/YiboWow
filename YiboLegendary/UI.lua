local Addon = _G.YiboLegendary
local UI = {}
Addon.UI = UI

local STATUS = { completed = "已完成", in_progress = "进行中", available = "可接取", locked = "未解锁", unavailable = "阶段未开放" }
local STATUS_COLORS = {
    completed = { 0.22, 0.88, 0.48 },
    in_progress = { 1, 0.78, 0.34 },
    available = { 0.36, 0.9, 0.88 },
    locked = { 0.56, 0.64, 0.69 },
    unavailable = { 1, 0.48, 0.5 },
}

local ROW_HEIGHT = 26
local COLUMNS = {
    { id = "character", key = "character", title = "角色", width = 200, minWidth = 145, defaultVisible = true },
    { id = "chapter", key = "chapter", title = "章节", width = 64, minWidth = 54, defaultVisible = false },
    { id = "task", key = "task", title = "当前任务", width = 220, minWidth = 150, defaultVisible = true },
    { id = "objective", key = "objective", title = "目标", width = 360, minWidth = 230, defaultVisible = true },
    { id = "action", key = "action", title = "行动", width = 240, minWidth = 190, defaultVisible = true },
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

local function CurrentDefinition(current)
    return Addon.Data.byID[current.definitionId] or current.definition or {}
end

local function ObjectiveText(_, current)
    local definition = CurrentDefinition(current)
    if definition.valor and current.valorProgress ~= nil then
        local formatNumber = BreakUpLargeNumbers or tostring
        return string.format("累计获得勇气点数：%s/%s", formatNumber(current.valorProgress), formatNumber(Addon.Data.VALOR_TARGET))
    end
    return current.log and #current.log.objectives > 0 and table.concat(current.log.objectives, "；") or definition.objective
end

local function TaskName(current)
    local definition = CurrentDefinition(current)
    return definition.name or (current.log and current.log.title) or "未知任务"
end

local function ChapterText(snapshot, current)
    if snapshot.completed then
        return "已完成"
    end
    if not current then
        return "—"
    end
    return "第 " .. tostring(current.definition.chapter or "?") .. " 章"
end

local function ClassColor(character)
    local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[character.class or ""]
    if color then
        return color.r, color.g, color.b
    end
    return 0.92, 0.96, 0.98
end

function UI:GetVisibleCharacters(characters)
    local visible = {}
    for _, character in ipairs(characters or Addon.Core.Characters:GetAll()) do
        local store = Addon.db.byCharacter[character.id]
        if IsEligibleCharacter(character) and store and store.snapshot then
            visible[#visible + 1] = { character = character, snapshot = store.snapshot }
        end
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
    header:SetPoint("TOPLEFT", 8, -40)
    header:SetPoint("TOPRIGHT", -14, -40)
    header.bg = header:CreateTexture(nil, "BACKGROUND")
    header.bg:SetAllPoints(header)
    header.bg:SetColorTexture(0.06, 0.16, 0.19, 0.96)
    header.cells = {}
    local offset = 10
    for _, column in ipairs(COLUMNS) do
        local text = self:CreateText(header, "GameFontNormalSmall", column.width - 8)
        text:SetPoint("LEFT", offset, 0)
        text:SetText(column.title)
        text:SetTextColor(0.53, 0.78, 0.8)
        header.cells[column.key] = text
        offset = offset + column.width
    end
    return header
end

function UI:CreateAccountPage(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints(parent)
    frame.summary = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.summary:SetPoint("TOPLEFT", 12, -12)
    frame.summary:SetTextColor(0.72, 0.84, 0.86)
    frame.header = self:CreateHeader(frame)

    frame.scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    frame.scroll:SetPoint("TOPLEFT", 8, -68)
    frame.scroll:SetPoint("BOTTOMRIGHT", -14, 8)
    frame.content = CreateFrame("Frame", nil, frame.scroll)
    frame.content:SetWidth(1166)
    frame.scroll:SetScrollChild(frame.content)
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
    row.divider:SetColorTexture(0.11, 0.25, 0.29, 0.9)
    row.cells = {}
    for _, column in ipairs(COLUMNS) do
        local text = self:CreateText(row, "GameFontNormalSmall", column.width - 8)
        text:SetPoint("LEFT", 10, 0)
        row.cells[column.key] = text
    end
    row:SetScript("OnEnter", function(self)
        if not self.tooltipLines then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        for _, line in ipairs(self.tooltipLines) do GameTooltip:AddLine(line.text, line.r, line.g, line.b, true) end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    frame.rows[index] = row
    return row
end

function UI:IsColumnVisible(column)
    return not self.accountContext or self.accountContext:GetFieldVisible(column)
end

function UI:ApplyColumnLayout()
    local frame = self.details
    local visibleColumns, preferredWidth = {}, 0
    for _, column in ipairs(COLUMNS) do
        if self:IsColumnVisible(column) then
            visibleColumns[#visibleColumns + 1] = column
            preferredWidth = preferredWidth + column.width
        end
    end
    local viewportWidth = (frame.scroll:GetWidth() or 0) - 2
    if viewportWidth <= 0 then viewportWidth = (frame:GetWidth() or 0) - 22 end
    if viewportWidth <= 0 then viewportWidth = preferredWidth + 18 end
    local availableWidth = math.max(420, viewportWidth - 18)
    local scale = math.min(1, availableWidth / math.max(1, preferredWidth))
    local offset = 10
    for _, column in ipairs(COLUMNS) do
        local visible = self:IsColumnVisible(column)
        local headerCell = frame.header.cells[column.key]
        headerCell:SetShown(visible)
        if visible then
            local width = math.max(column.minWidth or 40, math.floor(column.width * scale))
            headerCell:ClearAllPoints()
            headerCell:SetPoint("LEFT", offset, 0)
            headerCell:SetWidth(width - 8)
        end
        for _, row in ipairs(frame.rows) do
            local cell = row.cells[column.key]
            cell:SetShown(visible)
            if visible then
                local width = math.max(column.minWidth or 40, math.floor(column.width * scale))
                cell:ClearAllPoints()
                cell:SetPoint("LEFT", offset, 0)
                cell:SetWidth(width - 8)
            end
        end
        if visible then offset = offset + math.max(column.minWidth or 40, math.floor(column.width * scale)) end
    end
    local contentWidth = math.max(420, viewportWidth)
    frame.content:SetWidth(contentWidth)
end

function UI:UpdateRow(row, character, snapshot, currentCharacter, index)
    row.character, row.snapshot = character, snapshot
    local current = snapshot.current
    local isCurrent = currentCharacter and character.id == currentCharacter.id
    if isCurrent then
        row.bg:SetColorTexture(0.05, 0.25, 0.24, 0.92)
    elseif index % 2 == 0 then
        row.bg:SetColorTexture(0.045, 0.12, 0.15, 0.72)
    else
        row.bg:SetColorTexture(0.025, 0.08, 0.11, 0.72)
    end
    local red, green, blue = ClassColor(character)
    row.cells.character:SetText((isCurrent and "● " or "") .. CharacterLabel(character))
    row.cells.character:SetTextColor(red, green, blue)
    row.tooltipLines = { { text = CharacterLabel(character), r = red, g = green, b = blue } }
    if snapshot.readable == false then
        row.cells.chapter:SetText("异常")
        row.cells.task:SetText("无法读取任务完成状态")
        row.cells.objective:SetText("执行 /yle probe 检查客户端 API")
        row.cells.action:SetText("等待兼容性确认")
        row.tooltipLines[#row.tooltipLines + 1] = { text = "任务状态：无法读取；请执行 /yle probe", r = 1, g = 0.48, b = 0.5 }
        for _, key in ipairs({ "chapter", "task", "objective", "action" }) do row.cells[key]:SetTextColor(1, 0.48, 0.5) end
        return
    end
    if snapshot.completed then
        row.cells.chapter:SetText("完成")
        row.cells.task:SetText("传说披风任务线")
        row.cells.objective:SetText("已完成")
        row.cells.action:SetText("—")
        row.tooltipLines[#row.tooltipLines + 1] = { text = "传说披风任务线：已完成", r = 0.22, g = 0.88, b = 0.48 }
        for _, key in ipairs({ "chapter", "task", "objective", "action" }) do row.cells[key]:SetTextColor(0.22, 0.88, 0.48) end
        return
    end
    if not current then
        row.cells.chapter:SetText("—")
        row.cells.task:SetText("尚无可确定的下一任务")
        row.cells.objective:SetText("检查前置任务、声望或服务器阶段")
        row.cells.action:SetText("等待条件满足")
        row.tooltipLines[#row.tooltipLines + 1] = { text = "下一步：检查前置任务、声望或服务器阶段", r = 0.56, g = 0.64, b = 0.69 }
        for _, key in ipairs({ "chapter", "task", "objective", "action" }) do row.cells[key]:SetTextColor(0.56, 0.64, 0.69) end
        return
    end
    local statusColor = STATUS_COLORS[current.status] or STATUS_COLORS.locked
    local chapter = ChapterText(snapshot, current)
    if current.definition.phase and current.phaseStatus == "unknown" then chapter = chapter .. " · 待确认" end
    row.cells.chapter:SetText(chapter)
    row.cells.chapter:SetTextColor(statusColor[1], statusColor[2], statusColor[3])
    row.cells.task:SetText(TaskName(current))
    row.cells.task:SetTextColor(0.92, 0.96, 0.98)
    row.cells.objective:SetText(ObjectiveText(snapshot, current))
    row.cells.objective:SetTextColor(0.76, 0.86, 0.88)
    row.cells.action:SetText(Addon.Data:GetTableAction(current))
    row.cells.action:SetTextColor(0.36, 0.9, 0.88)
    row.tooltipLines[#row.tooltipLines + 1] = { text = "任务：" .. TaskName(current), r = 0.92, g = 0.96, b = 0.98 }
    row.tooltipLines[#row.tooltipLines + 1] = { text = "目标：" .. ObjectiveText(snapshot, current), r = 0.76, g = 0.86, b = 0.88 }
    row.tooltipLines[#row.tooltipLines + 1] = { text = "行动：" .. Addon.Data:GetTableAction(current), r = 0.36, g = 0.9, b = 0.88 }
end

function UI:RefreshDetails(context)
    local frame = self.details
    if not frame then return end
    self.accountContext = context
    local currentCharacter = Addon.Core.Characters:GetCurrent()
    local visible = self:GetVisibleCharacters(context and context.characters)
    local inProgress, available = 0, 0
    for index, item in ipairs(visible) do
        local row = frame.rows[index] or self:CreateRow(index)
        self:UpdateRow(row, item.character, item.snapshot, currentCharacter, index)
        row:Show()
        local status = item.snapshot.current and item.snapshot.current.status
        if status == "in_progress" then inProgress = inProgress + 1 end
        if status == "available" then available = available + 1 end
    end
    for index = #visible + 1, #frame.rows do frame.rows[index]:Hide() end
    self:ApplyColumnLayout()
    local contentHeight = #visible * ROW_HEIGHT
    local viewportHeight = frame.scroll:GetHeight() or 500
    local needsScroll = not (context and context.preview) and contentHeight > viewportHeight
    frame.content:SetHeight(math.max(contentHeight, viewportHeight))
    frame.scroll:SetVerticalScroll(0)
    if frame.scroll.ScrollBar then
        frame.scroll.ScrollBar:SetShown(needsScroll)
    end
    frame.summary:SetText(string.format("已同步角色：|cff20e070%d|r    进行中：|cffffc857%d|r    可接取：|cff5ce5e0%d|r    悬停行可查看完整文本", #visible, inProgress, available))
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
    -- AccountView 的标题栏、摘要、表头和底部留白共占约 128 像素。
    -- 预览固定最多 20 行，必须让每一行在首屏完整出现，不能依赖滚动条。
    return 820, math.max(150, 128 + (rows * ROW_HEIGHT))
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
        settings = {
            title = "传说之路",
            description = "统一配置页面显示、独立入口，以及主表和悬停预览字段。业务进度仍由本插件保存。",
        },
        fields = COLUMNS,
        GetPreviewFields = function() return UI:GetPreviewColumns() end,
        SetPreviewFieldVisible = function(fieldID, visible) UI:SetPreviewFieldVisible(fieldID, visible) end,
        GetPreviewSize = function(context) return UI:GetPreviewSize(context) end,
        Create = function(parent) UI:CreateAccountPage(parent) end,
        Refresh = function(_, context) UI:RefreshDetails(context) end,
        GetSummary = function(characters)
            local inProgress, available = 0, 0
            for _, item in ipairs(UI:GetVisibleCharacters(characters)) do
                local status = item.snapshot.current and item.snapshot.current.status
                if status == "in_progress" then inProgress = inProgress + 1 end
                if status == "available" then available = available + 1 end
            end
            return string.format("进行中 %d · 可接取 %d", inProgress, available)
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
        pageID = "legendary",
        text = "[Yibo] 传说之路",
        icon = "Interface\\Icons\\INV_Misc_Note_05",
    })
end

function UI:Refresh()
    if Addon.Core.AccountView then Addon.Core.AccountView:RefreshPage() end
end
