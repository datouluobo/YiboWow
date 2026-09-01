local Addon = _G.YiboTodo
local Settings = {}
Addon.Settings = Settings

function Settings:GetMode(kind, id, fallback)
    local overrides = Addon.db.settings.modeOverrides[kind] or {}
    return overrides[id] or fallback or "required"
end

function Settings:SetMode(kind, id, mode)
    Addon.db.settings = Addon.db.settings or {}
    Addon.db.settings.modeOverrides = Addon.db.settings.modeOverrides or {}
    local overrides = Addon.db.settings.modeOverrides[kind]
    if type(overrides) ~= "table" then overrides = {}; Addon.db.settings.modeOverrides[kind] = overrides end
    if mode == nil then overrides[id] = nil else overrides[id] = mode end
    Addon:NotifyChanged()
end

local function ConfigureModeCheckbox(check, kind, id, enabledMode, context)
    check.modeKind, check.modeID, check.enabledMode, check.modeContext = kind, id, enabledMode, context
    if check.modeClickBound then return end
    check.modeClickBound = true
    check:SetScript("OnClick", function(control)
        local checked = not control:GetChecked()
        control:SetChecked(checked)
        -- Store an explicit enabled value.  Removing the override relies on a
        -- fallback during the same refresh and was the source of the one-way
        -- checkbox state in the hosted settings panel.
        Settings:SetMode(control.modeKind, control.modeID, checked and control.enabledMode or "hidden")
        local liveContext = control.modeContext
        if liveContext then
            liveContext.notifyPageChanged()
            liveContext.refreshPage()
        end
    end)
end

function Settings:CreatePanel(parent, context)
    local panel = parent.todoSettingsPanel
    if not panel then
        panel = CreateFrame("Frame", nil, parent); parent.todoSettingsPanel = panel
        panel:SetPoint("TOPLEFT"); panel:SetPoint("TOPRIGHT"); panel.title = context.createText(panel, 12, _G.YiboCore.UITheme.Colors.text, "LEFT")
        panel.title:SetPoint("TOPLEFT", 12, -12); panel.body = context.createText(panel, 11, _G.YiboCore.UITheme.Colors.muted, "LEFT"); panel.body:SetPoint("TOPLEFT", 12, -40); panel.body:SetPoint("TOPRIGHT", -12, -40)
        panel.groupChecks = {}
    end
    panel.yiboSettingsOwner = "todo"
    panel:Show()
    panel.title:SetText("项目过滤")
    panel.body:SetText("勾选的项目会显示并计入待办；取消勾选即可停止监控并从所有角色视图中隐藏。冷却状态以该角色自己的历史观察为准；尚未观察时会明确显示为待确认。")
    local y = 76
    local groups = {}
    for _, group in pairs(Addon.Catalog.groups or {}) do if group.active then groups[#groups + 1] = group end end
    table.sort(groups, function(left, right)
        if (left.order or 999) ~= (right.order or 999) then return (left.order or 999) < (right.order or 999) end
        return tostring(left.id) < tostring(right.id)
    end)
    local columnGap = 12
    local columnWidth = math.max(190, math.floor(((parent:GetWidth() or 420) - 36 - columnGap) / 2))
    for index, group in ipairs(groups) do
        local check = panel.groupChecks[index] or context.createCheckbox(panel, "")
        panel.groupChecks[index] = check
        local column = (index - 1) % 2
        local row = math.floor((index - 1) / 2)
        check:ClearAllPoints(); check:SetPoint("TOPLEFT", 12 + column * (columnWidth + columnGap), -(y + row * 28))
        check:SetWidth(columnWidth)
        local groupID, defaultMode = group.id, group.defaultMode
        check.label:SetText(group.label)
        check:SetChecked(Settings:GetMode("cooldownGroup", groupID, defaultMode) ~= "hidden")
        ConfigureModeCheckbox(check, "cooldownGroup", groupID, "required", context)
        check:Show()
    end
    for index = #groups + 1, #panel.groupChecks do panel.groupChecks[index]:Hide() end
    y = y + math.ceil(#groups / 2) * 28
    local farm = Addon.Catalog.farmOperations and Addon.Catalog.farmOperations["mop.farm.operation-observed"]
    if farm then
        panel.farmCheck = panel.farmCheck or context.createCheckbox(panel, "")
        panel.farmCheck:ClearAllPoints(); panel.farmCheck:SetPoint("TOPLEFT", 12, -y); panel.farmCheck:SetWidth(columnWidth * 2 + columnGap)
        panel.farmCheck.label:SetText("显示农场操作（低保真，不计入待办）")
        panel.farmCheck:SetChecked(Settings:GetMode("activity", farm.id, farm.defaultMode) ~= "hidden")
        ConfigureModeCheckbox(panel.farmCheck, "activity", farm.id, "display", context)
        panel.farmCheck:Show(); y = y + 28
    end
    local nomi = Addon.Catalog.dailyActivities and Addon.Catalog.dailyActivities["mop.nomi"]
    if nomi then
        panel.nomiCheck = panel.nomiCheck or context.createCheckbox(panel, "")
        panel.nomiCheck:ClearAllPoints(); panel.nomiCheck:SetPoint("TOPLEFT", 12, -y); panel.nomiCheck:SetWidth(columnWidth * 2 + columnGap)
        panel.nomiCheck.label:SetText("监控诺米日常（完成过后跨日直接显示可做，任务日志优先）")
        panel.nomiCheck:SetChecked(Settings:GetMode("activity", nomi.id, nomi.defaultMode) ~= "hidden")
        ConfigureModeCheckbox(panel.nomiCheck, "activity", nomi.id, "display", context)
        panel.nomiCheck:Show(); y = y + 28
    end
    panel:SetHeight(y + 4); return y + 4
end
