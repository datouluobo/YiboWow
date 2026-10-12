local Addon = _G.YiboTaskHub
local Settings = {}
Addon.Settings = Settings
function Settings:GetDisplayCharacters(characters)
    if Addon.db.settings.showOtherCharacters ~= false then return characters end
    local current = Addon.Core.Characters:GetCurrent({ identityOnly = true })
    local result = {}
    for _, c in ipairs(characters or {}) do if current and c.id == current.id then result[#result + 1] = c end end
    return result
end

function Settings:WorkKey(providerID, groupID)
    return #providerID .. ":" .. providerID .. ":" .. (groupID or "*")
end

function Settings:IsWorkVisible(task, providerID)
    local hidden = Addon.db.settings.hiddenWork or {}
    if hidden[self:WorkKey(providerID)] then return false end
    local group = task.displayGroup
    return not (type(group) == "table" and type(group.id) == "string" and hidden[self:WorkKey(providerID, group.id)])
end

function Settings:SetWorkVisible(option, visible)
    Addon.db.settings.hiddenWork = Addon.db.settings.hiddenWork or {}
    Addon.db.settings.hiddenWork[option.key] = not visible and Addon.Core.Defaults:Copy(option) or nil
    Addon.Core.AccountView:NotifyPageChanged(Addon.PAGE_ID)
    Addon.Displays:ScheduleRefresh()
end

function Settings:WorkOptions()
    local options, byKey = {}, {}
    local function Add(option)
        if not byKey[option.key] then options[#options + 1], byKey[option.key] = option, true end
    end
    for _, source in ipairs(Addon.Contracts:GetResults(Addon.Core.Characters:GetAll({ identityOnly = true }))) do
        local providerID = source.descriptor.providerID
        local title = source.result and source.result.sourceTitle or source.descriptor.owner
        Add({ key = self:WorkKey(providerID), providerID = providerID, sourceTitle = title, title = Addon:T("TEXT.ALL_TASKS.211678") })
        for _, group in ipairs(source.result and source.result.displayGroups or {}) do
            if type(group) == "table" and type(group.id) == "string" and group.id ~= "" and type(group.title) == "string" then
                Add({ key = self:WorkKey(providerID, group.id), providerID = providerID, sourceTitle = title, title = group.title })
            end
        end
        for _, task in ipairs(source.result and source.result.data.tasks or {}) do
            local group = task.displayGroup
            if type(group) == "table" and type(group.id) == "string" and group.id ~= "" and type(group.title) == "string" then
                Add({ key = self:WorkKey(providerID, group.id), providerID = providerID, sourceTitle = title, title = group.title })
            end
        end
    end
    -- Hidden entries remain recoverable when their source is temporarily absent.
    for _, option in pairs(Addon.db.settings.hiddenWork or {}) do if type(option) == "table" and type(option.key) == "string"
        and type(option.providerID) == "string" and type(option.title) == "string" and type(option.sourceTitle) == "string" then Add(option) end end
    table.sort(options, function(a, b)
        if a.providerID ~= b.providerID then return a.providerID < b.providerID end
        return a.key < b.key
    end)
    return options
end

function Settings:Set(key, value)
    if key == "bossTargetsAutoDisplay" then return Addon.BossTargets:SetAutoDisplay(value) end
    if key == "hudEnabled" or key == "hudLocked" or key == "showOtherCharacters" then
        if type(value) ~= "boolean" then return false end
    elseif key == "hudRows" then
        if not ({ [3] = true, [5] = true, [8] = true, [12] = true })[value] then return false end
    elseif key == "reminderMode" then
        if not ({ summary = true, hud = true, list = true })[value] then return false end
    else return false end
    Addon.db.settings[key] = value
    Addon.Core.AccountView:NotifyPageChanged(Addon.PAGE_ID)
    Addon.Displays:ScheduleRefresh()
    return true
end

function Settings:SetPreviewField(id, visible)
    for _, field in ipairs(Addon.Presentation.fields) do
        if field.id == id and field.preview ~= false then
            Addon.db.settings.previewColumns[id] = visible == true
            Addon.Core.AccountView:NotifyPageChanged(Addon.PAGE_ID)
            return true
        end
    end
    return false
end

function Settings:CreatePanel(parent, context)
    local panel = parent.taskHubSettings
    local theme = Addon.Core.UITheme
    if not panel then
        panel = CreateFrame("Frame", nil, parent); parent.taskHubSettings = panel
        panel:SetPoint("TOPLEFT"); panel:SetPoint("TOPRIGHT")
        panel.title = theme:CreateText(panel, theme.Font.body, theme.Colors.text)
        panel.title:SetPoint("TOPLEFT", 12, -12); panel.title:SetText(Addon:T("TEXT.BUSINESS_SETTINGS.60735B"))
        panel.left, panel.right = CreateFrame("Frame", nil, panel), CreateFrame("Frame", nil, panel)
        panel.reminderTitle = theme:CreateText(panel.left, theme.Font.body, theme.Colors.text)
        panel.reminderTitle:SetPoint("TOPLEFT"); panel.reminderTitle:SetText(Addon:T("TEXT.LOGIN_REMINDER.91C177"))
        panel.mode = theme:CreateDropdown(panel.left, 220, {
            { value = "summary", label = Addon:T("TEXT.BRIEF_SUMMARY_PANEL.E33659") }, { value = "hud", label = Addon:T("TEXT.PANEL_ONLY.3267C4") }, { value = "list", label = Addon:T("TEXT.OPEN_THE_LIST_WHEN_TASKS_ARE_AVAILAB.DE9810") },
        })
        panel.mode:SetPoint("TOPLEFT", 0, -28)
        panel.mode:SetOnValueChanged(function(value) Settings:Set("reminderMode", value) end)
        panel.note = theme:CreateText(panel.left, theme.Font.assist, theme.Colors.muted)
        panel.note:SetPoint("TOPLEFT", 0, -66); panel.note:SetWordWrap(true)
        panel.note:SetText(Addon:T("TEXT.SHOW_ONE_REMINDER_PER_LOGIN_LATE_ARR.3B5146"))
        panel.autoDisplay = theme:CreateCheckbox(panel.left, Addon:T("TEXT.SHOW_BOSS_GOALS_AUTOMATICALLY_IN_THE.A0FD8D"))
        panel.autoDisplay:SetPoint("TOPLEFT", 0, -146)
        panel.autoDisplay:SetScript("OnClick", function(control)
            Settings:Set("bossTargetsAutoDisplay", not control:GetChecked())
            control:SetChecked(Addon.db.settings.bossTargetsAutoDisplay)
        end)
        panel.otherCharacters = theme:CreateCheckbox(panel.left, Addon:T("TEXT.SHOW_GOALS_FOR_OTHER_CHARACTERS.4B56B0"))
        panel.otherCharacters:SetPoint("TOPLEFT", 0, -178)
        panel.otherCharacters:SetScript("OnClick", function(control)
            Settings:Set("showOtherCharacters", not control:GetChecked())
            control:SetChecked(Addon.db.settings.showOtherCharacters)
        end)
        theme:BindTooltip(panel.otherCharacters, Addon:T("TEXT.SHOW_GOALS_FOR_OTHER_CHARACTERS.4B56B0"), { Addon:T("TEXT.APPLIES_TO_THE_OVERVIEW_GOAL_MANAGEM.520691") })
        panel.enabled = theme:CreateCheckbox(panel.right, Addon:T("TEXT.SHOW_CURRENT_CHARACTER_PANEL.F34B2A"))
        panel.enabled:SetPoint("TOPLEFT")
        panel.locked = theme:CreateCheckbox(panel.right, Addon:T("TEXT.LOCK_PANEL_POSITION.08C175"))
        panel.locked:SetPoint("TOPLEFT", 0, -32)
        for _, pair in ipairs({ { panel.enabled, "hudEnabled" }, { panel.locked, "hudLocked" } }) do
            local control, key = pair[1], pair[2]
            control:SetScript("OnClick", function()
                Settings:Set(key, not control:GetChecked()); control:SetChecked(Addon.db.settings[key])
            end)
        end
        panel.rows = theme:CreateDropdown(panel.right, 220, {
            { value = 3, label = Addon:T("TEXT.PANEL_UP_TO_3_TASKS.7292B2") }, { value = 5, label = Addon:T("TEXT.PANEL_UP_TO_5_TASKS.D698FF") },
            { value = 8, label = Addon:T("TEXT.PANEL_UP_TO_8_TASKS.5B206A") }, { value = 12, label = Addon:T("TEXT.PANEL_UP_TO_12_TASKS.7550EA") },
        })
        panel.rows:SetPoint("TOPLEFT", 0, -66)
        panel.rows:SetOnValueChanged(function(value) Settings:Set("hudRows", value) end)
        panel.drag = theme:CreateText(panel.right, theme.Font.assist, theme.Colors.muted)
        panel.drag:SetPoint("TOPLEFT", 0, -106); panel.drag:SetWordWrap(true)
        panel.drag:SetText(Addon:T("TEXT.DRAG_THE_PANEL_TITLE_TO_MOVE_IT_VIEW.AE7CD1"))
        panel.reset = theme:CreateButton(panel.right, 150, Addon:T("TEXT.RESET_PANEL_POSITION.119C7E"), "secondary")
        panel.reset:SetPoint("TOPLEFT", 0, -154)
        panel.reset:SetScript("OnClick", function()
            Addon.db.settings.hudPosition = nil
            if Addon.HUD.frame then Addon.HUD:RestorePosition() end
        end)
        panel.itemActions = theme:CreateButton(panel.right, 220, Addon:T("TEXT.ADD_GESTURE_GOAL_MARKER.3E995E"), "secondary")
        panel.itemActions:SetPoint("TOPLEFT", 0, -198)
        panel.itemActions:SetScript("OnClick", function() Addon.Core.AccountView:ShowSettings("core") end)
        theme:BindTooltip(panel.itemActions, Addon:T("TEXT.ADD_GESTURE_GOAL_MARKER.3E995E"), {
            Addon:T("TEXT.OPEN_CORE_SETTINGS_WINDOW.94CF4F"),
            Addon:T("TEXT.CHOOSE_ONE_ADD_GESTURE_TOP_RIGHT_BUT.14E8ED"),
            Addon:T("TEXT.ADDED_MARKER_GOLD_CORNER_OR_TEAL_DOT.82EA0F"),
        })
        panel.work = CreateFrame("Frame", nil, panel)
        panel.workChecks = {}
        panel.workTitle = theme:CreateText(panel.work, theme.Font.body, theme.Colors.text)
        panel.workTitle:SetPoint("TOPLEFT"); panel.workTitle:SetText(Addon:T("TEXT.ACTION_HUB_CONTENT.927430"))
        panel.roles = theme:CreateButton(panel.work, 140, Addon:T("TEXT.CHARACTER_VISIBILITY_ORDER.A999D2"), "secondary")
        panel.roles:SetPoint("TOPRIGHT", 0, 0)
        panel.roles:SetScript("OnClick", function() Addon.Core.AccountView:ShowSettings("sorting") end)
        panel.monitoring = theme:CreateButton(panel.work, 140, Addon:T("TEXT.TASK_MONITORING_ITEMS.DAE1C8"), "secondary")
        panel.monitoring:SetPoint("RIGHT", panel.roles, "LEFT", -8, 0)
        panel.monitoring:SetScript("OnClick", function() Addon.Core.AccountView:ShowSettings("todo") end)
        panel.workSource = theme:CreateDropdown(panel.work, 220, {})
        panel.workSource:SetPoint("TOPLEFT", 0, -38)
        panel.workSource:SetOnValueChanged(function(id)
            panel.sourceID, panel.workPage = id, 1; Settings:CreatePanel(parent, context)
        end)
        panel.workNote = theme:CreateText(panel.work, theme.Font.assist, theme.Colors.muted)
        panel.workNote:SetPoint("TOPLEFT", 0, -76); panel.workNote:SetWordWrap(true)
        panel.workNote:SetText(Addon:T("TEXT.THESE_OPTIONS_AFFECT_THE_MAIN_LIST_H.24511C"))
        panel.workPrev = theme:CreateButton(panel.work, 62, Addon:T("TEXT.PREVIOUS.B41561"), "secondary")
        panel.workNext = theme:CreateButton(panel.work, 62, Addon:T("TEXT.NEXT.67A246"), "secondary")
        panel.workFooter = theme:CreateText(panel.work, theme.Font.assist, theme.Colors.muted)
        panel.workPrev:SetPoint("TOPLEFT", 0, -248); panel.workNext:SetPoint("LEFT", panel.workPrev, "RIGHT", 8, 0)
        panel.workFooter:SetPoint("LEFT", panel.workNext, "RIGHT", 12, 0)
        panel.workPrev:SetScript("OnClick", function() panel.workPage = panel.workPage - 1; Settings:CreatePanel(parent, context) end)
        panel.workNext:SetScript("OnClick", function() panel.workPage = panel.workPage + 1; Settings:CreatePanel(parent, context) end)
    end
    panel.yiboSettingsOwner = Addon.PAGE_ID
    local width = math.max(180, parent:GetWidth() - 24)
    local columns = width >= 540
    local colWidth = columns and math.floor((width - 20) / 2) or width
    panel.left:ClearAllPoints(); panel.left:SetPoint("TOPLEFT", 12, -46); panel.left:SetSize(colWidth, 222)
    panel.right:ClearAllPoints(); panel.right:SetPoint("TOPLEFT", columns and colWidth + 32 or 12, columns and -46 or -282); panel.right:SetSize(colWidth, 232)
    panel.itemActions:SetWidth(math.min(220, colWidth))
    panel.mode:SetWidth(colWidth); panel.rows:SetWidth(colWidth)
    panel.note:SetSize(colWidth, 74); panel.drag:SetSize(colWidth, 42)
    panel.autoDisplay:SetWidth(colWidth)
    panel.autoDisplay:SetChecked(Addon.db.settings.bossTargetsAutoDisplay)
    panel.otherCharacters:SetWidth(colWidth); panel.otherCharacters:SetChecked(Addon.db.settings.showOtherCharacters ~= false)
    local baseHeight = columns and 300 or 524
    local narrow = width < 340
    local extraHeight = (columns and 286 or 320) + (narrow and 70 or 0)
    panel.work:ClearAllPoints(); panel.work:SetPoint("TOPLEFT", 12, -baseHeight); panel.work:SetSize(width, extraHeight)
    panel.workTitle:SetWidth(columns and math.max(80, width - 310) or width); panel.workTitle:SetHeight(30)
    panel.roles:ClearAllPoints(); panel.monitoring:ClearAllPoints()
    panel.roles:SetWidth(columns and 140 or math.min(140, math.floor((width - 8) / 2)))
    panel.monitoring:SetWidth(panel.roles:GetWidth())
    panel.roles:SetText(Addon:T("TEXT.CHARACTERS_ORDER.00D299")); panel.monitoring:SetText(Addon:T("TEXT.TASK_MONITORING.F54E5D"))
    if columns then
        panel.roles:SetPoint("TOPRIGHT", 0, 0); panel.monitoring:SetPoint("RIGHT", panel.roles, "LEFT", -8, 0)
    else
        panel.roles:SetPoint("TOPLEFT", 0, -34); panel.monitoring:SetPoint("LEFT", panel.roles, "RIGHT", 8, 0)
    end
    local offset = columns and 0 or 34
    panel.workSource:ClearAllPoints(); panel.workSource:SetPoint("TOPLEFT", 0, -38 - offset); panel.workSource:SetWidth(math.min(220, width))
    panel.workNote:ClearAllPoints(); panel.workNote:SetPoint("TOPLEFT", 0, -76 - offset)
    local noteExtra = narrow and 38 or 0
    panel.workPrev:ClearAllPoints(); panel.workPrev:SetPoint("TOPLEFT", 0, -248 - offset - noteExtra)
    panel.workNote:SetSize(width, 36 + noteExtra)
    panel.workFooter:ClearAllPoints()
    if narrow then panel.workFooter:SetPoint("TOPLEFT", 0, -280 - offset - noteExtra)
    else panel.workFooter:SetPoint("LEFT", panel.workNext, "RIGHT", 12, 0) end
    panel.workFooter:SetWidth(narrow and width or math.max(1, width - 152)); panel.workFooter:SetHeight(28)
    local all, entries, sources, known = self:WorkOptions(), {}, { { value = "all", label = Addon:T("TEXT.ALL_SOURCES.F8D22F") } }, {}
    for _, option in ipairs(all) do
        if not known[option.providerID] then sources[#sources + 1] = { value = option.providerID, label = option.sourceTitle }; known[option.providerID] = true end
    end
    if not known[panel.sourceID] then panel.sourceID = "all" end
    for _, option in ipairs(all) do if panel.sourceID == "all" or panel.sourceID == option.providerID then entries[#entries + 1] = option end end
    panel.workSource:SetOptions(sources); panel.workSource:SetValue(panel.sourceID)
    local perPage = columns and 8 or 4
    local pages = math.max(1, math.ceil(#entries / perPage))
    panel.workPage = math.max(1, math.min(panel.workPage or 1, pages))
    for _, check in ipairs(panel.workChecks) do check:Hide() end
    for i = 1, math.min(perPage, #entries - (panel.workPage - 1) * perPage) do
        local option = entries[(panel.workPage - 1) * perPage + i]
        local check = panel.workChecks[i] or theme:CreateCheckbox(panel.work, "")
        panel.workChecks[i] = check
        check:ClearAllPoints(); check:SetPoint("TOPLEFT", columns and ((i - 1) % 2) * (colWidth + 20) or 0, -116 - offset - noteExtra - math.floor((i - 1) / (columns and 2 or 1)) * 32)
        check:SetWidth(colWidth); check.label:SetWidth(math.max(80, colWidth - 28))
        check.label:SetText(option.title == Addon:T("TEXT.ALL_TASKS.211678") and (option.sourceTitle .. Addon:T("TEXT.ALL_TASKS.CB2359")) or option.title)
        check:SetChecked(not Addon.db.settings.hiddenWork[option.key]); check:Show()
        check:SetEnabled(option.key == self:WorkKey(option.providerID) or not Addon.db.settings.hiddenWork[self:WorkKey(option.providerID)])
        theme:BindTooltip(check, option.title, { Addon:T("TEXT.SOURCE.64B3B5") .. option.sourceTitle, Addon:T("TEXT.CHANGES_ONLY_ACTION_HUB_VISIBILITY_C.C76DF1") })
        check:SetScript("OnClick", function()
            Settings:SetWorkVisible(option, not check:GetChecked()); Settings:CreatePanel(parent, context)
        end)
    end
    panel.workPrev:SetEnabled(panel.workPage > 1); panel.workNext:SetEnabled(panel.workPage < pages)
    panel.workPrev:SetShown(pages > 1); panel.workNext:SetShown(pages > 1)
    panel.workFooter:SetText(#entries == 0 and Addon:T("TEXT.NO_SOURCE_ITEMS_YET_COMPATIBLE_BUSIN.4A439D") or string.format(Addon:T("TEXT.PAGE_D_D_D_ITEMS.58176A"), panel.workPage, pages, #entries))
    panel:SetHeight(baseHeight + extraHeight)
    panel.enabled:SetChecked(Addon.db.settings.hudEnabled); panel.locked:SetChecked(Addon.db.settings.hudLocked)
    panel.mode:SetValue(Addon.db.settings.reminderMode); panel.rows:SetValue(Addon.db.settings.hudRows)
    panel:Show()
    return panel
end
