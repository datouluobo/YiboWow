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
local PROFILE_FILTER_LABELS = Core.Locale:Bind(function() return { all = Core:Text("CORE.ALL_CHARACTERS"), profiled = Core:Text("CORE.WITH_PROFILES"), missing = Core:Text("CORE.WITHOUT_PROFILES") } end)
local function CreateSettings(parent)
    parent.heading = AddText(parent, "GameFontNormalLarge", nil, COLORS.text); parent.heading:SetPoint("TOPLEFT", 20, -18)
    parent.hint = AddText(parent, "GameFontNormalSmall", nil, COLORS.muted); parent.hint:SetPoint("TOPLEFT", 20, -47)
    parent.resetLayout = CreateChromeButton(parent, 116, 22, Core:Text("CORE.RESET_LAYOUT"))
    parent.resetLayout:SetPoint("TOPRIGHT", -20, -18)
    parent.resetLayout:SetScript("OnClick", function() AccountView:ResetWindowLayout() end)
    parent.scroll = Theme:CreateScrollFrame(parent)
    parent.scroll:SetPoint("TOPLEFT", 20, -76); parent.scroll:SetPoint("BOTTOMRIGHT", -Theme.Space.xs, 14)
    parent.content = CreateFrame("Frame", nil, parent.scroll); parent.content:SetWidth(620); parent.scroll:SetScrollChild(parent.content)
    parent.rows = {}
    parent.rowPools = {}
    parent.displayTabs = {}

end

local function SettingsRow(parent, index, kind)
    -- A slot can alternate between several control kinds as pages change.
    -- Keep each kind reachable for reuse instead of abandoning hidden frames.
    local pool = parent.rowPools[index] or {}
    parent.rowPools[index] = pool
    local previous = parent.rows[index]
    if previous and previous.controlType ~= kind then previous:Hide() end
    local row = pool[kind]
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
            row.up = CreateChromeButton(row, 44, 22, Core:Text("CORE.UP"))
            row.up:SetPoint("RIGHT", -206, 0)
            row.down = CreateChromeButton(row, 44, 22, Core:Text("CORE.DOWN"))
            row.down:SetPoint("RIGHT", -158, 0)
            row.hidden = CreateChromeButton(row, 58, 22, Core:Text("CORE.HIDE"), false)
            row.hidden:SetPoint("RIGHT", -96, 0)
            row.delete = CreateChromeButton(row, 88, 22, Core:Text("CORE.DELETE_CACHE"), true)
            row.delete:SetPoint("RIGHT", -2, 0)
            row.delete:SetWidth(math.max(row.delete:GetWidth(), Theme:MeasureText(Theme.Font.body, Core:Text("CORE.CURRENT_CHARACTER")) + 18))
            row.hidden:SetWidth(math.max(row.hidden:GetWidth(), Theme:MeasureText(Theme.Font.body, Core:Text("CORE.VISIBLE")) + 18))
            local offset = 2
            for _, button in ipairs({ row.delete, row.hidden, row.down, row.up }) do
                button:ClearAllPoints(); button:SetPoint("RIGHT", -offset, 0)
                offset = offset + button:GetWidth() + 4
            end
            row.label:ClearAllPoints(); row.label:SetPoint("LEFT", 2, 0); row.label:SetPoint("RIGHT", -offset, 0)
        elseif kind == "addon-panel" then
            row = CreateFrame("Frame", nil, parent.content)
            row:SetWidth(600)
        elseif kind == "input" then
            row = CreateFrame("Frame", nil, parent.content)
            row:SetHeight(Theme.Size.standard)
            row.label = AddText(row, "GameFontNormalSmall", nil, COLORS.muted)
            row.label:SetPoint("LEFT", 0, 0)
            row.input = Theme:CreateInput(row,{width=120,maxLetters=64})
            row.input:SetHeight(Theme.Size.standard)
            row.input:SetTextInsets(7, 7, 0, 0)
        elseif kind == "dropdown" then
            row = CreateFrame("Frame", nil, parent.content)
            row:SetHeight(Theme.Size.standard)
            row.label = AddText(row, "GameFontNormalSmall", nil, COLORS.muted)
            row.label:SetPoint("LEFT", 0, 0); row.label:SetWidth(104)
            row.dropdown = Theme:CreateDropdown(row, 180, {})
            row.dropdown:SetPoint("LEFT", row.label, "RIGHT", 8, 0)
        elseif kind == "order-actions" then
            row=CreateFrame("Frame",nil,parent.content);row:SetHeight(Theme.Size.standard)
        elseif kind == "business-entry" then
            -- All page, entry, and column decisions stay adjacent to their
            -- plugin instead of sending users to a separate field section.
            row = CreateFrame("Frame", nil, parent.content)
            row:SetHeight(Theme.Size.standard)
            row.title = AddText(row, "GameFontNormalSmall", nil, COLORS.text)
            row.visible = Theme:CreateCheckbox(row, Core:Text("CORE.SHOW_PAGE"))
            row.entryLabel = AddText(row, "GameFontNormalSmall", nil, COLORS.muted)
            row.entryLabel:SetText(Core:Text("CORE.SEPARATE_ENTRY"))
            row.dropdown = Theme:CreateDropdown(row, 126, {})
            row.mainFields = Theme:CreateMultiSelectDropdown(row, 118, {})
            row.previewFields = Theme:CreateMultiSelectDropdown(row, 118, {})
            row.viewMode = Theme:CreateDropdown(row, 90, {})
        elseif kind == "core-entry" then
            row = CreateFrame("Frame", nil, parent.content)
            row:SetHeight(Theme.Size.standard)
            row.title = AddText(row, "GameFontNormalSmall", nil, COLORS.text)
            row.visible = Theme:CreateCheckbox(row, Core:Text("CORE.WINDOW_HOVER"))
            row.entryLabel = AddText(row, "GameFontNormalSmall", nil, COLORS.muted)
            row.entryLabel:SetText(Core:Text("CORE.CORE_ENTRY"))
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
        elseif kind == "short-name" then
            row = CreateFrame("Frame", nil, parent.content)
            row:SetHeight(28)
            row.label = AddText(row, "GameFontNormalSmall", nil, COLORS.text)
            row.label:SetPoint("LEFT", 2, 0); row.label:SetPoint("RIGHT", -198, 0)
            row.input = Theme:CreateInput(row,{width=112,height=26,maxLetters=32})
            row.input:SetSize(112, 26); row.input:SetPoint("RIGHT", -80, 0); row.input:SetAutoFocus(false); row.input:SetMaxLetters(32); row.input:SetTextInsets(6, 6, 0, 0)
            row.clear = CreateChromeButton(row, 70, 20, Core:Text("CORE.CLEAR"), false); row.clear:SetPoint("RIGHT", -2, 0)
        else
            row = CreateChromeButton(parent.content, 250, 22, "")
        end
        pool[kind] = row
    end
    parent.rows[index] = row
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
    parent.content:SetWidth(math.max(300, settingsViewportWidth - 18))
    local targetID = AccountView.settingsTargetPageID or "display"
    local settingsOnlyID = type(targetID) == "string" and targetID:match("^addon%-settings:(.+)$")
    local selected = AccountView._pages[targetID]
    local settingsOnly = settingsOnlyID and Core.SettingsRegistry and Core.SettingsRegistry._panels[settingsOnlyID]
    local displayMode, sortingMode, coreMode = targetID == "display", targetID == "sorting", targetID == "core"
    local generalMode, barMode = targetID == "general", targetID == "bar"
    if not (displayMode or generalMode or barMode or sortingMode or coreMode or settingsOnly or (selected and not selected.internal)) then
        targetID, displayMode = "display", true
        AccountView.settingsTargetPageID = targetID
    end
    local titles = { bar = Core:Text("ENTRY.TAB_BAR"), general = Core:Text("CORE.CORE_SETTINGS"), display = Core:Text("CORE.DISPLAY_ENTRIES_385"), sorting = Core:Text("CORE.CHARACTERS_SORTING_386"), core = Core:Text("CORE.WINDOW_387") }
    parent.heading:SetText(titles[targetID] or ((selected and selected.title) or (settingsOnly and settingsOnly.title) or Core:Text("CORE.ADDON_388")) .. Core:Text("CORE.SETTINGS_389"))
    parent.hint:SetText(barMode and Core:Text("ENTRY.BAR_PAGE_HINT") or generalMode and Core:Text("ENTRY.GENERAL_HINT") or displayMode and Core:Text("CORE.MANAGE_CORE_AND_ADDON_PAGES_SEPARATE_ENTRIES") or (sortingMode and Core:Text("CORE.MANAGE_CHARACTERS_SORTING_CACHES_AND_BUSINESS_PAGE") or (coreMode and Core:Text("CORE.MANAGE_WINDOW_LAYOUT_TARGET_ADD_GESTURES_AND") or Core:Text("CORE.ONLY_THIS_ADDON_S_BUSINESS_RULES_AND"))))
    parent.resetLayout:SetShown(coreMode)
    local showHint=not (generalMode or coreMode or sortingMode or displayMode or barMode)
    parent.hint:SetShown(showHint)
    parent.hint:SetPoint("TOPRIGHT", -20, -47);parent.hint:SetWordWrap(true)
    parent.scroll:SetPoint("TOPLEFT",20,showHint and -math.max(76,57+parent.hint:GetStringHeight()) or -56)

    local index, y, gridColumn = 0, 0, 0
    local function RefreshVisibleSettings()
        -- Losing focus while a page is being hidden must still commit an edit,
        -- but must not rebuild the page the user is in the middle of leaving.
        if parent:IsShown() and AccountView.activePageID == "settings"
            and (AccountView.settingsTargetPageID or "display") == targetID then AccountView:RefreshPage() end
    end
    local gridGap, gridMinimum = 16, 230
    local gridColumns = math.max(1, math.floor((parent.content:GetWidth() + gridGap) / (gridMinimum + gridGap)))
    local compactForm = displayMode or generalMode or barMode or sortingMode
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
        if compactForm then gridWidth=math.min(gridWidth,380) end
    end
    local function PlaceFormControl(row, minimumWidth)
        if minimumWidth > gridWidth and gridColumns > 1 then
            FinishGridRow()
            local width = parent.content:GetWidth() - 4
            row:ClearAllPoints(); row:SetPoint("TOPLEFT", 2, -y); row:SetWidth(width)
            y = y + Theme.Size.standard + 4
            return width
        end
        PlaceGridControl(row)
        return gridWidth
    end
    local function Heading(text)
        FinishGridRow()
        index = index + 1; local row = SettingsRow(parent, index, "heading"); PlaceSettingsRow(row, y)
        row:SetWidth(math.max(1, parent.content:GetWidth() - 4)); row:SetWordWrap(true)
        row:SetText(text); row:SetTextColor(COLORS.accent[1], COLORS.accent[2], COLORS.accent[3]); row:Show()
        y = y + math.max(28, row:GetStringHeight() + 10)
    end
    local function Note(text)
        FinishGridRow()
        index=index+1
        local row=SettingsRow(parent,index,"heading");PlaceSettingsRow(row,y)
        row:SetWidth(parent.content:GetWidth()-4);row:SetWordWrap(true)
        row:SetText(text);row:SetTextColor(COLORS.muted[1],COLORS.muted[2],COLORS.muted[3]);row:Show()
        y=y+math.max(24,row:GetStringHeight()+8)
    end
    local function Check(label, checked, callback)
        index = index + 1; local row = SettingsRow(parent, index, "check")
        row:SetEnabled(true);row:SetAlpha(1)
        local width = PlaceFormControl(row, sortingMode and 260 or Theme:MeasureText(Theme.Font.body,label)+28)
        row.label:SetWidth(math.max(40, width - 24)); row.label:SetWordWrap(true)
        row.label:SetText(label); row:SetChecked(checked); row:SetScript("OnClick", function(self) self:SetChecked(not self:GetChecked()); callback(self:GetChecked()); AccountView:RefreshPage() end); row:Show()
        local height = math.max(Theme.Size.standard, row.label:GetStringHeight() + 8)
        row:SetHeight(height); y = y + height - Theme.Size.standard
        return row
    end
    local function Button(label, callback, width, kind, selected)
        index = index + 1; local row = SettingsRow(parent, index, "button")
        row:SetEnabled(true);row:SetAlpha(1)
        local available=PlaceFormControl(row, Theme:MeasureText(Theme.Font.body, label) + 24)
        if compactForm then row:SetWidth(math.min(available,math.max(100,Theme:MeasureText(Theme.Font.body,label)+24)));row:SetHeight(Theme.Size.standard) end
        row.kind = kind or "default"; row:SetText(label); row:SetState(selected and "selected" or "default"); row:SetScript("OnClick", callback); row:Show()
        return row
    end
    local function Input(label, value, callback, inputWidth)
        index = index + 1; local row = SettingsRow(parent, index, "input")
        local labelWidth = Theme:MeasureText(Theme.Font.assist, label)
        local width = PlaceFormControl(row, labelWidth + (inputWidth or 120) + 8)
        row.label:SetText(label); row.label:SetWidth(math.min(labelWidth, math.floor(width * 0.5)))
        row.input:ClearAllPoints(); row.input:SetPoint("LEFT", row.label, "RIGHT", 6, 0)
        if inputWidth or compactForm then row.input:SetWidth(inputWidth or 120) else row.input:SetPoint("RIGHT", 0, 0) end
        row.input:SetText(value or "")
        local function Save(control)
            local valid, normalized, badToken = Core.LevelFilter:Validate(control:GetText())
            if not valid then
                control:SetText(value or "")
                Core:Print(Core:Text("CORE.INVALID_LEVEL_FILTER") .. tostring(badToken))
                return
            end
            if normalized == (value or "") then
                if control:GetText() ~= normalized then control:SetText(normalized) end
                return
            end
            value = normalized
            callback(normalized)
            control:SetText(normalized)
            RefreshVisibleSettings()
        end
        row.input:SetScript("OnEnterPressed", function(control) Save(control); control:ClearFocus() end)
        row.input:SetScript("OnEditFocusLost",function(control) control:SetBackdropBorderColor(unpack(COLORS.lineSoft));Save(control) end)
        row.input:SetScript("OnEscapePressed", function(control) control:SetText(value or ""); control:ClearFocus() end)
        row:Show()
        return row
    end
    local function CharacterFilterInput(page, filter)
        index=index+1
        local row=SettingsRow(parent,index,"input")
        local available=PlaceFormControl(row,260)
        row.label:ClearAllPoints();row.label:SetPoint("LEFT",0,0);row.label:SetWidth(math.max(100,available-138));row.label:SetWordWrap(false)
        row.label:SetText(page.title)
        row.input:ClearAllPoints();row.input:SetPoint("RIGHT",0,0);row.input:SetWidth(120)
        row.input:SetText(filter.GetExpression() or "")
        local function Save(control)
            local valid, normalized, badToken = Core.LevelFilter:Validate(control:GetText())
            if not valid then
                control:SetText(filter.GetExpression() or "")
                Core:Print(page.title .. Core:Text("CORE.INVALID_LEVEL_FILTER") .. tostring(badToken))
                return
            end
            if normalized == (filter.GetExpression() or "") then
                if control:GetText() ~= normalized then control:SetText(normalized) end
                return
            end
            local ok, errorMessage = filter.SetExpression(normalized)
            if ok == false then
                control:SetText(filter.GetExpression() or "")
                Core:Print(page.title .. Core:Text("CORE.COULD_NOT_SAVE_LEVEL_FILTER") .. tostring(errorMessage))
                return
            end
            control:SetText(normalized)
            RefreshVisibleSettings()
        end
        row.input:SetScript("OnEnterPressed", function(control) Save(control); control:ClearFocus() end)
        row.input:SetScript("OnEditFocusLost",function(control) control:SetBackdropBorderColor(unpack(COLORS.lineSoft));Save(control) end)
        row.input:SetScript("OnEscapePressed", function(control) control:SetText(filter.GetExpression() or ""); control:ClearFocus() end)
        row:Show()
    end
    local function Dropdown(label, value, options, callback)
        index = index + 1; local row = SettingsRow(parent, index, "dropdown")
        row:SetAlpha(1);row.dropdown:SetEnabled(true)
        local labelWidth, optionWidth = Theme:MeasureText(Theme.Font.assist, label), 0
        for _, option in ipairs(options) do optionWidth = math.max(optionWidth, Theme:MeasureText(Theme.Font.body, option.label or "")) end
        local width = PlaceFormControl(row, compactForm and label~=Core:Text("ENTRY.ORDER_BUTTON") and 260 or labelWidth + optionWidth + 40)
        row.label:SetText(label)
        row.label:SetWidth(compactForm and math.max(104,math.min(140,width-160)) or math.min(labelWidth,math.floor(width*0.5)))
        row.dropdown:ClearAllPoints();row.dropdown:SetPoint("LEFT",row.label,"RIGHT",8,0)
        if compactForm then
            row.dropdown:SetWidth(math.min(width-row.label:GetWidth()-8,math.max(140,optionWidth+32)));row.dropdown:SetHeight(Theme.Size.standard)
        else row.dropdown:SetPoint("RIGHT",0,0) end
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
    local width = parent.content:GetWidth() or 600
    local available=width-48
    local widths={math.floor(available*0.16),math.floor(available*0.06),math.floor(available*0.08),math.floor(available*0.10),math.floor(available*0.08),math.floor(available*0.17),math.floor(available*0.17)}
    local x=2
    local columns={}
    for i,w in ipairs(widths) do columns[i]={x=x,width=w,y=0};x=x+w+6 end
    columns[8]={x=x,width=math.max(60,width-x-4),y=0}
    local DISPLAY_COLUMNS={page=columns[1],visible=columns[2],entryLabel=columns[3],entryMode=columns[4],mainFields=columns[6],previewFields=columns[7],option=columns[8]}
    local channelStart=columns[3].x
    local displayRowHeight=30
    local function EntryChannels(row, id)
        if row.entryLabel then row.entryLabel:Hide() end
        if row.dropdown then row.dropdown:Hide() end
        row.channels = row.channels or {}
        local saved = Core.Entry:GetEntryChannels(id)
        local enabled = Core.Entry:GetBuiltinBarSettings().enabled
        local keys = {"minimap","broker","builtinBar"}
        local labels = {minimap="ENTRY.CHANNEL_MINIMAP",broker="ENTRY.CHANNEL_BROKER",builtinBar="ENTRY.CHANNEL_BUILTINBAR"}
        for i,key in ipairs(keys) do
            local control = row.channels[i]
            if not control then control = Theme:CreateCheckbox(row,""); row.channels[i]=control end
            local column=columns[i+2]
            control:ClearAllPoints();control:SetPoint("TOPLEFT",column.x,0);control:SetWidth(column.width)
            control.label:SetText("");control.label:Hide()
            control:SetHeight(Theme.Size.standard)
            control:SetChecked(saved[key]);control:SetEnabled(key ~= "builtinBar" or enabled)
            control:SetAlpha((key ~= "builtinBar" or enabled) and 1 or 0.65)
            control:SetScript("OnClick",function()
                if key == "builtinBar" and not Core.Entry:GetBuiltinBarSettings().enabled then return end
                Core.Entry:SetEntryChannel(id,key,not Core.Entry:GetEntryChannels(id)[key])
                AccountView:RefreshPage()
            end)
            control:Show()
        end
    end
    local function PlaceDisplayColumn(control, columnID)
        local column = DISPLAY_COLUMNS[columnID]
        control:ClearAllPoints(); control:SetPoint("TOPLEFT", column.x, -(column.y or 0)); control:SetWidth(column.width)
    end
    local function BusinessEntryRow(page, entry, options)
        -- This is a form row, not a grid item.  Keeping its anchors local to
        -- the row guarantees that every plugin retains one readable scan line
        -- at any supported settings-window width.
        FinishGridRow()
        index = index + 1
        local row = SettingsRow(parent, index, "business-entry")
        row:ClearAllPoints(); row:SetPoint("TOPLEFT", 2, -y); row:SetWidth(parent.content:GetWidth() or 600); row:SetHeight(Theme.Size.standard)
        PlaceDisplayColumn(row.title, "page"); row.title:SetText(page.title);row.title:SetHeight(Theme.Size.standard)
        PlaceDisplayColumn(row.visible, "visible")
        row.visible.label:SetText("");row.visible.label:Hide()
        row.visible:Show();row.visible:SetHeight(Theme.Size.standard)
        row.visible:SetChecked(not page.settingsOnly and PageEnabled(page))
        row.visible:SetScript("OnClick", function(control)
            control:SetChecked(not control:GetChecked())
            settings.pages[page.id] = control:GetChecked()
            Core.Entry:Refresh()
            AccountView:RefreshPage()
        end)
        if page.settingsOnly then row.visible:Hide() end
        if entry then EntryChannels(row, entry.id)
        else
            row.dropdown:Hide();row.entryLabel:ClearAllPoints();row.entryLabel:SetPoint("TOPLEFT",page.settingsOnly and DISPLAY_COLUMNS.visible.x or channelStart,0);row.entryLabel:SetWidth(page.settingsOnly and width-DISPLAY_COLUMNS.visible.x-4 or columns[6].x-channelStart-6);row.entryLabel:SetHeight(30);row.entryLabel:SetText(Core:Text(page.settingsOnly and "ENTRY.SETTINGS_ONLY" or "ENTRY.NO_SEPARATE_ENTRY"));row.entryLabel:Show()
            for _,control in ipairs(row.channels or {}) do control:Hide() end
        end
        local pageFields = AccountView:GetFieldDefinitions(page.id)
        local hasMainFields = #pageFields > 0
        PlaceDisplayColumn(row.viewMode, "option")
        PlaceDisplayColumn(row.mainFields, "mainFields")
        PlaceDisplayColumn(row.previewFields, "previewFields")
        if hasMainFields then
            local mainOptions, previewOptions = {}, {}
            for _, field in ipairs(pageFields) do
                local currentField = field
                mainOptions[#mainOptions + 1] = {
                    title = currentField.title,
                    group = currentField.group,
                    isSelected = function() return AccountView:GetFieldVisible(page.id, currentField) end,
                    setSelected = function(visible) AccountView:SetFieldVisible(page.id, currentField.id, visible) end,
                }
                if currentField.preview ~= false and page.previewEnabled and type(page.SetPreviewFieldVisible) == "function" then
                    previewOptions[#previewOptions + 1] = {
                        title = currentField.title,
                        group = currentField.group,
                        isSelected = function() return GetPreviewFieldVisible(page, currentField) end,
                        setSelected = function(visible) page.SetPreviewFieldVisible(currentField.id, visible) end,
                    }
                end
            end
            if page.previewEnabled and type(page.GetPreviewFieldDefinitions) == "function" and type(page.SetPreviewFieldVisible) == "function" then
                for _, field in ipairs(page.GetPreviewFieldDefinitions() or {}) do
                    local currentField = field
                    previewOptions[#previewOptions + 1] = {
                        title = currentField.title,
                        group = currentField.group,
                        isSelected = function() return GetPreviewFieldVisible(page, currentField) end,
                        setSelected = function(visible) page.SetPreviewFieldVisible(currentField.id, visible) end,
                    }
                end
            end
            row.mainFields:SetSummary("")
            row.mainFields:SetOptions(mainOptions); row.mainFields:Show()
            if #previewOptions > 0 then
                row.previewFields:SetSummary("")
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
        local rowHeight=displayRowHeight

        row:SetHeight(rowHeight)
        y = y + rowHeight + 8
    end
    local function ArchiveEntryRow()
        FinishGridRow()
        index = index + 1
        local row = SettingsRow(parent, index, "archive-entry")
        local archiveSettings = ArchiveSettings()
        row:ClearAllPoints(); row:SetPoint("TOPLEFT", 2, -y); row:SetWidth(parent.content:GetWidth() or 600)
        PlaceDisplayColumn(row.title, "page"); row.title:SetText(Core:Text("CORE.CHARACTER_ARCHIVE"));row.title:SetHeight(Theme.Size.standard)
        row.entryLabel = row.entryLabel or AddText(row,"GameFontNormalSmall",nil,COLORS.muted)
        row.entryLabel:SetText("—");PlaceDisplayColumn(row.entryLabel,"entryLabel")
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
        row.mainFields:SetSummary(""); row.mainFields:SetOptions(mainOptions); row.mainFields:Show()
        row.previewFields:SetSummary(""); row.previewFields:SetOptions(previewOptions); row.previewFields:Show()
        row:Show()
        row:SetHeight(30)
        y = y + 38
    end
    local function CoreEntryRow(options)
        FinishGridRow()
        index = index + 1
        local row = SettingsRow(parent, index, "core-entry")
        row:ClearAllPoints(); row:SetPoint("TOPLEFT", 2, -y); row:SetWidth(parent.content:GetWidth() or 600)
        PlaceDisplayColumn(row.title, "page"); row.title:SetText("Core");row.title:SetHeight(Theme.Size.standard)
        row.visible:Hide()
        EntryChannels(row, "YiboCore")
        local previewOptions = {}
        for _, page in ipairs(AccountView:GetPreviewPageOptions()) do previewOptions[#previewOptions + 1] = { value = page.id, label = Core:Text("CORE.HOVER_407") .. page.title } end
        -- Core uses the same contextual-options column as page layout modes;
        -- unlike business pages its option is the page used for the preview.
        row.previewLabel:Hide()
        PlaceDisplayColumn(row.preview, "option")
        row.preview:SetOptions(previewOptions); row.preview:SetValue(AccountView:GetPreviewPage().id)
        row.preview:SetOnValueChanged(function(pageID)
            settings.entry.previewPageID = pageID
            AccountView:RefreshPage()
        end)
        row:SetHeight(30)
        row:Show(); y = y + 38
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
        local function IsCurrentPanel()
            if not (parent:IsShown() and row:IsShown() and AccountView.activePageID == "settings"
                and AccountView.settingsTargetPageID == targetID and row.yiboHostedOwner == hostedOwner) then return false end
            if selected then return AccountView._pages[selected.id] == selected end
            return settingsOnly and Core.SettingsRegistry and Core.SettingsRegistry._panels[settingsOnly.id] == settingsOnly
        end
        local hostedContext
        hostedContext = {
            availableHeight = math.max(1, (parent.scroll:GetHeight() or 1) - y - 8),
            refreshPage = function() if IsCurrentPanel() then AccountView:RefreshPage() end end,
            notifyPageChanged = function() if selected then AccountView:NotifyPageChanged(selected.id) end end,
            -- Allow a business panel to repaint its own controls without
            -- rebuilding the whole settings workbench.
            refreshPanel = function()
                if not IsCurrentPanel() then return end
                local ok, heightOrError = xpcall(function()
                    return details.CreateSettingsPanel(row, hostedContext)
                end, function(message) return tostring(message) end)
                if ok then
                    if not IsCurrentPanel() then return end
                    local previousHeight = row:GetHeight() or 1
                    row:SetHeight(math.max(1, tonumber(heightOrError) or previousHeight))
                    parent.settingsContentHeight = math.max(0, (parent.settingsContentHeight or 0) + row:GetHeight() - previousHeight)
                    parent.content:SetHeight(math.max(parent.settingsContentHeight, parent.scroll:GetHeight() or 1))
                    parent.scroll:SetContentHeight(parent.settingsContentHeight)
                else
                    Core:Print(Core:Text("CORE.ADDON_408") .. tostring((selected and selected.title) or (settingsOnly and settingsOnly.title) or Core:Text("CORE.UNKNOWN")) .. Core:Text("CORE.BUSINESS_SETTINGS_REFRESH_FAILED") .. tostring(heightOrError))
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
            Core:Print(Core:Text("CORE.ADDON_408") .. tostring((selected and selected.title) or (settingsOnly and settingsOnly.title) or Core:Text("CORE.UNKNOWN")) .. Core:Text("CORE.EMBEDDED_SETTINGS_CREATION_FAILED") .. tostring(heightOrError))
            if not row.errorLabel then
                row.errorLabel = AddText(row, "GameFontNormalSmall", nil, COLORS.danger)
                row.errorLabel:SetPoint("TOPLEFT", 2, 0); row.errorLabel:SetPoint("RIGHT", -2, 0)
                row.errorLabel:SetWordWrap(true)
            end
            row.errorLabel:SetText(Core:Text("CORE.BUSINESS_SETTINGS_COULD_NOT_LOAD") .. tostring(heightOrError))
            row.errorLabel:Show()
            row:SetHeight(40)
            y = y + 50
            return
        end
        if row.errorLabel then row.errorLabel:Hide() end
        row:SetHeight(math.max(1, tonumber(heightOrError) or row:GetHeight() or 1))
        y = y + row:GetHeight()
    end
    local function SortControls(pageID)
        local page = pageID and AccountView._pages[pageID]
        local saved = page and AccountView:GetPageCharacterSort(pageID) or AccountView:GetDefaultCharacterSort()
        local effective = page and AccountView:GetEffectiveCharacterSort(pageID) or saved
        if sortingMode and not page then
            local options={}
            for _,mode in ipairs(SORT_MODES) do options[#options+1]={value=mode,label=SORT_LABELS[mode]} end
            Dropdown(Core:Text("CORE.DEFAULT_CHARACTER_SORTING"),effective.mode,options,function(mode)
                local nextSettings=Copy(effective);nextSettings.mode=mode;nextSettings.direction=DefaultDirection(mode)
                AccountView:SetDefaultCharacterSort(nextSettings)
            end)
            if effective.mode~="custom" then
                Button(Core:Text("CORE.SORT_DIRECTION")..(effective.direction=="asc" and Core:Text("CORE.ASCENDING") or Core:Text("CORE.DESCENDING")),function()
                    local nextSettings=Copy(effective);nextSettings.direction=effective.direction=="asc" and "desc" or "asc";AccountView:SetDefaultCharacterSort(nextSettings)
                end)
            end
            Check(Core:Text("CORE.PIN_CURRENT_CHARACTER"),effective.pinCurrent==true,function(value)
                local nextSettings=Copy(effective);nextSettings.pinCurrent=value;AccountView:SetDefaultCharacterSort(nextSettings)
            end)
            return
        end
        if page then
            Button(Core:Text("CORE.USE_SHARED_SETTINGS"), function()
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
            Button(Core:Text("CORE.SORT_DIRECTION") .. (effective.direction == "asc" and Core:Text("CORE.ASCENDING") or Core:Text("CORE.DESCENDING")), function()
                local nextSettings = Copy(effective)
                nextSettings.inherited = nil
                nextSettings.direction = nextSettings.direction == "asc" and "desc" or "asc"
                if page then AccountView:SetPageCharacterSort(pageID, nextSettings) else AccountView:SetDefaultCharacterSort(nextSettings) end
            end, 300, "secondary")
        end
        Check(Core:Text("CORE.PIN_CURRENT_CHARACTER"), effective.pinCurrent == true, function(checked)
            local nextSettings = Copy(effective)
            nextSettings.inherited = nil
            nextSettings.pinCurrent = checked
            if page then AccountView:SetPageCharacterSort(pageID, nextSettings) else AccountView:SetDefaultCharacterSort(nextSettings) end
        end)
    end
    local function CharacterOrderRows()
        Button(Core:Text("CORE.REBUILD_BY_RECENT_LOGIN"), function() AccountView:RebuildCustomCharacterOrder("recent") end, 300, "secondary")
        Button(Core:Text("CORE.RESTORE_REGISTRATION_ORDER"), function() AccountView:RebuildCustomCharacterOrder("seen") end, 300, "secondary")
        local byID = {}
        for _, character in ipairs(Core.Characters:GetAllCached({ identityOnly = true })) do byID[character.id] = character end
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
        Button(Core:Text("CORE.PREVIOUS_419") .. parent.characterOrderPage .. " / " .. totalPages .. Core:Text("FORMAT.CLOSE_PAREN"), function()
            parent.characterOrderPage = math.max(1, parent.characterOrderPage - 1); AccountView:RefreshPage()
        end, 300, "secondary")
        Button(Core:Text("CORE.NEXT_420") .. parent.characterOrderPage .. " / " .. totalPages .. Core:Text("FORMAT.CLOSE_PAREN"), function()
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
                row.label:SetText(tostring(orderIndex) .. ". " .. Core.Characters:FormatName({ name = character.name or Core:Text("CORE.UNKNOWN_CHARACTER"), realm = character.realm or Core:Text("CORE.UNKNOWN_REALM") }, { realmMode = "full" }) .. " · " .. tostring(character.level or "?") .. Core:Text("CORE.LEVELS"))
                local classColor = RAID_CLASS_COLORS and RAID_CLASS_COLORS[character.class or ""]
                row.label:SetTextColor(classColor and classColor.r or COLORS.text[1], classColor and classColor.g or COLORS.text[2], classColor and classColor.b or COLORS.text[3])
                row.up:SetState(orderIndex == 1 and "disabled" or "default")
                row.down:SetState(orderIndex == #order and "disabled" or "default")
                row.up:EnableMouse(orderIndex > 1); row.down:EnableMouse(orderIndex < #order)
                local rowCharacterID = characterID
                row.up:SetScript("OnClick", function() AccountView:MoveCustomCharacter(rowCharacterID, -1) end)
                row.down:SetScript("OnClick", function() AccountView:MoveCustomCharacter(rowCharacterID, 1) end)
                local hidden = Settings().hiddenCharacters[rowCharacterID] == true
                row.hidden:SetText(hidden and Core:Text("CORE.VISIBLE") or Core:Text("CORE.HIDE"))
                row.hidden.kind = "secondary"; row.hidden:SetState(hidden and "selected" or "default")
                row.hidden:SetScript("OnClick", function()
                    AccountView:SetCharacterHidden(rowCharacterID, not hidden)
                end)
                local current = Core.Characters:GetCurrentID() == characterID
                row.delete:SetText(current and Core:Text("CORE.CURRENT_CHARACTER") or Core:Text("CORE.DELETE_CACHE"))
                row.delete:SetState(current and "disabled" or "default")
                row.delete:EnableMouse(not current)
                row.delete:SetScript("OnClick", function() ShowCharacterDeleteConfirmation(rowCharacterID) end)
                row:Show()
            end
        end
        y = y + math.min(rowsPerColumn, visibleCount) * 28
    end

    local function ShortNameRows()
        local characters = Core.Characters:GetAllCached({ identityOnly = true })
        local pageSize = 20
        local totalPages = math.max(1, math.ceil(#characters / pageSize))
        parent.shortNamePage = math.max(1, math.min(tonumber(parent.shortNamePage) or 1, totalPages))
        Button(Core:Text("CORE.PREVIOUS_419") .. parent.shortNamePage .. " / " .. totalPages .. Core:Text("FORMAT.CLOSE_PAREN"), function() parent.shortNamePage = math.max(1, parent.shortNamePage - 1); AccountView:RefreshPage() end, 300, "secondary")
        Button(Core:Text("CORE.NEXT_420") .. parent.shortNamePage .. " / " .. totalPages .. Core:Text("FORMAT.CLOSE_PAREN"), function() parent.shortNamePage = math.min(totalPages, parent.shortNamePage + 1); AccountView:RefreshPage() end, 300, "secondary")
        FinishGridRow()
        local duplicates = Core.Characters:GetShortNameDuplicates()
        local first, last = (parent.shortNamePage - 1) * pageSize + 1, math.min(#characters, parent.shortNamePage * pageSize)
        for characterIndex = first, last do
            local character = characters[characterIndex]
            index = index + 1
            local row = SettingsRow(parent, index, "short-name")
            PlaceSettingsRow(row, y); row:SetWidth(parent.content:GetWidth() or 600)
            local displayName = Core.Characters:FormatName(character, { nameMode = "short" })
            local warning = duplicates[displayName] and Core:Text("CORE.DUPLICATE_SHORT_NAME") or ""
            row.label:SetText(Core.Characters:FormatName({ name = character.name or Core:Text("CORE.UNKNOWN_CHARACTER"), realm = character.realm or Core:Text("CORE.UNKNOWN_REALM") }, { realmMode = "full" }) .. warning)
            local savedValue = displayName == character.name and "" or displayName
            row.input:SetText(savedValue)
            local characterID = character.id
            local function Save(control)
                if control:GetText() == savedValue then return end
                local result, errorMessage = Core.Characters:SetShortName(characterID, control:GetText())
                if result == nil then Core:Print(Core:Text("CORE.COULD_NOT_SAVE_SHORT_NAME") .. tostring(errorMessage)); return end
                savedValue = result
                control:SetText(result)
                RefreshVisibleSettings()
            end
            row.input:SetScript("OnEnterPressed", function(control) Save(control); control:ClearFocus() end)
            row.input:SetScript("OnEditFocusLost",function(control) control:SetBackdropBorderColor(unpack(COLORS.lineSoft));Save(control) end)
            row.input:SetScript("OnEscapePressed", function(control)
                local currentName = Core.Characters:FormatName(character, { nameMode = "short" })
                control:SetText(currentName == character.name and "" or currentName)
                control:ClearFocus()
            end)
            row.clear:SetScript("OnClick", function() Core.Characters:SetShortName(characterID, ""); AccountView:RefreshPage() end)
            row:Show(); y = y + 30
        end
    end

    if sortingMode then
        SetGridMinimum(260,3)
        SortControls(nil)
        Heading(Core:Text("CORE.CHARACTER_ORDER_CACHE"))
        local shortNameToggle = Button(parent.showShortNames and Core:Text("CORE.COLLAPSE_SHORT_NAMES") or Core:Text("CORE.MANAGE_SHORT_NAMES"), function() parent.showShortNames = not parent.showShortNames; AccountView:RefreshPage() end, 300, "disclosure")
        if parent.showShortNames then
            FinishGridRow()
            ShortNameRows()
        end
        Button(parent.showCharacterOrder and Core:Text("CORE.COLLAPSE_ORDER_AND_CACHE") or Core:Text("CORE.OPEN_ORDER_AND_CACHE"), function()
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
        SetGridMinimum(260,3)
        Heading(Core:Text("CORE.BUSINESS_PAGE_CHARACTER_FILTERS"))
        FinishGridRow()
        index = index + 1
        local ruleHint = SettingsRow(parent, index, "heading")
        PlaceSettingsRow(ruleHint, y)
        ruleHint:SetText(Core:Text("CORE.RULES_90_LEVEL_90_ONLY_1_20"))
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
        if count == 0 then Heading(Core:Text("CORE.NO_BUSINESS_PAGES_SUPPORT_CHARACTER_FILTERS")) end
        local archive = ArchiveSettings()
        local function CycleArchiveProfile(mode)
            local values = { "all", "profiled", "missing" }
            local current = archive.filters[mode].profile
            for position, value in ipairs(values) do
                if value == current then archive.filters[mode].profile = values[(position % #values) + 1]; break end
            end
            AccountView:RefreshPage()
        end
        SetGridMinimum(260,3)
        Heading(Core:Text("CORE.CHARACTER_ARCHIVE_FILTERS"))
        Button(Core:Text("CORE.TABLE_FILTER") .. (PROFILE_FILTER_LABELS[archive.filters.page.profile] or PROFILE_FILTER_LABELS.all), function() CycleArchiveProfile("page") end, 300)
        Check(Core:Text("CORE.INCLUDE_HIDDEN_CHARACTERS_IN_TABLE_FILTER"), archive.filters.page.includeHidden == true, function(checked) archive.filters.page.includeHidden = checked end)
        Input(Core:Text("CORE.TABLE_LEVEL_FILTER"), archive.filters.page.levelExpr, function(value) archive.filters.page.levelExpr = value end)
        Heading(Core:Text("CORE.CHARACTER_ARCHIVE_HOVER_FILTERS"))
        Button(Core:Text("CORE.HOVER_FILTER") .. (PROFILE_FILTER_LABELS[archive.filters.preview.profile] or PROFILE_FILTER_LABELS.all), function() CycleArchiveProfile("preview") end, 300)
        Check(Core:Text("CORE.INCLUDE_HIDDEN_CHARACTERS_IN_HOVER_FILTER"), archive.filters.preview.includeHidden == true, function(checked) archive.filters.preview.includeHidden = checked end)
        Input(Core:Text("CORE.HOVER_LEVEL_FILTER"), archive.filters.preview.levelExpr, function(value) archive.filters.preview.levelExpr = value end)
    elseif coreMode then
        Heading(Core:Text("CORE.ADD_TO_ACTION_CENTER"))
        local actions = Core.BusinessItemActions
        local options = actions:GetOptions()
        local modes = { { value = "menu", label = Core:Text("CORE.TOP_RIGHT_BUTTON_CHECK") },
            { value = "middle", label = Core:Text("CORE.MIDDLE_CLICK_443") }, { value = "ctrlLeft", label = Core:Text("CORE.CTRL_CLICK_444") } }
        if options.mode == "custom" then modes[#modes + 1] = { value = "custom", label = Core:Text("CORE.PREVIOUS_CUSTOM_GESTURE") .. actions:GestureLabel() } end
        Dropdown(Core:Text("CORE.ADD_METHOD_CHOOSE_ONE"), options.mode, modes, function(value)
            local ok, err = actions:SetOptions({ mode = value }); if not ok then Core:Print(err) end; AccountView:RefreshPage()
        end)
        Dropdown(Core:Text("CORE.ADDED_TARGET_MARK"), options.markerStyle, {
            { value = "corner", label = Core:Text("CORE.GOLD_CORNER_AT_BOTTOM_LEFT") }, { value = "dot", label = Core:Text("CORE.TEAL_DOT_AT_BOTTOM_LEFT") },
        }, function(value) local ok, err = actions:SetOptions({ markerStyle = value }); if not ok then Core:Print(err) end; AccountView:RefreshPage() end)
        Heading(Core:Text("CORE.MIDDLE_CLICK_OR_CTRL_CLICK_AGAIN_TO"))
        Heading(Core:Text("CORE.WINDOW_LAYOUT"))
        Button(Core:Text("CORE.RESET_WINDOW_POSITION"), function() AccountView:ResetWindowLayout() end)
    elseif displayMode or generalMode or barMode then
        SetGridMinimum(260,2)
        local section=barMode and "bar" or "entries"
        if generalMode then
            Dropdown(Core:Text("LANGUAGE.TITLE"),Core.Locale:GetPreference(),{
                {value="auto",label=Core:Text("LANGUAGE.AUTO")},
                {value="zh",label=Core:Text("LANGUAGE.CHINESE")},
                {value="en",label=Core:Text("LANGUAGE.ENGLISH")},
            },function(value) Core.Locale:SetPreference(value) end)
            if Core.Locale:IsReloadPending() then
                Button(Core:Text("LANGUAGE.RELOAD"),function() ReloadUI() end)
                Note(Core:Text("LANGUAGE.PENDING"))
            elseif Core.Locale:GetPreference()=="auto" then Note(Core:Text("LANGUAGE.ACTIVE",Core:Text(Core.Locale:GetLanguage()=="zh" and "LANGUAGE.CHINESE" or "LANGUAGE.ENGLISH"))) end
            Note(Core:Text("LANGUAGE.DESCRIPTION"))
            Heading(Core:Text("ENTRY.HOVER_OPTIONS"))
            Check(Core:Text("ENTRY.HOVER_MAIN"),settings.entry.showPreviewWhileMainWindowOpen,function(value) settings.entry.showPreviewWhileMainWindowOpen=value end)
        elseif section == "bar" then
            local bar=Core.Entry:GetBuiltinBarSettings()
            local function Enabled(control)
                control:SetEnabled(bar.enabled);control:SetAlpha(bar.enabled and 1 or 0.65);return control
            end
            Check(Core:Text("ENTRY.BAR_ENABLED"),bar.enabled,function(value) Core.Entry:SetBuiltinBarEnabled(value) end)
            Heading(Core:Text("ENTRY.BAR_APPEARANCE"))
            Enabled(Check(Core:Text("ENTRY.BAR_LOCKED"),bar.locked,function(value) Core.Entry:SetBuiltinBarOption("locked",value) end))
            Enabled(Check(Core:Text("ENTRY.BAR_NAMES"),bar.showNames,function(value) Core.Entry:SetBuiltinBarOption("showNames",value) end))
            Enabled(Check(Core:Text("ENTRY.BAR_BORDER"),bar.showBorder,function(value) Core.Entry:SetBuiltinBarOption("showBorder",value) end))
            Enabled(Button(Core:Text("ENTRY.BAR_RESET"),function() Core.Entry:SetBuiltinBarPosition("TOP","TOP",0,-16);AccountView:RefreshPage() end))
            local sizes,spaces,alphas={},{},{}
            for _,n in ipairs({16,20,24,28,32,40,48}) do sizes[#sizes+1]={value=n,label=tostring(n)} end
            for _,n in ipairs({0,2,4,6,8,12,16,20}) do spaces[#spaces+1]={value=n,label=tostring(n)} end
            for _,n in ipairs({0,0.25,0.5,0.75,0.95,1}) do alphas[#alphas+1]={value=n,label=tostring(math.floor(n*100+0.5)).."%"} end
            local function BarDropdown(label,key,options)
                local row=Dropdown(label,bar[key],options,function(value) Core.Entry:SetBuiltinBarOption(key,value) end)
                Enabled(row.dropdown);row:SetAlpha(bar.enabled and 1 or 0.65)
            end
            BarDropdown(Core:Text("ENTRY.BAR_SIZE"),"iconSize",sizes)
            BarDropdown(Core:Text("ENTRY.BAR_SPACING"),"spacing",spaces)
            local backgrounds={}
            for _,item in ipairs({{"theme","ENTRY.COLOR_THEME"},{"black","ENTRY.COLOR_BLACK"},{"charcoal","ENTRY.COLOR_CHARCOAL"},{"navy","ENTRY.COLOR_NAVY"},{"forest","ENTRY.COLOR_FOREST"}}) do
                backgrounds[#backgrounds+1]={value=item[1],label=Core:Text(item[2])}
            end
            BarDropdown(Core:Text("ENTRY.BAR_BACKGROUND"),"background",backgrounds)
            BarDropdown(Core:Text("ENTRY.BAR_OPACITY"),"backgroundAlpha",alphas)
            Heading(Core:Text("ENTRY.BAR_ORDER"))
            local entries=Core.Entry:GetBuiltinBarEntries()
            local options,current={},nil
            for i,entry in ipairs(entries) do
                options[#options+1]={value=entry.id,label=tostring(i)..". "..entry.text}
                if entry.id==parent.orderEntryID then current=i end
            end
            if not current and entries[1] then current=1;parent.orderEntryID=entries[1].id end
            if #entries>0 then
                local selectedRow=Dropdown(Core:Text("ENTRY.ORDER_BUTTON"),parent.orderEntryID,options,function(id) parent.orderEntryID=id end)
                Enabled(selectedRow.dropdown)
                local actions=SettingsRow(parent,index+1,"order-actions");index=index+1
                local actionWidth=PlaceFormControl(actions,230)
                actions.buttons=actions.buttons or {}
                local definitions={{key="ENTRY.ORDER_PREVIOUS",direction=-1},{key="ENTRY.ORDER_NEXT",direction=1}}
                for i,definition in ipairs(definitions) do
                    local button=actions.buttons[i] or CreateChromeButton(actions,100,24,"");actions.buttons[i]=button
                    button:SetText(Core:Text(definition.key));button:ClearAllPoints();button:SetPoint("TOPLEFT",(i-1)*120,0);button:SetWidth(112);button:SetHeight(Theme.Size.standard)
                    button:SetEnabled(bar.enabled and (definition.direction==-1 and current>1 or definition.direction==1 and current<#entries))
                    button:SetAlpha(button:IsEnabled() and 1 or 0.65)
                    button:SetScript("OnClick",function() Core.Entry:MoveBuiltinBarEntry(parent.orderEntryID,definition.direction);AccountView:RefreshPage() end)
                end
                actions:Show()
                Enabled(Button(Core:Text("ENTRY.ORDER_RESET"),function() Core.Entry:ResetBuiltinBarOrder();AccountView:RefreshPage() end))
            else Note(Core:Text("ENTRY.BAR_EMPTY")) end
            Note(Core:Text("ENTRY.BAR_ORDER_HINT"))
        else
            FinishGridRow();index=index+1
            local header=SettingsRow(parent,index,"order-actions")
            header:ClearAllPoints();header:SetPoint("TOPLEFT",2,-y);header:SetWidth(width);header:SetHeight(36)
            header.labels=header.labels or {}
            for i,key in ipairs({"ENTRY.HEADER_PAGE","ENTRY.HEADER_SHOW","ENTRY.CHANNEL_MINIMAP","ENTRY.HEADER_BROKER","ENTRY.HEADER_BAR","CORE.TABLE","CORE.HOVER","ENTRY.HEADER_LAYOUT"}) do
                local label=header.labels[i] or AddText(header,"GameFontNormalSmall",nil,COLORS.muted);header.labels[i]=label
                label:ClearAllPoints();label:SetPoint("TOPLEFT",columns[i].x,0);label:SetWidth(columns[i].width);label:SetHeight(34);label:SetWordWrap(true);label:SetText(Core:Text(key))
            end
            header:Show();y=y+38
            CoreEntryRow({})
            ArchiveEntryRow()
            local pages={}
            local included={}
            for _,page in ipairs(AccountView._pageOrder) do
                if not page.internal then pages[#pages+1]=page;included[page.addonName or page.id]=true end
            end
            for _,panel in ipairs(Core:GetRegisteredSettingsPanels()) do
                if not included[panel.addonName] then
                    pages[#pages+1]={id="addon-settings:"..panel.id,addonName=panel.addonName,title=panel.title,fields={},settingsOnly=true}
                    included[panel.addonName]=true
                end
            end
            table.sort(pages,function(a,b) if a.addonName~=b.addonName then return tostring(a.addonName)<tostring(b.addonName) end return a.id<b.id end)
            for _,page in ipairs(pages) do
                BusinessEntryRow(page,Core.Entry:GetBusinessEntryByPageID(page.id),{})
            end
            if #pages==0 then Note(Core:Text("CORE.NO_BUSINESS_ADDONS_REGISTERED")) end
        end
    else
        local details = settingsOnly or (selected and selected.settings) or {}
        if details.description then
            local text = SettingsRow(parent, index + 1, "heading"); index = index + 1; PlaceSettingsRow(text, y); text:SetText(details.description); text:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3]); text:Show(); y = y + 28
        end
            if type(details.CreateSettingsPanel) == "function" then
                AddonPanel(details)
            else
                Heading(Core:Text("CORE.NO_ADDON_SPECIFIC_SETTINGS"))
            end
    end
    for stale = index + 1, #parent.rows do
        local row = parent.rows[stale]
        for _, dropdown in ipairs({ row.dropdown, row.mainFields, row.previewFields, row.viewMode, row.preview }) do
            if dropdown and dropdown.menu then dropdown.menu:Hide() end
        end
        row:Hide()
    end
    parent.settingsContentHeight = y + 8
    parent.content:SetHeight(math.max(parent.settingsContentHeight, parent.scroll:GetHeight() or 1))
    -- WoW's native range can include pooled, hidden controls from another page.
    -- Use this page's measured content so fitted pages release the scrollbar.
    parent.scroll:SetContentHeight(parent.settingsContentHeight)
end

AccountView._pages.settings = Core.Locale:Bind(function() return {
    id = "settings", title = Core:Text("CORE.SETTINGS"), order = 999, internal = true,
    Create = CreateSettings, Refresh = RefreshSettings,
} end)

Core.Capabilities:Register("account-preview-field-groups", 1)
