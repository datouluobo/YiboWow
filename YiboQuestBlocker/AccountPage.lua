local YQB = _G.YQB
local Theme = _G.YiboCore.UITheme

-- Core 页面只组合 QuestBlocker 已有的数据与业务操作；任务拦截、缓存和
-- SavedVariables 仍完全由 Core.lua 负责。
local Page = {}
YQB.AccountPage = Page

local ROW_H, GROUP_H, CHARACTER_COL_W, COMPACT_CHARACTER_COL_W, GLOBAL_W, STATUS_HIT = Theme.Size.standard, Theme.Size.double, 92, 72, 40, 24
local PREVIEW_MARGIN, PREVIEW_SCROLLBAR_GUTTER, CORE_PREVIEW_BORDER = 16, 16, 2
local COLORS = Theme.Colors

local function Text(parent, template, color)
    local font = parent:CreateFontString(nil, "OVERLAY", template or "GameFontNormalSmall")
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
    return IsAllRealms(context) and CHARACTER_COL_W or COMPACT_CHARACTER_COL_W
end

local function ClearRows(instance)
    for _, row in ipairs(instance.rows) do row:Hide() end
    instance.rowCount = 0
end

local function Row(instance)
    instance.rowCount = instance.rowCount + 1
    local index = instance.rowCount
    local row = instance.rows[index]
    if not row then
        row = CreateFrame("Frame", nil, instance.content, "BackdropTemplate")
        row:SetHeight(ROW_H)
        row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        row.task = Text(row, "GameFontNormalSmall", COLORS.text); row.task:SetPoint("LEFT", 8, 0)
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
    local currentID = YQB.GetCurrentCharacterID()
    for index, key in ipairs(characters) do
        local band = row.characterBands[index]
        if not band then
            band = row:CreateTexture(nil, "ARTWORK", nil, -8)
            row.characterBands[index] = band
            local edges = {}
            edges.left = row:CreateTexture(nil, "ARTWORK", nil, -7)
            edges.right = row:CreateTexture(nil, "ARTWORK", nil, -7)
            edges.bottom = row:CreateTexture(nil, "ARTWORK", nil, -7)
            for _, edge in pairs(edges) do edge:SetColorTexture(COLORS.line[1], COLORS.line[2], COLORS.line[3], 0.82) end
            row.characterBandEdges[index] = edges
        end
        band:ClearAllPoints()
        band:SetPoint("TOPLEFT", row, "TOPLEFT", startX + ((index - 1) * characterWidth), 0)
        band:SetSize(characterWidth, ROW_H)
        band:SetColorTexture(COLORS.current[1], COLORS.current[2], COLORS.current[3], 0.46)
        local shown = showCharacters and key == currentID
        band:SetShown(shown)
        local edges = row.characterBandEdges[index]
        edges.left:ClearAllPoints(); edges.left:SetPoint("TOPLEFT", band, "TOPLEFT"); edges.left:SetPoint("BOTTOMLEFT", band, "BOTTOMLEFT"); edges.left:SetWidth(1)
        edges.right:ClearAllPoints(); edges.right:SetPoint("TOPRIGHT", band, "TOPRIGHT"); edges.right:SetPoint("BOTTOMRIGHT", band, "BOTTOMRIGHT"); edges.right:SetWidth(1)
        edges.bottom:ClearAllPoints(); edges.bottom:SetPoint("BOTTOMLEFT", band, "BOTTOMLEFT"); edges.bottom:SetPoint("BOTTOMRIGHT", band, "BOTTOMRIGHT"); edges.bottom:SetHeight(1)
        edges.left:SetShown(shown); edges.right:SetShown(shown); edges.bottom:Hide()
    end
    for index = #characters + 1, #row.characterBands do
        row.characterBands[index]:Hide()
        for _, edge in pairs(row.characterBandEdges[index]) do edge:Hide() end
    end
end

local function FinishCharacterColumnBorder(instance, characters)
    local currentID = YQB.GetCurrentCharacterID()
    local currentIndex
    for index, key in ipairs(characters) do if key == currentID then currentIndex = index break end end
    local lastRow = instance.rows[instance.rowCount]
    if currentIndex and lastRow and lastRow.characterBandEdges[currentIndex] then
        lastRow.characterBandEdges[currentIndex].bottom:Show()
    end
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
            control.box:SetBackdropBorderColor(COLORS.line[1], COLORS.line[2], COLORS.line[3], control.currentCharacter and 1 or 0.72)
        end
    end
    button:SetChecked(blocked)
end

local function Header(instance, characters, showGlobal, showCharacters, showRealms)
    instance.headerTask:SetWidth(instance.taskWidth - 12)
    instance.headerGlobal:SetShown(showGlobal)
    instance.headerGlobal:ClearAllPoints()
    if showGlobal then instance.headerGlobal:SetPoint("LEFT", instance.header, "LEFT", instance.taskWidth, 0) end
    for _, cell in ipairs(instance.headerCharacters) do cell:Hide() end
    local x = instance.taskWidth + (showGlobal and GLOBAL_W or 0)
    local characterWidth = CharacterWidth(instance)
    if showCharacters then
        for index, key in ipairs(characters) do
            local cell = instance.headerCharacters[index]
            if not cell then
                cell = CreateFrame("Frame", nil, instance.header, "BackdropTemplate")
                cell:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
                cell:EnableMouse(true)
                cell.name = Text(cell, "GameFontNormalSmall", COLORS.text)
                cell.name:SetJustifyH("CENTER"); cell.name:SetWordWrap(false)
                cell.name:SetPoint("TOPLEFT", cell, "TOPLEFT", 2, -5)
                cell.name:SetPoint("TOPRIGHT", cell, "TOPRIGHT", -2, -5)
                cell.name:SetHeight(16)
                cell.realm = Text(cell, "GameFontNormalSmall", COLORS.muted)
                cell.realm:SetJustifyH("CENTER"); cell.realm:SetWordWrap(false)
                cell.realm:SetPoint("BOTTOMLEFT", cell, "BOTTOMLEFT", 2, 5)
                cell.realm:SetPoint("BOTTOMRIGHT", cell, "BOTTOMRIGHT", -2, 5)
                cell.realm:SetHeight(16)
                instance.headerCharacters[index] = cell
            end
            local name, realm = CharacterIdentity(instance.characterRecords[key], key)
            local color = ClassColor(key)
            if key == YQB.GetCurrentCharacterID() then
                cell:SetBackdropColor(COLORS.current[1], COLORS.current[2], COLORS.current[3], 0.64)
                cell:SetBackdropBorderColor(COLORS.line[1], COLORS.line[2], COLORS.line[3], 0.72)
            else
                cell:SetBackdropColor(0, 0, 0, 0)
                cell:SetBackdropBorderColor(0, 0, 0, 0)
            end
            cell.name:SetTextColor(color.r or color[1], color.g or color[2], color.b or color[3])
            cell.name:SetText(name)
            cell.name:ClearAllPoints()
            if showRealms then
                cell.name:SetWordWrap(false); cell.name:SetHeight(16)
                cell.name:SetPoint("TOPLEFT", cell, "TOPLEFT", 2, -5)
                cell.name:SetPoint("TOPRIGHT", cell, "TOPRIGHT", -2, -5)
                cell.realm:SetText("-" .. realm)
                cell.realm:Show()
            else
                -- A character column is a comparable matrix field, so CJK and
                -- Latin names must share one line and one visual rhythm.  The
                -- tooltip retains the complete name when it is clipped.
                cell.name:SetWordWrap(false); cell.name:SetHeight(16)
                cell.name:SetPoint("LEFT", cell, "LEFT", 2, 0)
                cell.name:SetPoint("RIGHT", cell, "RIGHT", -2, 0)
                cell.realm:Hide()
            end
            cell:ClearAllPoints(); cell:SetPoint("LEFT", instance.header, "LEFT", x, 0)
            cell:SetSize(characterWidth, Theme.Size.double)
            Theme:BindTooltip(cell, showRealms and (name .. "-" .. realm) or name)
            cell:Show()
            x = x + characterWidth
        end
    end
end

local function RenderQuest(instance, item, characters, showGlobal, showCharacters, currentTask)
    local row = Row(instance)
    row.task:SetText("[" .. item.id .. "] " .. tostring(item.name or "未知任务"))
    row.task:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3])
    row.task:SetWidth(instance.taskWidth - 12)
    local tone = currentTask and COLORS.current or (instance.rowCount % 2 == 0 and COLORS.alternate or COLORS.row)
    row:SetBackdropColor(tone[1], tone[2], tone[3], 0.94)
    row:SetBackdropBorderColor(COLORS.line[1], COLORS.line[2], COLORS.line[3], 0.42)
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
    row:SetBackdropBorderColor(COLORS.line[1], COLORS.line[2], COLORS.line[3], 0.75)
    row.global:Hide(); for _, cell in ipairs(row.cells) do cell:Hide() end
    SetCharacterBands(row, characters or {}, instance.taskWidth + (showGlobal and GLOBAL_W or 0), CharacterWidth(instance), showCharacters)
end

function Page.Create(instance)
    instance.title = Text(instance, "GameFontNormalLarge", COLORS.text); instance.title:SetPoint("TOPLEFT", 18, -15)
    instance.summary = Text(instance, "GameFontNormalSmall", COLORS.muted); instance.summary:SetPoint("TOPRIGHT", -18, -18)
    instance.toolbar = CreateFrame("Frame", nil, instance, "BackdropTemplate"); instance.toolbar:SetPoint("TOPLEFT", 20, -44); instance.toolbar:SetPoint("TOPRIGHT", -20, -44); instance.toolbar:SetHeight(Theme.Size.standard)
    instance.toolbar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    instance.toolbar:SetBackdropColor(COLORS.toolbar[1], COLORS.toolbar[2], COLORS.toolbar[3], 0.9); instance.toolbar:SetBackdropBorderColor(COLORS.line[1], COLORS.line[2], COLORS.line[3], 0.52)
    instance.daily = Check(instance.toolbar, "日常"); instance.daily:SetPoint("LEFT", 7, 0)
    instance.normal = Check(instance.toolbar, "普通"); instance.normal:SetPoint("LEFT", instance.daily.label, "RIGHT", 14, 0)
    instance.hideComplete = Check(instance.toolbar, "隐藏已完成"); instance.hideComplete:SetPoint("LEFT", instance.normal.label, "RIGHT", 14, 0)
    instance.autoAbandon = Check(instance.toolbar, "自动放弃"); instance.autoAbandon:SetPoint("LEFT", instance.hideComplete.label, "RIGHT", 14, 0)
    instance.level = CreateFrame("EditBox", nil, instance.toolbar, "InputBoxTemplate"); instance.level:SetSize(104, 20); instance.level:SetPoint("RIGHT", -7, 0); instance.level:SetAutoFocus(false)
    instance.levelLabel = Text(instance.toolbar, "GameFontNormalSmall", COLORS.muted); instance.levelLabel:SetPoint("RIGHT", instance.level, "LEFT", -6, 0); instance.levelLabel:SetText("等级")
    instance.header = CreateFrame("Frame", nil, instance); instance.header:SetPoint("TOPLEFT", 20, -80); instance.header:SetPoint("TOPRIGHT", -38, -80); instance.header:SetHeight(Theme.Size.double)
    instance.header.bg = instance.header:CreateTexture(nil, "BACKGROUND"); instance.header.bg:SetAllPoints(); instance.header.bg:SetColorTexture(COLORS.chrome[1], COLORS.chrome[2], COLORS.chrome[3], 0.98)
    instance.headerTask = Text(instance.header, "GameFontNormalSmall", COLORS.muted); instance.headerTask:SetPoint("LEFT", 8, 0); instance.headerTask:SetText("任务")
    instance.headerGlobal = Text(instance.header, "GameFontNormalSmall", COLORS.muted); instance.headerGlobal:SetWidth(GLOBAL_W); instance.headerGlobal:SetJustifyH("CENTER"); instance.headerGlobal:SetText("全局")
    instance.scroll = Theme:CreateScrollFrame(instance); instance.scroll:SetPoint("TOPLEFT", 18, -112); instance.scroll:SetPoint("BOTTOMRIGHT", -38, 58)
    instance.content = CreateFrame("Frame", nil, instance.scroll); instance.content:SetWidth(700); instance.scroll:SetScrollChild(instance.content)
    instance.rows, instance.headerCharacters, instance.rowCount = {}, {}, 0
    instance.scopeButtons = {}
    instance.addPanel = CreateFrame("Frame", nil, instance, "BackdropTemplate"); instance.addPanel:SetPoint("BOTTOMLEFT", 18, 15); instance.addPanel:SetPoint("BOTTOMRIGHT", -18, 15); instance.addPanel:SetHeight(29)
    instance.addPanel:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 }); instance.addPanel:SetBackdropColor(COLORS.toolbar[1], COLORS.toolbar[2], COLORS.toolbar[3], 0.9); instance.addPanel:SetBackdropBorderColor(COLORS.line[1], COLORS.line[2], COLORS.line[3], 0.52)
    instance.manual = CreateFrame("EditBox", nil, instance.addPanel, "InputBoxTemplate"); instance.manual:SetSize(108, 20); instance.manual:SetPoint("LEFT", 7, 0); instance.manual:SetAutoFocus(false); instance.manual:SetNumeric(true)
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
    instance.title:SetShown(not preview); instance.summary:SetShown(not preview)
    instance.toolbar:SetShown(not preview); instance.addPanel:SetShown(not preview)
    instance.daily:SetShown(not preview); instance.daily.label:SetShown(not preview)
    instance.normal:SetShown(not preview); instance.normal.label:SetShown(not preview)
    instance.hideComplete:SetShown(not preview); instance.hideComplete.label:SetShown(not preview)
    instance.autoAbandon:SetShown(not preview); instance.autoAbandon.label:SetShown(not preview)
    instance.level:SetShown(not preview); instance.levelLabel:SetShown(not preview)
    instance.manual:SetShown(not preview); instance.addChar:SetShown(not preview); instance.addGlobal:SetShown(not preview); instance.abandon:SetShown(not preview)
    for index, value in ipairs(context.scopeDefinition and context.scopeDefinition.values or {}) do
        local scopeID = value.id
        local control = instance.scopeButtons[index]
        if not control then
            control = Button(instance, value.title, 88)
            instance.scopeButtons[index] = control
        end
        control:ClearAllPoints()
        control:SetPoint("TOPLEFT", instance, "TOPLEFT", (preview and 16 or 20) + ((index - 1) * 96), preview and -8 or -80)
        control:SetText(value.title)
        control:SetState(scopeID == context.scope and "selected" or "default")
        control:SetScript("OnClick", function() context:SetScope(scopeID) end)
        control:Show()
    end
    for index = #(context.scopeDefinition and context.scopeDefinition.values or {}) + 1, #instance.scopeButtons do
        instance.scopeButtons[index]:Hide()
    end
    instance.header:ClearAllPoints(); instance.scroll:ClearAllPoints()
    if preview then
        -- Header and rows share the same viewport.  The final 16px are a
        -- dedicated scrollbar gutter, so a visible thumb never covers the
        -- last character column and an exact-fit matrix is never clipped.
        instance.header:SetPoint("TOPLEFT", PREVIEW_MARGIN, -44); instance.header:SetPoint("TOPRIGHT", -(PREVIEW_MARGIN + PREVIEW_SCROLLBAR_GUTTER), -44)
        instance.scroll:SetPoint("TOPLEFT", PREVIEW_MARGIN, -92); instance.scroll:SetPoint("BOTTOMRIGHT", -PREVIEW_MARGIN, 8)
    else
        instance.header:SetPoint("TOPLEFT", 20, -116); instance.header:SetPoint("TOPRIGHT", -38, -116)
        instance.scroll:SetPoint("TOPLEFT", 20, -168); instance.scroll:SetPoint("BOTTOMRIGHT", -38, 58)
    end
    instance.title:SetText("任务屏蔽")
    instance.daily:SetChecked(filters.showDaily); instance.normal:SetChecked(filters.showNormal); instance.hideComplete:SetChecked(filters.hideComplete); instance.autoAbandon:SetChecked(filters.autoAbandon)
    instance.level:SetText(filters.levelExpr or "")
    local globalCount, charCount, total = YQB.GetStats()
    instance.summary:SetText(string.format("全局 %d · 当前 %d · 总计 %d", globalCount, charCount, total))
    local characters = {}
    instance.characterRecords = instance.characterRecords or {}
    for _, character in ipairs(context.characters or {}) do
        characters[#characters + 1] = character.id
        instance.characterRecords[character.id] = character
    end
    local showGlobal = context:GetFieldVisible("global")
    -- Hover is the same complete account projection as the main matrix.
    -- Its cells remain interactive while the pointer stays within the preview.
    local showCharacters = context:GetFieldVisible("characters")
    instance.taskWidth = 250
    local columns = #characters
    local viewportWidth = instance.scroll:GetWidth() or 0
    local remainingWidth = viewportWidth - instance.taskWidth - (showGlobal and GLOBAL_W or 0) - 6
    if not IsAllRealms(context) then
        instance.characterColumnWidth = COMPACT_CHARACTER_COL_W
    elseif columns > 0 and remainingWidth > 0 then
        instance.characterColumnWidth = math.max(54, math.min(CHARACTER_COL_W, math.floor(remainingWidth / columns)))
    else
        instance.characterColumnWidth = CHARACTER_COL_W
    end
    Header(instance, characters, showGlobal, showCharacters, IsAllRealms(context))
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
        contentWidth = math.max(480, width, viewportWidth - 18)
    end
    instance.content:SetWidth(contentWidth); instance.content:SetHeight(math.max(44, instance.rowCount * ROW_H))
    instance.scroll:SetContentHeight(instance.content:GetHeight())
    if preview then instance.scroll:SetVerticalScroll(0) end
    instance.scroll:RefreshScrollbar()
end

function Page.GetPreviewSize(context)
    local characterColumns = context:GetFieldVisible("characters") and (#(context.characters or {}) * PreferredCharacterWidth(context)) or 0
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
    -- Hover contains only the table projection: its height must track the
    -- rows actually rendered, not the full editor page or hidden quest rows.
    local rows = blocked + 1 + (currentVisible and (current + 1) or 0)
    -- Includes the 47px shared hover chrome, the scope switcher, the matrix
    -- header and the scroll viewport.  Keep an additional 16px margin so an
    -- exact-fit matrix never gains a one-row scroll range from frame rounding
    -- or borders.
    local frameHeight = 164 + (rows * ROW_H)
    local matrixWidth = 250 + globalColumn + characterColumns
        + (PREVIEW_MARGIN * 2) + PREVIEW_SCROLLBAR_GUTTER + CORE_PREVIEW_BORDER
    return math.max(matrixWidth, ScopeControlsWidth(context)), math.max(150, frameHeight)
end

function Page.GetLayoutMetrics(context)
    local characters = context and context.characters or {}
    local showGlobal = context and context:GetFieldVisible("global")
    local showCharacters = context and context:GetFieldVisible("characters")
    local blocked = #(YQB.GetBlockedQuestList() or {})
    local currentKey, currentVisible = YQB.GetCurrentCharacterID(), false
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
    local width = 250 + (showGlobal and GLOBAL_W or 0) + (showCharacters and #characters * PreferredCharacterWidth(context) or 0) + 38
    return {
        minWidth = 582,
        preferredWidth = math.max(582, width),
        minHeight = 383,
        -- Header, scroll offset and fixed action bar are all included so the
        -- default size shows the complete matrix without a vertical scrollbar.
        preferredHeight = math.max(383, 230 + (rows * ROW_H)),
        horizontalOverflow = "matrix",
        verticalOverflow = "content",
    }
end

function Page.GetHoverMetrics(context)
    local width, height = Page.GetPreviewSize(context)
    return {
        minWidth = 420,
        preferredWidth = width,
        minHeight = 150,
        preferredHeight = height,
        horizontalOverflow = "matrix",
        verticalOverflow = "content",
    }
end
