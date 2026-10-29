local YQB = _G.YQB
if not (YQB and YQB.CoreCompatible) then return end
local Core = _G.YiboCore
local Theme = _G.YiboCore.UITheme

-- Core 页面只组合 QuestBlocker 已有的数据与业务操作；任务拦截、缓存和
-- SavedVariables 仍完全由 Core.lua 负责。
local Page = {}
YQB.AccountPage = Page

local ROW_H, GROUP_H, CHARACTER_COL_W, COMPACT_CHARACTER_COL_W, GLOBAL_W, STATUS_HIT = Theme.Table.rowHeight, Theme.Table.groupHeight, Theme:GetCharacterMatrixColumnWidth(), Theme:GetCharacterMatrixColumnWidth(), 36, 20
local COLORS = Theme.Colors

local function Text(parent, template, color, size)
    local font = parent:CreateFontString(nil, "OVERLAY", template or "GameFontNormalSmall")
    Theme:ApplyTextStyle(font, size or (template == "GameFontNormalLarge" and Theme.Font.title or Theme.Font.assist))
    font:SetJustifyH("LEFT")
    font:SetJustifyV("MIDDLE")
    if color then font:SetTextColor(color[1], color[2], color[3]) end
    return font
end

local function Button(parent, label, width)
    return Theme:CreateButton(parent, width or 84, label)
end

local function Check(parent, label)
    return Theme:CreateCheckbox(parent, label)
end

local function StatusCheck(parent)
    local check = Check(parent, "")
    check:SetSize(STATUS_HIT, STATUS_HIT)
    check.box:ClearAllPoints(); check.box:SetPoint("CENTER")
    check.label:Hide()
    check.mark:SetVertexColor(COLORS.text[1], COLORS.text[2], COLORS.text[3])
    -- Matrix states use red/teal semantics; the generic green hover outline
    -- would otherwise make a blocked state look briefly unblocked.
    check.disableHoverAccent = true
    return check
end

local function CharacterDisplayName(characterID)
    local character = Core.Characters:Get(characterID, { identityOnly = true })
    if not character then return "?" end
    return Core.Characters:FormatName(character, { nameMode = "short" }) or character.name or "?"
end

local function DB()
    return YQB.GetDatabase and YQB.GetDatabase() or _G.YiboQuestBlockerDB or {}
end

local function IsGroupExpanded(groupKey)
    local settings = DB().settings or {}
    settings.groupExpanded = settings.groupExpanded or { blocked = true, current = true }
    return settings.groupExpanded[groupKey] ~= false
end

local function SetGroupExpanded(instance, groupKey, expanded)
    local db = DB()
    db.settings = db.settings or {}
    db.settings.groupExpanded = db.settings.groupExpanded or { blocked = true, current = true }
    db.settings.groupExpanded[groupKey] = expanded == true
    YQB.PersistDB()
    if instance.context and instance.context.preview and Core.Entry and Core.Entry.SuppressPreviewClose then
        Core.Entry:SuppressPreviewClose(0.75)
    end
    if instance.context then
        instance.context:Refresh()
        -- Re-measure once the scroll child has received the new row count.
        -- The first refresh updates the matrix immediately; the next frame
        -- lets Core's measured-height pass shrink or grow the outer shell too.
        if C_Timer and C_Timer.After then
            C_Timer.After(0, function()
                if instance:IsShown() and instance.context then instance.context:Refresh() end
            end)
        end
    end
end

local function ClassColor(characterID)
    local character = _G.YiboCore.Characters:Get(characterID, { identityOnly = true })
    local class = character and character.class
    return class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] or COLORS.text
end

local function CharacterWidth(instance)
    return instance.characterColumnWidth or CHARACTER_COL_W
end

local function IsAllRealms(context)
    return context and context.scope == "all"
end

local function ScopeControlsWidth(context)
    return 40 + (#(context and context.scopeDefinition and context.scopeDefinition.values or {}) * 96)
end

local function PreferredCharacterWidth(context)
    return Theme:GetCharacterMatrixColumnWidth(context)
end

local function ClearRows(instance)
    for _, row in ipairs(instance.rows) do row:Hide() end
    instance.rowCount = 0
    instance.dataRowCount = 0
end

local function Row(instance)
    instance.rowCount = instance.rowCount + 1
    local index = instance.rowCount
    local row = instance.rows[index]
    if not row then
        row = CreateFrame("Frame", nil, instance.content, "BackdropTemplate")
        row:SetHeight(ROW_H)
        row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        row.task = Text(row, "GameFontNormalSmall", COLORS.text, Theme.Font.body); row.task:SetPoint("LEFT", 8, 0)
        row.global = StatusCheck(row)
        row.cells = {}
        row.characterBands = {}
        row.characterBandEdges = {}
        instance.rows[index] = row
    end
    row:ClearAllPoints(); row:SetPoint("TOPLEFT", instance.content, "TOPLEFT", 0, -((index - 1) * ROW_H))
    row:SetPoint("RIGHT", instance.content, "RIGHT", 0, 0)
    row:Show()
    return row
end

local function SetCharacterBands(row, characters, startX, characterWidth, showCharacters)
    if not showCharacters then
        for _, tint in ipairs(row.columnTints or {}) do tint:Hide() end
        return
    end
    local columns = {}
    for _ = 1, #(characters or {}) do columns[#columns + 1] = characterWidth end
    Theme:ApplyDataColumnTints(row, columns, ROW_H, startX)
end

local function FinishCharacterColumnBorder(instance, characters)
    -- Positioning happens after the content height is known in Refresh.
end

local function AddCell(row, index)
    local cell = row.cells[index]
    if not cell then
        cell = StatusCheck(row)
        row.cells[index] = cell
    end
    return cell
end

local function SetStatusCheckbox(button, blocked, currentCharacter)
    button.blocked = blocked
    button.currentCharacter = currentCharacter == true
    button.visualizer = function(control)
        if control.blocked then
            control.box:SetBackdropColor(COLORS.blocked[1], COLORS.blocked[2], COLORS.blocked[3], COLORS.blocked[4])
            control.box:SetBackdropBorderColor(COLORS.danger[1], COLORS.danger[2], COLORS.danger[3], 0.92)
        else
            control.box:SetBackdropColor(COLORS.chrome[1], COLORS.chrome[2], COLORS.chrome[3], 0.96)
            control.box:SetBackdropBorderColor(COLORS.line[1], COLORS.line[2], COLORS.line[3], 0.72)
        end
    end
    button:SetChecked(blocked)
end

local function Header(instance, characters, showGlobal, showCharacters, context)
    local showRealms = IsAllRealms(context)
    local headerHeight = Theme:GetCharacterHeaderHeight(context)
    instance.header:SetHeight(headerHeight)
    instance.headerTask:SetWidth(instance.taskWidth - 12)
    instance.headerGlobal:SetShown(showGlobal)
    instance.headerGlobal:ClearAllPoints()
    if showGlobal then instance.headerGlobal:SetPoint("LEFT", instance.header, "LEFT", instance.taskWidth, 0) end
    for _, cell in ipairs(instance.headerCharacters) do cell:Hide() end
    local x = instance.taskWidth + (showGlobal and GLOBAL_W or 0)
    instance.currentCharacterX, instance.currentCharacterWidth = nil, nil
    local characterWidth = CharacterWidth(instance)
    if showCharacters then
        for index, key in ipairs(characters) do
            local cell = instance.headerCharacters[index]
            if not cell then
                cell = Theme:CreateMatrixHeader(instance.header)
                instance.headerCharacters[index] = cell
            end
            local color = ClassColor(key)
            Theme:SetCharacterHeader(cell, instance.characterRecords[key], context, { color=color })
            cell:ClearAllPoints(); cell:SetPoint("LEFT", instance.header, "LEFT", x, 0)
            cell:SetSize(characterWidth, headerHeight)
            if key == YQB.GetCurrentCharacterID() then
                instance.currentCharacterX, instance.currentCharacterWidth = x, characterWidth
            end
            cell:Show()
            x = x + characterWidth
        end
    end
end

local function RenderQuest(instance, item, characters, showGlobal, showCharacters, currentTask)
    local row = Row(instance)
    instance.dataRowCount = instance.dataRowCount + 1
    if row.groupArrow then row.groupArrow:Hide() end
    row.task:ClearAllPoints(); row.task:SetPoint("LEFT", row, "LEFT", 8, 0)
    row.task:SetText("[" .. item.id .. "] " .. tostring(item.name or YQB.T("PAGE.UNKNOWN_QUEST")))
    row.task:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3])
    row.task:SetWidth(instance.taskWidth - 12)
    -- Keep row parity readable even for the current-task group. Its border
    -- carries that state, so the fill remains comparable with adjacent rows.
    local tone = Theme:GetDataRowColor(instance.dataRowCount)
    row:SetBackdropColor(tone[1], tone[2], tone[3], 0.94)
    local rowBorder = currentTask and COLORS.line or COLORS.matrixLine
    row:SetBackdropBorderColor(rowBorder[1], rowBorder[2], rowBorder[3], rowBorder[4])
    local status = YQB.GetBlockStatus(item.id)
    local x = instance.taskWidth
    local characterWidth = CharacterWidth(instance)
    row.global:ClearAllPoints(); row.global:SetShown(showGlobal)
    if showGlobal then
        row.global:SetPoint("LEFT", row, "LEFT", x + math.floor((GLOBAL_W - STATUS_HIT) / 2), 0); SetStatusCheckbox(row.global, status.global, false)
        row.global:SetScript("OnClick", function()
            if status.global then YQB.RemoveBlock(item.id, "global") else YQB.AddBlock(item.id, "global") end
        end)
        x = x + GLOBAL_W
    end
    local characterStartX = x
    SetCharacterBands(row, characters, characterStartX, characterWidth, showCharacters)
    for index, key in ipairs(characters) do
        local cell = AddCell(row, index); cell:ClearAllPoints(); cell:SetPoint("LEFT", row, "LEFT", x + math.floor((characterWidth - STATUS_HIT) / 2), 0)
        cell:SetShown(showCharacters); SetStatusCheckbox(cell, status[key], key == YQB.GetCurrentCharacterID())
        cell:SetScript("OnClick", function()
            if status[key] then YQB.RemoveCharBlock(item.id, key) else YQB.AddCharBlock(item.id, key) end
        end)
        x = x + characterWidth
    end
    for index = #characters + 1, #row.cells do row.cells[index]:Hide() end
end

local function RenderGroup(instance, title, characters, showGlobal, showCharacters, groupKey)
    local row = Row(instance)
    local expanded = IsGroupExpanded(groupKey)
    row.groupArrow = row.groupArrow or row:CreateTexture(nil, "OVERLAY")
    row.groupArrow:SetSize(16, 16)
    row.groupArrow:SetPoint("LEFT", row, "LEFT", 6, 0)
    row.groupArrow:SetTexture(expanded and "Interface\\Buttons\\UI-MinusButton-Up" or "Interface\\Buttons\\UI-PlusButton-Up")
    row.groupArrow:SetVertexColor(COLORS.accent[1], COLORS.accent[2], COLORS.accent[3], 1)
    row.groupArrow:Show()
    row.task:ClearAllPoints(); row.task:SetPoint("LEFT", row, "LEFT", 28, 0)
    row.task:SetText(title); row.task:SetWidth(600)
    row.task:SetTextColor(COLORS.accent[1], COLORS.accent[2], COLORS.accent[3])
    row:SetBackdropColor(COLORS.toolbar[1], COLORS.toolbar[2], COLORS.toolbar[3], 0.98)
    row:SetBackdropBorderColor(COLORS.matrixLine[1], COLORS.matrixLine[2], COLORS.matrixLine[3], COLORS.matrixLine[4])
    row.global:Hide(); for _, cell in ipairs(row.cells) do cell:Hide() end
    SetCharacterBands(row, characters or {}, instance.taskWidth + (showGlobal and GLOBAL_W or 0), CharacterWidth(instance), showCharacters)
    row:EnableMouse(true)
    row:SetScript("OnMouseUp", function()
        SetGroupExpanded(instance, groupKey, not IsGroupExpanded(groupKey))
    end)
    return expanded
end

function Page.Create(instance)
    local mainInset = Theme:GetMatrixInsets(false)
    instance.title = Text(instance, "GameFontNormalLarge", COLORS.text); instance.title:Hide()
    instance.summary = Text(instance, "GameFontNormalSmall", COLORS.muted); instance.summary:Hide()
    instance.toolbar = CreateFrame("Frame", nil, instance, "BackdropTemplate"); instance.toolbar:SetPoint("TOPLEFT", mainInset.left, -mainInset.top); instance.toolbar:SetPoint("TOPRIGHT", -mainInset.right, -mainInset.top); instance.toolbar:SetHeight(Theme.Size.standard)
    instance.toolbar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    instance.toolbar:SetBackdropColor(COLORS.toolbar[1], COLORS.toolbar[2], COLORS.toolbar[3], 0.9); instance.toolbar:SetBackdropBorderColor(COLORS.line[1], COLORS.line[2], COLORS.line[3], 0.52)
    instance.daily = Check(instance.toolbar, YQB.T("PAGE.DAILY")); instance.daily:SetPoint("LEFT", 7, 0)
    instance.normal = Check(instance.toolbar, YQB.T("PAGE.NORMAL")); instance.normal:SetPoint("LEFT", instance.daily.label, "RIGHT", Theme.Space.sm, 0)
    instance.hideComplete = Check(instance.toolbar, YQB.T("PAGE.HIDE_COMPLETE")); instance.hideComplete:SetPoint("LEFT", instance.normal.label, "RIGHT", Theme.Space.sm, 0)
    instance.processMode = Theme:CreateDropdown(instance.toolbar, 156, YQB.GetProcessModeOptions()); instance.processMode:SetPoint("LEFT", instance.hideComplete.label, "RIGHT", Theme.Space.sm, 0)
    instance.level = Theme:CreateInput(instance.toolbar, {
        width = 104, height = 20, maxLetters = 80, placeholder = YQB.T("PAGE.LEVEL"),
        Validate = function(text)
            local valid, normalized, badToken = YQB.ValidateLevelExpr(text)
            if valid then return true end
            return false, YQB.T("PAGE.INVALID_LEVEL", tostring(badToken or text))
        end,
        OnInvalid = function(message) Core:Print(message) end,
        OnSubmit = function(text, input)
            local valid, normalized = YQB.ValidateLevelExpr(text)
            if valid then DB().filters.levelExpr = normalized; YQB.PersistDB(); if instance.context then instance.context:Refresh() end end
        end,
    })
    instance.level:SetPoint("RIGHT", -7, 0)
    instance.levelLabel = Text(instance.toolbar, "GameFontNormalSmall", COLORS.muted); instance.levelLabel:SetPoint("RIGHT", instance.level, "LEFT", -6, 0); instance.levelLabel:SetText(YQB.T("PAGE.LEVEL"))
    instance.header = CreateFrame("Frame", nil, instance); instance.header:SetPoint("TOPLEFT", instance.toolbar, "BOTTOMLEFT", 0, -Theme.Space.sm); instance.header:SetPoint("TOPRIGHT", instance.toolbar, "BOTTOMRIGHT", 0, -Theme.Space.sm); instance.header:SetHeight(GROUP_H)
    instance.header.bg = instance.header:CreateTexture(nil, "BACKGROUND"); instance.header.bg:SetAllPoints(); instance.header.bg:SetColorTexture(COLORS.chrome[1], COLORS.chrome[2], COLORS.chrome[3], 0.98)
    instance.headerTask = Text(instance.header, "GameFontNormalSmall", COLORS.muted); instance.headerTask:SetPoint("LEFT", 8, 0); instance.headerTask:SetText(YQB.T("PAGE.QUEST"))
    instance.headerGlobal = Text(instance.header, "GameFontNormalSmall", COLORS.muted); instance.headerGlobal:SetWidth(GLOBAL_W); instance.headerGlobal:SetJustifyH("CENTER"); instance.headerGlobal:SetText(YQB.T("PAGE.GLOBAL"))
    instance.scroll = Theme:CreateScrollFrame(instance); instance.scroll:BindScrollbarGutter(instance.header); instance.scroll:SetPoint("TOPLEFT", instance.header, "BOTTOMLEFT", 0, -Theme.Space.xs)
    instance.content = CreateFrame("Frame", nil, instance.scroll); instance.content:SetWidth(700); instance.scroll:SetScrollChild(instance.content)
    instance.currentCharacterOutline = Theme:CreateCurrentCharacterOutline(instance)
    instance.rows, instance.headerCharacters, instance.rowCount = {}, {}, 0
    instance.scopeButtons = {}
    instance.addPanel = CreateFrame("Frame", nil, instance, "BackdropTemplate"); instance.addPanel:SetPoint("BOTTOMLEFT", mainInset.left, mainInset.bottom); instance.addPanel:SetPoint("BOTTOMRIGHT", -mainInset.right, mainInset.bottom); instance.addPanel:SetHeight(29)
    instance.scroll:SetPoint("BOTTOMRIGHT", instance.addPanel, "TOPRIGHT", 0, Theme.Space.sm)
    instance.addPanel:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 }); instance.addPanel:SetBackdropColor(COLORS.toolbar[1], COLORS.toolbar[2], COLORS.toolbar[3], 0.9); instance.addPanel:SetBackdropBorderColor(COLORS.line[1], COLORS.line[2], COLORS.line[3], 0.52)
    instance.manualLabel = Text(instance.addPanel, "GameFontNormalSmall", COLORS.muted, Theme.Font.assist); instance.manualLabel:SetPoint("LEFT", 7, 0); instance.manualLabel:SetText(YQB.T("PAGE.QUEST_ID"))
    instance.manual = Theme:CreateInput(instance.addPanel, { width = 108, height = 20, maxLetters = 12, numeric = true })
    instance.manual:SetPoint("LEFT", instance.manualLabel, "RIGHT", 6, 0)
    instance.addChar = Button(instance.addPanel, YQB.T("PAGE.ADD_CURRENT"), 92); instance.addChar:SetPoint("LEFT", instance.manual, "RIGHT", 8, 0)
    instance.addGlobal = Button(instance.addPanel, YQB.T("PAGE.ADD_GLOBAL"), 68); instance.addGlobal:SetPoint("LEFT", instance.addChar, "RIGHT", 6, 0)
    instance.abandon = Button(instance.addPanel, YQB.T("PAGE.ABANDON"), 174); instance.abandon:SetPoint("RIGHT", -7, 0)
    local function RefreshFromControl() if instance.context then instance.context:Refresh() end end
    instance.daily:SetScript("OnClick", function(self) self:SetChecked(not self:GetChecked()); DB().filters.showDaily = self:GetChecked(); YQB.PersistDB(); RefreshFromControl() end)
    instance.normal:SetScript("OnClick", function(self) self:SetChecked(not self:GetChecked()); DB().filters.showNormal = self:GetChecked(); YQB.PersistDB(); RefreshFromControl() end)
    instance.hideComplete:SetScript("OnClick", function(self) self:SetChecked(not self:GetChecked()); DB().filters.hideComplete = self:GetChecked(); YQB.PersistDB(); RefreshFromControl() end)
    instance.processMode:SetOnValueChanged(function(mode)
        YQB.SetProcessMode(mode); RefreshFromControl()
    end)
    local function Add(scope)
        local id = tonumber(instance.manual:GetText()); if not id then return end
        YQB.AddBlock(id, scope); instance.manual:SetValue("")
    end
    instance.addChar:SetScript("OnClick", function() Add("char") end)
    instance.addGlobal:SetScript("OnClick", function() Add("global") end)
    instance.abandon:SetScript("OnClick", function()
        if not YQB.IsProcessingPaused() then YQB.AbandonRejectedQuestsInLog() end
    end)
end

function Page.Refresh(instance, context)
    instance.context = context
    local db, filters = DB(), DB().filters or {}
    local preview = context.preview == true
    instance.title:Hide(); instance.summary:Hide()
    instance.toolbar:SetShown(not preview); instance.addPanel:SetShown(not preview)
    instance.daily:SetShown(not preview); instance.daily.label:SetShown(not preview)
    instance.normal:SetShown(not preview); instance.normal.label:SetShown(not preview)
    instance.hideComplete:SetShown(not preview); instance.hideComplete.label:SetShown(not preview)
    -- Character admission is configured centrally in Core 常规设置 → 角色过滤.
    instance.level:Hide(); instance.levelLabel:Hide()
    instance.manualLabel:SetShown(not preview); instance.manual:SetShown(not preview); instance.addChar:SetShown(not preview); instance.addGlobal:SetShown(not preview); instance.abandon:SetShown(not preview)
    for _, control in ipairs(instance.scopeButtons or {}) do control:Hide() end
    instance.header:ClearAllPoints(); instance.scroll:ClearAllPoints()
    local inset = Theme:GetMatrixInsets(preview)
    if preview then
        -- Preview state belongs in Core's title-bar action slot.  This keeps
        -- the compact hover projection focused on the matrix itself.
        context:SetTitleBarControl(instance.processMode, 156)
        instance.header:SetPoint("TOPLEFT", instance, "TOPLEFT", inset.left, -inset.top); instance.header:SetPoint("TOPRIGHT", instance, "TOPRIGHT", -inset.right, -inset.top)
        instance.scroll:SetPoint("TOPLEFT", instance.header, "BOTTOMLEFT", 0, -Theme.Space.xs); instance.scroll:SetPoint("BOTTOMRIGHT", -inset.right, inset.bottom)
    else
        -- Main-page controls are explicit fixed regions.  The matrix follows
        -- the toolbar by the documented 12px gap and stops 12px above the
        -- persistent bottom action panel; that panel itself keeps the 20px
        -- shell-bottom inset.
        context:ClearTitleBarControl()
        instance.processMode:SetParent(instance.toolbar)
        local mainInset = Theme:GetMatrixInsets(false)
        instance.toolbar:ClearAllPoints(); instance.toolbar:SetPoint("TOPLEFT", mainInset.left, -mainInset.top); instance.toolbar:SetPoint("TOPRIGHT", -mainInset.right, -mainInset.top)
        instance.processMode:ClearAllPoints(); instance.processMode:SetPoint("LEFT", instance.hideComplete.label, "RIGHT", Theme.Space.sm, 0)
        instance.processMode:Show()
        instance.header:SetPoint("TOPLEFT", instance.toolbar, "BOTTOMLEFT", 0, -Theme.Space.sm); instance.header:SetPoint("TOPRIGHT", instance.toolbar, "BOTTOMRIGHT", 0, -Theme.Space.sm)
        instance.scroll:SetPoint("TOPLEFT", instance.header, "BOTTOMLEFT", 0, -Theme.Space.xs); instance.scroll:SetPoint("BOTTOMRIGHT", instance.addPanel, "TOPRIGHT", 0, Theme.Space.sm)
    end
    instance.title:SetText(YQB.T("PAGE.TITLE"))
    instance.daily:SetChecked(filters.showDaily); instance.normal:SetChecked(filters.showNormal); instance.hideComplete:SetChecked(filters.hideComplete)
    instance.processMode:SetValue(YQB.GetProcessMode())
    local paused = YQB.IsProcessingPaused()
    instance.abandon:SetState(paused and "disabled" or "default")
    instance.abandon:SetText(paused and YQB.T("PAGE.PAUSED_ABANDON") or YQB.T("PAGE.ABANDON"))
    instance.level:SetValue(filters.levelExpr or "")
    local globalCount, charCount, total = YQB.GetStats()
    instance.summary:SetText(YQB.T("PAGE.SUMMARY", globalCount, charCount, total))
    local allCharacters, characters = {}, {}
    instance.characterRecords = instance.characterRecords or {}
    for _, character in ipairs(context.characters or {}) do
        allCharacters[#allCharacters + 1] = character
        instance.characterRecords[character.id] = character
    end
    local showGlobal = context:GetFieldVisible("global")
    -- Hover is the same complete account projection as the main matrix.
    -- Its cells remain interactive while the pointer stays within the preview.
    local showCharacters = context:GetFieldVisible("characters")
    instance.taskWidth = 250
    local fixedWidth = instance.taskWidth + (showGlobal and GLOBAL_W or 0)
    local metrics = Page.GetSurfaceMetrics(context)
    local availableWidth = math.max(1, Core.AccountView:GetScrollSurfaceWidth(context, instance, metrics.scrollContentHeight, metrics.scrollFixedHeight) - inset.left - inset.right)
    local visibleCharacters, pageInfo = allCharacters, nil
    if showCharacters then
        visibleCharacters, pageInfo = Core.AccountView:GetColumnPage("quest-blocker", "characters", allCharacters, availableWidth, fixedWidth, Theme:GetCharacterMatrixColumnWidth(context), YQB.GetCurrentCharacterID())
    end
    Core.AccountView:UpdateColumnPager(instance, "quest-blocker", "characters", pageInfo, instance.header, YQB.T("PAGE.CHARACTER"))
    for _, character in ipairs(visibleCharacters) do characters[#characters + 1] = character.id end
    -- Character columns must remain directly comparable across every account
    -- page.  Do not stretch a short roster into wider, page-specific cells.
    instance.characterColumnWidth = Theme:GetCharacterMatrixColumnWidth(context)
    Header(instance, characters, showGlobal, showCharacters, context)
    ClearRows(instance)
    local blocked = YQB.GetBlockedQuestList()
    local blockedExpanded = RenderGroup(instance, YQB.T("PAGE.BLOCKED_GROUP", #blocked), characters, showGlobal, showCharacters, "blocked")
    if blockedExpanded then
        for _, item in ipairs(blocked) do RenderQuest(instance, item, characters, showGlobal, showCharacters, false) end
    end
    local current = YQB.GetCurrentQuestList()
    local currentVisible = false
    for _, character in ipairs(allCharacters) do if character.id == YQB.GetCurrentCharacterID() then currentVisible = true; break end end
    if currentVisible then
        local currentExpanded = RenderGroup(instance, YQB.T("PAGE.CURRENT_GROUP", CharacterDisplayName(YQB.GetCurrentCharacterID())), characters, showGlobal, showCharacters, "current")
        if currentExpanded then
            for _, item in ipairs(current) do
                if not YQB.IsQuestBlockedByAny(item.id) then RenderQuest(instance, item, characters, showGlobal, showCharacters, true) end
            end
        end
    end
    FinishCharacterColumnBorder(instance, characters)
    -- Keep the scroll child exactly aligned with the rendered matrix.  Using a
    -- wider value here leaves trailing space after the final character and
    -- makes that column appear wider, especially beside mixed CJK/Latin names.
    local width = instance.taskWidth + (showGlobal and GLOBAL_W or 0) + (showCharacters and #characters * CharacterWidth(instance) or 0)
    -- The hover preview stays content-sized.  In the main window, extend row
    -- surfaces across the viewport so a small character set still reads as
    -- one table instead of an abruptly truncated block beside empty space.
    local contentWidth
    if preview then
        -- Keep the preview matrix content-sized.  The scroll frame is wider by
        -- one dedicated gutter; painting rows into that gutter made it look
        -- like a nameless character column, especially with few characters.
        contentWidth = width
    else
        contentWidth = math.max(480, width, instance.scroll:GetWidth() or 0)
    end
    instance.content:SetWidth(contentWidth); instance.content:SetHeight(math.max(44, instance.rowCount * ROW_H))
    instance.scroll:SetContentHeight(instance.content:GetHeight())
    Theme:UpdateCurrentCharacterColumnOutline(instance.currentCharacterOutline, instance.header, instance.scroll, instance.currentCharacterX, instance.currentCharacterWidth, showCharacters and instance.currentCharacterX ~= nil)
    if preview then instance.scroll:SetVerticalScroll(0) end
    instance.scroll:RefreshScrollbar()
end

function Page.GetSurfaceMetrics(context)
    local fixedWidth = 250 + (context:GetFieldVisible("global") and GLOBAL_W or 0)
    local characterCount = #(context.characters or {})
    local columnWidth = PreferredCharacterWidth(context)
    -- Metrics describe the complete role matrix.  AccountView expands the
    -- outer window to its safe screen edge before the shared pager selects a
    -- subset of these character columns for rendering.
    local characterColumns = context:GetFieldVisible("characters") and (characterCount * columnWidth) or 0
    local globalColumn = context:GetFieldVisible("global") and GLOBAL_W or 0
    local blocked = #(YQB.GetBlockedQuestList() or {})
    local characters, currentKey, currentVisible = context.characters or {}, YQB.GetCurrentCharacterID(), false
    for _, character in ipairs(characters) do
        if character.id == currentKey then currentVisible = true; break end
    end
    local current = 0
    if currentVisible then
        for _, item in ipairs(YQB.GetCurrentQuestList() or {}) do
            if not YQB.IsQuestBlockedByAny(item.id) then current = current + 1 end
        end
    end
    local rows = (IsGroupExpanded("blocked") and (blocked + 1) or 1)
    if currentVisible then
        rows = rows + (IsGroupExpanded("current") and (current + 1) or 1)
    end
    local mainInset = Theme:GetMatrixInsets(false)
    local previewInset = Theme:GetMatrixInsets(true)
    -- The hover shell is content-sized.  Its table already anchors to the
    -- preview matrix inset, so using the full main-page `Space.lg` margin here
    -- created a visibly wider blank tail after the last character column.
    local sideInset = context.preview and previewInset or mainInset
    -- The fixed regions mirror the actual anchors in Refresh: toolbar,
    -- header, data gap, bottom action panel, and the shared shell insets.
    -- Keeping this formula structural prevents a future title/control change
    -- from creating a window taller than the matrix it contains.
    local headerHeight = Theme:GetCharacterHeaderHeight(context)
    local mainFixedHeight = mainInset.top + Theme.Size.standard + Theme.Space.sm + headerHeight + Theme.Space.xs + Theme.Space.sm + 29 + mainInset.bottom
    local previewFixedHeight = previewInset.top + headerHeight + Theme.Space.xs + previewInset.bottom
    return {
        minContentWidth = fixedWidth + (context:GetFieldVisible("characters") and COMPACT_CHARACTER_COL_W or 0) + sideInset.left + sideInset.right,
        naturalContentWidth = fixedWidth + characterColumns + sideInset.left + sideInset.right,
        minContentHeight = (context.preview and previewFixedHeight or mainFixedHeight) + ROW_H,
        naturalContentHeight = (context.preview and previewFixedHeight or mainFixedHeight) + rows * ROW_H,
        scrollContentHeight = math.max(44, rows * ROW_H),
        scrollFixedHeight = context.preview and previewFixedHeight or mainFixedHeight,
        fixedLeftWidth = 250 + globalColumn,
        fixedTopHeight = headerHeight,
        horizontalOverflow = "paginate",
        verticalOverflow = "content",
    }
end

function Page.GetMeasuredHeight(instance)
    local pageHeight = instance:GetHeight() or 0
    local viewportHeight = instance.scroll and instance.scroll:GetHeight() or 0
    local bodyHeight = instance.content and instance.content:GetHeight() or 0
    if pageHeight <= 0 or viewportHeight <= 0 or bodyHeight <= 0 then return nil end
    return pageHeight - viewportHeight + bodyHeight
end

-- Legacy readers can keep loading during the API-v5 migration. New pages use
-- the content-only contract above, so these adapters no longer drive layout.
function Page.GetPreviewSize(context)
    local metrics = Page.GetSurfaceMetrics(context)
    return metrics.naturalContentWidth + 2, metrics.naturalContentHeight + Theme.Geometry.titleBar + 2
end

function Page.GetLayoutMetrics(context)
    local metrics = Page.GetSurfaceMetrics(context)
    local geometry = Theme.Geometry
    local shellWidth = geometry.navigation + geometry.shellBorder * 2 + 1
    local shellHeight = geometry.titleBar + geometry.shellBorder * 2
    return { minWidth = metrics.minContentWidth + shellWidth, preferredWidth = metrics.naturalContentWidth + shellWidth, minHeight = metrics.minContentHeight + shellHeight, preferredHeight = metrics.naturalContentHeight + shellHeight, horizontalOverflow = metrics.horizontalOverflow, verticalOverflow = metrics.verticalOverflow }
end

function Page.GetHoverMetrics(context)
    local metrics = Page.GetSurfaceMetrics(context)
    local shell = Theme.Geometry.shellBorder * 2
    return { minWidth = 420, preferredWidth = metrics.naturalContentWidth + shell,
        minHeight = metrics.minContentHeight + Theme.Geometry.titleBar + shell, preferredHeight = metrics.naturalContentHeight + Theme.Geometry.titleBar + shell,
        scrollContentHeight = metrics.scrollContentHeight, scrollFixedHeight = metrics.scrollFixedHeight,
        horizontalOverflow = "paginate", verticalOverflow = "content" }
end
