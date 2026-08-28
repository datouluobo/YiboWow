local YAB = _G.YAB
local Theme = _G.YiboCore.UITheme

local SettingsFrame
local hoverModeLabel
local hoverScaleLabel
local minimapCheck
local npcInput
local statusText
local customList
local customListBox
local customListScroll
local customListContent
local customListRows = {}
local minimapCheckLabel
local levelExprBox
local levelExprInput
local levelExprHint
local displayHint
local displayContainer
local displayGroupChecks = {}
local displayItemChecks = {}
local displayLabels = {}
local displayColumnCount = 2
local displayColumnWidth = 164
local characterRows = {}
local characterPage = 1
local characterPageLabel
local characterPrevButton
local characterNextButton
local characterShowAllCheck
local characterShowAllLabel
local characterCleanupButton
local characterCleanupLabel
local CHARACTER_ROWS_PER_PAGE = 15

local FRAME_BG_COLOR = { 0.03, 0.03, 0.04, 0.96 }
local PANEL_BG_COLOR = { 0.055, 0.055, 0.07, 0.94 }
local PANEL_ALT_BG_COLOR = { 0.04, 0.04, 0.05, 0.92 }
local BORDER_COLOR = { 0.24, 0.2, 0.12, 0.95 }
local INNER_BORDER_COLOR = { 0.22, 0.22, 0.24, 0.9 }
local TITLE_COLOR = { 1, 0.82, 0.2 }
local TEXT_COLOR = { 0.95, 0.95, 0.95 }
local SUBTEXT_COLOR = { 0.72, 0.72, 0.72 }
local BUTTON_BG_COLOR = { 0.09, 0.085, 0.075, 0.96 }
local BUTTON_HOVER_BG_COLOR = { 0.14, 0.12, 0.08, 0.98 }
local BUTTON_ACTIVE_BG_COLOR = { 0.18, 0.13, 0.04, 0.98 }
local BUTTON_BORDER_COLOR = { 0.34, 0.28, 0.14, 0.96 }
local BUTTON_DISABLED_BG_COLOR = { 0.05, 0.05, 0.055, 0.85 }
local BUTTON_DISABLED_TEXT_COLOR = { 0.45, 0.45, 0.45 }
local DANGER_TEXT_COLOR = { 1, 0.42, 0.28 }
local PRIMARY_TEXT_COLOR = { 1, 0.82, 0.2 }

local function CreateText(parent, size, justify)
    local text = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    local font, _, flags = text:GetFont()
    text:SetFont(font, size or 12, flags)
    text:SetJustifyH(justify or "LEFT")
    text:SetJustifyV("MIDDLE")
    return text
end

local function UpdateLevelExprVisual(valid)
    if not levelExprBox or not levelExprInput then
        return
    end
    if valid then
        levelExprBox:SetBackdropBorderColor(0.18, 0.18, 0.18, 0.95)
        levelExprInput:SetTextColor(0.95, 0.95, 0.95)
    else
        levelExprBox:SetBackdropBorderColor(0.85, 0.24, 0.24, 0.95)
        levelExprInput:SetTextColor(1, 0.55, 0.55)
    end
end

local function CommitLevelExpr(refresh)
    if not levelExprInput then
        return false
    end
    local valid, normalized, badToken = YAB.ValidateLevelExpr(levelExprInput:GetText())
    levelExprInput:SetText(normalized)
    UpdateLevelExprVisual(valid)
    if not valid then
        if statusText then
            statusText:SetText("等级过滤格式无效: " .. tostring(badToken or ""))
            statusText:SetTextColor(1, 0.3, 0.3)
        end
        return false
    end

    local ok = YAB.SetLevelFilterExpr(normalized)
    if ok and refresh and statusText then
        if normalized == "" or normalized == "0" then
            statusText:SetText("等级过滤已清除，当前显示全部等级角色。")
        else
            statusText:SetText("等级过滤已更新: " .. normalized)
        end
        statusText:SetTextColor(0.2, 0.9, 0.35)
    end
    return ok
end

local function SetBackdrop(frame)
    frame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    frame:SetBackdropColor(FRAME_BG_COLOR[1], FRAME_BG_COLOR[2], FRAME_BG_COLOR[3], FRAME_BG_COLOR[4])
    frame:SetBackdropBorderColor(BORDER_COLOR[1], BORDER_COLOR[2], BORDER_COLOR[3], BORDER_COLOR[4])
end

local function SetPanelBackdrop(frame, useAlt)
    frame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    local bg = useAlt and PANEL_ALT_BG_COLOR or PANEL_BG_COLOR
    frame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4])
    frame:SetBackdropBorderColor(INNER_BORDER_COLOR[1], INNER_BORDER_COLOR[2], INNER_BORDER_COLOR[3], INNER_BORDER_COLOR[4])
end

local function CreateSectionPanel(parent, titleText, width, height, useAlt)
    local panel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    panel:SetSize(width, height)
    SetPanelBackdrop(panel, useAlt)

    panel.title = CreateText(panel, 12, "LEFT")
    panel.title:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -12)
    panel.title:SetText(titleText or "")
    panel.title:SetTextColor(TITLE_COLOR[1], TITLE_COLOR[2], TITLE_COLOR[3])

    panel.divider = panel:CreateTexture(nil, "ARTWORK")
    panel.divider:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    panel.divider:SetHeight(1)
    panel.divider:SetPoint("TOPLEFT", panel.title, "BOTTOMLEFT", 0, -8)
    panel.divider:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -12, 0)
    panel.divider:SetVertexColor(BORDER_COLOR[1], BORDER_COLOR[2], BORDER_COLOR[3], 0.5)

    return panel
end

local function CreateInsetBox(parent, width, height)
    local box = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    box:SetSize(width, height)
    box:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    box:SetBackdropColor(0.02, 0.02, 0.03, 0.84)
    box:SetBackdropBorderColor(0.16, 0.16, 0.18, 0.92)
    return box
end

local function SetButtonVisual(button, state)
    if not button or not button.text then
        return
    end

    local enabled = button:IsEnabled()
    if not enabled then
        button:SetBackdropColor(BUTTON_DISABLED_BG_COLOR[1], BUTTON_DISABLED_BG_COLOR[2], BUTTON_DISABLED_BG_COLOR[3], BUTTON_DISABLED_BG_COLOR[4])
        button:SetBackdropBorderColor(0.15, 0.15, 0.16, 0.92)
        button.text:SetTextColor(BUTTON_DISABLED_TEXT_COLOR[1], BUTTON_DISABLED_TEXT_COLOR[2], BUTTON_DISABLED_TEXT_COLOR[3])
        return
    end

    local bg = BUTTON_BG_COLOR
    if state == "hover" then
        bg = BUTTON_HOVER_BG_COLOR
    elseif state == "active" then
        bg = BUTTON_ACTIVE_BG_COLOR
    end
    button:SetBackdropColor(bg[1], bg[2], bg[3], bg[4])
    button:SetBackdropBorderColor(BUTTON_BORDER_COLOR[1], BUTTON_BORDER_COLOR[2], BUTTON_BORDER_COLOR[3], BUTTON_BORDER_COLOR[4])

    local color = TEXT_COLOR
    if button.variant == "primary" then
        color = PRIMARY_TEXT_COLOR
    elseif button.variant == "danger" then
        color = DANGER_TEXT_COLOR
    elseif button.variant == "muted" then
        color = SUBTEXT_COLOR
    end
    button.text:SetTextColor(color[1], color[2], color[3])
end

local function CreateTextButton(parent, width, height, label, variant)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(width, height)
    button.variant = variant or "neutral"
    button:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    button.text = CreateText(button, 11, "CENTER")
    button.text:SetPoint("CENTER", button, "CENTER", 0, 0)
    button.text:SetPoint("LEFT", button, "LEFT", 6, 0)
    button.text:SetPoint("RIGHT", button, "RIGHT", -6, 0)
    button.SetText = function(self, text)
        self.text:SetText(text or "")
    end
    button:SetScript("OnEnter", function(self)
        SetButtonVisual(self, "hover")
    end)
    button:SetScript("OnLeave", function(self)
        SetButtonVisual(self)
    end)
    button:SetScript("OnMouseDown", function(self)
        SetButtonVisual(self, "active")
    end)
    button:SetScript("OnMouseUp", function(self)
        SetButtonVisual(self, "hover")
    end)
    button:SetScript("OnEnable", function(self)
        SetButtonVisual(self)
    end)
    button:SetScript("OnDisable", function(self)
        SetButtonVisual(self)
    end)
    button:SetText(label or "")
    SetButtonVisual(button)
    return button
end

local function HoverModeCycle(current)
    if current == "full" then
        return "simple"
    elseif current == "simple" then
        return "off"
    end
    return "full"
end

local function HoverModeLabel(mode)
    if mode == "simple" then
        return "简易模式"
    elseif mode == "off" then
        return "关闭"
    end
    return "完整模式"
end

local function HoverScaleLabel(scale)
    local percent = math.floor(((tonumber(scale) or 1) * 100) + 0.5)
    return "悬停 UI 缩放: " .. tostring(percent) .. "%"
end

local function RaiseSettingsTooltip()
    if not GameTooltip then
        return
    end
    GameTooltip:SetToplevel(true)
    GameTooltip:SetFrameStrata("TOOLTIP")
    local settingsLevel = SettingsFrame and SettingsFrame.GetFrameLevel and SettingsFrame:GetFrameLevel() or 0
    GameTooltip:SetFrameLevel(math.max(GameTooltip:GetFrameLevel() or 0, settingsLevel + 40))
end

local function CreateCheckbox(parent, labelText)
    local check = Theme:CreateCheckbox(parent, labelText)
    check.label:SetTextColor(TEXT_COLOR[1], TEXT_COLOR[2], TEXT_COLOR[3])
    return check, check.label
end

local function SetCheckboxVisual(check, label, enabled)
    check:SetEnabled(enabled)
    if enabled then
        label:SetTextColor(TEXT_COLOR[1], TEXT_COLOR[2], TEXT_COLOR[3])
    else
        label:SetTextColor(0.45, 0.45, 0.45)
    end
end

local function RebuildDisplayControls()
    if not SettingsFrame or not displayContainer then
        return
    end

    for _, check in pairs(displayGroupChecks) do
        check:Hide()
    end
    for _, check in pairs(displayItemChecks) do
        check:Hide()
    end
    for key, label in pairs(displayLabels) do
        if not displayGroupChecks[key] and not displayItemChecks[key] then
            label:Hide()
        else
            label:Hide()
        end
    end

    local allTargets = YAB.GetAllBossList and YAB.GetAllBossList() or {}
    local targetsByGroup = {}
    for _, target in ipairs(allTargets) do
        local groupKey = target.group or "custom"
        targetsByGroup[groupKey] = targetsByGroup[groupKey] or {}
        targetsByGroup[groupKey][#targetsByGroup[groupKey] + 1] = target
    end

    local groups = YAB.GetDisplayGroups and YAB.GetDisplayGroups() or {}
    local columnHeights = {}
    local columnCount = math.max(displayColumnCount, 1)
    for index = 1, columnCount do
        columnHeights[index] = 0
    end

    for groupIndex, group in ipairs(groups) do
        local column = ((groupIndex - 1) % columnCount) + 1
        local columnX = (column - 1) * displayColumnWidth
        local groupCheck = displayGroupChecks[group.key]
        local groupLabel = displayLabels[group.key]
        if not groupCheck then
            groupCheck, groupLabel = CreateCheckbox(displayContainer, group.name)
            displayGroupChecks[group.key] = groupCheck
            displayLabels[group.key] = groupLabel
            groupCheck:SetScript("OnClick", function(self)
                self:SetChecked(not self:GetChecked())
                YAB.SetDisplayGroupEnabled(group.key, self:GetChecked())
            end)
        end
        groupLabel:SetText(group.name)
        groupCheck:ClearAllPoints()
        groupCheck:SetPoint("TOPLEFT", displayContainer, "TOPLEFT", columnX, -columnHeights[column])
        groupCheck:Show()
        groupLabel:Show()
        columnHeights[column] = columnHeights[column] + 22
        for _, target in ipairs(targetsByGroup[group.key] or {}) do
            local itemCheck = displayItemChecks[target.key]
            local itemLabel = displayLabels[target.key]
            if not itemCheck then
                itemCheck, itemLabel = CreateCheckbox(displayContainer, target.name)
                displayItemChecks[target.key] = itemCheck
                displayLabels[target.key] = itemLabel
                itemCheck:SetScript("OnClick", function(self)
                    self:SetChecked(not self:GetChecked())
                    YAB.SetDisplayItemEnabled(target.key, self:GetChecked())
                end)
            end
            itemLabel:SetText(target.name)
            itemCheck:ClearAllPoints()
            itemCheck:SetPoint("TOPLEFT", displayContainer, "TOPLEFT", columnX + 18, -columnHeights[column])
            itemCheck:Show()
            itemLabel:Show()
            columnHeights[column] = columnHeights[column] + 18
        end
        columnHeights[column] = columnHeights[column] + 12
    end

    local maxHeight = 0
    for index = 1, columnCount do
        if columnHeights[index] > maxHeight then
            maxHeight = columnHeights[index]
        end
    end
    displayContainer:SetHeight(math.max(maxHeight, 180))
end

local function RefreshCharacterCacheControls()
    if not SettingsFrame or not characterPageLabel then
        return
    end

    local showAll = YAB.GetCharacterCacheShowAll and YAB.GetCharacterCacheShowAll()
    local keys = YAB.GetCachedCharacterKeys and YAB.GetCachedCharacterKeys(showAll) or {}
    local totalPages = math.max(1, math.ceil(#keys / CHARACTER_ROWS_PER_PAGE))
    if characterPage > totalPages then
        characterPage = totalPages
    elseif characterPage < 1 then
        characterPage = 1
    end

    local startIndex = (characterPage - 1) * CHARACTER_ROWS_PER_PAGE + 1
    for rowIndex, row in ipairs(characterRows) do
        local charKey = keys[startIndex + rowIndex - 1]
        if charKey then
            local label = YAB.GetCachedCharacterLabel and YAB.GetCachedCharacterLabel(charKey) or charKey
            local canDelete, reason = false, nil
            if YAB.CanDeleteCharacter then
                canDelete, reason = YAB.CanDeleteCharacter(charKey)
            end
            row.charKey = charKey
            row.label:SetText(label)
            row.label:SetTextColor(TEXT_COLOR[1], TEXT_COLOR[2], TEXT_COLOR[3])
            row.deleteButton.charKey = charKey
            row.deleteButton.label = label
            row.deleteButton.reason = reason
            row.deleteButton:Hide()
            row:Show()
        else
            row.charKey = nil
            row.deleteButton.charKey = nil
            row:Hide()
        end
    end

    if #keys == 0 then
        characterPageLabel:SetText(showAll and "没有已缓存角色" or "没有符合过滤的角色")
    else
        characterPageLabel:SetText("第 " .. characterPage .. " / " .. totalPages .. " 页，共 " .. #keys .. " 个")
    end
    if characterShowAllCheck then
        characterShowAllCheck:SetChecked(showAll)
        SetCheckboxVisual(characterShowAllCheck, characterShowAllLabel, true)
    end
    if characterCleanupButton then characterCleanupButton:Hide() end
    if characterCleanupLabel then
        local levelExpr = tostring(YAB.GetLevelFilterExpr and YAB.GetLevelFilterExpr() or "")
        if levelExpr == "" or levelExpr == "0" then
            characterCleanupLabel:SetText("请在 YiboCore 角色档案中逐个删除缓存")
        else
            characterCleanupLabel:SetText("请在 YiboCore 角色档案中逐个删除缓存")
        end
        characterCleanupLabel:SetWidth(260)
    end
    characterPrevButton:SetEnabled(characterPage > 1)
    characterNextButton:SetEnabled(characterPage < totalPages)
    SetButtonVisual(characterPrevButton)
    SetButtonVisual(characterNextButton)
end

local function RefreshCustomTargetControls()
    if not customList or not customListBox or not customListContent then
        return
    end

    local targets = YiboAltoBossDB and YiboAltoBossDB.customTargets or {}
    local items = {}
    for _, item in pairs(targets) do
        local id = tonumber(item.id)
        if id then
            items[#items + 1] = id
        end
    end
    table.sort(items)

    if #items == 0 then
        customList:SetText("当前没有自定义 NPC。")
        customList:Show()
    else
        customList:Hide()
    end

    local contentHeight = (#items * 18) + 4
    customListContent:SetHeight(math.max(contentHeight, 98))
    if customListScroll then
        customListScroll:SetVerticalScroll(0)
    end

    for index, id in ipairs(items) do
        local row = customListRows[index]
        if not row then
            row = CreateTextButton(customListContent, 1, 18, "", "neutral")
            row:SetScript("OnClick", function(self)
                if not npcInput then
                    return
                end
                npcInput:SetText(tostring(self.npcId or ""))
                npcInput:ClearFocus()
                if statusText then
                    statusText:SetText("已填入 NPC ID " .. tostring(self.npcId) .. "，可点击删除。")
                    statusText:SetTextColor(SUBTEXT_COLOR[1], SUBTEXT_COLOR[2], SUBTEXT_COLOR[3])
                end
            end)
            customListRows[index] = row
        end
        row.npcId = id
        row:SetText("NPC " .. tostring(id))
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", customListContent, "TOPLEFT", 0, -4 - ((index - 1) * 18))
        row:SetSize(math.max(customListContent:GetWidth() or 0, 1), 18)
        row:Show()
    end
    for index = #items + 1, #customListRows do
        customListRows[index]:Hide()
    end
end

function YAB.RefreshSettingsUI(preserveStatus)
    if not SettingsFrame then
        return
    end
    local minimap = YAB.GetMinimapConfig()
    if minimapCheck then
        minimapCheck:SetChecked(not minimap.hide)
    end
    if hoverModeLabel then
        hoverModeLabel:SetText("悬停临时窗口: " .. HoverModeLabel(YAB.GetHoverMode()))
    end
    if hoverScaleLabel then
        hoverScaleLabel:SetText(HoverScaleLabel(YAB.GetHoverScale and YAB.GetHoverScale() or 1))
    end
    if levelExprInput then
        levelExprInput:SetText(tostring(YAB.GetLevelFilterExpr() or ""))
        local valid = YAB.ValidateLevelExpr(levelExprInput:GetText())
        UpdateLevelExprVisual(valid)
    end
    if statusText and not preserveStatus then
        local levelExpr = tostring(YAB.GetLevelFilterExpr() or "")
        if levelExpr == "" or levelExpr == "0" then
            statusText:SetText("当前未启用等级过滤。")
        else
            statusText:SetText("当前等级过滤: " .. levelExpr)
        end
        statusText:SetTextColor(SUBTEXT_COLOR[1], SUBTEXT_COLOR[2], SUBTEXT_COLOR[3])
    end

    RefreshCustomTargetControls()

    RebuildDisplayControls()
    RefreshCharacterCacheControls()

    local allTargets = YAB.GetAllBossList and YAB.GetAllBossList() or {}
    local targetsByGroup = {}
    for _, target in ipairs(allTargets) do
        local groupKey = target.group or "custom"
        targetsByGroup[groupKey] = targetsByGroup[groupKey] or {}
        targetsByGroup[groupKey][#targetsByGroup[groupKey] + 1] = target
    end

    for _, group in ipairs(YAB.GetDisplayGroups and YAB.GetDisplayGroups() or {}) do
        local groupCheck = displayGroupChecks[group.key]
        if groupCheck then
            groupCheck:SetChecked(YAB.IsDisplayGroupEnabled(group.key))
        end
        local groupEnabled = YAB.IsDisplayGroupEnabled(group.key)
        for _, target in ipairs(targetsByGroup[group.key] or {}) do
            local itemCheck = displayItemChecks[target.key]
            if itemCheck then
                itemCheck:SetChecked(YAB.IsDisplayItemChecked(target.key))
                SetCheckboxVisual(itemCheck, displayLabels[target.key], groupEnabled)
            end
        end
    end
end

function YAB.ToggleSettingsWindow()
    if not SettingsFrame then
        return
    end
    if SettingsFrame:IsShown() then
        SettingsFrame:Hide()
        YAB.SetSettingsShown(false)
    else
        if YAB.HideEntryHover then
            YAB.HideEntryHover()
        end
        SettingsFrame:SetFrameStrata("DIALOG")
        SettingsFrame:SetToplevel(true)
        SettingsFrame:Show()
        SettingsFrame:Raise()
        YAB.SetSettingsShown(true)
        YAB.RefreshSettingsUI()
    end
end

function YAB.IsSettingsWindowShown()
    return SettingsFrame and SettingsFrame:IsShown() or false
end

function YAB.InitializeSettings()
    if SettingsFrame then
        return
    end

    SettingsFrame = CreateFrame("Frame", "YiboAltoBossSettingsFrame", UIParent, "BackdropTemplate")
    SettingsFrame:SetSize(680, 760)
    SettingsFrame:SetPoint("CENTER", UIParent, "CENTER", 220, 0)
    SettingsFrame:SetFrameStrata("DIALOG")
    SettingsFrame:SetToplevel(true)
    SettingsFrame:SetMovable(true)
    SettingsFrame:EnableMouse(true)
    SettingsFrame:RegisterForDrag("LeftButton")
    SettingsFrame:SetScript("OnDragStart", SettingsFrame.StartMoving)
    SettingsFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self:Raise()
    end)
    SettingsFrame:SetScript("OnHide", function()
        YAB.SetSettingsShown(false)
    end)
    SetBackdrop(SettingsFrame)
    SettingsFrame:Hide()

    local title = CreateText(SettingsFrame, 14, "LEFT")
    title:SetPoint("TOPLEFT", SettingsFrame, "TOPLEFT", 14, -12)
    title:SetText("YiboAltoBoss 设置")
    title:SetTextColor(TITLE_COLOR[1], TITLE_COLOR[2], TITLE_COLOR[3])

    local headerHint = CreateText(SettingsFrame, 11, "RIGHT")
    headerHint:SetPoint("TOPRIGHT", SettingsFrame, "TOPRIGHT", -14, -14)
    headerHint:SetText("按功能分区，便于快速扫描")
    headerHint:SetTextColor(SUBTEXT_COLOR[1], SUBTEXT_COLOR[2], SUBTEXT_COLOR[3])

    local generalPanel = CreateSectionPanel(SettingsFrame, "基础设置", 652, 166, false)
    generalPanel:SetPoint("TOPLEFT", SettingsFrame, "TOPLEFT", 14, -40)

    local displayPanel = CreateSectionPanel(SettingsFrame, "显示项配置", 382, 296, true)
    displayPanel:SetPoint("TOPLEFT", generalPanel, "BOTTOMLEFT", 0, -12)

    local customPanel = CreateSectionPanel(SettingsFrame, "自定义目标", 258, 296, true)
    customPanel:SetPoint("TOPRIGHT", generalPanel, "BOTTOMRIGHT", 0, -12)

    local characterPanel = CreateSectionPanel(SettingsFrame, "角色缓存管理", 652, 184, false)
    characterPanel:SetPoint("TOPLEFT", displayPanel, "BOTTOMLEFT", 0, -12)

    local coreEntryHint = CreateText(generalPanel, 12, "LEFT")
    coreEntryHint:SetPoint("TOPLEFT", generalPanel, "TOPLEFT", 12, -38)
    coreEntryHint:SetPoint("TOPRIGHT", generalPanel, "TOPRIGHT", -12, -38)
    coreEntryHint:SetText("小地图、Broker 和悬停预览由 YiboCore 统一管理，可在 Core 设置中配置。")
    coreEntryHint:SetTextColor(SUBTEXT_COLOR[1], SUBTEXT_COLOR[2], SUBTEXT_COLOR[3])

    local levelTitle = CreateText(generalPanel, 11, "LEFT")
    levelTitle:SetPoint("TOPLEFT", generalPanel, "TOPLEFT", 12, -82)
    levelTitle:SetText("等级过滤")
    levelTitle:SetTextColor(SUBTEXT_COLOR[1], SUBTEXT_COLOR[2], SUBTEXT_COLOR[3])

    levelExprBox = CreateInsetBox(generalPanel, 178, 26)
    levelExprBox:SetPoint("TOPLEFT", generalPanel, "TOPLEFT", 12, -100)

    levelExprInput = CreateFrame("EditBox", nil, levelExprBox, "InputBoxTemplate")
    levelExprInput:SetPoint("TOPLEFT", levelExprBox, "TOPLEFT", 6, -2)
    levelExprInput:SetPoint("BOTTOMRIGHT", levelExprBox, "BOTTOMRIGHT", -6, 2)
    levelExprInput:SetAutoFocus(false)
    levelExprInput:SetTextInsets(0, 0, 0, 0)

    local levelHelpButton = CreateTextButton(generalPanel, 26, 22, "?", "primary")
    levelHelpButton:SetPoint("LEFT", levelExprBox, "RIGHT", 8, 0)

    levelExprHint = CreateText(generalPanel, 11, "LEFT")
    levelExprHint:SetPoint("LEFT", levelHelpButton, "RIGHT", 12, 0)
    levelExprHint:SetPoint("RIGHT", generalPanel, "RIGHT", -12, 0)
    levelExprHint:SetJustifyH("LEFT")
    levelExprHint:SetText("支持 90、1-20、<=3、>=85、<=3,89,90；留空或 0 表示不过滤。")
    levelExprHint:SetTextColor(SUBTEXT_COLOR[1], SUBTEXT_COLOR[2], SUBTEXT_COLOR[3])

    levelExprInput:SetScript("OnEnterPressed", function(self)
        CommitLevelExpr(true)
        self:ClearFocus()
    end)
    levelExprInput:SetScript("OnEditFocusGained", function(self)
        self:HighlightText()
    end)
    levelExprInput:SetScript("OnEditFocusLost", function()
        CommitLevelExpr(true)
    end)
    levelExprInput:SetScript("OnEscapePressed", function(self)
        self:SetText(tostring(YAB.GetLevelFilterExpr() or ""))
        UpdateLevelExprVisual(true)
        self:ClearFocus()
    end)

    levelHelpButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("等级过滤说明", 1, 0.82, 0.2)
        GameTooltip:AddLine("支持多个条件，分隔符只能使用英文逗号。", 0.9, 0.9, 0.9, true)
        GameTooltip:AddLine("可用格式: 90  1-20  <=3  >=85", 0.7, 0.85, 1, true)
        GameTooltip:AddLine("示例: <=3,89,90", 0.7, 1, 0.7, true)
        GameTooltip:AddLine("输入 0 或留空表示不过滤等级。", 1, 0.82, 0.25, true)
        GameTooltip:AddLine("输入后按回车或移开焦点即可生效。", 1, 0.82, 0.25, true)
        RaiseSettingsTooltip()
        GameTooltip:Show()
        GameTooltip:Raise()
    end)
    levelHelpButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    -- The expression is now configured once in Core 常规设置 → 角色过滤.
    levelTitle:Hide(); levelExprBox:Hide(); levelExprInput:Hide(); levelHelpButton:Hide(); levelExprHint:Hide()

    displayHint = CreateText(displayPanel, 11, "LEFT")
    displayHint:SetPoint("TOPLEFT", displayPanel, "TOPLEFT", 12, -34)
    displayHint:SetWidth(350)
    displayHint:SetWordWrap(true)
    displayHint:SetText("仅勾选的项目会显示在主窗口中。关闭显示会停止后续记录，但不会删除已有历史数据。")
    displayHint:SetTextColor(SUBTEXT_COLOR[1], SUBTEXT_COLOR[2], SUBTEXT_COLOR[3])

    displayContainer = CreateFrame("Frame", nil, displayPanel)
    displayContainer:SetPoint("TOPLEFT", displayHint, "BOTTOMLEFT", 0, -10)
    displayContainer:SetSize(350, 228)
    RebuildDisplayControls()

    local characterHint = CreateText(characterPanel, 11, "LEFT")
    characterHint:SetPoint("TOPLEFT", characterPanel, "TOPLEFT", 12, -34)
    characterHint:SetWidth(300)
    characterHint:SetText("默认按等级过滤显示；共享位面/刷新历史保留。")
    characterHint:SetTextColor(SUBTEXT_COLOR[1], SUBTEXT_COLOR[2], SUBTEXT_COLOR[3])

    characterPageLabel = CreateText(characterPanel, 11, "CENTER")
    characterPageLabel:SetPoint("TOPRIGHT", characterPanel, "TOPRIGHT", -86, -35)
    characterPageLabel:SetSize(138, 18)
    characterPageLabel:SetTextColor(SUBTEXT_COLOR[1], SUBTEXT_COLOR[2], SUBTEXT_COLOR[3])

    characterPrevButton = CreateTextButton(characterPanel, 46, 20, "上一页", "neutral")
    characterPrevButton:SetPoint("RIGHT", characterPageLabel, "LEFT", -6, 0)
    characterPrevButton:SetScript("OnClick", function()
        characterPage = characterPage - 1
        RefreshCharacterCacheControls()
    end)

    characterNextButton = CreateTextButton(characterPanel, 46, 20, "下一页", "primary")
    characterNextButton:SetPoint("LEFT", characterPageLabel, "RIGHT", 6, 0)
    characterNextButton:SetScript("OnClick", function()
        characterPage = characterPage + 1
        RefreshCharacterCacheControls()
    end)

    characterShowAllCheck, characterShowAllLabel = CreateCheckbox(characterPanel, "显示全部角色")
    characterShowAllCheck:SetPoint("TOPLEFT", characterPanel, "TOPLEFT", 12, -54)
    characterShowAllCheck:SetScript("OnClick", function(self)
        self:SetChecked(not self:GetChecked())
        characterPage = 1
        if YAB.SetCharacterCacheShowAll then
            YAB.SetCharacterCacheShowAll(self:GetChecked())
        else
            RefreshCharacterCacheControls()
        end
    end)

    characterCleanupButton = CreateTextButton(characterPanel, 82, 20, "清理过滤外", "danger")
    characterCleanupButton:SetPoint("TOPRIGHT", characterPanel, "TOPRIGHT", -112, -54)
    characterCleanupButton:SetScript("OnClick", function()
        local cleanupKeys = YAB.GetFilteredOutCachedCharacterKeys and YAB.GetFilteredOutCachedCharacterKeys() or {}
        if #cleanupKeys == 0 then
            if statusText then
                statusText:SetText("没有需要清理的过滤外角色。")
                statusText:SetTextColor(SUBTEXT_COLOR[1], SUBTEXT_COLOR[2], SUBTEXT_COLOR[3])
            end
            return
        end
        if StaticPopup_Show then
            StaticPopup_Show("YAB_DELETE_FILTERED_CHARACTERS", tostring(#cleanupKeys), nil, cleanupKeys)
        else
            local deleted, skipped = 0, 0
            if YAB.DeleteCharacters then
                deleted, skipped = YAB.DeleteCharacters(cleanupKeys)
            end
            if statusText then
                statusText:SetText("已清理过滤外角色: " .. tostring(deleted) .. " 个，跳过 " .. tostring(skipped) .. " 个。")
                statusText:SetTextColor(0.2, 0.9, 0.35)
            end
            RefreshCharacterCacheControls()
        end
    end)
    characterCleanupButton:Hide()

    characterCleanupLabel = CreateText(characterPanel, 11, "LEFT")
    characterCleanupLabel:SetPoint("LEFT", characterCleanupButton, "RIGHT", 8, 0)
    characterCleanupLabel:SetWidth(92)
    characterCleanupLabel:SetTextColor(SUBTEXT_COLOR[1], SUBTEXT_COLOR[2], SUBTEXT_COLOR[3])
    characterCleanupLabel:ClearAllPoints()
    characterCleanupLabel:SetPoint("TOPRIGHT", characterPanel, "TOPRIGHT", -12, -57)
    characterCleanupLabel:SetWidth(280)

    if StaticPopupDialogs and not StaticPopupDialogs.YAB_DELETE_CHARACTER then
        StaticPopupDialogs.YAB_DELETE_CHARACTER = {
            text = "确定删除角色“%s”的本插件缓存吗？\n这会移除该角色的击杀记录和位面缓存，不会删除游戏角色。",
            button1 = "删除",
            button2 = "取消",
            OnAccept = function(_, charKey)
                local label = YAB.GetCachedCharacterLabel and YAB.GetCachedCharacterLabel(charKey) or tostring(charKey or "")
                local ok, err = false, "删除角色缓存失败。"
                if YAB.DeleteCharacter then
                    ok, err = YAB.DeleteCharacter(charKey)
                end
                if statusText then
                    if ok then
                        statusText:SetText("已删除角色缓存: " .. label)
                        statusText:SetTextColor(0.2, 0.9, 0.35)
                    else
                        statusText:SetText(err or "删除角色缓存失败。")
                        statusText:SetTextColor(1, 0.3, 0.3)
                    end
                end
                RefreshCharacterCacheControls()
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
    end

    if StaticPopupDialogs and not StaticPopupDialogs.YAB_DELETE_FILTERED_CHARACTERS then
        StaticPopupDialogs.YAB_DELETE_FILTERED_CHARACTERS = {
            text = "确定清理 %s 个不符合当前等级过滤的角色缓存吗？\n当前登录角色会自动跳过；共享位面/刷新历史会保留。",
            button1 = "清理",
            button2 = "取消",
            OnAccept = function(_, cleanupKeys)
                local deleted, skipped = 0, 0
                if YAB.DeleteCharacters then
                    deleted, skipped = YAB.DeleteCharacters(cleanupKeys)
                end
                if statusText then
                    statusText:SetText("已清理过滤外角色: " .. tostring(deleted) .. " 个，跳过 " .. tostring(skipped) .. " 个。")
                    statusText:SetTextColor(0.2, 0.9, 0.35)
                end
                characterPage = 1
                RefreshCharacterCacheControls()
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
    end

    for _, columnX in ipairs({ 219, 432 }) do
        local divider = characterPanel:CreateTexture(nil, "ARTWORK")
        divider:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
        divider:SetWidth(1)
        divider:SetPoint("TOPLEFT", characterPanel, "TOPLEFT", columnX, -78)
        divider:SetPoint("BOTTOMLEFT", characterPanel, "BOTTOMLEFT", columnX, 18)
        divider:SetVertexColor(INNER_BORDER_COLOR[1], INNER_BORDER_COLOR[2], INNER_BORDER_COLOR[3], 0.72)
    end

    for index = 1, CHARACTER_ROWS_PER_PAGE do
        local rowsPerColumn = math.ceil(CHARACTER_ROWS_PER_PAGE / 3)
        local column = math.ceil(index / rowsPerColumn)
        local rowInColumn = index - ((column - 1) * rowsPerColumn)
        local columnX = 12 + ((column - 1) * 213)
        local row = CreateFrame("Frame", nil, characterPanel)
        row:SetSize(202, 16)
        row:SetPoint("TOPLEFT", characterPanel, "TOPLEFT", columnX, -78 - ((rowInColumn - 1) * 18))

        row.label = CreateText(row, 11, "LEFT")
        row.label:SetPoint("LEFT", row, "LEFT", 0, 0)
        row.label:SetSize(154, 16)
        row.label:SetTextColor(TEXT_COLOR[1], TEXT_COLOR[2], TEXT_COLOR[3])

        row.deleteButton = CreateTextButton(row, 42, 16, "删", "danger")
        row.deleteButton:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        row.deleteButton:SetScript("OnClick", function(self)
            local charKey = self.charKey
            local label = self.label or (YAB.GetCachedCharacterLabel and YAB.GetCachedCharacterLabel(charKey)) or tostring(charKey or "")
            local canDelete, reason = false, nil
            if YAB.CanDeleteCharacter then
                canDelete, reason = YAB.CanDeleteCharacter(charKey)
            end
            if not canDelete then
                if statusText then
                    statusText:SetText(reason or "该角色不能删除。")
                    statusText:SetTextColor(1, 0.3, 0.3)
                end
                return
            end
            if StaticPopup_Show then
                StaticPopup_Show("YAB_DELETE_CHARACTER", label, nil, charKey)
            else
                local ok, err = YAB.DeleteCharacter(charKey)
                if statusText then
                    statusText:SetText(ok and ("已删除角色缓存: " .. label) or (err or "删除角色缓存失败。"))
                    statusText:SetTextColor(ok and 0.2 or 1, ok and 0.9 or 0.3, ok and 0.35 or 0.3)
                end
                RefreshCharacterCacheControls()
            end
        end)
        row.deleteButton:Hide()
        row.label:SetWidth(202)

        characterRows[index] = row
    end

    local customHint = CreateText(customPanel, 11, "LEFT")
    customHint:SetPoint("TOPLEFT", customPanel, "TOPLEFT", 12, -34)
    customHint:SetPoint("RIGHT", customPanel, "RIGHT", -12, 0)
    customHint:SetWordWrap(true)
    customHint:SetText("补充监控列表之外的 NPC，便于临时追踪；输入 NPC ID 后可添加或删除。")
    customHint:SetTextColor(SUBTEXT_COLOR[1], SUBTEXT_COLOR[2], SUBTEXT_COLOR[3])

    local npcLabel = CreateText(customPanel, 11, "LEFT")
    npcLabel:SetPoint("TOPLEFT", customPanel, "TOPLEFT", 12, -82)
    npcLabel:SetText("NPC ID")
    npcLabel:SetTextColor(SUBTEXT_COLOR[1], SUBTEXT_COLOR[2], SUBTEXT_COLOR[3])

    npcInput = CreateFrame("EditBox", nil, customPanel, "InputBoxTemplate")
    npcInput:SetSize(96, 24)
    npcInput:SetPoint("TOPLEFT", npcLabel, "BOTTOMLEFT", 0, -6)
    npcInput:SetAutoFocus(false)
    npcInput:SetNumeric(true)

    local addButton = CreateTextButton(customPanel, 50, 22, "添加", "primary")
    addButton:SetPoint("LEFT", npcInput, "RIGHT", 8, 0)
    addButton:SetScript("OnClick", function()
        local ok, err = YAB.AddCustomTarget(npcInput:GetText())
        if ok then
            statusText:SetText("已添加自定义目标。")
            statusText:SetTextColor(0.2, 0.9, 0.35)
            npcInput:SetText("")
        else
            statusText:SetText(err or "添加失败。")
            statusText:SetTextColor(1, 0.3, 0.3)
        end
        YAB.RefreshSettingsUI(true)
    end)

    local removeButton = CreateTextButton(customPanel, 50, 22, "删除", "neutral")
    removeButton:SetPoint("LEFT", addButton, "RIGHT", 6, 0)
    removeButton:SetScript("OnClick", function()
        local ok, err = YAB.RemoveCustomTarget(npcInput:GetText())
        if ok then
            statusText:SetText(err or "已删除自定义目标。")
            statusText:SetTextColor(0.2, 0.9, 0.35)
            npcInput:SetText("")
        else
            statusText:SetText(err or "删除失败。")
            statusText:SetTextColor(1, 0.3, 0.3)
        end
        YAB.RefreshSettingsUI(true)
    end)

    statusText = CreateText(SettingsFrame, 11, "LEFT")
    statusText:SetPoint("BOTTOMLEFT", SettingsFrame, "BOTTOMLEFT", 16, 18)
    statusText:SetWidth(400)
    statusText:SetWordWrap(true)
    statusText:SetTextColor(SUBTEXT_COLOR[1], SUBTEXT_COLOR[2], SUBTEXT_COLOR[3])
    statusText:SetText("这里会把自定义目标加入 Boss 列表。")

    local customListTitle = CreateText(customPanel, 11, "LEFT")
    customListTitle:SetPoint("TOPLEFT", npcInput, "BOTTOMLEFT", 0, -32)
    customListTitle:SetText("当前自定义目标（点击填入 ID）")
    customListTitle:SetTextColor(SUBTEXT_COLOR[1], SUBTEXT_COLOR[2], SUBTEXT_COLOR[3])

    customListBox = CreateInsetBox(customPanel, 234, 106)
    customListBox:SetPoint("TOPLEFT", customListTitle, "BOTTOMLEFT", 0, -6)

    customListScroll = Theme:CreateScrollFrame(customListBox)
    customListScroll:SetPoint("TOPLEFT", customListBox, "TOPLEFT", 4, -4)
    customListScroll:SetPoint("BOTTOMRIGHT", customListBox, "BOTTOMRIGHT", -22, 4)

    customListContent = CreateFrame("Frame", nil, customListScroll)
    customListContent:SetSize(204, 1)
    customListScroll:SetScrollChild(customListContent)

    customList = CreateText(customListContent, 11, "LEFT")
    customList:SetPoint("TOPLEFT", customListContent, "TOPLEFT", 4, -6)
    customList:SetPoint("RIGHT", customListContent, "RIGHT", -4, 0)
    customList:SetWordWrap(true)
    customList:SetTextColor(TEXT_COLOR[1], TEXT_COLOR[2], TEXT_COLOR[3])

    local closeButton = CreateTextButton(SettingsFrame, 70, 22, "关闭", "primary")
    closeButton:SetPoint("BOTTOMRIGHT", SettingsFrame, "BOTTOMRIGHT", -14, 12)
    closeButton:SetScript("OnClick", function()
        SettingsFrame:Hide()
    end)

    if YAB.GetUIState().settingsShown then
        SettingsFrame:SetFrameStrata("DIALOG")
        SettingsFrame:SetToplevel(true)
        SettingsFrame:Show()
        SettingsFrame:Raise()
    end
    YAB.RefreshSettingsUI()
end

-- 由 YiboCore 的统一设置工作台承载；业务状态和校验仍归 AltoBoss。
function YAB.CreateCoreSettingsPanel(parent, context)
    context = context or {}
    local panel = parent.yabSettingsPanel
    if not panel then
        panel = CreateFrame("Frame", nil, parent)
        panel:SetSize(600, 1)
        panel:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
        parent.yabSettingsPanel = panel
        panel.groupChecks, panel.groupExpandButtons, panel.itemChecks = {}, {}, {}
        -- Unconfigured groups default to expanded.  The per-group preference
        -- belongs to AltoBoss because it only changes this business editor.
        YiboAltoBossDB.ui = YiboAltoBossDB.ui or {}
        YiboAltoBossDB.ui.settingsExpandedGroups = YiboAltoBossDB.ui.settingsExpandedGroups or {}
        panel.customRows = {}
        panel.expandedGroups = YiboAltoBossDB.ui.settingsExpandedGroups

        local Section = context.createSection
        panel.targets = Section(panel, "监控目标", 292, 1)
        panel.targets:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
        panel.targetHint = context.createText(panel.targets, Theme.Font.assist, Theme.Colors.muted, "LEFT")
        panel.targetHint:SetPoint("TOPLEFT", 12, -40); panel.targetHint:SetPoint("TOPRIGHT", -12, -40)
        panel.targetHint:SetText("关闭项目会停止后续记录，不会删除已有历史数据。点击 + 展开组内目标。")
        panel.targetContent = CreateFrame("Frame", nil, panel.targets)
        panel.targetContent:SetPoint("TOPLEFT", 12, -62); panel.targetContent:SetPoint("TOPRIGHT", -12, -62)

        panel.filter = Section(panel, "角色过滤", 292, 126)
        panel.filter:SetPoint("TOPLEFT", panel.targets, "TOPRIGHT", 12, 0)
        local filterHint = context.createText(panel.filter, Theme.Font.assist, Theme.Colors.muted, "LEFT")
        filterHint:SetPoint("TOPLEFT", 12, -40); filterHint:SetPoint("TOPRIGHT", -12, -40)
        filterHint:SetText("支持 90、1-20、<=3、>=85；留空或 0 不过滤。")
        panel.levelInput = CreateFrame("EditBox", nil, panel.filter, "InputBoxTemplate")
        panel.levelInput:SetSize(174, 24); panel.levelInput:SetPoint("TOPLEFT", 12, -70)
        panel.levelInput:SetAutoFocus(false)
        local levelHelp = context.createButton(panel.filter, 72, "格式说明")
        levelHelp:SetPoint("LEFT", panel.levelInput, "RIGHT", 8, 0)
        context.bindTooltip(levelHelp, "等级过滤", { "可输入单个等级、区间或比较表达式。", "示例：90、1-20、<=3、>=85。", "留空或 0 表示不过滤。" })
        panel.levelStatus = context.createText(panel.filter, Theme.Font.assist, Theme.Colors.muted, "LEFT")
        panel.levelStatus:SetPoint("TOPLEFT", 12, -102); panel.levelStatus:SetPoint("TOPRIGHT", -12, -102)
        local function CommitEmbeddedFilter()
            local valid, normalized, badToken = YAB.ValidateLevelExpr(panel.levelInput:GetText())
            panel.levelInput:SetText(normalized)
            if valid then
                YAB.SetLevelFilterExpr(normalized)
                panel.levelStatus:SetText(normalized == "" or normalized == "0" and "显示全部等级角色。" or ("已过滤：" .. normalized))
                panel.levelStatus:SetTextColor(Theme.Colors.success[1], Theme.Colors.success[2], Theme.Colors.success[3])
                if context and context.notifyPageChanged then context.notifyPageChanged() end
            else
                panel.levelStatus:SetText("格式无效：" .. tostring(badToken or ""))
                panel.levelStatus:SetTextColor(Theme.Colors.danger[1], Theme.Colors.danger[2], Theme.Colors.danger[3])
            end
        end
        panel.levelInput:SetScript("OnEnterPressed", function(self) CommitEmbeddedFilter(); self:ClearFocus() end)
        panel.levelInput:SetScript("OnEditFocusLost", CommitEmbeddedFilter)
        panel.levelInput:SetScript("OnEscapePressed", function(self) self:SetText(tostring(YAB.GetLevelFilterExpr() or "")); self:ClearFocus() end)

        panel.custom = Section(panel, "自定义目标", 292, 1)
        panel.custom:SetPoint("TOPRIGHT", panel.targets, "TOPRIGHT", 596, 0)
        local customHint = context.createText(panel.custom, Theme.Font.assist, Theme.Colors.muted, "LEFT")
        customHint:SetPoint("TOPLEFT", 12, -40); customHint:SetText("NPC ID（点击下方已添加的目标可回填）")
        panel.npcInput = CreateFrame("EditBox", nil, panel.custom, "InputBoxTemplate")
        panel.npcInput:SetSize(92, 24); panel.npcInput:SetPoint("TOPLEFT", 12, -70); panel.npcInput:SetAutoFocus(false); panel.npcInput:SetNumeric(true)
        local add = context.createButton(panel.custom, 52, "添加"); add:SetState("selected"); add:SetPoint("LEFT", panel.npcInput, "RIGHT", 8, 0)
        local remove = context.createButton(panel.custom, 52, "删除", "danger"); remove:SetPoint("LEFT", add, "RIGHT", 6, 0)
        panel.customStatus = context.createText(panel.custom, Theme.Font.assist, Theme.Colors.muted, "LEFT"); panel.customStatus:SetPoint("TOPLEFT", 12, -102); panel.customStatus:SetPoint("TOPRIGHT", -12, -102)
        local function UpdateCustom(ok, message)
            panel.customStatus:SetText(message or "")
            local color = ok and Theme.Colors.success or Theme.Colors.danger
            panel.customStatus:SetTextColor(color[1], color[2], color[3])
            if ok then panel.npcInput:SetText("") end
            if context and context.refreshPage then context.refreshPage() end
        end
        add:SetScript("OnClick", function() local ok, message = YAB.AddCustomTarget(panel.npcInput:GetText()); UpdateCustom(ok, message or (ok and "已添加自定义目标。" or "添加失败。")) end)
        remove:SetScript("OnClick", function() local ok, message = YAB.RemoveCustomTarget(panel.npcInput:GetText()); UpdateCustom(ok, message or (ok and "已删除自定义目标。" or "删除失败。")) end)

    end

    panel.levelInput:SetText(tostring(YAB.GetLevelFilterExpr() or ""))
    panel.filter:Hide()
    local panelWidth = math.max(600, parent:GetWidth() or 600)
    local halfWidth = math.floor((panelWidth - 12) / 2)
    panel:SetWidth(panelWidth)
    panel.targets:SetWidth(halfWidth)
    panel.filter:SetWidth(halfWidth)
    panel.custom:SetWidth(halfWidth)
    local groups = YAB.GetDisplayGroups and YAB.GetDisplayGroups() or {}
    for _, check in pairs(panel.groupChecks) do check:Hide() end
    for _, check in pairs(panel.itemChecks) do check:Hide() end
    for _, button in pairs(panel.groupExpandButtons) do button:Hide() end
    for _, button in ipairs(panel.customRows) do button:Hide() end
    local targetsByGroup = {}
    for _, target in ipairs(YAB.GetAllBossList and YAB.GetAllBossList() or {}) do
        local groupKey = target.group or "custom"
        targetsByGroup[groupKey] = targetsByGroup[groupKey] or {}
        targetsByGroup[groupKey][#targetsByGroup[groupKey] + 1] = target
    end
    local columnHeight = 0
    local columnWidth = halfWidth - 24
    for index, group in ipairs(groups) do
        local check = panel.groupChecks[group.key]
        if not check then
            check = context.createCheckbox(panel.targetContent, group.name)
            check:SetWidth(250); check.label:SetWidth(224)
            panel.groupChecks[group.key] = check
            check:SetScript("OnClick", function(self)
                self:SetChecked(not self:GetChecked())
                YAB.SetDisplayGroupEnabled(group.key, self:GetChecked())
                if context and context.notifyPageChanged then context.notifyPageChanged() end
            end)
        end
        check:SetWidth(columnWidth - 30); check.label:SetWidth(columnWidth - 56)
        check:ClearAllPoints(); check:SetPoint("TOPLEFT", panel.targetContent, "TOPLEFT", 0, -columnHeight)
        check:SetChecked(YAB.IsDisplayGroupEnabled(group.key)); check.label:SetText(group.name); check:Show()
        local expand = panel.groupExpandButtons[group.key]
        if not expand then
            expand = context.createButton(panel.targetContent, 22, "+")
            panel.groupExpandButtons[group.key] = expand
            expand:SetScript("OnClick", function()
                local expanded = panel.expandedGroups[group.key] ~= false
                panel.expandedGroups[group.key] = not expanded
                YAB.PersistDB()
                if context and context.refreshPage then context.refreshPage() end
            end)
        end
        expand:ClearAllPoints(); expand:SetPoint("TOPLEFT", panel.targetContent, "TOPLEFT", columnWidth - 30, -columnHeight + 3)
        local expanded = panel.expandedGroups[group.key] ~= false
        expand:SetText(expanded and "−" or "+"); expand:Show()
        columnHeight = columnHeight + 28
        for _, target in ipairs(expanded and (targetsByGroup[group.key] or {}) or {}) do
            local itemCheck = panel.itemChecks[target.key]
            if not itemCheck then
                itemCheck = context.createCheckbox(panel.targetContent, target.name)
                itemCheck:SetWidth(236); itemCheck.label:SetWidth(210)
                panel.itemChecks[target.key] = itemCheck
                itemCheck:SetScript("OnClick", function(self)
                    self:SetChecked(not self:GetChecked())
                    YAB.SetDisplayItemEnabled(target.key, self:GetChecked())
                    if context and context.notifyPageChanged then context.notifyPageChanged() end
                end)
            end
            itemCheck:SetWidth(columnWidth - 44); itemCheck.label:SetWidth(columnWidth - 70)
            itemCheck:ClearAllPoints(); itemCheck:SetPoint("TOPLEFT", panel.targetContent, "TOPLEFT", 16, -columnHeight)
            itemCheck:SetChecked(YAB.IsDisplayItemChecked(target.key)); itemCheck.label:SetText(target.name)
            itemCheck:EnableMouse(YAB.IsDisplayGroupEnabled(group.key))
            itemCheck:Show()
            columnHeight = columnHeight + 26
        end
        columnHeight = columnHeight + 4
    end
    local targetHeight = math.max(88, columnHeight)
    panel.targetContent:SetHeight(targetHeight)
    panel.targets:SetHeight(targetHeight + 74)

    panel.filter:ClearAllPoints(); panel.filter:SetPoint("TOPLEFT", panel.targets, "TOPRIGHT", 12, 0); panel.filter:Hide()
    panel.custom:ClearAllPoints(); panel.custom:SetPoint("TOPLEFT", panel.targets, "TOPRIGHT", 12, 0)
    local customTargets = {}
    for _, target in ipairs(targetsByGroup.custom or {}) do customTargets[#customTargets + 1] = target end
    local customY = 126
    for index, target in ipairs(customTargets) do
        local row = panel.customRows[index]
        if not row then
            row = context.createButton(panel.custom, 128, "")
            row:SetScript("OnClick", function(self)
                panel.npcInput:SetText(tostring(self.npcID or "")); panel.npcInput:ClearFocus()
                panel.customStatus:SetText("已回填 NPC ID " .. tostring(self.npcID or "") .. "，可继续删除。")
                panel.customStatus:SetTextColor(Theme.Colors.muted[1], Theme.Colors.muted[2], Theme.Colors.muted[3])
            end)
            panel.customRows[index] = row
        end
        local column = (index - 1) % 2
        local rowIndex = math.floor((index - 1) / 2)
        local customButtonWidth = math.floor((panel.custom:GetWidth() - 36) / 2)
        row:SetWidth(customButtonWidth); row:ClearAllPoints(); row:SetPoint("TOPLEFT", panel.custom, "TOPLEFT", 12 + column * (customButtonWidth + 8), -customY - rowIndex * 28)
        row.npcID = target.id; row:SetText((target.name or "自定义目标") .. " " .. tostring(target.id)); row:Show()
    end
    local customRows = math.ceil(#customTargets / 2)
    panel.custom:SetHeight(math.max(126, 134 + customRows * 28))
    panel:SetHeight(math.max(panel.targets:GetHeight(), panel.custom:GetHeight()))
    return panel:GetHeight()
end
