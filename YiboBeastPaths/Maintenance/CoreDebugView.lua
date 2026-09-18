local addonName, ns = ...
local YBP = _G.YiboBeastPaths

-- The calibrator owns the saved data and actions.  This file owns only the
-- Core-hosted presentation; the legacy UIPanelButtonTemplate panel is never
-- constructed by the Core page.
local view
local tabs = { { "calibrate", "路线校准" }, { "fusion", "融合工作台" },
    { "footprints", "脚印管理" }, { "export", "导出" } }
local presets = { fine = { 0.002, 0.005 }, medium = { 0.005, 0.01 }, coarse = { 0.01, 0.02 } }
local BUTTON_MIN_WIDTH, BUTTON_MAX_WIDTH = 80, 176
local BUTTON_GAP, MAX_BUTTONS_PER_ROW = 8, 6

local function ui()
    local db = _G.YiboBeastPathsDebugDB
    return db and db.ui or nil
end

local function fmt(value)
    return type(value) == "number" and string.format("%.4f", value) or "—"
end

local function current(action)
    local petID = YBP:GetSelectedDebugPetID()
    if petID then action(petID) end
end

local function confirm(message, action)
    current(function(petID)
        YBP:ConfirmDebugAction(message, function() action(petID) end)
    end)
end

local function nudge(field, direction)
    current(function(petID)
        local state = ui()
        if not state then return end
        local move, scale = state.stepMove or 0.005, state.stepScale or 0.01
        if field == "nodeX" or field == "nodeY" or field == "nodeScale" then
            local key = field == "nodeX" and "normalizedX" or field == "nodeY" and "normalizedY" or "nodeScale"
            YBP:AdjustDebugRouteNodeValue(petID, "start", key, direction * (field == "nodeScale" and scale or move))
        elseif field == "mmX" or field == "mmY" or field == "mmScale" or field == "mmScaleX"
            or field == "mmScaleY" or field == "mmThickness" then
            local keys = { mmX = "offsetX", mmY = "offsetY", mmScale = "scale",
                mmScaleX = "scaleX", mmScaleY = "scaleY", mmThickness = "lineThickness" }
            YBP:AdjustDebugMinimapValue(petID, keys[field], direction *
                ((field == "mmX" or field == "mmY") and move or scale))
        else
            YBP:EnsureDebugTransform(petID)
            YBP:AdjustDebugValue(petID, field, direction *
                ((field == "offsetX" or field == "offsetY") and move or scale))
        end
    end)
end

local function visual(key, delta, low, high, decimals)
    if not YBP.SetRouteVisualSetting then return end
    local settings = YBP.GetRouteVisualSettings and YBP:GetRouteVisualSettings() or {}
    local defaults = ns.routeDisplayMeta and ns.routeDisplayMeta.defaults or {}
    local value = (settings[key] or defaults[key] or 0) + delta
    value = math.max(low, math.min(high, value))
    if decimals > 0 then
        local factor = 10 ^ decimals
        value = math.floor(value * factor + 0.5) / factor
    end
    YBP:SetRouteVisualSetting(key, value)
end

local function cycleRoute(direction)
    local ids = YBP:GetDebugPetIDsForCurrentMap() or {}
    if #ids == 0 then return end
    local index = 1
    for i, id in ipairs(ids) do
        if id == YBP:GetSelectedDebugPetID() then index = i; break end
    end
    index = ((index - 1 + direction) % #ids) + 1
    YBP:SetSelectedDebugPetID(ids[index])
end

local function makeText(theme, parent, font, color)
    local label = theme:CreateText(parent, font, color, "LEFT")
    label:SetWordWrap(true)
    label:SetJustifyV("TOP")
    return label
end

local function addButton(theme, group, label, callback, kind)
    local button = theme:CreateButton(group.frame, 120, label, kind or "secondary")
    button.layoutLabel = label
    button:SetScript("OnClick", function()
        callback()
        YBP:RefreshDebugPanel()
    end)
    group.buttons[#group.buttons + 1] = button
    return button
end

local function addGroup(theme, tab, title, note)
    local frame = CreateFrame("Frame", nil, tab.frame, "BackdropTemplate")
    frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    frame:SetBackdropColor(unpack(theme.Colors.panel))
    frame:SetBackdropBorderColor(unpack(theme.Colors.lineSoft))
    local group = { frame = frame, buttons = {}, theme = theme,
        title = makeText(theme, frame, theme.Font.section, theme.Colors.text) }
    group.title:SetText(title)
    if note then
        group.note = makeText(theme, frame, theme.Font.assist, theme.Colors.muted)
        group.note:SetText(note)
    end
    tab.groups[#tab.groups + 1] = group
    return group
end

local function addPair(theme, group, minus, plus, field)
    addButton(theme, group, minus, function() nudge(field, -1) end)
    addButton(theme, group, plus, function() nudge(field, 1) end)
end

local function makeTabs(theme, panel)
    panel.tabs = {}
    panel.tabButtons = {}
    for _, spec in ipairs(tabs) do
        local key, label = spec[1], spec[2]
        local button = theme:CreateButton(panel, 120, label, "secondary")
        button:SetScript("OnClick", function() YBP:SetActiveDebugTab(key) end)
        panel.tabButtons[key] = button
        local frame = CreateFrame("Frame", nil, panel)
        panel.tabs[key] = { frame = frame, groups = {} }
    end
end

local function buildCalibrate(theme, tab)
    local group = addGroup(theme, tab, "调节步进", "先选择每次点击的幅度；大图、起点和小图共用。")
    for _, spec in ipairs({ { "细调", "fine" }, { "中调", "medium" }, { "粗调", "coarse" } }) do
        local name, key = spec[1], spec[2]
        local button = addButton(theme, group, name, function()
            local state = ui()
            if state then state.stepMove, state.stepScale = presets[key][1], presets[key][2] end
        end)
        button.preset = key
    end

    group = addGroup(theme, tab, "大地图路线", "依次调整位置、缩放比例、线宽和透明度。")
    addPair(theme, group, "左移", "右移", "offsetX")
    addPair(theme, group, "上移", "下移", "offsetY")
    addPair(theme, group, "缩小", "放大", "scale")
    addPair(theme, group, "横缩", "横放", "scaleX")
    addPair(theme, group, "竖缩", "竖放", "scaleY")
    addButton(theme, group, "线条变细", function() YBP:AdjustDebugRouteThickness(-0.10) end)
    addButton(theme, group, "线条变粗", function() YBP:AdjustDebugRouteThickness(0.10) end)
    addButton(theme, group, "更透明", function() current(function(id) YBP:AdjustDebugValue(id, "opacity", -0.05) end) end)
    addButton(theme, group, "更明显", function() current(function(id) YBP:AdjustDebugValue(id, "opacity", 0.05) end) end)

    group = addGroup(theme, tab, "起点节点", "调整路线首节点的位置和大小。")
    addPair(theme, group, "节点左", "节点右", "nodeX")
    addPair(theme, group, "节点上", "节点下", "nodeY")
    addPair(theme, group, "节点小", "节点大", "nodeScale")

    group = addGroup(theme, tab, "小地图路线", "调整小图路线的偏移、缩放比例和线宽。")
    addPair(theme, group, "小图左", "小图右", "mmX")
    addPair(theme, group, "小图上", "小图下", "mmY")
    addPair(theme, group, "小图缩小", "小图放大", "mmScale")
    addPair(theme, group, "小图横缩", "小图横放", "mmScaleX")
    addPair(theme, group, "小图竖缩", "小图竖放", "mmScaleY")
    addPair(theme, group, "小图线细", "小图线粗", "mmThickness")
    addButton(theme, group, "小图清零", function()
        confirm("确定清除当前宠物的小地图变换吗？", function(id) YBP:ResetDebugMinimapTransform(id) end)
    end, "danger")

    group = addGroup(theme, tab, "当前路线", "保存当前宠物的路线或参考层参数；重置会清除路线、起点及小图变换。")
    addButton(theme, group, "保存当前", function()
        current(function(id)
            YBP:EnsureDebugTransform(id)
            YBP:EnsureDebugRouteNode(id, "start")
            local savedReference = YBP:SaveCurrentReferenceDisplayTransform(id)
            print(string.format("|cff20e070[Yibo]|r 隐兽寻踪调试：已保存宠物 [%d] 的%s调试参数。",
                id, savedReference and "参考层" or "路线与起点"))
        end)
    end, "default")
    addButton(theme, group, "重置当前", function()
        confirm("确定重置当前宠物的路线、节点与小地图变换吗？", function(id)
            YBP:ResetDebugTransform(id)
            YBP:ResetDebugMinimapTransform(id)
            YBP:ResetDebugRouteNode(id, "start")
        end)
    end, "danger")
end

local function buildFusion(theme, tab)
    local group = addGroup(theme, tab, "路线重算", "选择只重算当前宠物，或重算当前地图的全部路线。")
    addButton(theme, group, "重算当前", function()
        current(function(id) if YBP.ResolveRouteForPet then YBP:ResolveRouteForPet(id) end end)
    end, "default")
    addButton(theme, group, "重算本图", function()
        local mapID = YBP.GetDebugContextMapID and YBP:GetDebugContextMapID() or YBP:GetCurrentWorldMapID()
        if mapID and YBP.ResolveRoutesForMap then YBP:ResolveRoutesForMap(mapID) end
    end)
    group = addGroup(theme, tab, "图层显示", "开关只改变图层可见性，不删除路线或脚印数据。")
    for _, spec in ipairs({ { "最终层", "showResolved" }, { "底稿层", "showLegacyOverlay" },
        { "参考层", "showReference" }, { "脚印层", "showFootprints" } }) do
        local label, key = spec[1], spec[2]
        local button = addButton(theme, group, label, function()
            local settings = YBP.GetRouteDisplaySettings and YBP:GetRouteDisplaySettings()
            if settings and YBP.SetRouteDisplaySetting then YBP:SetRouteDisplaySetting(key, not settings[key]) end
        end)
        button.settingKey, button.baseLabel = key, label
    end
    group.autoButton = addButton(theme, group, "自动重算", function()
        if YBP.SetRouteAutoResolveEnabled then
            YBP:SetRouteAutoResolveEnabled(not YBP:IsRouteAutoResolveEnabled())
        end
    end)
    group = addGroup(theme, tab, "显示预设与导出", "预设批量切换图层；导出融合会打开导出页。")
    addButton(theme, group, "全开", function() if YBP.ApplyRouteDisplayPreset then YBP:ApplyRouteDisplayPreset("all") end end)
    addButton(theme, group, "仅最终层", function() if YBP.ApplyRouteDisplayPreset then YBP:ApplyRouteDisplayPreset("resolvedOnly") end end)
    addButton(theme, group, "重置显示", function()
        if YBP.ApplyRouteDisplayPreset then YBP:ApplyRouteDisplayPreset("default") end
        if YBP.ResetRouteVisualSettings then YBP:ResetRouteVisualSettings() end
    end)
    addButton(theme, group, "导出融合", function()
        YBP:SetActiveDebugTab("export")
        if view and view.exportBox then view.exportBox:SetText(YBP:ExportCurrentRouteFusionSnapshot() or "") end
    end, "default")
    addButton(theme, group, "重置细节", function() if YBP.ResetRouteVisualSettings then YBP:ResetRouteVisualSettings() end end)

    group = addGroup(theme, tab, "路线与脚印细节", "调整线宽、点位密度和脚印外观，不改动路线点位。")
    for _, spec in ipairs({
        { "主线细", "resolvedThickness", -0.5, 1, 8, 1 }, { "主线粗", "resolvedThickness", 0.5, 1, 8, 1 },
        { "脚印小", "footprintSize", -1, 4, 24, 0 }, { "脚印大", "footprintSize", 1, 4, 24, 0 },
        { "脚印淡", "footprintAlpha", -0.05, 0.15, 1, 2 }, { "脚印亮", "footprintAlpha", 0.05, 0.15, 1, 2 },
        { "参考细", "referenceThickness", -0.5, 1, 8, 1 }, { "参考粗", "referenceThickness", 0.5, 1, 8, 1 },
        { "点位疏", "routeDensity", -1, 1, 8, 0 }, { "点位密", "routeDensity", 1, 1, 8, 0 },
        { "小图点少", "minimapNearbyPointLimit", -1, 0, 20, 0 },
        { "小图点多", "minimapNearbyPointLimit", 1, 0, 20, 0 },
    }) do
        local label, key, delta, low, high, decimals = unpack(spec)
        addButton(theme, group, label, function() visual(key, delta, low, high, decimals) end)
    end
    group = addGroup(theme, tab, "融合详情")
    group.detail = makeText(theme, group.frame, theme.Font.assist, theme.Colors.muted)
end

local function buildFootprints(theme, tab)
    local group = addGroup(theme, tab, "脚印采集", "记录当前位置；删除与清空只作用于当前宠物。")
    addButton(theme, group, "记录脚印", function()
        local _, message = YBP:CaptureCurrentFootprintForSelectedPet()
        if message then print("|cff20e070[Yibo]|r 隐兽寻踪调试：" .. message) end
    end, "default")
    addButton(theme, group, "影响短", function() visual("footprintInfluenceArc", -0.1, 0.5, 2.5, 1) end)
    addButton(theme, group, "影响长", function() visual("footprintInfluenceArc", 0.1, 0.5, 2.5, 1) end)
    addButton(theme, group, "删最后点", function()
        if YBP.RemoveLastFootprintAnchor then
            confirm("确定删除最后一个脚印点吗？", function(id) YBP:RemoveLastFootprintAnchor(id) end)
        end
    end, "danger")
    addButton(theme, group, "清空脚印", function()
        if YBP.ClearFootprintAnchors then
            confirm("确定清空当前宠物的全部脚印点吗？此操作不可恢复。", function(id) YBP:ClearFootprintAnchors(id) end)
        end
    end, "danger")
    group = addGroup(theme, tab, "脚印列表", "每页 6 点，可逐点启用、禁用或删除。")
    tab.rows = {}
    for i = 1, 6 do
        local row = CreateFrame("Frame", nil, group.frame, "BackdropTemplate")
        row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
        row:SetBackdropColor(unpack(theme.Colors.row))
        row.label = makeText(theme, row, theme.Font.assist, theme.Colors.text)
        row.toggle = theme:CreateButton(row, 84, "禁用", "secondary")
        row.delete = theme:CreateButton(row, 84, "删除", "danger")
        tab.rows[i] = row
    end
    tab.pageGroup = addGroup(theme, tab, "分页")
    tab.prev = addButton(theme, tab.pageGroup, "上一页", function()
        local state = ui(); YBP:SetFootprintListOffset((state and state.footprintListOffset or 0) - 6)
    end)
    tab.next = addButton(theme, tab.pageGroup, "下一页", function()
        local state = ui(); YBP:SetFootprintListOffset((state and state.footprintListOffset or 0) + 6)
    end)
    tab.page = makeText(theme, tab.pageGroup.frame, theme.Font.assist, theme.Colors.muted)
end

local function buildExport(theme, tab)
    local group = addGroup(theme, tab, "参数导出", "先选择片段，再点全选复制；编辑文本不会修改路线数据。")
    for _, spec in ipairs({ { "参数当前", "current" }, { "脚印片段", "footprints" },
        { "融合片段", "resolved" }, { "参数本图", "map" }, { "本图改动", "mapFusion" } }) do
        local label, key = spec[1], spec[2]
        local button = addButton(theme, group, label, function()
            YBP:SetDebugExportView(key)
            if view and view.exportBox then view.exportBox:SetText(YBP:GetDebugExportText(key) or "") end
        end)
        button.exportKey = key
    end
    addButton(theme, group, "全选", function()
        if view and view.exportBox then view.exportBox:SetFocus(); view.exportBox:HighlightText() end
    end, "default")
    local boxFrame = CreateFrame("Frame", nil, tab.frame, "BackdropTemplate")
    boxFrame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    boxFrame:SetBackdropColor(unpack(theme.Colors.bg))
    boxFrame:SetBackdropBorderColor(unpack(theme.Colors.lineSoft))
    local scroll = CreateFrame("ScrollFrame", nil, boxFrame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 8, -8)
    scroll:SetPoint("BOTTOMRIGHT", -28, 8)
    local box = CreateFrame("EditBox", nil, scroll)
    box:SetMultiLine(true)
    box:SetAutoFocus(false)
    box:SetFontObject("GameFontHighlightSmall")
    box:SetWidth(500)
    box:SetHeight(700)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnTextChanged", function(self) self:GetParent():UpdateScrollChildRect() end)
    scroll:SetScrollChild(box)
    tab.boxFrame, tab.box = boxFrame, box
end

local function layoutGroup(group, width, y, isFootprintList, isPage)
    local frame = group.frame
    frame:ClearAllPoints(); frame:SetPoint("TOPLEFT", 8, -y); frame:SetWidth(width - 16)
    group.title:ClearAllPoints(); group.title:SetPoint("TOPLEFT", 12, -10)
    group.title:SetWidth(width - 40); group.title:SetHeight(22)
    local top = 38
    if group.note then
        group.note:ClearAllPoints(); group.note:SetPoint("TOPLEFT", 12, -top)
        group.note:SetWidth(width - 40); group.note:SetHeight(28)
        top = top + 32
    end
    local rows, currentRow = {}, { buttons = {}, widths = {}, minimumTotal = 0 }
    local availableWidth = width - 40
    for _, button in ipairs(group.buttons) do
        local label = button.layoutLabel or ""
        local _, characters = label:gsub("[^\128-\193]", "")
        local measured = group.theme.MeasureText and group.theme:MeasureText(group.theme.Font.body, label)
            or characters * (group.theme.Font.body or 16)
        local minimum = math.min(BUTTON_MAX_WIDTH, math.max(BUTTON_MIN_WIDTH, math.ceil(measured + 20)))
        local count = #currentRow.buttons
        if count == MAX_BUTTONS_PER_ROW
            or (count > 0 and currentRow.minimumTotal + minimum + count * BUTTON_GAP > availableWidth) then
            rows[#rows + 1] = currentRow
            currentRow = { buttons = {}, widths = {}, minimumTotal = 0 }
        end
        currentRow.buttons[#currentRow.buttons + 1] = button
        currentRow.widths[#currentRow.widths + 1] = minimum
        currentRow.minimumTotal = currentRow.minimumTotal + minimum
    end
    if #currentRow.buttons > 0 then rows[#rows + 1] = currentRow end
    for rowIndex, row in ipairs(rows) do
        local remaining = math.max(0, availableWidth - row.minimumTotal - (#row.buttons - 1) * BUTTON_GAP)
        while remaining > 0 do
            local growable = 0
            for _, value in ipairs(row.widths) do
                if value < BUTTON_MAX_WIDTH then growable = growable + 1 end
            end
            if growable == 0 then break end
            local share = math.max(1, math.floor(remaining / growable))
            for index, value in ipairs(row.widths) do
                if value < BUTTON_MAX_WIDTH and remaining > 0 then
                    local gain = math.min(share, BUTTON_MAX_WIDTH - value, remaining)
                    row.widths[index] = value + gain
                    remaining = remaining - gain
                end
            end
        end
        local x = 12
        for index, button in ipairs(row.buttons) do
            button:ClearAllPoints(); button:SetPoint("TOPLEFT", x, -top - (rowIndex - 1) * 38)
            button:SetWidth(row.widths[index])
            x = x + row.widths[index] + BUTTON_GAP
        end
    end
    top = top + #rows * 38
    if group.detail then
        group.detail:ClearAllPoints(); group.detail:SetPoint("TOPLEFT", 12, -top)
        group.detail:SetWidth(width - 40); group.detail:SetHeight(56)
        top = top + 58
    end
    if isFootprintList then
        for index, row in ipairs(isFootprintList.rows) do
            row:ClearAllPoints(); row:SetPoint("TOPLEFT", 12, -top - (index - 1) * 40)
            row:SetWidth(width - 40); row:SetHeight(36)
            row.label:ClearAllPoints(); row.label:SetPoint("TOPLEFT", 8, -8)
            row.label:SetPoint("RIGHT", row.toggle, "LEFT", -8, 0); row.label:SetHeight(24)
            row.delete:ClearAllPoints(); row.delete:SetPoint("RIGHT", -8, 0)
            row.toggle:ClearAllPoints(); row.toggle:SetPoint("RIGHT", row.delete, "LEFT", -8, 0)
        end
        top = top + 6 * 40
    end
    if isPage then
        isPage.page:ClearAllPoints(); isPage.page:SetPoint("TOPLEFT", 12, -top)
        isPage.page:SetWidth(width - 40); isPage.page:SetHeight(22)
        top = top + 24
    end
    frame:SetHeight(top + 10)
    return y + top + 22
end

local function layout(panel)
    local width = math.max(580, panel:GetWidth() or 580)
    local hasIcon = panel.petIconFrame and panel.petIconFrame:IsShown()
    -- Share the content cards' x=16 and right=width-24 guide lines.
    local headerLeft, headerRight, headerTop, headerBottom = 16, 24, 8, 12
    local controlWidth = width < 700 and 96 or 112
    local buttonHeight = panel.previous:GetHeight()
    local countHeight = 22
    local controlHeight = buttonHeight * 2 + 4 * 2 + countHeight
    local summaryHeight = width < 700 and (hasIcon and 168 or 120)
        or width < 850 and (hasIcon and 118 or 92) or 92
    -- One shared top/bottom rectangle encloses the icon, parameters and
    -- route switcher.  Wider/narrower summaries only change its height.
    local headerContentHeight = math.max(controlHeight, summaryHeight)
    local iconSize = headerContentHeight
    local controlGap = (headerContentHeight - buttonHeight * 2 - countHeight) / 2
    local tabsOffset = headerTop + headerContentHeight + headerBottom
    local groupOffset = tabsOffset + 48
    panel.petIconFrame:ClearAllPoints()
    panel.petIconFrame:SetSize(iconSize, iconSize)
    panel.petIconFrame:SetPoint("TOPLEFT", headerLeft, -headerTop)
    panel.summary:ClearAllPoints()
    if hasIcon then
        panel.summary:SetPoint("TOPLEFT", headerLeft + iconSize + 8, -headerTop)
    else
        panel.summary:SetPoint("TOPLEFT", headerLeft, -headerTop)
    end
    local summaryLeft = hasIcon and (headerLeft + iconSize + 8) or headerLeft
    local controlLeft = width - headerRight - controlWidth
    panel.summary:SetWidth(controlLeft - 12 - summaryLeft)
    panel.summary:SetHeight(headerContentHeight)
    panel.previous:ClearAllPoints()
    panel.previous:SetPoint("TOPLEFT", controlLeft, -headerTop)
    panel.previous:SetWidth(controlWidth)
    panel.next:ClearAllPoints()
    panel.next:SetPoint("TOPLEFT", controlLeft, -headerTop - buttonHeight - controlGap)
    panel.next:SetWidth(controlWidth)
    panel.routeCount:ClearAllPoints()
    panel.routeCount:SetPoint("TOPLEFT", controlLeft, -headerTop - headerContentHeight + countHeight)
    panel.routeCount:SetWidth(controlWidth)
    panel.routeCount:SetHeight(countHeight)
    -- Keep the tab band stable when Core's dynamic scrollbar disappears on a
    -- shorter tab, while reserving only the actual gutter rather than a
    -- second business-page inset.
    local tabBandWidth = width
    local content = panel:GetParent()
    local scroll = content and content:GetParent()
    local page = scroll and scroll:GetParent()
    if page and page.GetWidth then
        local stableViewportWidth = (page:GetWidth() or 0) - 32
        if stableViewportWidth > 0 then tabBandWidth = math.min(width, stableViewportWidth) end
    end
    -- The cards begin at x=16 and end at width-24.  Use that same span for
    -- the four equal tabs; fractional frame widths avoid a 1–3px remainder.
    local tabWidth = (tabBandWidth - 40 - 3 * 8) / 4
    for index, spec in ipairs(tabs) do
        local button = panel.tabButtons[spec[1]]
        button:ClearAllPoints(); button:SetPoint("TOPLEFT", 16 + (index - 1) * (tabWidth + 8), -tabsOffset)
        button:SetWidth(tabWidth)
    end
    local active = YBP:GetActiveDebugTab()
    for key, tab in pairs(panel.tabs) do
        tab.frame:ClearAllPoints(); tab.frame:SetPoint("TOPLEFT", 8, -groupOffset)
        tab.frame:SetWidth(width - 24)
        tab.frame:SetShown(key == active)
        local y = 0
        for index, group in ipairs(tab.groups) do
            y = layoutGroup(group, width - 24, y,
                key == "footprints" and index == 2 and tab or nil,
                key == "footprints" and index == 3 and tab or nil)
        end
        if tab.boxFrame then
            tab.boxFrame:ClearAllPoints(); tab.boxFrame:SetPoint("TOPLEFT", 8, -y)
            tab.boxFrame:SetSize(width - 40, 320)
            tab.box:SetWidth(width - 80)
            y = y + 332
        end
        tab.frame:SetHeight(y)
    end
    panel:SetHeight(groupOffset + (panel.tabs[active] and panel.tabs[active].frame:GetHeight() or 360) + 16)
end

local function update(panel)
    if not panel or not panel:IsShown() then return end
    local active = YBP:GetActiveDebugTab()
    for key, button in pairs(panel.tabButtons) do
        button:SetState(key == active and "selected" or "default")
    end
    local ids = YBP:GetDebugPetIDsForCurrentMap() or {}
    local id = YBP:GetSelectedDebugPetID()
    local mapID = YBP.GetDebugContextMapID and YBP:GetDebugContextMapID()
        or YBP.GetCurrentWorldMapID and YBP:GetCurrentWorldMapID() or nil
    local pet = id and ns.pets and ns.pets[id]
    local tooltipData = id and ns.routeNodeTooltips and ns.routeNodeTooltips[id]
    panel.petIconFrame:SetShown(id ~= nil)
    if id then
        panel.petIcon:SetTexture((tooltipData and (tooltipData.imageTexture or tooltipData.iconTexture))
            or "Interface\\Icons\\Ability_Tracking")
    end
    local transform = id and YBP:GetResolvedTransform(id)
    local minimap = id and YBP:GetDebugMinimapTransform(id)
    local node = id and YBP.GetResolvedRouteNodes and YBP:GetResolvedRouteNodes(id)
    local start = node and node[1]
    local state = ui()
    local step = state and state.stepMove == presets.fine[1] and "细"
        or state and state.stepMove == presets.coarse[1] and "粗" or "中"
    local index = id and YBP:GetPetIndexInCurrentMap(id) or 0
    panel.summary:SetText(string.format(
        "地图  %s%s    ·    宠物  %s%s\n位置  X %s  /  Y %s    缩放 %s [%s]    线宽 %s    透明 %s\n横缩 %s  /  竖缩 %s    ·    起点 X %s  /  Y %s  /  大小 %s\n小图  X %s  /  Y %s    缩放 %s    横缩 %s  /  竖缩 %s    线宽 %s",
        pet and pet.zone or "—", mapID and (" [" .. mapID .. "]") or "",
        pet and (pet.name or pet.nameEN) or "—", id and (" [" .. id .. "]") or "",
        fmt(transform and transform.offsetX), fmt(transform and transform.offsetY), fmt(transform and transform.scale), step,
        fmt(id and YBP:GetDebugRouteThickness()), fmt(transform and transform.opacity),
        fmt(transform and transform.scaleX), fmt(transform and transform.scaleY),
        fmt(start and start.normalizedX), fmt(start and start.normalizedY), fmt(start and start.nodeScale),
        fmt(minimap and minimap.offsetX), fmt(minimap and minimap.offsetY), fmt(minimap and minimap.scale),
        fmt(minimap and minimap.scaleX), fmt(minimap and minimap.scaleY), fmt(minimap and minimap.lineThickness)))
    panel.routeCount:SetText(string.format("当前路线  %d / %d", index, #ids))
    panel.previous:SetEnabled(#ids > 0); panel.next:SetEnabled(#ids > 0)

    for _, group in ipairs(panel.tabs.calibrate.groups) do
        for _, button in ipairs(group.buttons) do
            if button.preset then button:SetState(state and state.stepMove == presets[button.preset][1] and "selected" or "default") end
        end
    end
    local display = YBP.GetRouteDisplaySettings and YBP:GetRouteDisplaySettings() or {}
    for _, group in ipairs(panel.tabs.fusion.groups) do
        for _, button in ipairs(group.buttons) do
            if button.settingKey then
                local enabled = display[button.settingKey]
                button.layoutLabel = (enabled and "[开] " or "[关] ") .. button.baseLabel
                button:SetText(button.layoutLabel)
                button:SetState(enabled and "selected" or "default")
            end
        end
        if group.autoButton and YBP.IsRouteAutoResolveEnabled then
            local enabled = YBP:IsRouteAutoResolveEnabled()
            group.autoButton.layoutLabel = (enabled and "[开] " or "[关] ") .. "自动重算"
            group.autoButton:SetText(group.autoButton.layoutLabel)
            group.autoButton:SetState(enabled and "selected" or "default")
        end
        if group.detail then
            local settings = YBP.GetRouteVisualSettings and YBP:GetRouteVisualSettings() or {}
            local resolved = id and YBP.GetResolvedRoute and YBP:GetResolvedRoute(id)
            group.detail:SetText(string.format(
                "融合段 %d    状态 %s\n主线宽 %s    参考宽 %s    点位密度 %s    脚印大小 %s    脚印透明 %s    影响弧长 %s    小图近点 %s",
                resolved and #(resolved.segments or {}) or 0, resolved and (resolved.resolvedAt or "已生成") or "未生成",
                fmt(settings.resolvedThickness), fmt(settings.referenceThickness), fmt(settings.routeDensity),
                fmt(settings.footprintSize), fmt(settings.footprintAlpha), fmt(settings.footprintInfluenceArc),
                fmt(settings.minimapNearbyPointLimit)))
        end
    end

    local tab = panel.tabs.footprints
    local store = id and YBP.GetFootprintStore and YBP:GetFootprintStore(id)
    local points = store and store.points or {}
    local offset = math.min(state and state.footprintListOffset or 0, math.max(0, #points - 6))
    if state then state.footprintListOffset = offset end
    for rowIndex, row in ipairs(tab.rows) do
        local pointIndex = offset + rowIndex
        local point = points[pointIndex]
        row:SetShown(point ~= nil)
        if point then
            row.label:SetText(string.format("#%d [%s] X %s  Y %s%s", pointIndex,
                point.enabled == false and "关" or "开", fmt(point.x), fmt(point.y),
                point.note and point.note ~= "" and ("  " .. point.note) or ""))
            row.toggle:SetText(point.enabled == false and "启用" or "禁用")
            row.toggle:SetScript("OnClick", function()
                YBP:SetFootprintAnchorEnabled(id, pointIndex, point.enabled == false)
                YBP:RefreshDebugPanel()
            end)
            row.delete:SetScript("OnClick", function()
                YBP:ConfirmDebugAction("确定删除此脚印点吗？", function()
                    YBP:RemoveFootprintAnchor(id, pointIndex)
                    YBP:RefreshDebugPanel()
                end)
            end)
        end
    end
    local pages = #points == 0 and 0 or math.ceil(#points / 6)
    tab.page:SetText(string.format("共 %d 点    ·    第 %d / %d 页", #points,
        #points == 0 and 0 or math.floor(offset / 6) + 1, pages))
    tab.prev:SetEnabled(offset > 0)
    tab.next:SetEnabled(offset < math.max(0, #points - 6))
    for _, button in ipairs(panel.tabs.export.groups[1].buttons) do
        if button.exportKey then button:SetState(button.exportKey == YBP:GetDebugExportView() and "selected" or "default") end
    end
    if active == "export" and panel.lastExportID ~= id then
        panel.tabs.export.box:SetText(YBP:GetDebugExportText(YBP:GetDebugExportView()) or "")
        panel.lastExportID = id
    end
    layout(panel)
    local content = panel:GetParent()
    if content then
        content:SetHeight(panel:GetHeight())
        local scroll = content:GetParent()
        if scroll and scroll.SetContentHeight then scroll:SetContentHeight(panel:GetHeight()) end
    end
end

function YBP:CreateCoreDebugPanel(parent)
    if view and view:GetParent() == parent then return view end
    local core = _G.YiboCore
    local theme = core and core.UITheme
    if not theme then return nil end
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetPoint("TOPLEFT", parent, "TOPLEFT")
    panel:SetWidth(math.max(580, parent:GetWidth() or 580))
    panel.petIconFrame = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    panel.petIconFrame:SetSize(52, 52)
    panel.petIconFrame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    panel.petIconFrame:SetBackdropColor(unpack(theme.Colors.panel))
    panel.petIconFrame:SetBackdropBorderColor(unpack(theme.Colors.lineSoft))
    panel.petIcon = panel.petIconFrame:CreateTexture(nil, "ARTWORK")
    panel.petIcon:SetPoint("TOPLEFT", 2, -2)
    panel.petIcon:SetPoint("BOTTOMRIGHT", -2, 2)
    panel.summary = makeText(theme, panel, theme.Font.assist, theme.Colors.text)
    panel.summary:SetJustifyV("MIDDLE")
    panel.previous = theme:CreateButton(panel, 90, "上一条", "secondary")
    panel.previous:SetScript("OnClick", function() cycleRoute(-1) end)
    panel.next = theme:CreateButton(panel, 90, "下一条", "secondary")
    panel.next:SetScript("OnClick", function() cycleRoute(1) end)
    panel.routeCount = makeText(theme, panel, theme.Font.assist, theme.Colors.muted)
    panel.routeCount:SetJustifyH("CENTER")
    makeTabs(theme, panel)
    buildCalibrate(theme, panel.tabs.calibrate)
    buildFusion(theme, panel.tabs.fusion)
    buildFootprints(theme, panel.tabs.footprints)
    buildExport(theme, panel.tabs.export)
    view = panel
    layout(panel)
    update(panel)
    return panel
end

function YBP:RefreshDebugPanel()
    if view and view:IsShown() then update(view) end
end
