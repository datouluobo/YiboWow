local Addon = _G.YiboTodo
local Settings = {}
Addon.Settings = Settings

-- WoW profession-book order for the craft professions that currently expose
-- cooldowns.  This is intentionally independent from activity priority: the
-- settings page groups related recipes together before applying recipe order.
local PROFESSION_ORDER = { [171] = 10, [164] = 20, [333] = 30, [202] = 40, [773] = 50, [755] = 60, [165] = 70, [197] = 80 }

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
    -- Compatibility for existing callers and SavedVariables migrations: the
    -- former per-cooldown/activity switches now write the matching child of
    -- the monitoring-group setting as well.
    local monitoringGroup
    if kind == "cooldownGroup" then monitoringGroup = "profession-cooldown"
    elseif kind == "activity" then
        local map = { ["mop.farm.operation-observed"] = "farm", ["mop.nomi"] = "nomi", ["mop.halfhill.cooking-daily"] = "cooking-daily" }
        monitoringGroup = map[id]
    end
    if monitoringGroup then
        local groups = Addon.db.settings.monitoringGroups or {}; Addon.db.settings.monitoringGroups = groups
        local group = groups[monitoringGroup] or { enabled = true, items = {} }; groups[monitoringGroup] = group
        group.items = type(group.items) == "table" and group.items or {}
        if mode == "hidden" then group.items[id] = false else group.items[id] = nil end
    end
    if Addon.Snapshot then Addon.Snapshot:Invalidate() end
    Addon:NotifyChanged()
end

function Settings:GetMonitoringItems(groupID)
    local definition = Addon.Catalog.monitoringGroups and Addon.Catalog.monitoringGroups[groupID]
    if not definition then return {} end
    local items = {}
    if definition.memberKind == "cooldown-group" then
        for _, group in pairs(Addon.Catalog.groups or {}) do
            if group.active then
                local candidate = false
                for _, recipe in pairs(Addon.Catalog.recipes or {}) do
                    if recipe.cooldownGroupID == group.id and recipe.verificationStatus == "needs-live-confirmation" then candidate = true; break end
                end
                items[#items + 1] = { id = group.id, label = group.label, order = group.order, professionID = group.professionID, professionOrder = PROFESSION_ORDER[tonumber(group.professionID)] or 999, kind = "cooldown-group", defaultEnabled = not candidate, candidate = candidate }
            end
        end
    else
        for _, id in ipairs(definition.members or {}) do
            local source = definition.memberKind == "farm-operation" and Addon.Catalog.farmOperations[id] or Addon.Catalog.dailyActivities[id]
            if source then
                local defaultEnabled = source.defaultEnabled
                if defaultEnabled == nil then defaultEnabled = source.verificationStatus ~= "needs-live-confirmation" end
                items[#items + 1] = { id = id, label = source.label or id, order = source.order, kind = definition.memberKind, defaultEnabled = defaultEnabled, candidate = source.verificationStatus == "needs-live-confirmation" }
            end
        end
    end
    table.sort(items, function(left, right)
        if definition.memberKind == "cooldown-group" and left.professionOrder ~= right.professionOrder then return left.professionOrder < right.professionOrder end
        if (left.order or 999) ~= (right.order or 999) then return (left.order or 999) < (right.order or 999) end
        return left.id < right.id
    end)
    return items
end

local function MonitoringStore(groupID, create)
    Addon.db.settings = Addon.db.settings or {}
    local groups = Addon.db.settings.monitoringGroups
    if type(groups) ~= "table" then groups = {}; Addon.db.settings.monitoringGroups = groups end
    local value = groups[groupID]
    if not value and create then value = { enabled = true, items = {} }; groups[groupID] = value end
    if value then value.items = type(value.items) == "table" and value.items or {} end
    return value
end

function Settings:IsMonitoringItemEnabled(groupID, itemID)
    local group = MonitoringStore(groupID, false)
    if group and group.enabled == false then return false end
    if group and group.items[itemID] ~= nil then return group.items[itemID] == true end
    for _, item in ipairs(self:GetMonitoringItems(groupID)) do
        if item.id == itemID then return item.defaultEnabled ~= false end
    end
    return true
end

function Settings:GetMonitoringGroupState(groupID)
    local group = MonitoringStore(groupID, false)
    if group and group.enabled == false then return "hidden" end
    local items, enabled = self:GetMonitoringItems(groupID), 0
    for _, item in ipairs(items) do if self:IsMonitoringItemEnabled(groupID, item.id) then enabled = enabled + 1 end end
    if enabled == 0 then return "hidden" end
    if enabled < #items then return "partial" end
    return "enabled"
end

function Settings:IsMonitoringGroupEnabled(groupID)
    return self:GetMonitoringGroupState(groupID) ~= "hidden"
end

function Settings:SetMonitoringGroupEnabled(groupID, enabled, selectAll)
    local group = MonitoringStore(groupID, true)
    if enabled then
        group.enabled = true
        -- Re-enabling an empty child selection is an explicit request to start
        -- monitoring the group again, so restore its inherited defaults.
        local any = false
        for _, item in ipairs(self:GetMonitoringItems(groupID)) do if self:IsMonitoringItemEnabled(groupID, item.id) then any = true; break end end
        if selectAll or not any then
            for _, item in ipairs(self:GetMonitoringItems(groupID)) do group.items[item.id] = true end
        end
    else
        group.enabled = false
    end
    Addon:NotifyChanged()
end

function Settings:SetMonitoringItemEnabled(groupID, itemID, enabled)
    local group = MonitoringStore(groupID, true)
    if group.enabled == false then return end
    group.items[itemID] = enabled and true or false
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

function Settings:CreateLegacyPanel(parent, context)
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
        panel.nomiCheck.label:SetText("监控诺米日常（与诺米交谈时复查当天可接/已完成状态）")
        panel.nomiCheck:SetChecked(Settings:GetMode("activity", nomi.id, nomi.defaultMode) ~= "hidden")
        ConfigureModeCheckbox(panel.nomiCheck, "activity", nomi.id, "display", context)
        panel.nomiCheck:Show(); y = y + 28
    end
    local cooking = Addon.Catalog.dailyActivities and Addon.Catalog.dailyActivities["mop.halfhill.cooking-daily"]
    if cooking then
        panel.cookingCheck = panel.cookingCheck or context.createCheckbox(panel, "")
        panel.cookingCheck:ClearAllPoints(); panel.cookingCheck:SetPoint("TOPLEFT", 12, -y); panel.cookingCheck:SetWidth(columnWidth * 2 + columnGap)
        panel.cookingCheck.label:SetText("监控半山烹饪日常（五项轮换任务）")
        panel.cookingCheck:SetChecked(Settings:GetMode("activity", cooking.id, cooking.defaultMode) ~= "hidden")
        ConfigureModeCheckbox(panel.cookingCheck, "activity", cooking.id, "display", context)
        panel.cookingCheck:Show(); y = y + 28
    end
    panel:SetHeight(y + 4); return y + 4
end

local function BindMonitoringCheckbox(check, callback)
    check:SetScript("OnClick", function(control)
        callback(not control:GetChecked())
    end)
end

local function BindMonitoringGroupCheckbox(check, callback)
    check:SetScript("OnClick", function(control)
        local state = control.GetCheckState and control:GetCheckState() or (control:GetChecked() and "checked" or "unchecked")
        callback(state ~= "checked", state == "partial")
    end)
end

function Settings:CreatePanel(parent, context)
    local panel = parent.todoSettingsPanel
    if not panel then
        panel = CreateFrame("Frame", nil, parent); parent.todoSettingsPanel = panel
        panel:SetPoint("TOPLEFT"); panel:SetPoint("TOPRIGHT")
        panel.title = context.createText(panel, 12, _G.YiboCore.UITheme.Colors.text, "LEFT")
        panel.title:SetPoint("TOPLEFT", 12, -12)
        panel.body = context.createText(panel, 11, _G.YiboCore.UITheme.Colors.muted, "LEFT")
        panel.body:SetPoint("TOPLEFT", 12, -40); panel.body:SetPoint("TOPRIGHT", -12, -40)
        panel.groupChecks, panel.itemChecks = {}, {}
    end
    panel.yiboSettingsOwner = "todo"; panel:Show()
    panel.title:SetText("活动监控")
    panel.body:SetText("每个开关控制账号矩阵的一列；包含多个项目的列可单独选择项目。")
    local y, groupIndex, itemIndex = 76, 0, 0
    local groups = {}
    for _, group in pairs(Addon.Catalog.monitoringGroups or {}) do
        if #Settings:GetMonitoringItems(group.id) > 0 then groups[#groups + 1] = group end
    end
    table.sort(groups, function(left, right) return (left.order or 999) < (right.order or 999) end)
    local gap, itemLeft, itemRight, minimumItemWidth = 12, 28, 12, 150
    local availableWidth = math.max(1, (parent:GetWidth() or 420) - itemLeft - itemRight)
    local columns = availableWidth >= minimumItemWidth * 3 + gap * 2 and 3 or 2
    local width = math.floor((availableWidth - gap * (columns - 1)) / columns)
    for _, group in ipairs(groups) do
        groupIndex = groupIndex + 1
        local groupID = group.id
        local parentCheck = panel.groupChecks[groupIndex] or context.createCheckbox(panel, "")
        panel.groupChecks[groupIndex] = parentCheck
        local state = Settings:GetMonitoringGroupState(groupID)
        parentCheck:ClearAllPoints(); parentCheck:SetPoint("TOPLEFT", 12, -y); parentCheck:SetWidth((parent:GetWidth() or 420) - 24)
        local items = Settings:GetMonitoringItems(group.id)
        if #items == 1 then
            -- A one-item column has no meaningful parent/child choice.
            parentCheck:SetChecked(state ~= "hidden")
            parentCheck.label:SetText(group.label)
            BindMonitoringCheckbox(parentCheck, function(enabled)
                Settings:SetMonitoringGroupEnabled(groupID, enabled)
                context.notifyPageChanged(); context.refreshPage()
            end)
            parentCheck:Show(); y = y + 32
        else
            parentCheck:SetCheckState(state == "partial" and "partial" or (state == "enabled" and "checked" or "unchecked"))
            parentCheck.label:SetText(group.label)
            BindMonitoringGroupCheckbox(parentCheck, function(enabled, selectAll)
                Settings:SetMonitoringGroupEnabled(groupID, enabled, selectAll)
                context.notifyPageChanged(); context.refreshPage()
            end)
            parentCheck:Show(); y = y + 27
            for index, item in ipairs(items) do
                local itemID = item.id
                itemIndex = itemIndex + 1
                local check = panel.itemChecks[itemIndex] or context.createCheckbox(panel, "")
                panel.itemChecks[itemIndex] = check
                local column, row = (index - 1) % columns, math.floor((index - 1) / columns)
                check:ClearAllPoints(); check:SetPoint("TOPLEFT", 28 + column * (width + gap), -(y + row * 25)); check:SetWidth(width)
                check.label:SetText(item.label)
                check:SetChecked(Settings:IsMonitoringItemEnabled(groupID, itemID))
                check:SetEnabled(state ~= "hidden")
                BindMonitoringCheckbox(check, function(enabled)
                    Settings:SetMonitoringItemEnabled(groupID, itemID, enabled)
                    context.notifyPageChanged(); context.refreshPage()
                end)
                check:Show()
            end
            y = y + math.ceil(#items / columns) * 25 + 10
        end
    end
    for index = groupIndex + 1, #panel.groupChecks do panel.groupChecks[index]:Hide() end
    for index = itemIndex + 1, #panel.itemChecks do panel.itemChecks[index]:Hide() end
    panel:SetHeight(y + 4)
    return y + 4
end
