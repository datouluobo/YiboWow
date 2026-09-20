-- Internal account pages are loaded after AccountView.lua.  They own page-specific
-- presentation while AccountView remains the shared shell and public API.
local Core = _G.YiboCore
local AccountView = Core.AccountView
local Theme = Core.UITheme
local COLORS = Theme.Colors
local Helpers = AccountView._internal
local AddText = Helpers.AddText
local CreateChromeButton = Helpers.CreateChromeButton
local Settings = Helpers.Settings
local PageEnabled = Helpers.PageEnabled
local SORT_MODES = Helpers.SORT_MODES
local SORT_LABELS = Helpers.SORT_LABELS
local ArchiveSettings = Helpers.ArchiveSettings
local ArchiveFieldVisible = Helpers.ArchiveFieldVisible
local GetPreviewFieldVisible = Helpers.GetPreviewFieldVisible
local PROFILE_FILTER_LABELS = { all = "全部角色", profiled = "仅有档案", missing = "仅缺少档案" }
local function CreateSettings(parent)
    parent.heading = AddText(parent, "GameFontNormalLarge", nil, COLORS.text); parent.heading:SetPoint("TOPLEFT", 20, -18)
    parent.hint = AddText(parent, "GameFontNormalSmall", nil, COLORS.muted); parent.hint:SetPoint("TOPLEFT", 20, -47)
    parent.resetLayout = CreateChromeButton(parent, 116, 22, "重置窗口布局")
    parent.resetLayout:SetPoint("TOPRIGHT", -20, -18)
    parent.resetLayout:SetScript("OnClick", function() AccountView:ResetWindowLayout() end)
    parent.scroll = Theme:CreateScrollFrame(parent)
    parent.scroll:SetPoint("TOPLEFT", 20, -76); parent.scroll:SetPoint("BOTTOMRIGHT", -Theme.Space.xs, 14)
    parent.content = CreateFrame("Frame", nil, parent.scroll); parent.content:SetWidth(620); parent.scroll:SetScrollChild(parent.content)
    parent.rows = {}
end

local function SettingsRow(parent, index, kind)
    local row = parent.rows[index]
    if row and row.controlType ~= kind then row:Hide(); row = nil end
    if not row then
        if kind == "check" then
            row = Theme:CreateCheckbox(parent.content, "")
            row:SetWidth(540)
            row.label:SetWidth(520)
        elseif kind == "heading" then
            row = AddText(parent.content, "GameFontNormal", nil, COLORS.accent)
        elseif kind == "character-order" then
            row = CreateFrame("Frame", nil, parent.content)
            row:SetSize(600, 24)
            row.label = AddText(row, "GameFontNormalSmall", nil, COLORS.text)
            row.label:SetPoint("LEFT", 2, 0); row.label:SetPoint("RIGHT", -258, 0)
            row.up = CreateChromeButton(row, 44, 22, "上移")
            row.up:SetPoint("RIGHT", -206, 0)
            row.down = CreateChromeButton(row, 44, 22, "下移")
            row.down:SetPoint("RIGHT", -158, 0)
            row.hidden = CreateChromeButton(row, 58, 22, "隐藏", false)
            row.hidden:SetPoint("RIGHT", -96, 0)
            row.delete = CreateChromeButton(row, 88, 22, "删除缓存", true)
            row.delete:SetPoint("RIGHT", -2, 0)
        elseif kind == "addon-panel" then
            row = CreateFrame("Frame", nil, parent.content)
            row:SetWidth(600)
        elseif kind == "input" then
            row = CreateFrame("Frame", nil, parent.content)
            row:SetHeight(Theme.Size.standard)
            row.label = AddText(row, "GameFontNormalSmall", nil, COLORS.muted)
            row.label:SetPoint("LEFT", 0, 0)
            row.input = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
            row.input:SetHeight(20); row.input:SetAutoFocus(false); row.input:SetMaxLetters(64)
            row.input:SetTextInsets(7, 7, 0, 0)
        elseif kind == "dropdown" then
            row = CreateFrame("Frame", nil, parent.content)
            row:SetHeight(Theme.Size.standard)
            row.label = AddText(row, "GameFontNormalSmall", nil, COLORS.muted)
            row.label:SetPoint("LEFT", 0, 0); row.label:SetWidth(104)
            row.dropdown = Theme:CreateDropdown(row, 180, {})
            row.dropdown:SetPoint("LEFT", row.label, "RIGHT", 8, 0)
        elseif kind == "business-entry" then
            -- All page, entry, and column decisions stay adjacent to their
            -- plugin instead of sending users to a separate field section.
            row = CreateFrame("Frame", nil, parent.content)
            row:SetHeight(Theme.Size.standard)
            row.title = AddText(row, "GameFontNormalSmall", nil, COLORS.text)
            row.visible = Theme:CreateCheckbox(row, "账号页显示")
            row.entryLabel = AddText(row, "GameFontNormalSmall", nil, COLORS.muted)
            row.entryLabel:SetText("独立入口")
            row.dropdown = Theme:CreateDropdown(row, 126, {})
            row.mainFields = Theme:CreateMultiSelectDropdown(row, 118, {})
            row.previewFields = Theme:CreateMultiSelectDropdown(row, 118, {})
            row.viewMode = Theme:CreateDropdown(row, 90, {})
        elseif kind == "core-entry" then
            row = CreateFrame("Frame", nil, parent.content)
            row:SetHeight(Theme.Size.standard)
            row.title = AddText(row, "GameFontNormalSmall", nil, COLORS.text)
            row.visible = Theme:CreateCheckbox(row, "窗口悬停")
            row.entryLabel = AddText(row, "GameFontNormalSmall", nil, COLORS.muted)
            row.entryLabel:SetText("Core 入口")
            row.dropdown = Theme:CreateDropdown(row, 110, {})
            row.previewLabel = AddText(row, "GameFontNormalSmall", nil, COLORS.muted)
            row.preview = Theme:CreateDropdown(row, 120, {})
        elseif kind == "archive-entry" then
            -- Character Archive is a built-in page, so it belongs in the
            -- same field controls as every business page rather than behind
            -- a second disclosure elsewhere on this screen.
            row = CreateFrame("Frame", nil, parent.content)
            row:SetHeight(Theme.Size.standard)
            row.title = AddText(row, "GameFontNormalSmall", nil, COLORS.text)
            row.mainFields = Theme:CreateMultiSelectDropdown(row, 118, {})
            row.previewFields = Theme:CreateMultiSelectDropdown(row, 118, {})
        elseif kind == "business-header" then
            row = CreateFrame("Frame", nil, parent.content)
            row:SetHeight(20)
            row.labels = {}
            for labelIndex = 1, 7 do
                row.labels[labelIndex] = AddText(row, "GameFontNormalSmall", nil, COLORS.muted)
                row.labels[labelIndex]:SetJustifyH(labelIndex >= 6 and "CENTER" or "LEFT")
            end
        elseif kind == "short-name" then
            row = CreateFrame("Frame", nil, parent.content)
            row:SetHeight(28)
            row.label = AddText(row, "GameFontNormalSmall", nil, COLORS.text)
            row.label:SetPoint("LEFT", 2, 0); row.label:SetPoint("RIGHT", -198, 0)
            row.input = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
            row.input:SetSize(112, 20); row.input:SetPoint("RIGHT", -80, 0); row.input:SetAutoFocus(false); row.input:SetMaxLetters(32); row.input:SetTextInsets(6, 6, 0, 0)
            row.clear = CreateChromeButton(row, 70, 20, "清除", false); row.clear:SetPoint("RIGHT", -2, 0)
        else
            row = CreateChromeButton(parent.content, 250, 22, "")
        end
        parent.rows[index] = row
    end
    row.controlType = kind
    return row
end

local function PlaceSettingsRow(row, y)
    row:ClearAllPoints(); row:SetPoint("TOPLEFT", 2, -y)
end

-- Settings supplied by a business addon live in this host.  Addons own their
-- data and validation, while Core owns the visual vocabulary so a legacy
-- settings frame can never leak a second theme, title bar, or scrollbar into
-- the workbench.
local function CreateHostedSettingsSection(parent, title, width, height)
    local section = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    section:SetSize(width, height)
    section:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    section:SetBackdropColor(COLORS.panel[1], COLORS.panel[2], COLORS.panel[3], 0.92)
    section:SetBackdropBorderColor(COLORS.lineSoft[1], COLORS.lineSoft[2], COLORS.lineSoft[3], 1)
    section.title = Theme:CreateText(section, Theme.Font.body, COLORS.accent, "LEFT")
    section.title:SetPoint("TOPLEFT", 12, -10)
    section.title:SetPoint("TOPRIGHT", -12, -10)
    section.title:SetText(title or "")
    section.rule = section:CreateTexture(nil, "ARTWORK")
    section.rule:SetColorTexture(COLORS.lineSoft[1], COLORS.lineSoft[2], COLORS.lineSoft[3], 0.8)
    section.rule:SetHeight(1)
    section.rule:SetPoint("TOPLEFT", 12, -30)
    section.rule:SetPoint("TOPRIGHT", -12, -30)
    return section
end

local function RefreshSettings(parent)
    local settings = Settings()
    -- The settings host follows the available right pane.  Individual controls
    -- may stay compact, but hosted plugin sections can use the spare width
    -- instead of leaving a narrow legacy panel stranded on the left.
    local settingsViewportWidth = parent.scroll:GetWidth() or 0
    if settingsViewportWidth <= 100 then settingsViewportWidth = (parent:GetWidth() or 658) - 38 end
    parent.content:SetWidth(math.max(600, settingsViewportWidth - 18))
    local targetID = AccountView.settingsTargetPageID or "display"
    local settingsOnlyID = type(targetID) == "string" and targetID:match("^addon%-settings:(.+)$")
    local selected = AccountView._pages[targetID]
    local settingsOnly = settingsOnlyID and Core.SettingsRegistry and Core.SettingsRegistry._panels[settingsOnlyID]
    local displayMode, sortingMode, coreMode = targetID == "display", targetID == "sorting", targetID == "core"
    if not (displayMode or sortingMode or coreMode or settingsOnly or (selected and not selected.internal)) then
        targetID, displayMode = "display", true
        AccountView.settingsTargetPageID = targetID
    end
    local titles = { display = "显示与入口", sorting = "角色与排序", core = "窗口" }
    parent.heading:SetText(titles[targetID] or ((selected and selected.title) or (settingsOnly and settingsOnly.title) or "插件") .. "业务设置")
    parent.hint:SetText(displayMode and "集中管理 Core 与插件页面、独立入口及显示字段。" or (sortingMode and "统一设置角色、排序、缓存和业务页面的角色过滤。" or (coreMode and "管理窗口布局。" or "这里只保留该插件自身的业务规则与数据管理。")))
    parent.resetLayout:SetShown(coreMode)

    local index, y, gridColumn = 0, 0, 0
    local gridGap, gridMinimum = 16, 230
    local gridColumns = math.max(1, math.floor((parent.content:GetWidth() + gridGap) / (gridMinimum + gridGap)))
    local gridWidth = math.floor((parent.content:GetWidth() - gridGap * (gridColumns - 1)) / gridColumns)
    local function PlaceGridControl(row)
        row:ClearAllPoints(); row:SetPoint("TOPLEFT", 2 + gridColumn * (gridWidth + gridGap), -y); row:SetWidth(gridWidth)
        gridColumn = gridColumn + 1
        if gridColumn >= gridColumns then y = y + Theme.Size.standard + 4; gridColumn = 0 end
    end
    local function FinishGridRow()
        if gridColumn ~= 0 then
            y = y + Theme.Size.standard + 4
            gridColumn = 0
        end
    end
    local function SetGridMinimum(value, maximumColumns)
        FinishGridRow()
        gridMinimum = value
        gridColumns = math.max(1, math.floor((parent.content:GetWidth() + gridGap) / (gridMinimum + gridGap)))
        if maximumColumns then gridColumns = math.min(gridColumns, maximumColumns) end
        gridWidth = math.floor((parent.content:GetWidth() - gridGap * (gridColumns - 1)) / gridColumns)
    end
    local function Heading(text)
        FinishGridRow()
        index = index + 1; local row = SettingsRow(parent, index, "heading"); PlaceSettingsRow(row, y); row:SetText(text); row:SetTextColor(COLORS.accent[1], COLORS.accent[2], COLORS.accent[3]); row:Show(); y = y + 28
    end
    local function Check(label, checked, callback)
        index = index + 1; local row = SettingsRow(parent, index, "check")
        PlaceGridControl(row); row.label:SetWidth(math.max(40, gridWidth - 24))
        row.label:SetText(label); row:SetChecked(checked); row:SetScript("OnClick", function(self) self:SetChecked(not self:GetChecked()); callback(self:GetChecked()); AccountView:RefreshPage() end); row:Show()
    end
    local function Button(label, callback, width, kind, selected)
        index = index + 1; local row = SettingsRow(parent, index, "button")
        PlaceGridControl(row)
        row.kind = kind or "default"; row:SetText(label); row:SetState(selected and "selected" or "default"); row:SetScript("OnClick", callback); row:Show()
        return row
    end
    local function Input(label, value, callback, inputWidth)
        index = index + 1; local row = SettingsRow(parent, index, "input")
        PlaceGridControl(row)
        row.label:SetText(label); row.label:SetWidth(math.min(84, math.floor(gridWidth * 0.36)))
        row.input:ClearAllPoints(); row.input:SetPoint("LEFT", row.label, "RIGHT", 6, 0)
        if inputWidth then row.input:SetWidth(inputWidth) else row.input:SetPoint("RIGHT", 0, 0) end
        row.input:SetText(value or "")
        local function Save(control)
            local valid, normalized, badToken = Core.LevelFilter:Validate(control:GetText())
            if not valid then
                control:SetText(value or "")
                Core:Print("等级过滤格式无效：" .. tostring(badToken))
                return
            end
            callback(normalized)
            control:SetText(normalized)
            AccountView:RefreshPage()
        end
        row.input:SetScript("OnEnterPressed", function(control) Save(control); control:ClearFocus() end)
        row.input:SetScript("OnEditFocusLost", Save)
        row.input:SetScript("OnEscapePressed", function(control) control:SetText(value or ""); control:ClearFocus() end)
        row:Show()
        return row
    end
    local function CharacterFilterInput(page, filter)
        -- Role filters are a compact, repeated form.  Give the page name a
        -- fixed no-wrap lane and align every editor farther right, rather than
        -- letting a narrow grid split “等级” onto a second line.
        FinishGridRow()
        index = index + 1
        local row = SettingsRow(parent, index, "input")
        row:ClearAllPoints(); row:SetPoint("TOPLEFT", 2, -y); row:SetWidth(parent.content:GetWidth() or 600)
        row.label:ClearAllPoints(); row.label:SetPoint("LEFT", 0, 0); row.label:SetWidth(184); row.label:SetWordWrap(false)
        row.label:SetText(page.title .. " · 等级")
        row.input:ClearAllPoints(); row.input:SetPoint("LEFT", row.label, "RIGHT", 18, 0); row.input:SetWidth(150)
        row.input:SetText(filter.GetExpression() or "")
        local function Save(control)
            local valid, normalized, badToken = Core.LevelFilter:Validate(control:GetText())
            if not valid then
                control:SetText(filter.GetExpression() or "")
                Core:Print(page.title .. "等级过滤格式无效：" .. tostring(badToken))
                return
            end
            local ok, errorMessage = filter.SetExpression(normalized)
            if ok == false then
                control:SetText(filter.GetExpression() or "")
                Core:Print(page.title .. "等级过滤保存失败：" .. tostring(errorMessage))
                return
            end
            control:SetText(normalized)
            AccountView:RefreshPage()
        end
        row.input:SetScript("OnEnterPressed", function(control) Save(control); control:ClearFocus() end)
        row.input:SetScript("OnEditFocusLost", Save)
        row.input:SetScript("OnEscapePressed", function(control) control:SetText(filter.GetExpression() or ""); control:ClearFocus() end)
        row:Show(); y = y + Theme.Size.standard + 4
    end
    local function Dropdown(label, value, options, callback)
        index = index + 1; local row = SettingsRow(parent, index, "dropdown")
        PlaceGridControl(row)
        row.label:SetText(label); row.label:SetWidth(math.min(120, math.floor(gridWidth * 0.38)))
        row.dropdown:ClearAllPoints(); row.dropdown:SetPoint("LEFT", row.label, "RIGHT", 8, 0); row.dropdown:SetPoint("RIGHT", 0, 0)
        row.dropdown:SetOptions(options); row.dropdown:SetValue(value)
        row.dropdown:SetOnValueChanged(function(nextValue)
            callback(nextValue)
            AccountView:RefreshPage()
        end)
        row:Show()
        return row
    end
    -- One shared column map keeps Core, Character Archive, and every plugin
    -- aligned even when a particular page has no entry, layout mode, or
    -- hover fields. Widths deliberately favor the selected-value text over
    -- empty whitespace between controls.
    local DISPLAY_COLUMNS = {
        page = { x = 2, width = 90 },
        visible = { x = 100, width = 100 },
        entryLabel = { x = 208, width = 70 },
        entryMode = { x = 282, width = 116 },
        option = { x = 406, width = 108 },
        mainFields = { x = 522, width = 126 },
        previewFields = { x = 656, width = 126 },
    }
    local function PlaceDisplayColumn(control, columnID)
        local column = DISPLAY_COLUMNS[columnID]
        control:ClearAllPoints(); control:SetPoint("LEFT", column.x, 0); control:SetWidth(column.width)
    end
    local function BusinessEntryRow(page, entry, options)
        -- This is a form row, not a grid item.  Keeping its anchors local to
        -- the row guarantees that every plugin retains one readable scan line
        -- at any supported settings-window width.
        FinishGridRow()
        index = index + 1
        local row = SettingsRow(parent, index, "business-entry")
        row:ClearAllPoints(); row:SetPoint("TOPLEFT", 2, -y); row:SetWidth(parent.content:GetWidth() or 600); row:SetHeight(Theme.Size.standard)
        PlaceDisplayColumn(row.title, "page"); row.title:SetText(page.title)
        PlaceDisplayColumn(row.visible, "visible")
        row.visible.label:SetWidth(76); row.visible.label:SetText("账号页显示")
        row.visible:SetChecked(PageEnabled(page))
        row.visible:SetScript("OnClick", function(control)
            control:SetChecked(not control:GetChecked())
            settings.pages[page.id] = control:GetChecked()
            AccountView:RefreshPage()
        end)
        PlaceDisplayColumn(row.entryLabel, "entryLabel"); row.entryLabel:SetWordWrap(false)
        PlaceDisplayColumn(row.dropdown, "entryMode")
        if entry then
            row.entryLabel:SetText("独立入口")
            row.entryLabel:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
            row.dropdown:SetOptions(options)
            row.dropdown:SetValue(Core.Entry:GetBusinessEntryMode(entry.id))
            row.dropdown:SetOnValueChanged(function(mode)
                settings.entry.pageModes[entry.id] = mode
                Core.Entry:Refresh()
                AccountView:RefreshPage()
            end)
            row.dropdown:Show()
        else
            row.entryLabel:SetText("无独立入口")
            row.entryLabel:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
            row.dropdown:Hide()
        end
        local hasMainFields = #page.fields > 0
        PlaceDisplayColumn(row.viewMode, "option")
        PlaceDisplayColumn(row.mainFields, "mainFields")
        PlaceDisplayColumn(row.previewFields, "previewFields")
        if hasMainFields then
            local mainOptions, previewOptions = {}, {}
            for _, field in ipairs(page.fields) do
                local currentField = field
                mainOptions[#mainOptions + 1] = {
                    title = currentField.title,
                    isSelected = function() return AccountView:GetFieldVisible(page.id, currentField) end,
                    setSelected = function(visible) AccountView:SetFieldVisible(page.id, currentField.id, visible) end,
                }
                if page.previewEnabled and type(page.SetPreviewFieldVisible) == "function" then
                    previewOptions[#previewOptions + 1] = {
                        title = currentField.title,
                        isSelected = function() return GetPreviewFieldVisible(page, currentField) end,
                        setSelected = function(visible) page.SetPreviewFieldVisible(currentField.id, visible) end,
                    }
                end
            end
            row.mainFields:SetSummary("主表")
            row.mainFields:SetOptions(mainOptions); row.mainFields:Show()
            if #previewOptions > 0 then
                row.previewFields:SetSummary("悬停")
                row.previewFields:SetOptions(previewOptions); row.previewFields:Show()
            else
                row.previewFields:Hide()
            end
        else
            row.mainFields:Hide(); row.previewFields:Hide()
        end
        if page.viewModes then
            local viewModeOptions = {}
            for _, mode in ipairs(page.viewModes) do viewModeOptions[#viewModeOptions + 1] = { value = mode.id, label = mode.title } end
            row.viewMode:SetOptions(viewModeOptions); row.viewMode:SetValue(AccountView:GetPageViewMode(page.id, page.viewModes))
            row.viewMode:SetOnValueChanged(function(mode)
                AccountView:SetPageViewMode(page.id, mode)
            end)
            row.viewMode:Show()
        else
            row.viewMode:Hide()
        end
        row:Show()
        y = y + Theme.Size.standard + 4
    end
    local function DisplayTableHeader()
        FinishGridRow()
        index = index + 1
        local row = SettingsRow(parent, index, "business-header")
        row:ClearAllPoints(); row:SetPoint("TOPLEFT", 2, -y); row:SetWidth(parent.content:GetWidth() or 600)
        local labels = {
            { "page", "页面" }, { "visible", "显示" }, { "entryLabel", "入口" },
            { "entryMode", "入口位置" }, { "option", "页面选项" },
            { "mainFields", "主表字段" }, { "previewFields", "悬停字段" },
        }
        for labelIndex, item in ipairs(labels) do
            local text = row.labels[labelIndex]
            local column = DISPLAY_COLUMNS[item[1]]
            text:ClearAllPoints(); text:SetPoint("LEFT", column.x, 0); text:SetWidth(column.width)
            text:SetText(item[2])
        end
        row:Show()
        y = y + 22
    end
    local function ArchiveEntryRow()
        FinishGridRow()
        index = index + 1
        local row = SettingsRow(parent, index, "archive-entry")
        local archiveSettings = ArchiveSettings()
        row:ClearAllPoints(); row:SetPoint("TOPLEFT", 2, -y); row:SetWidth(parent.content:GetWidth() or 600)
        PlaceDisplayColumn(row.title, "page"); row.title:SetText("角色档案")
        PlaceDisplayColumn(row.mainFields, "mainFields")
        PlaceDisplayColumn(row.previewFields, "previewFields")
        local mainOptions, previewOptions = {}, {}
        for _, field in ipairs(Core.Fields:GetByConsumer("character-archive")) do
            local currentField = field
            mainOptions[#mainOptions + 1] = {
                title = currentField.title,
                isSelected = function() return ArchiveFieldVisible(currentField, false) end,
                setSelected = function(visible) archiveSettings.fields[currentField.id] = visible end,
            }
            previewOptions[#previewOptions + 1] = {
                title = currentField.title,
                isSelected = function() return ArchiveFieldVisible(currentField, true) end,
                setSelected = function(visible) archiveSettings.previewFields[currentField.id] = visible end,
            }
        end
        row.mainFields:SetSummary("主表"); row.mainFields:SetOptions(mainOptions); row.mainFields:Show()
        row.previewFields:SetSummary("悬停"); row.previewFields:SetOptions(previewOptions); row.previewFields:Show()
        row:Show()
        y = y + Theme.Size.standard + 4
    end
    local function CoreEntryRow(options)
        FinishGridRow()
        index = index + 1
        local row = SettingsRow(parent, index, "core-entry")
        row:ClearAllPoints(); row:SetPoint("TOPLEFT", 2, -y); row:SetWidth(parent.content:GetWidth() or 600)
        PlaceDisplayColumn(row.title, "page"); row.title:SetText("Core")
        PlaceDisplayColumn(row.visible, "visible")
        row.visible.label:SetWidth(76); row.visible.label:SetText("窗口悬停")
        row.visible:SetChecked(settings.entry.showPreviewWhileMainWindowOpen == true)
        row.visible:SetScript("OnClick", function(control)
            control:SetChecked(not control:GetChecked())
            settings.entry.showPreviewWhileMainWindowOpen = control:GetChecked() == true
            AccountView:RefreshPage()
        end)
        PlaceDisplayColumn(row.entryLabel, "entryLabel"); row.entryLabel:SetWordWrap(false); row.entryLabel:SetText("Core 入口")
        PlaceDisplayColumn(row.dropdown, "entryMode")
        row.dropdown:SetOptions(options); row.dropdown:SetValue(Core.Entry and Core.Entry:GetCoreEntryMode() or "both")
        row.dropdown:SetOnValueChanged(function(mode)
            if Core.Entry then Core.Entry:SetCoreEntryMode(mode) end
            AccountView:RefreshPage()
        end)
        local previewOptions = {}
        for _, page in ipairs(AccountView:GetPreviewPageOptions()) do previewOptions[#previewOptions + 1] = { value = page.id, label = "悬停·" .. page.title } end
        -- Core uses the same contextual-options column as page layout modes;
        -- unlike business pages its option is the page used for the preview.
        row.previewLabel:Hide()
        PlaceDisplayColumn(row.preview, "option")
        row.preview:SetOptions(previewOptions); row.preview:SetValue(AccountView:GetPreviewPage().id)
        row.preview:SetOnValueChanged(function(pageID)
            settings.entry.previewPageID = pageID
            AccountView:RefreshPage()
        end)
        row:Show(); y = y + Theme.Size.standard + 4
    end
    local function AddonPanel(details)
        if type(details.CreateSettingsPanel) ~= "function" then return end
        FinishGridRow()
        index = index + 1
        local row = SettingsRow(parent, index, "addon-panel")
        row:SetWidth(parent.content:GetWidth() or 600)
        row:ClearAllPoints(); row:SetPoint("TOPLEFT", 2, -y)
        -- The same host row is reused when switching business settings.  Hide
        -- the previous addon's child frame first; otherwise its controls can
        -- remain above the newly selected page.
        local hostedOwner = (selected and selected.id) or (settingsOnly and ("addon-settings:" .. settingsOnly.id))
        if row.yiboHostedOwner ~= hostedOwner then
            for _, child in ipairs({ row:GetChildren() }) do child:Hide() end
            row.yiboHostedOwner = hostedOwner
        end
        row:Show()
        local hostedContext
        hostedContext = {
            refreshPage = function() AccountView:RefreshPage() end,
            notifyPageChanged = function() if selected then AccountView:NotifyPageChanged(selected.id) end end,
            -- Allow a business panel to repaint its own controls without
            -- rebuilding the whole settings workbench.
            refreshPanel = function()
                local ok, heightOrError = xpcall(function()
                    return details.CreateSettingsPanel(row, hostedContext)
                end, function(message) return tostring(message) end)
                if ok then
                    row:SetHeight(math.max(1, tonumber(heightOrError) or row:GetHeight() or 1))
                    if parent.scroll and parent.scroll.RefreshScrollbar then parent.scroll:RefreshScrollbar() end
                else
                    Core:Print("插件 “" .. tostring((selected and selected.title) or (settingsOnly and settingsOnly.title) or "未知") .. "” 的业务设置局部刷新失败：" .. tostring(heightOrError))
                end
            end,
            createSection = CreateHostedSettingsSection,
            createText = function(owner, size, color, justify) return Theme:CreateText(owner, size, color, justify) end,
            createButton = function(owner, width, label, kind) return Theme:CreateButton(owner, width, label, kind) end,
            createCheckbox = function(owner, label) return Theme:CreateCheckbox(owner, label) end,
            bindTooltip = function(control, title, lines) Theme:BindTooltip(control, title, lines) end,
            selectSettingsTarget = function(targetID) AccountView:SelectSettingsTarget(targetID) end,
        }
        local ok, heightOrError = xpcall(function()
            return details.CreateSettingsPanel(row, hostedContext)
        end, function(message) return tostring(message) end)
        if not ok then
            Core:Print("插件 “" .. tostring((selected and selected.title) or (settingsOnly and settingsOnly.title) or "未知") .. "” 的嵌入设置创建失败：" .. tostring(heightOrError))
            if not row.errorLabel then
                row.errorLabel = AddText(row, "GameFontNormalSmall", nil, COLORS.danger)
                row.errorLabel:SetPoint("TOPLEFT", 2, 0); row.errorLabel:SetPoint("RIGHT", -2, 0)
                row.errorLabel:SetWordWrap(true)
            end
            row.errorLabel:SetText("业务设置加载失败：" .. tostring(heightOrError))
            row.errorLabel:Show()
            row:SetHeight(40)
            y = y + 50
            return
        end
        if row.errorLabel then row.errorLabel:Hide() end
        row:SetHeight(math.max(1, tonumber(heightOrError) or row:GetHeight() or 1))
        y = y + row:GetHeight() + 10
    end
    local function SortControls(pageID)
        local page = pageID and AccountView._pages[pageID]
        local saved = page and AccountView:GetPageCharacterSort(pageID) or AccountView:GetDefaultCharacterSort()
        local effective = page and AccountView:GetEffectiveCharacterSort(pageID) or saved
        if page then
            Button("跟随通用设置", function()
                AccountView:ResetPageCharacterSort(pageID)
            end, 300, "default", saved.mode == "inherit")
        end
        for _, mode in ipairs(SORT_MODES) do
            local selectedMode = mode
            Button(SORT_LABELS[selectedMode], function()
                local nextSettings = Copy(effective)
                nextSettings.inherited = nil
                nextSettings.mode = selectedMode
                nextSettings.direction = DefaultDirection(selectedMode)
                if page then AccountView:SetPageCharacterSort(pageID, nextSettings) else AccountView:SetDefaultCharacterSort(nextSettings) end
            end, 300, "default", saved.mode == selectedMode)
        end
        if effective.mode ~= "custom" then
            Button("排序方向：" .. (effective.direction == "asc" and "升序 ↑" or "降序 ↓"), function()
                local nextSettings = Copy(effective)
                nextSettings.inherited = nil
                nextSettings.direction = nextSettings.direction == "asc" and "desc" or "asc"
                if page then AccountView:SetPageCharacterSort(pageID, nextSettings) else AccountView:SetDefaultCharacterSort(nextSettings) end
            end, 300, "secondary")
        end
        Check("当前角色置顶", effective.pinCurrent == true, function(checked)
            local nextSettings = Copy(effective)
            nextSettings.inherited = nil
            nextSettings.pinCurrent = checked
            if page then AccountView:SetPageCharacterSort(pageID, nextSettings) else AccountView:SetDefaultCharacterSort(nextSettings) end
        end)
    end
    local function CharacterOrderRows()
        Button("按最近登录顺序重建", function() AccountView:RebuildCustomCharacterOrder("recent") end, 300, "secondary")
        Button("恢复初始登记顺序", function() AccountView:RebuildCustomCharacterOrder("seen") end, 300, "secondary")
        local byID = {}
        for _, character in ipairs(Core.Characters:GetAllCached()) do byID[character.id] = character end
        local order = AccountView:GetCustomCharacterOrder()
        local orderGap, orderMinimum = 16, 520
        local orderColumns = math.max(1, math.floor((parent.content:GetWidth() + orderGap) / (orderMinimum + orderGap)))
        local orderWidth = math.floor((parent.content:GetWidth() - orderGap * (orderColumns - 1)) / orderColumns)
        -- Keep the order editor inside the visible workbench whenever possible.
        -- Reserve the pagination controls first, then derive how many complete
        -- rows fit in each column from the actual scroll viewport.
        local controlRows = math.ceil(4 / gridColumns)
        local orderTop = y + controlRows * (Theme.Size.standard + 4)
        local availableHeight = math.max(Theme.Size.standard + 4, (parent.scroll:GetHeight() or 0) - orderTop - 8)
        local rowsPerColumn = math.max(1, math.floor(availableHeight / 28))
        local pageSize = rowsPerColumn * orderColumns
        local totalPages = math.max(1, math.ceil(#order / pageSize))
        parent.characterOrderPage = math.max(1, math.min(tonumber(parent.characterOrderPage) or 1, totalPages))
        Button("上一页（" .. parent.characterOrderPage .. " / " .. totalPages .. "）", function()
            parent.characterOrderPage = math.max(1, parent.characterOrderPage - 1); AccountView:RefreshPage()
        end, 300, "secondary")
        Button("下一页（" .. parent.characterOrderPage .. " / " .. totalPages .. "）", function()
            parent.characterOrderPage = math.min(totalPages, parent.characterOrderPage + 1); AccountView:RefreshPage()
        end, 300, "secondary")
        FinishGridRow()
        local first = (parent.characterOrderPage - 1) * pageSize + 1
        local last = math.min(#order, first + pageSize - 1)
        local visibleCount = math.max(0, last - first + 1)
        for slot = 0, visibleCount - 1 do
            local orderIndex = first + slot
            local characterID = order[orderIndex]
            local character = byID[characterID]
            if character then
                index = index + 1
                local row = SettingsRow(parent, index, "character-order")
                -- Fill down the left column before continuing at the right.
                -- This preserves the visible sequence when the editor switches
                -- between one and two columns.
                local orderColumn = math.floor(slot / rowsPerColumn)
                local orderRow = slot % rowsPerColumn
                row:ClearAllPoints(); row:SetPoint("TOPLEFT", 2 + orderColumn * (orderWidth + orderGap), -(y + orderRow * 28)); row:SetWidth(orderWidth)
                row.label:SetText(tostring(orderIndex) .. ". " .. (character.name or "未知角色") .. "-" .. (character.realm or "未知服务器") .. " · " .. tostring(character.level or "?") .. "级")
                local classColor = RAID_CLASS_COLORS and RAID_CLASS_COLORS[character.class or ""]
                row.label:SetTextColor(classColor and classColor.r or COLORS.text[1], classColor and classColor.g or COLORS.text[2], classColor and classColor.b or COLORS.text[3])
                row.up:SetState(orderIndex == 1 and "disabled" or "default")
                row.down:SetState(orderIndex == #order and "disabled" or "default")
                row.up:EnableMouse(orderIndex > 1); row.down:EnableMouse(orderIndex < #order)
                local rowCharacterID = characterID
                row.up:SetScript("OnClick", function() AccountView:MoveCustomCharacter(rowCharacterID, -1) end)
                row.down:SetScript("OnClick", function() AccountView:MoveCustomCharacter(rowCharacterID, 1) end)
                local hidden = Settings().hiddenCharacters[rowCharacterID] == true
                row.hidden:SetText(hidden and "显示" or "隐藏")
                row.hidden.kind = "secondary"; row.hidden:SetState(hidden and "selected" or "default")
                row.hidden:SetScript("OnClick", function()
                    AccountView:SetCharacterHidden(rowCharacterID, not hidden)
                end)
                local current = Core.Characters:GetCurrentID() == characterID
                row.delete:SetText(current and "当前角色" or "删除缓存")
                row.delete:SetState(current and "disabled" or "default")
                row.delete:EnableMouse(not current)
                row.delete:SetScript("OnClick", function() ShowCharacterDeleteConfirmation(rowCharacterID) end)
                row:Show()
            end
        end
        y = y + math.min(rowsPerColumn, visibleCount) * 28
    end

    local function ShortNameRows()
        local characters = Core.Characters:GetAllCached()
        local pageSize = 20
        local totalPages = math.max(1, math.ceil(#characters / pageSize))
        parent.shortNamePage = math.max(1, math.min(tonumber(parent.shortNamePage) or 1, totalPages))
        Button("上一页（" .. parent.shortNamePage .. " / " .. totalPages .. "）", function() parent.shortNamePage = math.max(1, parent.shortNamePage - 1); AccountView:RefreshPage() end, 300, "secondary")
        Button("下一页（" .. parent.shortNamePage .. " / " .. totalPages .. "）", function() parent.shortNamePage = math.min(totalPages, parent.shortNamePage + 1); AccountView:RefreshPage() end, 300, "secondary")
        FinishGridRow()
        local duplicates = Core.Characters:GetShortNameDuplicates()
        local first, last = (parent.shortNamePage - 1) * pageSize + 1, math.min(#characters, parent.shortNamePage * pageSize)
        for characterIndex = first, last do
            local character = characters[characterIndex]
            index = index + 1
            local row = SettingsRow(parent, index, "short-name")
            PlaceSettingsRow(row, y); row:SetWidth(parent.content:GetWidth() or 600)
            local displayName = Core.Characters:GetDisplayName(character, "short")
            local warning = duplicates[displayName] and " · 短名重复" or ""
            row.label:SetText((character.name or "未知角色") .. "-" .. (character.realm or "未知服务器") .. warning)
            row.input:SetText(displayName == character.name and "" or displayName)
            local characterID = character.id
            local function Save(control)
                local result, errorMessage = Core.Characters:SetShortName(characterID, control:GetText())
                if result == nil then Core:Print("短名保存失败：" .. tostring(errorMessage)); return end
                AccountView:RefreshPage()
            end
            row.input:SetScript("OnEnterPressed", function(control) Save(control); control:ClearFocus() end)
            row.input:SetScript("OnEditFocusLost", Save)
            row.input:SetScript("OnEscapePressed", function(control) control:SetText(Core.Characters:GetDisplayName(character, "short") == character.name and "" or Core.Characters:GetDisplayName(character, "short")); control:ClearFocus() end)
            row.clear:SetScript("OnClick", function() Core.Characters:SetShortName(characterID, ""); AccountView:RefreshPage() end)
            row:Show(); y = y + 30
        end
    end

    if sortingMode then
        Heading("默认角色排序")
        SortControls(nil)
        Heading("角色名称")
        local shortNameToggle = Button(parent.showShortNames and "▾ 收起短名管理" or "▸ 管理自定义短名", function() parent.showShortNames = not parent.showShortNames; AccountView:RefreshPage() end, 300, "disclosure")
        if parent.showShortNames then
            FinishGridRow()
            ShortNameRows()
        end
        Heading("角色顺序与缓存")
        Button(parent.showCharacterOrder and "▾ 收起顺序与缓存" or "▸ 打开顺序与缓存", function()
            parent.showCharacterOrder = not parent.showCharacterOrder
            AccountView:RefreshPage()
        end, 300, "disclosure")
        if parent.showCharacterOrder then
            FinishGridRow()
            CharacterOrderRows()
        end
        -- Character filters share the same roster context as sorting and cache
        -- management, so they are a section here rather than a fourth Core
        -- navigation page.
        SetGridMinimum(math.max(300, parent.content:GetWidth() or 620))
        Heading("业务页面角色过滤")
        FinishGridRow()
        index = index + 1
        local ruleHint = SettingsRow(parent, index, "heading")
        PlaceSettingsRow(ruleHint, y)
        ruleHint:SetText("填写规则：90 = 仅 90 级；1-20 = 等级范围；<=3 / >=85 = 比较；留空或 0 = 不过滤。")
        ruleHint:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
        ruleHint:Show(); y = y + 24
        local count = 0
        for _, page in ipairs(AccountView._pageOrder) do
            local filter = page.characterFilter
            if not page.internal and filter then
                count = count + 1
                CharacterFilterInput(page, filter)
            end
        end
        if count == 0 then Heading("暂无支持角色过滤的业务页面") end
        local archive = ArchiveSettings()
        local function CycleArchiveProfile(mode)
            local values = { "all", "profiled", "missing" }
            local current = archive.filters[mode].profile
            for position, value in ipairs(values) do
                if value == current then archive.filters[mode].profile = values[(position % #values) + 1]; break end
            end
            AccountView:RefreshPage()
        end
        Heading("角色档案角色过滤")
        Button("主表筛选：" .. (PROFILE_FILTER_LABELS[archive.filters.page.profile] or PROFILE_FILTER_LABELS.all), function() CycleArchiveProfile("page") end, 300)
        Check("主表筛选时包含已隐藏角色", archive.filters.page.includeHidden == true, function(checked) archive.filters.page.includeHidden = checked end)
        Input("主表等级过滤", archive.filters.page.levelExpr, function(value) archive.filters.page.levelExpr = value end)
        Heading("角色档案悬停角色过滤")
        Button("悬停筛选：" .. (PROFILE_FILTER_LABELS[archive.filters.preview.profile] or PROFILE_FILTER_LABELS.all), function() CycleArchiveProfile("preview") end, 300)
        Check("悬停筛选时包含已隐藏角色", archive.filters.preview.includeHidden == true, function(checked) archive.filters.preview.includeHidden = checked end)
        Input("悬停等级过滤", archive.filters.preview.levelExpr, function(value) archive.filters.preview.levelExpr = value end)
    elseif coreMode then
        Heading("窗口布局")
        Button("重置窗口位置", function() AccountView:ResetWindowLayout() end)
        Heading("窗口尺寸会随当前页面内容自动适配。")
    elseif displayMode then
        local entryModeOptions = {
            { value = "none", label = "不显示" },
            { value = "broker", label = "仅 Broker" },
            { value = "minimap", label = "仅小地图" },
            { value = "both", label = "两者都显示" },
        }
        Heading("Core 与插件页面")
        DisplayTableHeader()
        CoreEntryRow(entryModeOptions)
        ArchiveEntryRow()
        local displayPages = {}
        for _, page in ipairs(AccountView._pageOrder) do
            if not page.internal then displayPages[#displayPages + 1] = page end
        end
        for _, page in ipairs(AccountView._pageOrder) do
            if not page.internal then
                local entry = Core.Entry and Core.Entry.GetBusinessEntryByPageID and Core.Entry:GetBusinessEntryByPageID(page.id)
                BusinessEntryRow(page, entry, entryModeOptions)
            end
        end
        if #displayPages == 0 then
            Heading("暂无已注册的业务插件")
        end
    else
        local details = settingsOnly or (selected and selected.settings) or {}
        if details.description then
            local text = SettingsRow(parent, index + 1, "heading"); index = index + 1; PlaceSettingsRow(text, y); text:SetText(details.description); text:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3]); text:Show(); y = y + 28
        end
            if type(details.CreateSettingsPanel) == "function" then
                AddonPanel(details)
            else
                Heading("暂无插件专属设置")
            end
    end
    for stale = index + 1, #parent.rows do
        local row = parent.rows[stale]
        for _, dropdown in ipairs({ row.dropdown, row.mainFields, row.previewFields, row.viewMode, row.preview }) do
            if dropdown and dropdown.menu then dropdown.menu:Hide() end
        end
        row:Hide()
    end
    parent.content:SetHeight(math.max(y + 8, parent.scroll:GetHeight() or 1))
    parent.scroll:RefreshScrollbar()
end

AccountView._pages.settings = {
    id = "settings", title = "设置", order = 999, internal = true,
    Create = CreateSettings, Refresh = RefreshSettings,
}
