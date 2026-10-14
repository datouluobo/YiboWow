if _G.YAB and _G.YAB.CoreReady == false then return end
local YAB, Core = _G.YAB, _G.YiboCore
local Theme = Core.UITheme
local TARGET_PAGE_SIZE, CUSTOM_PAGE_SIZE = 10, 8
local function Text(key, ...) return Core.Locale:Get("YiboAltoBoss", key, ...) end
local function Place(frame, relative, x, y, width, height)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", relative, "TOPLEFT", x, -y)
    frame:SetWidth(width)
    if height then frame:SetHeight(height) end
end

function YAB.RefreshSettingsUI()
    if YAB.RefreshCoreSettingsPage then YAB.RefreshCoreSettingsPage() end
end

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
        panel.targets = Section(panel, _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.TRACKED_TARGETS"), 292, 1)
        panel.targets:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
        panel.targetHint = context.createText(panel.targets, Theme.Font.assist, Theme.Colors.muted, "LEFT")
        panel.targetHint:SetPoint("TOPLEFT", 12, -40); panel.targetHint:SetPoint("TOPRIGHT", -12, -40)
        panel.targetHint:SetWordWrap(true); panel.targetHint:SetHeight(32); panel.targetHint:SetText(_G.YiboCore.Locale:Get("YiboAltoBoss", "UI.TURNING_AN_ITEM_OFF_STOPS_RECORDING_WITHOUT_REMOVING_HISTORY_CLICK_TO_EX"))
        panel.targetContent = CreateFrame("Frame", nil, panel.targets)
        panel.targetContent:SetPoint("TOPLEFT", 12, -80); panel.targetContent:SetPoint("TOPRIGHT", -12, -80)

        panel.custom = Section(panel, _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.CUSTOM_TARGETS"), 292, 1)
        panel.custom:SetPoint("TOPLEFT", panel.targets, "TOPRIGHT", 12, 0)
        local customHint = context.createText(panel.custom, Theme.Font.assist, Theme.Colors.muted, "LEFT")
        customHint:SetPoint("TOPLEFT", 12, -40); customHint:SetPoint("TOPRIGHT", -12, -40); customHint:SetHeight(24); customHint:SetText(_G.YiboCore.Locale:Get("YiboAltoBoss", "SETTINGS.NPC_HINT"))
        panel.npcInput = Theme:CreateInput(panel.custom, { width = 92, numeric = true })
        panel.npcInput:SetSize(92, 24); panel.npcInput:SetPoint("TOPLEFT", 12, -70); panel.npcInput:SetAutoFocus(false); panel.npcInput:SetNumeric(true)
        local add = context.createButton(panel.custom, 70, _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.ADD")); add:SetState("selected"); add:SetPoint("LEFT", panel.npcInput, "RIGHT", 8, 0)
        local remove
        local addCurrent = context.createButton(panel.custom, 160, _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.ADD_CURRENT_TARGET")); addCurrent:SetPoint("TOPLEFT", panel.custom, "TOPLEFT", 12, -102)
        panel.customStatus = context.createText(panel.custom, Theme.Font.assist, Theme.Colors.muted, "LEFT"); panel.customStatus:SetPoint("TOPLEFT", 12, -132); panel.customStatus:SetPoint("TOPRIGHT", -12, -132); panel.customStatus:SetHeight(48); panel.customStatus:SetWordWrap(true)
        panel.lockout = Section(panel, Text("SETTINGS.RULES"), 292, 200)
        panel.holidayCheck = context.createCheckbox(panel.lockout, _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.SEASONAL_BOSSES"))
        panel.holidayCheck:SetPoint("TOPLEFT", 12, -42)
        panel.holidayHint = context.createText(panel.lockout, Theme.Font.assist, Theme.Colors.muted, "LEFT")
        panel.holidayHint:SetPoint("TOPLEFT", 32, -70); panel.holidayHint:SetPoint("TOPRIGHT", -12, -70); panel.holidayHint:SetWordWrap(true); panel.holidayHint:SetHeight(28)
        panel.holidayHint:SetText(_G.YiboCore.Locale:Get("YiboAltoBoss", "UI.AUTOMATICALLY_INCLUDED_DURING_THE_EVENT_HIDDEN_WHEN_DISABLED"))
        panel.holidayCheck:SetScript("OnClick", function(self)
            self:SetChecked(not self:GetChecked())
            if YAB.Holiday then YAB.Holiday:SetEnabled(self:GetChecked()) end
            if context and context.refreshPage then context.refreshPage() end
        end)
        panel.lockoutHint = context.createText(panel.lockout, Theme.Font.assist, Theme.Colors.muted, "LEFT")
        panel.lockoutHint:SetPoint("TOPLEFT", 12, -108); panel.lockoutHint:SetPoint("TOPRIGHT", -12, -108); panel.lockoutHint:SetWordWrap(true); panel.lockoutHint:SetHeight(36)
        panel.lockoutHint:SetText(_G.YiboCore.Locale:Get("YiboAltoBoss", "UI.NORMAL_FIVE_PLAYER_ENTRY_LIMIT_SHARED_BY_GAME_ACCOUNT_AND_REALM_OVER_A_R"))
        panel.lockoutInput = Theme:CreateInput(panel.lockout, { width = 56, numeric = true,
            OnSubmit = function(text, input)
                local value = math.max(1, math.floor(tonumber(text) or 5))
                YiboAltoBossDB.settings.normalInstanceLimit = value
                input:SetValue(value)
                YAB.PersistDB()
                if context.notifyPageChanged then context.notifyPageChanged() end
            end,
        })
        panel.lockoutInput:SetSize(56, 24); panel.lockoutInput:SetPoint("TOPLEFT", 12, -160); panel.lockoutInput:SetAutoFocus(false); panel.lockoutInput:SetNumeric(true)
        local lockoutLabel = context.createText(panel.lockout, Theme.Font.assist, Theme.Colors.text, "LEFT")
        lockoutLabel:SetPoint("LEFT", panel.lockoutInput, "RIGHT", 8, 0); lockoutLabel:SetText(_G.YiboCore.Locale:Get("YiboAltoBoss", "UI.ENTRIES_HOUR"))
        local function TPText(key) return _G.YiboCore.Locale:Get("YiboAltoBoss", key) end
        panel.tooltipDetails = Section(panel, TPText("TP.SETTINGS"), 292, 200)
        panel.tooltipChecks = {}
        for index, definition in ipairs({
            { key = "historyKills", label = "TP.SHOW_HISTORY" },
            { key = "lastKill", label = "TP.SHOW_LAST" },
            { key = "entryCount", label = "TP.SHOW_ENTRIES" },
        }) do
            local optionKey = definition.key
            local check = context.createCheckbox(panel.tooltipDetails, TPText(definition.label))
            check:SetPoint("TOPLEFT", 12, -40 - (index - 1) * 28)
            check:SetScript("OnClick", function(self)
                self:SetChecked(not self:GetChecked())
                YiboAltoBossDB.settings.lockoutTooltip = YiboAltoBossDB.settings.lockoutTooltip or {}
                YiboAltoBossDB.settings.lockoutTooltip[optionKey] = self:GetChecked() == true
                YAB.PersistDB()
                if context.notifyPageChanged then context.notifyPageChanged() end
            end)
            panel.tooltipChecks[optionKey] = check
        end
        local function Pager(owner, key)
            local pager = { page = 1 }
            pager.previous = context.createButton(owner, 76, Text("SETTINGS.PREVIOUS"))
            pager.next = context.createButton(owner, 76, Text("SETTINGS.NEXT"))
            pager.label = context.createText(owner, Theme.Font.assist, Theme.Colors.muted, "CENTER")
            pager.previous:SetPoint("BOTTOMLEFT", 12, 12)
            pager.next:SetPoint("BOTTOMRIGHT", -12, 12)
            pager.label:SetPoint("LEFT", pager.previous, "RIGHT", 4, 0)
            pager.label:SetPoint("RIGHT", pager.next, "LEFT", -4, 0)
            local function Move(delta)
                pager.page = math.max(1, math.min(pager.total or 1, pager.page + delta))
                if context.refreshPage then context.refreshPage() end
            end
            pager.previous:SetScript("OnClick", function() Move(-1) end)
            pager.next:SetScript("OnClick", function() Move(1) end)
            panel[key] = pager
        end
        Pager(panel.targets, "targetPager")
        Pager(panel.custom, "customPager")
        panel.customEmpty = context.createText(panel.custom, Theme.Font.assist, Theme.Colors.muted, "LEFT")
        panel.customEmpty:SetPoint("TOPLEFT", 12, -192)
        panel.customEmpty:SetPoint("TOPRIGHT", -12, -192)
        panel.customEmpty:SetWordWrap(true); panel.customEmpty:SetHeight(48)
        panel.customEmpty:SetText(Text("SETTINGS.CUSTOM_EMPTY"))
        panel.data = Section(panel, Core.Locale:Get("YiboAltoBoss", "SETTINGS.DATA_AND_CACHE"), 600, 144)
        local risk = context.createText(panel.data, Theme.Font.assist, Theme.Colors.muted, "LEFT")
        panel.dataRisk = risk
        risk:SetPoint("TOPLEFT", 12, -40); risk:SetPoint("TOPRIGHT", -12, -40); risk:SetHeight(44); risk:SetWordWrap(true)
        risk:SetText(Core.Locale:Get("YiboAltoBoss", "SETTINGS.REMOVE_TARGET_RISK"))
        remove = context.createButton(panel.data, 220, Core.Locale:Get("YiboAltoBoss", "SETTINGS.REMOVE_TARGET"), "danger")
        remove:SetPoint("TOPLEFT", 12, -98)
        panel.removeTarget = remove
        panel:HookScript("OnHide", function()
            if panel.confirmation then panel.confirmation:Cancel(); panel.confirmation = nil end
        end)
        local function UpdateCustom(ok, message)
            panel.customStatus:SetText(message or "")
            local color = ok and Theme.Colors.success or Theme.Colors.danger
            panel.customStatus:SetTextColor(color[1], color[2], color[3])
            if ok then panel.npcInput:SetValue("") end
        end
        add:SetScript("OnClick", function() local ok, message = YAB.AddCustomTarget(panel.npcInput:GetText()); UpdateCustom(ok, message or (ok and _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.CUSTOM_TARGET_ADDED") or _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.COULD_NOT_ADD_TARGET"))) end)
        remove:SetScript("OnClick", function()
            local id = tonumber(panel.npcInput:GetText())
            local target = id and YiboAltoBossDB.customTargets[tostring(id)]
            if not target then
                UpdateCustom(false, Core.Locale:Get("YiboAltoBoss", "UI.CUSTOM_NPC_NOT_FOUND"))
                return
            end
            panel.confirmation = Core.ItemConfirmation:Show({
                text = Core.Locale:Get("YiboAltoBoss", "SETTINGS.REMOVE_TARGET_CONFIRM", target.name, id),
                IsCurrent = function() return panel:IsShown() and YiboAltoBossDB.customTargets[tostring(id)] == target end,
                OnAccept = function()
                    local ok, message = YAB.RemoveCustomTarget(id)
                    UpdateCustom(ok, message)
                    panel.confirmation = nil
                end,
                OnCancel = function() panel.confirmation = nil end,
            })
        end)
        addCurrent:SetScript("OnClick", function() local ok, message = YAB.AddCurrentTarget(); UpdateCustom(ok, message or (ok and _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.CURRENT_TARGET_ADDED") or _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.COULD_NOT_ADD_TARGET"))) end)

    end

    panel.yiboSettingsOwner = "altoboss"
    panel:Show()

    local panelWidth = math.max(320, parent:GetWidth() or 600)
    local twoColumns = panelWidth >= 760
    local halfWidth = twoColumns and math.floor((panelWidth - 12) / 2) or panelWidth
    panel:SetWidth(panelWidth)
    for _, section in ipairs({panel.targets, panel.custom, panel.lockout, panel.tooltipDetails}) do section:SetWidth(halfWidth) end
    for _, check in pairs(panel.tooltipChecks) do check:SetWidth(halfWidth - 24); check.label:SetWidth(halfWidth - 50) end
    local function TextHeight(label, minimum)
        label:SetHeight(0)
        local height = math.max(minimum, math.ceil(label:GetStringHeight() or minimum))
        label:SetHeight(height)
        return height
    end
    local holidayHintHeight = TextHeight(panel.holidayHint, 28)
    local lockoutHintTop = 70 + holidayHintHeight + 12
    panel.lockoutHint:ClearAllPoints()
    panel.lockoutHint:SetPoint("TOPLEFT", 12, -lockoutHintTop)
    panel.lockoutHint:SetPoint("TOPRIGHT", -12, -lockoutHintTop)
    local lockoutHintHeight = TextHeight(panel.lockoutHint, 36)
    local inputTop = lockoutHintTop + lockoutHintHeight + 16
    Place(panel.lockoutInput, panel.lockout, 12, inputTop, 56, 24)
    local rulesHeight = math.max(200, inputTop + 40)
    Place(panel.lockout, panel, 0, 0, halfWidth, rulesHeight)
    Place(panel.tooltipDetails, panel, twoColumns and halfWidth + 12 or 0, twoColumns and 0 or rulesHeight + 12, halfWidth, twoColumns and rulesHeight or 140)
    local listTop = twoColumns and rulesHeight + 24 or rulesHeight + 176
    Place(panel.targets, panel, 0, listTop, halfWidth, 420)
    Place(panel.custom, panel, twoColumns and halfWidth + 12 or 0, listTop, halfWidth, 420)
    local targetContentTop = 40 + TextHeight(panel.targetHint, 32) + 8
    panel.targetContent:ClearAllPoints()
    panel.targetContent:SetPoint("TOPLEFT", 12, -targetContentTop)
    panel.targetContent:SetPoint("TOPRIGHT", -12, -targetContentTop)
    local function UpdatePager(pager, total, count)
        pager.total = math.max(1, total)
        pager.page = math.max(1, math.min(pager.page, pager.total))
        pager.label:SetText(Text("SETTINGS.PAGE", pager.page, pager.total, count))
        pager.previous:SetEnabled(pager.page > 1)
        pager.previous:SetState(pager.page > 1 and "default" or "disabled")
        pager.next:SetEnabled(pager.page < pager.total)
        pager.next:SetState(pager.page < pager.total and "default" or "disabled")
    end
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
    -- Repeat the group heading on continuation pages so each item keeps its context.
    local pages, entries = {}, {}
    local function FinishPage()
        if #entries > 0 then pages[#pages + 1] = entries; entries = {} end
    end
    for _, group in ipairs(groups) do
        local expanded = panel.expandedGroups[group.key] ~= false
        local items = expanded and (targetsByGroup[group.key] or {}) or {}
        if #entries >= TARGET_PAGE_SIZE - 1 then FinishPage() end
        entries[#entries + 1] = {group = group}
        for _, target in ipairs(items) do
            if #entries >= TARGET_PAGE_SIZE then
                FinishPage(); entries[#entries + 1] = {group = group}
            end
            entries[#entries + 1] = {group = group, target = target}
        end
    end
    FinishPage()
    local targetCount = 0
    for _, items in pairs(targetsByGroup) do targetCount = targetCount + #items end
    UpdatePager(panel.targetPager, #pages, targetCount)
    local columnHeight, columnWidth = 0, halfWidth - 24
    for _, entry in ipairs(pages[panel.targetPager.page] or {}) do
        local group = entry.group
        if not entry.target then
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
            check:SetChecked(YAB.IsDisplayGroupEnabled(group.key)); check.label:SetText(group.name); check.label:SetWordWrap(false); Theme:BindTooltip(check, group.name); check:Show()
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
        else
            local target = entry.target
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
            itemCheck:SetChecked(YAB.IsDisplayItemChecked(target.key)); itemCheck.label:SetText(target.name); itemCheck.label:SetWordWrap(false); Theme:BindTooltip(itemCheck, target.name)
            itemCheck:EnableMouse(YAB.IsDisplayGroupEnabled(group.key))
            itemCheck:Show()
            columnHeight = columnHeight + 28
        end
    end
    panel.targetContent:SetHeight(math.max(28, columnHeight))
    local customTargets = {}
    for _, target in ipairs(targetsByGroup.custom or {}) do customTargets[#customTargets + 1] = target end
    table.sort(customTargets, function(a, b) return (tonumber(a.id) or 0) < (tonumber(b.id) or 0) end)
    UpdatePager(panel.customPager, math.ceil(#customTargets / CUSTOM_PAGE_SIZE), #customTargets)
    panel.customEmpty:SetShown(#customTargets == 0)
    local customY = 192
    local first = (panel.customPager.page - 1) * CUSTOM_PAGE_SIZE + 1
    for index = first, math.min(#customTargets, first + CUSTOM_PAGE_SIZE - 1) do
        local target = customTargets[index]
        local visibleIndex = index - first + 1
        local row = panel.customRows[visibleIndex]
        if not row then
            row = context.createButton(panel.custom, 128, "")
            row:SetScript("OnClick", function(self)
                panel.npcInput:SetValue(tostring(self.npcID or "")); panel.npcInput:ClearFocus()
                panel.customStatus:SetText(Core.Locale:Get("YiboAltoBoss", "FORMAT.FILLED_NPC_ID", tostring(self.npcID or "")))
                panel.customStatus:SetTextColor(Theme.Colors.muted[1], Theme.Colors.muted[2], Theme.Colors.muted[3])
            end)
            panel.customRows[visibleIndex] = row
        end
        row:SetWidth(halfWidth - 24); row:ClearAllPoints()
        row:SetPoint("TOPLEFT", panel.custom, "TOPLEFT", 12, -customY - (visibleIndex - 1) * 28)
        local title = Text("FORMAT.CUSTOM_TARGET_ID", target.name or Text("UI.CUSTOM_TARGETS"), tostring(target.id))
        row.npcID = target.id
        row:SetText(title); row.label:SetWordWrap(false)
        Theme:BindTooltip(row, title); row:Show()
    end
    panel.holidayCheck:SetChecked(not (YiboAltoBossDB.settings and YiboAltoBossDB.settings.showHolidayBosses == false))
    panel.lockoutInput:SetValue(tostring((YiboAltoBossDB.settings and YiboAltoBossDB.settings.normalInstanceLimit) or 5))
    for key, check in pairs(panel.tooltipChecks) do
        check:SetChecked(YiboAltoBossDB.settings.lockoutTooltip and YiboAltoBossDB.settings.lockoutTooltip[key] == true or false)
    end
    local targetHeight = math.max(200, targetContentTop + columnHeight + 56)
    local visibleCustomRows = math.min(CUSTOM_PAGE_SIZE, math.max(0, #customTargets - first + 1))
    local customHeight = math.max(272, customY + visibleCustomRows * 28 + 56)
    local dataTop
    if twoColumns then
        local listHeight = math.max(targetHeight, customHeight)
        panel.targets:SetHeight(listHeight); panel.custom:SetHeight(listHeight)
        dataTop = listTop + listHeight + 24
    else
        panel.targets:SetHeight(targetHeight)
        Place(panel.custom, panel, 0, listTop + targetHeight + 12, panelWidth, customHeight)
        dataTop = listTop + targetHeight + 12 + customHeight + 24
    end
    Place(panel.data, panel, 0, dataTop, panelWidth, 144)
    local riskHeight = TextHeight(panel.dataRisk, 32)
    Place(panel.removeTarget, panel.data, 12, 40 + riskHeight + 12, 220)
    panel.data:SetHeight(40 + riskHeight + 12 + Theme.Size.standard + 16)
    panel:SetHeight(dataTop + panel.data:GetHeight() + 12)
    return panel:GetHeight()
end
