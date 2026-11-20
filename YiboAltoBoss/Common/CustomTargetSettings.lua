if _G.YAB and _G.YAB.CoreReady == false then return end
local YAB, Core = _G.YAB, _G.YiboCore
local Theme = Core.UITheme
local Editor = {}
YAB.CustomTargetSettings = Editor
local CUSTOM_PAGE_SIZE = 8
local function Text(key, ...) return Core.Locale:Get("YiboAltoBoss", key, ...) end
local function Place(frame, relative, x, y, width, height)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", relative, "TOPLEFT", x, -y)
    frame:SetWidth(width)
    if height then frame:SetHeight(height) end
end

function Editor.CreatePager(owner, context)
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
    return pager
end

function Editor.UpdatePager(pager, total, count)
    pager.total = math.max(1, total)
    pager.page = math.max(1, math.min(pager.page, pager.total))
    pager.label:SetText(Text("SETTINGS.PAGE", pager.page, pager.total, count))
    pager.previous:SetEnabled(pager.page > 1)
    pager.previous:SetState(pager.page > 1 and "default" or "disabled")
    pager.next:SetEnabled(pager.page < pager.total)
    pager.next:SetState(pager.page < pager.total and "default" or "disabled")
end

function Editor.Create(panel, context, config)
    local Section = context.createSection
    panel.customRows = {}
    panel.custom = Section(panel, _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.CUSTOM_TARGETS"), 292, 1)
    local customHint = context.createText(panel.custom, Theme.Font.assist, Theme.Colors.muted, "LEFT")
    customHint:SetPoint("TOPLEFT", 12, -40); customHint:SetPoint("TOPRIGHT", -12, -40); customHint:SetHeight(24); customHint:SetText(Text(config.hint))
    panel.npcInput = Theme:CreateInput(panel.custom, { width = 92, numeric = true })
    panel.npcInput:SetSize(92, 24); panel.npcInput:SetPoint("TOPLEFT", 12, -70); panel.npcInput:SetAutoFocus(false); panel.npcInput:SetNumeric(true)
    local add = context.createButton(panel.custom, 70, _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.ADD")); add:SetState("selected"); add:SetPoint("LEFT", panel.npcInput, "RIGHT", 8, 0)
    panel.customStatus = context.createText(panel.custom, Theme.Font.assist, Theme.Colors.muted, "LEFT"); panel.customStatus:SetPoint("TOPLEFT", 12, -132); panel.customStatus:SetPoint("TOPRIGHT", -12, -132); panel.customStatus:SetHeight(48); panel.customStatus:SetWordWrap(true)
    panel.customPager = Editor.CreatePager(panel.custom, context)
    panel.customEmpty = context.createText(panel.custom, Theme.Font.assist, Theme.Colors.muted, "LEFT")
    panel.customEmpty:SetPoint("TOPLEFT", 12, -192)
    panel.customEmpty:SetPoint("TOPRIGHT", -12, -192)
    panel.customEmpty:SetWordWrap(true); panel.customEmpty:SetHeight(48)
    panel.customEmpty:SetText(Text(config.empty or "SETTINGS.CUSTOM_EMPTY"))
    panel.data = Section(panel, Core.Locale:Get("YiboAltoBoss", "SETTINGS.DATA_AND_CACHE"), 600, 144)
    local risk = context.createText(panel.data, Theme.Font.assist, Theme.Colors.muted, "LEFT")
    panel.dataRisk = risk
    risk:SetPoint("TOPLEFT", 12, -40); risk:SetPoint("TOPRIGHT", -12, -40); risk:SetHeight(44); risk:SetWordWrap(true)
    risk:SetText(Core.Locale:Get("YiboAltoBoss", "SETTINGS.REMOVE_TARGET_RISK"))
    local remove = context.createButton(panel.data, 220, Core.Locale:Get("YiboAltoBoss", "SETTINGS.REMOVE_TARGET"), "danger")
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
    add:SetScript("OnClick", function() local ok, message = config.add(panel.npcInput:GetText()); UpdateCustom(ok, message or (ok and _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.CUSTOM_TARGET_ADDED") or _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.COULD_NOT_ADD_TARGET"))) end)
    remove:SetScript("OnClick", function()
        local id = tonumber(panel.npcInput:GetText())
        local target = id and config.directory()[tostring(id)]
        if not target then
            UpdateCustom(false, Core.Locale:Get("YiboAltoBoss", "UI.CUSTOM_NPC_NOT_FOUND"))
            return
        end
        panel.confirmation = Core.ItemConfirmation:Show({
            text = Core.Locale:Get("YiboAltoBoss", "SETTINGS.REMOVE_TARGET_CONFIRM", target.name, id),
            IsCurrent = function() return panel:IsShown() and config.directory()[tostring(id)] == target end,
            OnAccept = function()
                local ok, message = config.remove(id)
                UpdateCustom(ok, message)
                panel.confirmation = nil
            end,
            OnCancel = function() panel.confirmation = nil end,
        })
    end)
    if config.addCurrent then
        local addCurrent = context.createButton(panel.custom, 160, Text("UI.ADD_CURRENT_TARGET"))
        addCurrent:SetPoint("TOPLEFT", panel.custom, "TOPLEFT", 12, -102)
        addCurrent:SetScript("OnClick", function()
            local ok, message = config.addCurrent()
            UpdateCustom(ok, message or Text(ok and "UI.CURRENT_TARGET_ADDED" or "UI.COULD_NOT_ADD_TARGET"))
        end)
    end
end

function Editor.Refresh(panel, context, customTargets, halfWidth)
    for _, button in ipairs(panel.customRows) do button:Hide() end
    table.sort(customTargets, function(a, b) return (tonumber(a.id) or 0) < (tonumber(b.id) or 0) end)
    Editor.UpdatePager(panel.customPager, math.ceil(#customTargets / CUSTOM_PAGE_SIZE), #customTargets)
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
    local visibleRows = math.min(CUSTOM_PAGE_SIZE, math.max(0, #customTargets - first + 1))
    return math.max(272, customY + visibleRows * 28 + 56)
end

function Editor.PlaceRemoval(panel, dataTop, panelWidth)
    Place(panel.data, panel, 0, dataTop, panelWidth, 144)
    panel.dataRisk:SetHeight(0)
    local riskHeight = math.max(32, math.ceil(panel.dataRisk:GetStringHeight() or 32))
    panel.dataRisk:SetHeight(riskHeight)
    Place(panel.removeTarget, panel.data, 12, 40 + riskHeight + 12, 220)
    panel.data:SetHeight(40 + riskHeight + 12 + Theme.Size.standard + 16)
    return panel.data:GetHeight()
end
