local Addon = _G.YiboTodo
local Page = {}
Addon.AccountPage = Page
local Theme = _G.YiboCore.UITheme
local C = Theme.Colors

local ROW_HEIGHT, ICON_SIZE, ICON_GAP = 38, 22, 3
local STATUS_TEXT = { actionable = "现在制作", cooldown = "冷却中", estimated = "预计可做", unknown = "待扫描" }

local function Text(parent, size, color, justify)
    return Theme:CreateText(parent, size, color, justify or "LEFT")
end

local function Release(pool, from)
    for index = from or 1, #pool do pool[index]:Hide() end
end

local function Period(project)
    if project.period == "daily-07" then return "每日（服务器时间 07:00 重置）" end
    return "固定时长冷却"
end

local function ConfirmedAt(project)
    local timestamp = tonumber(project.observedAt) or 0
    return timestamp > 0 and date("%Y-%m-%d %H:%M", timestamp) or "尚未确认"
end

local function ProjectTooltip(project)
    local lines = {
        { kind = "pair", label = "周期", value = Period(project) },
        { kind = "pair", label = "状态", value = STATUS_TEXT[project.state] or "待扫描" },
        { kind = "pair", label = "最后确认", value = ConfirmedAt(project) },
    }
    if project.readyAt and project.state == "cooldown" then
        lines[#lines + 1] = { kind = "pair", label = "预计恢复", value = date("%Y-%m-%d %H:%M", project.readyAt) }
    end
    return lines
end

local function SlotTooltip(slot)
    return { { kind = "text", text = "Core 已确认该角色拥有“" .. tostring(slot.name or "该专业") .. "”，但尚未采集到受支持的冷却配方。", wrap = true } }
end

local function GetIcon(parent, index)
    parent.icons = parent.icons or {}
    local button = parent.icons[index]
    if button then return button end
    button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(ICON_SIZE, ICON_SIZE)
    button:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    button.texture = button:CreateTexture(nil, "ARTWORK")
    button.texture:SetPoint("TOPLEFT", 2, -2); button.texture:SetPoint("BOTTOMRIGHT", -2, 2)
    button.check = button:CreateTexture(nil, "OVERLAY")
    button.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    button.check:SetSize(12, 12); button.check:SetPoint("BOTTOMRIGHT", 2, -2)
    button.estimatedBorder = CreateFrame("Frame", nil, button, "BackdropTemplate")
    button.estimatedBorder:SetAllPoints()
    button.estimatedBorder:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 5 })
    button.estimatedBorder:EnableMouse(false)
    parent.icons[index] = button
    return button
end

local function GetOverflow(parent)
    if parent.overflow then return parent.overflow end
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(28, ICON_SIZE)
    button:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    button.label = Text(button, Theme.Font.assist, C.muted, "CENTER"); button.label:SetAllPoints()
    parent.overflow = button
    return button
end

local function SetIcon(button, project)
    local texture = (GetItemIcon and project.icon and GetItemIcon(project.icon)) or "Interface\\Icons\\INV_Misc_QuestionMark"
    button.texture:SetTexture(texture)
    button.texture:SetDesaturated(project.state == "cooldown" or project.state == "unknown")
    if project.state == "cooldown" then button.texture:SetVertexColor(0.42, 0.48, 0.50, 0.92) else button.texture:SetVertexColor(1, 1, 1, 1) end
    button.check:SetShown(project.state == "cooldown")
    button.check:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 1)
    button.estimatedBorder:SetShown(project.state == "estimated")
    button.estimatedBorder:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3], 0.9)
    button:SetBackdropColor(C.chrome[1], C.chrome[2], C.chrome[3], 0.95)
    button:SetBackdropBorderColor(C.matrixLine[1], C.matrixLine[2], C.matrixLine[3], C.matrixLine[4])
    Theme:BindTooltip(button, project.label, ProjectTooltip(project))
    button:Show()
end

local function SetPlaceholder(parent, slot)
    local button = GetIcon(parent, 1)
    button.texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    button.texture:SetDesaturated(true); button.texture:SetVertexColor(C.muted[1], C.muted[2], C.muted[3], 0.9)
    button.check:Hide(); button.estimatedBorder:Hide()
    button:SetBackdropColor(C.chrome[1], C.chrome[2], C.chrome[3], 0.95)
    button:SetBackdropBorderColor(C.matrixLine[1], C.matrixLine[2], C.matrixLine[3], C.matrixLine[4])
    Theme:BindTooltip(button, "待扫描", SlotTooltip(slot))
    button:Show()
end

local function RenderProjects(cell, projects, slot)
    Release(cell.icons or {}, 1)
    if not slot then
        cell.empty:SetText("—"); cell.empty:Show(); if cell.overflow then cell.overflow:Hide() end
        return
    end
    cell.empty:Hide()
    if #projects == 0 then
        SetPlaceholder(cell, slot)
        if cell.overflow then cell.overflow:Hide() end
        return
    end
    local width, shown = math.max(ICON_SIZE, cell:GetWidth() or ICON_SIZE), 0
    for _, project in ipairs(projects) do
        if shown == 0 or shown * (ICON_SIZE + ICON_GAP) + ICON_SIZE <= width then
            shown = shown + 1
            local icon = GetIcon(cell, shown)
            icon:ClearAllPoints(); icon:SetPoint("LEFT", cell, "LEFT", (shown - 1) * (ICON_SIZE + ICON_GAP), 0)
            SetIcon(icon, project)
        else break end
    end
    local remaining, overflow = #projects - shown, GetOverflow(cell)
    if remaining > 0 then
        overflow:ClearAllPoints(); overflow:SetPoint("LEFT", cell, "LEFT", shown * (ICON_SIZE + ICON_GAP), 0)
        overflow.label:SetText("+" .. remaining)
        local lines = {}
        for index = shown + 1, #projects do
            local project = projects[index]
            lines[#lines + 1] = { kind = "section", text = tostring(project.label) }
            for _, detail in ipairs(ProjectTooltip(project)) do lines[#lines + 1] = detail end
        end
        Theme:BindTooltip(overflow, "其余制作项目", lines); overflow:Show()
    else overflow:Hide() end
end

local function Cell(row, index)
    row.cells = row.cells or {}
    local cell = row.cells[index]
    if cell then return cell end
    cell = CreateFrame("Frame", nil, row)
    cell.empty = Text(cell, Theme.Font.body, C.muted, "CENTER"); cell.empty:SetAllPoints()
    row.cells[index] = cell
    return cell
end

local function Row(frame, index)
    local row = frame.rows[index]
    if row then return row end
    row = CreateFrame("Frame", nil, frame.body, "BackdropTemplate")
    row:SetHeight(ROW_HEIGHT)
    row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    row.name = Text(row, Theme.Font.body, C.text)
    frame.rows[index] = row
    return row
end

local function Header(frame, index)
    local header = frame.headers[index]
    if header then return header end
    header = CreateFrame("Frame", nil, frame.header, "BackdropTemplate")
    header:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    header.label = Text(header, Theme.Font.assist, C.muted, "CENTER"); header.label:SetAllPoints()
    frame.headers[index] = header
    return header
end

function Page.Create(frame)
    frame.header = CreateFrame("Frame", nil, frame); frame.header:SetHeight(Theme.Table.headerHeight)
    frame.account = CreateFrame("Frame", nil, frame, "BackdropTemplate"); frame.account:SetHeight(ROW_HEIGHT)
    frame.account:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    frame.account.label = Text(frame.account, Theme.Font.assist, C.muted); frame.account.label:SetPoint("LEFT", 8, 0); frame.account.label:SetText("账号共享")
    frame.account.projects = CreateFrame("Frame", nil, frame.account)
    frame.account.projects.empty = Text(frame.account.projects, Theme.Font.body, C.muted, "CENTER"); frame.account.projects.empty:SetAllPoints()
    frame.body = CreateFrame("Frame", nil, frame)
    frame.emptyTitle = Text(frame, Theme.Font.section, C.text)
    frame.empty = Text(frame, Theme.Font.body, C.muted); frame.empty:SetWordWrap(true)
    frame.rows, frame.headers = {}, {}
end

local function Layout(frame)
    local width = math.max(500, frame:GetWidth() or 0)
    local character = math.min(150, math.max(110, math.floor(width * 0.22)))
    local common = math.max(88, math.floor(width * 0.18))
    local slot = math.floor((width - character - common) / 2)
    return character, slot, slot, width - character - slot * 2
end

function Page.Refresh(frame, context)
    local snapshot, count = Addon.Snapshot:Build(), 0
    local characterWidth, slotOneWidth, slotTwoWidth, commonWidth = Layout(frame)
    for _, row in ipairs(frame.rows) do row:Hide() end
    frame.header:ClearAllPoints(); frame.header:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -12); frame.header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -12)
    local columns = { { "角色", characterWidth }, { "专业槽位 1", slotOneWidth }, { "专业槽位 2", slotTwoWidth }, { "通用项目", commonWidth } }
    local x = 0
    for index, definition in ipairs(columns) do
        local header = Header(frame, index); header:ClearAllPoints(); header:SetPoint("TOPLEFT", frame.header, "TOPLEFT", x, 0); header:SetSize(definition[2], Theme.Table.headerHeight)
        header.label:SetText(definition[1]); header:SetBackdropColor(C.toolbar[1], C.toolbar[2], C.toolbar[3], C.toolbar[4]); header:SetBackdropBorderColor(C.lineSoft[1], C.lineSoft[2], C.lineSoft[3], C.lineSoft[4]); header:Show(); x = x + definition[2]
    end
    Release(frame.headers, #columns + 1)
    local accountProjects = snapshot.accountActivities or {}
    frame.account:SetShown(#accountProjects > 0)
    local top = frame.header
    if #accountProjects > 0 then
        frame.account:ClearAllPoints(); frame.account:SetPoint("TOPLEFT", frame.header, "BOTTOMLEFT", 0, -4); frame.account:SetPoint("TOPRIGHT", frame.header, "BOTTOMRIGHT", 0, -4)
        frame.account:SetBackdropColor(C.row[1], C.row[2], C.row[3], C.row[4]); frame.account:SetBackdropBorderColor(C.matrixLine[1], C.matrixLine[2], C.matrixLine[3], C.matrixLine[4])
        frame.account.label:SetWidth(characterWidth - 8)
        frame.account.projects:ClearAllPoints(); frame.account.projects:SetPoint("LEFT", characterWidth, 0); frame.account.projects:SetPoint("RIGHT", 0, 0)
        RenderProjects(frame.account.projects, accountProjects, { name = "账号共享" }); top = frame.account
    end
    for _, character in ipairs(context.characters or {}) do
        local data = snapshot.characters[character.id]
        if data then
            count = count + 1
            local row = Row(frame, count)
            row:ClearAllPoints(); row:SetPoint("TOPLEFT", top, "BOTTOMLEFT", 0, -4 - ((count - 1) * (ROW_HEIGHT + 4))); row:SetPoint("TOPRIGHT", top, "BOTTOMRIGHT", 0, -4 - ((count - 1) * (ROW_HEIGHT + 4))); row:SetHeight(ROW_HEIGHT)
            local fill = count % 2 == 0 and C.alternate or C.row
            row:SetBackdropColor(fill[1], fill[2], fill[3], 0.9); row:SetBackdropBorderColor(C.matrixLine[1], C.matrixLine[2], C.matrixLine[3], C.matrixLine[4])
            row.name:ClearAllPoints(); row.name:SetPoint("LEFT", 8, 0); row.name:SetWidth(characterWidth - 8); row.name:SetText(character.name or "?")
            local first, second, common = Cell(row, 1), Cell(row, 2), Cell(row, 3)
            first:ClearAllPoints(); first:SetPoint("LEFT", characterWidth, 0); first:SetWidth(slotOneWidth)
            second:ClearAllPoints(); second:SetPoint("LEFT", characterWidth + slotOneWidth, 0); second:SetWidth(slotTwoWidth)
            common:ClearAllPoints(); common:SetPoint("LEFT", characterWidth + slotOneWidth + slotTwoWidth, 0); common:SetWidth(commonWidth)
            RenderProjects(first, data.projectsBySlot[1] or {}, data.professionSlots[1])
            RenderProjects(second, data.projectsBySlot[2] or {}, data.professionSlots[2])
            RenderProjects(common, data.commonProjects or {}, false)
            row:Show()
        end
    end
    frame.header:SetShown(count > 0)
    frame.emptyTitle:SetShown(count == 0); frame.empty:SetShown(count == 0)
    if count == 0 then
        frame.emptyTitle:ClearAllPoints(); frame.emptyTitle:SetPoint("TOPLEFT", 24, -26); frame.emptyTitle:SetText("等待专业快照")
        frame.empty:ClearAllPoints(); frame.empty:SetPoint("TOPLEFT", 24, -56); frame.empty:SetPoint("TOPRIGHT", -24, -56); frame.empty:SetText("YiboCore 尚未确认可显示角色的两项主专业。登录角色后打开一次专业面板，即可采集受支持的冷却配方。")
    end
end

function Page.GetSurfaceMetrics()
    return { minContentWidth = 500, naturalContentWidth = 760, minContentHeight = 120, naturalContentHeight = 260, horizontalOverflow = "none", verticalOverflow = "content" }
end
