local Addon = _G.YiboTodo
local Page = {}
Addon.AccountPage = Page
local Theme = _G.YiboCore.UITheme
local C = Theme.Colors

local ROW_HEIGHT, ROW_GAP, ICON_SIZE, ICON_GAP = Theme.Table.iconRowHeight, 0, 22, 3
local MIN_PROJECT_SLOTS, OVERFLOW_WIDTH = 4, ICON_SIZE
local FARM_COLUMN_WIDTH = ICON_SIZE + 8
local NOMI_COLUMN_WIDTH = ICON_SIZE + 8
local STATUS_TEXT = { actionable = "可制作", cooldown = "冷却中", completed = "已完成", estimated = "可制作（按冷却时间）", ["skill-insufficient"] = "专业技能不足", unknown = Theme.StatusText.unknown }

local function ProjectColumnWidth(slots)
    slots = math.max(MIN_PROJECT_SLOTS, tonumber(slots) or 0)
    return slots * ICON_SIZE + (slots - 1) * ICON_GAP
end

local MIN_PROJECT_COLUMN_WIDTH = ProjectColumnWidth(MIN_PROJECT_SLOTS)

local function CharacterLabel(character, showRealm)
    local name = tostring(character and character.name or "?")
    if showRealm then return name .. "-" .. tostring(character and character.realm or "未知服务器") end
    return name
end

local function CharacterColumnWidth(context)
    local showRealm = context and context.scope == "all"
    local width = 96
    for _, character in ipairs(context and context.characters or {}) do
        width = math.max(width, Theme:MeasureText(Theme.Font.body, CharacterLabel(character, showRealm)) + Theme.Space.lg)
    end
    return width
end

local function ApplyCharacterColor(text, character)
    local colors = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS
    local color = colors and colors[character and character.class or ""]
    text:SetTextColor(color and color.r or C.text[1], color and color.g or C.text[2], color and color.b or C.text[3])
end

local function Text(parent, size, color, justify)
    return Theme:CreateText(parent, size, color, justify or "LEFT")
end

local function Release(pool, from)
    for index = from or 1, #pool do pool[index]:Hide() end
end

local function ProjectTooltip(project)
    local lines = { { kind = "pair", label = "状态", value = project.statusText or STATUS_TEXT[project.state] or "状态异常" } }
    if project.state == "unknown" and not project.optimisticFarm then
        local detail = project.reason == "recipe-unlearned"
            and "该角色尚未学会此配方。"
            or "尚未取得该角色自己的可靠冷却记录，因此不会按可制作处理。"
        lines[#lines + 1] = { kind = "text", text = detail }
    end
    if project.readyAt and project.state == "cooldown" then
        lines[#lines + 1] = { kind = "pair", label = "恢复", value = date("%m-%d %H:%M", project.readyAt) }
    end
    if project.state == "skill-insufficient" then
        local current, required = tonumber(project.skillLevel), tonumber(project.requiredSkillLevel)
        local detail = current and required and string.format("当前专业技能点不足（%d/%d），提升技能后即可制作。", current, required) or "当前专业技能点不足，提升技能后即可制作。"
        lines[#lines + 1] = { kind = "text", text = detail }
    end
    if project.operationLabels and #project.operationLabels > 0 then lines[#lines + 1] = { kind = "pair", label = "今日记录", value = table.concat(project.operationLabels, "、") } end
    if project.observedAt then lines[#lines + 1] = { kind = "pair", label = "最近观察", value = date("%m-%d %H:%M", project.observedAt) } end
    if project.nextResetAt then lines[#lines + 1] = { kind = "pair", label = "本日截止", value = date("%m-%d %H:%M", project.nextResetAt) } end
    if project.optimisticFarm then lines[#lines + 1] = { kind = "text", text = "低保真规则：一次已验证操作按整轮农场流程投影。" } end
    return lines
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
    button.skillInsufficient = button:CreateTexture(nil, "OVERLAY")
    button.skillInsufficient:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
    button.skillInsufficient:SetSize(10, 10); button.skillInsufficient:SetPoint("BOTTOMRIGHT", -1, 1)
    button.unknown = button:CreateTexture(nil, "OVERLAY")
    button.unknown:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    button.unknown:SetSize(11, 11); button.unknown:SetPoint("TOPRIGHT", 1, 1)
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
    button:SetSize(OVERFLOW_WIDTH, ICON_SIZE)
    button:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    button.label = Text(button, Theme.Font.assist, C.muted, "CENTER"); button.label:SetAllPoints()
    parent.overflow = button
    return button
end

local function SetIcon(button, project)
    local resolved
    if project.iconKind == "spell" and GetSpellTexture then resolved = GetSpellTexture(project.icon)
    elseif project.iconKind == "texture" then resolved = project.icon
    elseif GetItemIcon and project.icon then resolved = GetItemIcon(project.icon) end
    if not resolved and project.fallbackSpellID and GetSpellTexture then resolved = GetSpellTexture(project.fallbackSpellID) end
    local texture = resolved or project.fallbackIcon or "Interface\\Icons\\INV_Misc_QuestionMark"
    button:SetSize(ICON_SIZE, ICON_SIZE)
    button.texture:SetTexture(texture)
    local skillInsufficient = project.state == "skill-insufficient"
    -- A farm observation deliberately retains the model's unknown state, but
    -- it is not missing data: today's operation was witnessed. Do not cover
    -- its harvest basket with the generic missing-information question mark.
    local unknown = project.state == "unknown" and not project.operationObserved
    local completed = project.state == "completed"
    button.texture:SetDesaturated(project.state == "cooldown" or completed or skillInsufficient or unknown)
    if project.state == "cooldown" or completed then button.texture:SetVertexColor(0.42, 0.48, 0.50, 0.92) else button.texture:SetVertexColor(1, 1, 1, 1) end
    if skillInsufficient then button.texture:SetVertexColor(0.82, 0.53, 0.28, 0.92) end
    if unknown then button.texture:SetVertexColor(C.muted[1], C.muted[2], C.muted[3], 0.76) end
    button.check:SetShown(project.state == "cooldown" or completed)
    button.check:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 1)
    button.skillInsufficient:SetShown(skillInsufficient)
    button.unknown:SetShown(unknown)
    button.estimatedBorder:SetShown(project.state == "estimated")
    button.estimatedBorder:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3], 0.9)
    button:SetBackdropColor(C.chrome[1], C.chrome[2], C.chrome[3], 0.95)
    button:SetBackdropBorderColor(C.matrixLine[1], C.matrixLine[2], C.matrixLine[3], C.matrixLine[4])
    Theme:BindTooltip(button, project.label, ProjectTooltip(project))
    button:Show()
end

local function RenderProjects(cell, projects)
    Release(cell.icons or {}, 1)
    cell:Show()
    if #projects == 0 then
        cell.empty:SetText("—"); cell.empty:Show(); if cell.overflow then cell.overflow:Hide() end
        return
    end
    cell.empty:Hide()
    local width, shown, used = math.max(ICON_SIZE, cell:GetWidth() or ICON_SIZE), 0, 0
    for index in ipairs(projects) do
        local leadingGap = shown > 0 and ICON_GAP or 0
        local overflowReserve = index < #projects and (ICON_GAP + OVERFLOW_WIDTH) or 0
        if shown == 0 or used + leadingGap + ICON_SIZE + overflowReserve <= width then
            shown = shown + 1
            used = used + leadingGap + ICON_SIZE
        else break end
    end
    local remaining, overflow = #projects - shown, GetOverflow(cell)
    local contentWidth = used + (remaining > 0 and (shown > 0 and ICON_GAP or 0) + OVERFLOW_WIDTH or 0)
    local x = math.max(0, math.floor((width - contentWidth) / 2))
    for index = 1, shown do
        local icon = GetIcon(cell, index)
        icon:ClearAllPoints(); icon:SetPoint("LEFT", cell, "LEFT", x, 0)
        SetIcon(icon, projects[index])
        x = x + ICON_SIZE + ICON_GAP
    end
    if remaining > 0 then
        overflow:ClearAllPoints(); overflow:SetPoint("LEFT", cell, "LEFT", x, 0)
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

local function HasCommonProjects(snapshot, characters)
    for _, character in ipairs(characters or {}) do
        local data = snapshot.characters[character.id]
        if data and #(data.commonProjects or {}) > 0 then return true end
    end
    return false
end

local function ProfessionColumnWidth(snapshot, characters)
    local slots = MIN_PROJECT_SLOTS
    for _, character in ipairs(characters or {}) do
        local data = snapshot.characters[character.id]
        slots = math.max(slots, #(data and data.professionProjects or {}))
    end
    return ProjectColumnWidth(slots)
end

local function HasFarmColumn()
    local farm = Addon.Catalog.farmOperations and Addon.Catalog.farmOperations["mop.farm.operation-observed"]
    return farm and Addon.Settings:GetMode("activity", farm.id, farm.defaultMode) ~= "hidden"
end

local function HasNomiColumn()
    local nomi = Addon.Catalog.dailyActivities and Addon.Catalog.dailyActivities["mop.nomi"]
    return nomi and Addon.Settings:GetMode("activity", nomi.id, nomi.defaultMode) ~= "hidden"
end

local function Row(frame, index)
    local row = frame.rows[index]
    if row then return row end
    row = CreateFrame("Frame", nil, frame.body, "BackdropTemplate")
    row:SetHeight(ROW_HEIGHT)
    row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    row.currentOutline = Theme:CreateCurrentCharacterOutline(row)
    row.name = Text(row, Theme.Font.body, C.text)
    row.status = Text(row, Theme.Font.body, C.muted, "LEFT")
    frame.rows[index] = row
    return row
end

local function Header(frame, index)
    local header = frame.headers[index]
    if header then return header end
    header = Theme:CreateMatrixHeader(frame.header)
    frame.headers[index] = header
    return header
end

function Page.Create(frame)
    frame:SetClipsChildren(true)
    frame.header = CreateFrame("Frame", nil, frame); frame.header:SetHeight(Theme.Table.headerHeight)
    frame.account = CreateFrame("Frame", nil, frame, "BackdropTemplate"); frame.account:SetHeight(ROW_HEIGHT)
    frame.account:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    frame.account.label = Text(frame.account, Theme.Font.assist, C.muted); frame.account.label:SetPoint("LEFT", 8, 0); frame.account.label:SetText("账号共享")
    frame.account.projects = CreateFrame("Frame", nil, frame.account)
    frame.account.projects.empty = Text(frame.account.projects, Theme.Font.body, C.muted, "CENTER"); frame.account.projects.empty:SetAllPoints()
    frame.scroll = Theme:CreateScrollFrame(frame)
    frame.body = CreateFrame("Frame", nil, frame.scroll)
    frame.scroll:SetScrollChild(frame.body)
    frame.emptyTitle = Text(frame, Theme.Font.section, C.text)
    frame.empty = Text(frame, Theme.Font.body, C.muted); frame.empty:SetWordWrap(true)
    frame.rows, frame.headers = {}, {}
end

local function Layout(characterWidth, professionWidth, hasFarm, hasNomi, hasCommon)
    return characterWidth, professionWidth, hasFarm and FARM_COLUMN_WIDTH or 0, hasNomi and NOMI_COLUMN_WIDTH or 0, hasCommon and MIN_PROJECT_COLUMN_WIDTH or 0
end

local function ConfigureScroll(frame, top, tableWidth, contentHeight, inset)
    local scroll = frame.scroll
    scroll:ClearAllPoints()
    scroll:SetPoint("TOPLEFT", top, "BOTTOMLEFT", 0, -ROW_GAP)
    scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -inset.right, inset.bottom)
    -- Match the Boss weekly matrix: the scroll viewport owns the available
    -- page space, while the child owns only actual table content width.
    -- The shared scroll frame then decides whether a thumb is necessary.
    frame.body:SetSize(tableWidth, math.max(1, contentHeight))
    scroll:SetContentHeight(frame.body:GetHeight())
    scroll:RefreshScrollbar()
end

function Page.Refresh(frame, context)
    local snapshot, count = Addon.Snapshot:Build(), 0
    local showProfession = context:GetFieldVisible("professionCooldown")
    local showFarm = context:GetFieldVisible("farmOperation")
    local showNomi = context:GetFieldVisible("nomi")
    local showCommon = context:GetFieldVisible("commonProjects")
    local hasCommon = showCommon and HasCommonProjects(snapshot, context.characters)
    local hasFarm = showFarm and HasFarmColumn()
    local hasNomi = showNomi and HasNomiColumn()
    local characterWidth, professionWidth, farmWidth, nomiWidth, commonWidth = Layout(CharacterColumnWidth(context), ProfessionColumnWidth(snapshot, context.characters), hasFarm, hasNomi, hasCommon)
    local tableWidth = characterWidth + (showProfession and professionWidth or 0) + farmWidth + nomiWidth + commonWidth
    local inset = Theme:GetMatrixInsets(context.preview)
    for _, row in ipairs(frame.rows) do row:Hide() end
    frame.header:ClearAllPoints(); frame.header:SetPoint("TOPLEFT", frame, "TOPLEFT", inset.left, -inset.top); frame.header:SetSize(tableWidth, Theme.Table.headerHeight)
    local columns = { { "角色", characterWidth } }
    if showProfession then
        columns[#columns + 1] = { "专业CD", professionWidth }
    end
    if hasFarm then columns[#columns + 1] = { "农场", farmWidth } end
    if hasNomi then columns[#columns + 1] = { "诺米", nomiWidth } end
    if hasCommon then columns[#columns + 1] = { "通用项目", commonWidth } end
    local x = 0
    for index, definition in ipairs(columns) do
        local header = Header(frame, index); header:ClearAllPoints(); header:SetPoint("TOPLEFT", frame.header, "TOPLEFT", x, 0); header:SetSize(definition[2], Theme.Table.headerHeight)
        Theme:SetMatrixHeader(header, definition[1], { height=Theme.Table.headerHeight, fill=C.toolbar, rule=C.lineSoft }); header:Show(); x = x + definition[2]
    end
    Release(frame.headers, #columns + 1)
    local accountProjects = snapshot.accountActivities or {}
    frame.account:SetShown(showCommon and #accountProjects > 0)
    local top = frame.header
    if showCommon and #accountProjects > 0 then
        frame.account:ClearAllPoints(); frame.account:SetPoint("TOPLEFT", frame.header, "BOTTOMLEFT", 0, -ROW_GAP); frame.account:SetSize(tableWidth, ROW_HEIGHT)
        frame.account:SetBackdropColor(C.row[1], C.row[2], C.row[3], C.row[4]); frame.account:SetBackdropBorderColor(C.matrixLine[1], C.matrixLine[2], C.matrixLine[3], C.matrixLine[4])
        frame.account.label:SetWidth(characterWidth - 8)
        frame.account.projects:Show()
        frame.account.projects:ClearAllPoints(); frame.account.projects:SetPoint("TOP", 0, 0); frame.account.projects:SetPoint("BOTTOM", 0, 0)
        frame.account.projects:SetPoint("LEFT", characterWidth, 0); frame.account.projects:SetPoint("RIGHT", 0, 0)
        RenderProjects(frame.account.projects, accountProjects)
        top = frame.account
    end
    local y = 0
    local current = Addon.Core.Characters:GetCurrent()
    for _, character in ipairs(context.characters or {}) do
        local data = snapshot.characters[character.id]
        if data then
            count = count + 1
            local row = Row(frame, count)
            row:ClearAllPoints(); row:SetPoint("TOPLEFT", frame.body, "TOPLEFT", 0, -y); row:SetSize(tableWidth, ROW_HEIGHT)
            local fill = Theme:GetDataRowColor(count)
            row:SetBackdropColor(fill[1], fill[2], fill[3], 0.9); row:SetBackdropBorderColor(C.matrixLine[1], C.matrixLine[2], C.matrixLine[3], C.matrixLine[4])
            Theme:SetCurrentCharacterOutline(row.currentOutline, current and character.id == current.id)
            row.name:ClearAllPoints(); row.name:SetPoint("LEFT", 8, 0); row.name:SetWidth(characterWidth - 8)
            row.name:SetText(CharacterLabel(character, context.scope == "all")); ApplyCharacterColor(row.name, character)
            Release(row.cells or {}, 1)
            if showProfession or hasFarm or hasNomi or hasCommon then
                local offset, nextCell = characterWidth, 1
                if showProfession then
                local profession = Cell(row, 1)
                profession:ClearAllPoints(); profession:SetPoint("LEFT", characterWidth, 0); profession:SetSize(professionWidth, ROW_HEIGHT)
                RenderProjects(profession, data.professionProjects or {})
                offset, nextCell = offset + professionWidth, nextCell + 1
                end
                if hasFarm then
                    local farm = Cell(row, nextCell)
                    farm:ClearAllPoints(); farm:SetPoint("LEFT", offset, 0); farm:SetSize(farmWidth, ROW_HEIGHT)
                    RenderProjects(farm, data.farmProjects or {})
                    offset, nextCell = offset + farmWidth, nextCell + 1
                end
                if hasNomi then
                    local nomi = Cell(row, nextCell)
                    nomi:ClearAllPoints(); nomi:SetPoint("LEFT", offset, 0); nomi:SetSize(nomiWidth, ROW_HEIGHT)
                    RenderProjects(nomi, data.nomiProjects or {})
                    offset, nextCell = offset + nomiWidth, nextCell + 1
                end
                if hasCommon then
                    local common = Cell(row, nextCell)
                    common:ClearAllPoints(); common:SetPoint("LEFT", offset, 0); common:SetSize(commonWidth, ROW_HEIGHT)
                    RenderProjects(common, data.commonProjects or {})
                end
                -- The catalog and Core's profession snapshot are enough to
                -- decide whether a project belongs to this character.  An
                -- empty monitored set is therefore a real empty state, not
                -- a request for another profession-panel scan.
                row.status:Hide()
            else
                row.status:Hide()
            end
            row:Show()
            y = y + ROW_HEIGHT + ROW_GAP
        end
    end
    frame.header:SetShown(count > 0)
    frame.scroll:SetShown(count > 0)
    if count > 0 then ConfigureScroll(frame, top, tableWidth, y, inset) end
    frame.emptyTitle:SetShown(count == 0); frame.empty:SetShown(count == 0)
    if count == 0 then
        frame.emptyTitle:ClearAllPoints(); frame.emptyTitle:SetPoint("TOPLEFT", 24, -26); frame.emptyTitle:SetText("等待角色快照")
        frame.empty:ClearAllPoints(); frame.empty:SetPoint("TOPLEFT", 24, -56); frame.empty:SetPoint("TOPRIGHT", -24, -56); frame.empty:SetText("YiboCore 尚未提供可显示角色。登录角色后，专业冷却与诺米任务日志会按各自的采集规则更新。")
    end
end

function Page.GetSurfaceMetrics(context)
    local snapshot, count = Addon.Snapshot:Build(), 0
    for _, character in ipairs((context and context.characters) or {}) do if snapshot.characters[character.id] then count = count + 1 end end
    local inset = Theme:GetMatrixInsets(context and context.preview)
    local showProfession = context and context.GetFieldVisible and context:GetFieldVisible("professionCooldown")
    local showFarm = context and context.GetFieldVisible and context:GetFieldVisible("farmOperation")
    local showNomi = context and context.GetFieldVisible and context:GetFieldVisible("nomi")
    local showCommon = context and context.GetFieldVisible and context:GetFieldVisible("commonProjects")
    local hasCommon = showCommon and HasCommonProjects(snapshot, context and context.characters)
    local hasFarm = showFarm and HasFarmColumn()
    local hasNomi = showNomi and HasNomiColumn()
    local accountHeight = showCommon and #(snapshot.accountActivities or {}) > 0 and ROW_HEIGHT + ROW_GAP or 0
    local visibleRows = math.max(1, math.min(20, count))
    local professionWidth = ProfessionColumnWidth(snapshot, context and context.characters)
    local tableWidth = CharacterColumnWidth(context) + (showProfession and professionWidth or 0) + (hasFarm and FARM_COLUMN_WIDTH or 0) + (hasNomi and NOMI_COLUMN_WIDTH or 0) + (hasCommon and MIN_PROJECT_COLUMN_WIDTH or 0)
    -- The scrollbar uses the page inset rather than a data-column gutter.
    -- The table width therefore remains the same with and without overflow.
    local projectsWidth = tableWidth + Theme.Space.sm * 2
    return {
        minContentWidth = (showProfession or hasFarm or hasNomi or hasCommon) and projectsWidth or 220,
        naturalContentWidth = (showProfession or hasFarm or hasNomi or hasCommon) and projectsWidth or 280,
        minContentHeight = 120,
        naturalContentHeight = inset.top + Theme.Table.headerHeight + accountHeight + ROW_GAP + visibleRows * (ROW_HEIGHT + ROW_GAP) + inset.bottom,
        horizontalOverflow = "none",
        verticalOverflow = "content",
    }
end

function Page.GetMeasuredHeight(frame)
    local pageHeight = frame:GetHeight() or 0
    local viewportHeight = frame.scroll and frame.scroll:GetHeight() or 0
    local bodyHeight = frame.body and frame.body:GetHeight() or 0
    if pageHeight <= 0 or viewportHeight <= 0 or bodyHeight <= 0 then return nil end
    return pageHeight - viewportHeight + bodyHeight
end

function Page.GetHoverMetrics(context)
    local metrics = Page.GetSurfaceMetrics(context)
    local shell = Theme.Geometry.shellBorder * 2
    return {
        minWidth = metrics.minContentWidth + shell,
        preferredWidth = metrics.naturalContentWidth + shell,
        minHeight = metrics.minContentHeight + Theme.Geometry.titleBar + shell,
        preferredHeight = metrics.naturalContentHeight + Theme.Geometry.titleBar + shell,
        horizontalOverflow = "content",
        verticalOverflow = "content",
    }
end
