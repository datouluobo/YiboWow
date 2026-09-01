local YQB = _G.YQB
local Core = _G.YiboCore
local Theme = _G.YiboCore.UITheme

-- Core 页面只组合 QuestBlocker 已有的数据与业务操作；任务拦截、缓存和
-- SavedVariables 仍完全由 Core.lua 负责。
local Page = {}
YQB.AccountPage = Page

local ROW_H, GROUP_H, CHARACTER_COL_W, COMPACT_CHARACTER_COL_W, GLOBAL_W, STATUS_HIT = Theme.Table.rowHeight, Theme.Table.groupHeight, Theme.Table.characterColumnWidth, Theme.Table.characterColumnWidth, 36, 20
local PREVIEW_MARGIN, PREVIEW_SCROLLBAR_GUTTER, CORE_PREVIEW_BORDER = 16, 16, 2
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

local function ShortName(characterID)
    local character = _G.YiboCore.Characters:Get(characterID)
    return character and character.name or "?"
end

local function CharacterIdentity(character, fallbackKey)
    -- v2 uses Core character records.  The fallback only protects rendering
    -- while Core is promoting an early-login fallback ID to the player GUID.
    local key = tostring(fallbackKey or (type(character) == "string" and character) or "?")
    local keyName, keyRealm = key:match("^(.-)%-(.+)$")
    local name = type(character) == "table" and character.name or nil
    local realm = type(character) == "table" and character.realm or nil
    if not name or name == "" then name = keyName or key end
    if not realm or realm == "" then realm = keyRealm or "未知服务器" end
    return tostring(name), tostring(realm)
end

local function DB()
    return YQB.GetDatabase and YQB.GetDatabase() or _G.YiboQuestBlockerDB or {}
end

local function ClassColor(characterID)
    local character = _G.YiboCore.Characters:Get(characterID)
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
    if context and context.preview then return COMPACT_CHARACTER_COL_W end
    return IsAllRealms(context) and CHARACTER_COL_W or COMPACT_CHARACTER_COL_W
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
    -- The matrix owns one continuous current-character outline.  Per-row
    -- fills and stitched edges made the same role look different by row.
    for _, band in ipairs(row.characterBands or {}) do band:Hide() end
    for _, edges in ipairs(row.characterBandEdges or {}) do
        for _, edge in pairs(edges) do edge:Hide() end
    end
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
            local name, realm = CharacterIdentity(instance.characterRecords[key], key)
            local color = ClassColor(key)
            Theme:SetCharacterHeader(cell, instance.characterRecords[key], context, { name=name, realm=realm, color=color })
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
    row.task:SetText("[" .. item.id .. "] " .. tostring(item.name or "未知任务"))
    row.task:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3])
    row.task:SetWidth(instance.taskWidth - 12)
    local tone = currentTask and COLORS.current or Theme:GetDataRowColor(instance.dataRowCount)
    row:SetBackdropColor(tone[1], tone[2], tone[3], 0.94)
    row:SetBackdropBorderColor(COLORS.matrixLine[1], COLORS.matrixLine[2], COLORS.matrixLine[3], COLORS.matrixLine[4])
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

local function RenderGroup(instance, title, characters, showGlobal, showCharacters)
    local row = Row(instance)
    row.task:SetText("▾ " .. title); row.task:SetWidth(600)
    row.task:SetTextColor(COLORS.accent[1], COLORS.accent[2], COLORS.accent[3])
    row:SetBackdropColor(COLORS.toolbar[1], COLORS.toolbar[2], COLORS.toolbar[3], 0.98)
    row:SetBackdropBorderColor(COLORS.matrixLine[1], COLORS.matrixLine[2], COLORS.matrixLine[3], COLORS.matrixLine[4])
    row.global:Hide(); for _, cell in ipairs(row.cells) do cell:Hide() end
    SetCharacterBands(row, characters or {}, instance.taskWidth + (showGlobal and GLOBAL_W or 0), CharacterWidth(instance), showCharacters)
end

function Page.Create(instance)
    local mainInset = Theme:GetMatrixInsets(false)
    instance.title = Text(instance, "GameFontNormalLarge", COLORS.text); instance.title:Hide()
    instance.summary = Text(instance, "GameFontNormalSmall", COLORS.muted); instance.summary:Hide()
    instance.toolbar = CreateFrame("Frame", nil, instance, "BackdropTemplate"); instance.toolbar:SetPoint("TOPLEFT", mainInset.left, -mainInset.top); instance.toolbar:SetPoint("TOPRIGHT", -mainInset.right, -mainInset.top); instance.toolbar:SetHeight(Theme.Size.standard)
    instance.toolbar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    instance.toolbar:SetBackdropColor(COLORS.toolbar[1], COLORS.toolbar[2], COLORS.toolbar[3], 0.9); instance.toolbar:SetBackdropBorderColor(COLORS.line[1], COLORS.line[2], COLORS.line[3], 0.52)
    instance.daily = Check(instance.toolbar, "日常"); instance.daily:SetPoint("LEFT", 7, 0)
    instance.normal = Check(instance.toolbar, "普通"); instance.normal:SetPoint("LEFT", instance.daily.label, "RIGHT", Theme.Space.sm, 0)
    instance.hideComplete = Check(instance.toolbar, "隐藏已完成"); instance.hideComplete:SetPoint("LEFT", instance.normal.label, "RIGHT", Theme.Space.sm, 0)
    instance.autoAbandon = Check(instance.toolbar, "自动放弃"); instance.autoAbandon:SetPoint("LEFT", instance.hideComplete.label, "RIGHT", Theme.Space.sm, 0)
    instance.level = CreateFrame("EditBox", nil, instance.toolbar, "InputBoxTemplate"); instance.level:SetSize(104, 20); instance.level:SetPoint("RIGHT", -7, 0); instance.level:SetAutoFocus(false)
    instance.levelLabel = Text(instance.toolbar, "GameFontNormalSmall", COLORS.muted); instance.levelLabel:SetPoint("RIGHT", instance.level, "LEFT", -6, 0); instance.levelLabel:SetText("等级")
    instance.header = CreateFrame("Frame", nil, instance); instance.header:SetPoint("TOPLEFT", instance.toolbar, "BOTTOMLEFT", 0, -Theme.Space.sm); instance.header:SetPoint("TOPRIGHT", instance.toolbar, "BOTTOMRIGHT", 0, -Theme.Space.sm); instance.header:SetHeight(GROUP_H)
    instance.header.bg = instance.header:CreateTexture(nil, "BACKGROUND"); instance.header.bg:SetAllPoints(); instance.header.bg:SetColorTexture(COLORS.chrome[1], COLORS.chrome[2], COLORS.chrome[3], 0.98)
    instance.headerTask = Text(instance.header, "GameFontNormalSmall", COLORS.muted); instance.headerTask:SetPoint("LEFT", 8, 0); instance.headerTask:SetText("任务")
    instance.headerGlobal = Text(instance.header, "GameFontNormalSmall", COLORS.muted); instance.headerGlobal:SetWidth(GLOBAL_W); instance.headerGlobal:SetJustifyH("CENTER"); instance.headerGlobal:SetText("全局")
    instance.scroll = Theme:CreateScrollFrame(instance); instance.scroll:BindScrollbarGutter(instance.header); instance.scroll:SetPoint("TOPLEFT", instance.header, "BOTTOMLEFT", 0, -Theme.Space.xs)
    instance.content = CreateFrame("Frame", nil, instance.scroll); instance.content:SetWidth(700); instance.scroll:SetScrollChild(instance.content)
    instance.currentCharacterOutline = Theme:CreateCurrentCharacterOutline(instance)
    instance.rows, instance.headerCharacters, instance.rowCount = {}, {}, 0
    instance.scopeButtons = {}
    instance.addPanel = CreateFrame("Frame", nil, instance, "BackdropTemplate"); instance.addPanel:SetPoint("BOTTOMLEFT", mainInset.left, mainInset.bottom); instance.addPanel:SetPoint("BOTTOMRIGHT", -mainInset.right, mainInset.bottom); instance.addPanel:SetHeight(29)
    instance.scroll:SetPoint("BOTTOMRIGHT", instance.addPanel, "TOPRIGHT", 0, Theme.Space.sm)
    instance.addPanel:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 }); instance.addPanel:SetBackdropColor(COLORS.toolbar[1], COLORS.toolbar[2], COLORS.toolbar[3], 0.9); instance.addPanel:SetBackdropBorderColor(COLORS.line[1], COLORS.line[2], COLORS.line[3], 0.52)
    instance.manualLabel = Text(instance.addPanel, "GameFontNormalSmall", COLORS.muted, Theme.Font.assist); instance.manualLabel:SetPoint("LEFT", 7, 0); instance.manualLabel:SetText("任务 ID")
    instance.manual = CreateFrame("EditBox", nil, instance.addPanel, "InputBoxTemplate"); instance.manual:SetSize(108, 20); instance.manual:SetPoint("LEFT", instance.manualLabel, "RIGHT", 6, 0); instance.manual:SetAutoFocus(false); instance.manual:SetNumeric(true)
    instance.addChar = Button(instance.addPanel, "+ 当前角色", 92); instance.addChar:SetPoint("LEFT", instance.manual, "RIGHT", 8, 0)
    instance.addGlobal = Button(instance.addPanel, "+ 全局", 68); instance.addGlobal:SetPoint("LEFT", instance.addChar, "RIGHT", 6, 0)
    instance.abandon = Button(instance.addPanel, "放弃日志中的已拒绝任务", 174); instance.abandon:SetPoint("RIGHT", -7, 0)
    local function RefreshFromControl() if instance.context then instance.context:Refresh() end end
    instance.daily:SetScript("OnClick", function(self) self:SetChecked(not self:GetChecked()); DB().filters.showDaily = self:GetChecked(); YQB.PersistDB(); RefreshFromControl() end)
    instance.normal:SetScript("OnClick", function(self) self:SetChecked(not self:GetChecked()); DB().filters.showNormal = self:GetChecked(); YQB.PersistDB(); RefreshFromControl() end)
    instance.hideComplete:SetScript("OnClick", function(self) self:SetChecked(not self:GetChecked()); DB().filters.hideComplete = self:GetChecked(); YQB.PersistDB(); RefreshFromControl() end)
    instance.autoAbandon:SetScript("OnClick", function(self) self:SetChecked(not self:GetChecked()); DB().filters.autoAbandon = self:GetChecked(); YQB.PersistDB(); RefreshFromControl() end)
    instance.level:SetScript("OnEnterPressed", function(self)
        local valid, normalized = YQB.ValidateLevelExpr(self:GetText())
        if valid then DB().filters.levelExpr = normalized; YQB.PersistDB(); RefreshFromControl() end
        self:ClearFocus()
    end)
    local function Add(scope)
        local id = tonumber(instance.manual:GetText()); if not id then return end
        YQB.AddBlock(id, scope); instance.manual:SetText("")
    end
    instance.addChar:SetScript("OnClick", function() Add("char") end)
    instance.addGlobal:SetScript("OnClick", function() Add("global") end)
    instance.abandon:SetScript("OnClick", function() YQB.AbandonRejectedQuestsInLog() end)
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
    instance.autoAbandon:SetShown(not preview); instance.autoAbandon.label:SetShown(not preview)
    -- Character admission is configured centrally in Core 常规设置 → 角色过滤.
    instance.level:Hide(); instance.levelLabel:Hide()
    instance.manualLabel:SetShown(not preview); instance.manual:SetShown(not preview); instance.addChar:SetShown(not preview); instance.addGlobal:SetShown(not preview); instance.abandon:SetShown(not preview)
    for _, control in ipairs(instance.scopeButtons or {}) do control:Hide() end
    instance.header:ClearAllPoints(); instance.scroll:ClearAllPoints()
    local inset = Theme:GetMatrixInsets(preview)
    if preview then
        -- The preview has no local controls: its matrix starts at the preview
        -- top inset and ends at the preview bottom inset.
        instance.header:SetPoint("TOPLEFT", instance, "TOPLEFT", inset.left, -inset.top); instance.header:SetPoint("TOPRIGHT", instance, "TOPRIGHT", -inset.right, -inset.top)
        instance.scroll:SetPoint("TOPLEFT", instance.header, "BOTTOMLEFT", 0, -Theme.Space.xs); instance.scroll:SetPoint("BOTTOMRIGHT", -inset.right, inset.bottom)
    else
        -- Main-page controls are explicit fixed regions.  The matrix follows
        -- the toolbar by the documented 12px gap and stops 12px above the
        -- persistent bottom action panel; that panel itself keeps the 20px
        -- shell-bottom inset.
        instance.header:SetPoint("TOPLEFT", instance.toolbar, "BOTTOMLEFT", 0, -Theme.Space.sm); instance.header:SetPoint("TOPRIGHT", instance.toolbar, "BOTTOMRIGHT", 0, -Theme.Space.sm)
        instance.scroll:SetPoint("TOPLEFT", instance.header, "BOTTOMLEFT", 0, -Theme.Space.xs); instance.scroll:SetPoint("BOTTOMRIGHT", instance.addPanel, "TOPRIGHT", 0, Theme.Space.sm)
    end
    instance.title:SetText("任务屏蔽")
    instance.daily:SetChecked(filters.showDaily); instance.normal:SetChecked(filters.showNormal); instance.hideComplete:SetChecked(filters.hideComplete); instance.autoAbandon:SetChecked(filters.autoAbandon)
    instance.level:SetText(filters.levelExpr or "")
    local globalCount, charCount, total = YQB.GetStats()
    instance.summary:SetText(string.format("全局 %d · 当前 %d · 总计 %d", globalCount, charCount, total))
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
    local availableWidth = math.max(fixedWidth + COMPACT_CHARACTER_COL_W, (tonumber(context.surfaceAvailableWidth) or instance:GetWidth() or 1) - inset.left - inset.right)
    local visibleCharacters, pageInfo = Core.AccountView:GetColumnPage("quest-blocker", "characters", allCharacters, availableWidth, fixedWidth, COMPACT_CHARACTER_COL_W)
    for _, character in ipairs(visibleCharacters) do characters[#characters + 1] = character.id end
    -- Character columns must remain directly comparable across every account
    -- page.  Do not stretch a short roster into wider, page-specific cells.
    instance.characterColumnWidth = Theme.Table.characterColumnWidth
    Header(instance, characters, showGlobal, showCharacters, context)
    ClearRows(instance)
    local blocked = YQB.GetBlockedQuestList()
    RenderGroup(instance, "拒绝任务 (" .. #blocked .. " 个)", characters, showGlobal, showCharacters)
    for _, item in ipairs(blocked) do RenderQuest(instance, item, characters, showGlobal, showCharacters, false) end
    local current = YQB.GetCurrentQuestList()
    local currentVisible = false
    for _, key in ipairs(characters) do if key == YQB.GetCurrentCharacterID() then currentVisible = true; break end end
    if currentVisible then
        RenderGroup(instance, "当前角色任务 (" .. ShortName(YQB.GetCurrentCharacterID()) .. ")", characters, showGlobal, showCharacters)
        for _, item in ipairs(current) do
            if not YQB.IsQuestBlockedByAny(item.id) then RenderQuest(instance, item, characters, showGlobal, showCharacters, true) end
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
    instance.currentCharacterOutline:ClearAllPoints()
    if showCharacters and instance.currentCharacterX then
        instance.currentCharacterOutline:SetPoint("TOPLEFT", instance.header, "TOPLEFT", instance.currentCharacterX, 0)
        instance.currentCharacterOutline:SetPoint("BOTTOMRIGHT", instance.scroll, "BOTTOMLEFT", instance.currentCharacterX + instance.currentCharacterWidth, 0)
        Theme:SetCurrentCharacterOutline(instance.currentCharacterOutline, true)
    else
        Theme:SetCurrentCharacterOutline(instance.currentCharacterOutline, false)
    end
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
    local rows = blocked + 1 + (currentVisible and (current + 1) or 0)
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
    local width, height = Page.GetPreviewSize(context)
    return { minWidth = 420, preferredWidth = width, minHeight = 150, preferredHeight = height, horizontalOverflow = "paginate", verticalOverflow = "content" }
end
