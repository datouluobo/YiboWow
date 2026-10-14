local addonName, ns = ...
local T = ns.Text
local YBP = _G.YiboBeastPaths

-- The calibrator owns the saved data and actions.  This file owns only the
-- Core-hosted presentation; the legacy UIPanelButtonTemplate panel is never
-- constructed by the Core page.
local view
local tabs = { { "calibrate", "TAB_CALIBRATE" }, { "fusion", "TAB_FUSION" },
    { "footprints", "TAB_FOOTPRINTS" }, { "export", "TAB_EXPORT" } }
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
        local key, label = spec[1], T(spec[2])
        local button = theme:CreateButton(panel, 120, label, "secondary")
        button:SetScript("OnClick", function() YBP:SetActiveDebugTab(key) end)
        panel.tabButtons[key] = button
        local frame = CreateFrame("Frame", nil, panel)
        panel.tabs[key] = { frame = frame, groups = {} }
    end
end

local function buildCalibrate(theme, tab)
    local group = addGroup(theme, tab, T("STEPS"), T("STEPS_NOTE"))
    for _, spec in ipairs({ { T("FINE"), "fine" }, { T("MEDIUM"), "medium" }, { T("COARSE"), "coarse" } }) do
        local name, key = spec[1], spec[2]
        local button = addButton(theme, group, name, function()
            local state = ui()
            if state then state.stepMove, state.stepScale = presets[key][1], presets[key][2] end
        end)
        button.preset = key
    end

    group = addGroup(theme, tab, T("WORLD_ROUTE"), T("WORLD_NOTE"))
    addPair(theme, group, T("LEFT"), T("RIGHT"), "offsetX")
    addPair(theme, group, T("UP"), T("DOWN"), "offsetY")
    addPair(theme, group, T("SMALLER"), T("LARGER"), "scale")
    addPair(theme, group, T("NARROWER"), T("WIDER"), "scaleX")
    addPair(theme, group, T("SHORTER"), T("TALLER"), "scaleY")
    addButton(theme, group, T("THINNER"), function() YBP:AdjustDebugRouteThickness(-0.10) end)
    addButton(theme, group, T("THICKER"), function() YBP:AdjustDebugRouteThickness(0.10) end)
    addButton(theme, group, T("FADE"), function() current(function(id) YBP:AdjustDebugValue(id, "opacity", -0.05) end) end)
    addButton(theme, group, T("OPAQUE"), function() current(function(id) YBP:AdjustDebugValue(id, "opacity", 0.05) end) end)

    group = addGroup(theme, tab, T("START_NODE"), T("START_NOTE"))
    addPair(theme, group, T("NODE_LEFT"), T("NODE_RIGHT"), "nodeX")
    addPair(theme, group, T("NODE_UP"), T("NODE_DOWN"), "nodeY")
    addPair(theme, group, T("NODE_SMALL"), T("NODE_LARGE"), "nodeScale")

    group = addGroup(theme, tab, T("MINIMAP_ROUTE"), T("MINIMAP_NOTE"))
    addPair(theme, group, T("MM_LEFT"), T("MM_RIGHT"), "mmX")
    addPair(theme, group, T("MM_UP"), T("MM_DOWN"), "mmY")
    addPair(theme, group, T("MM_SMALL"), T("MM_LARGE"), "mmScale")
    addPair(theme, group, T("MM_NARROW"), T("MM_WIDE"), "mmScaleX")
    addPair(theme, group, T("MM_SHORT"), T("MM_TALL"), "mmScaleY")
    addPair(theme, group, T("MM_THIN"), T("MM_THICK"), "mmThickness")
    addButton(theme, group, T("MM_RESET"), function()
        confirm(T("MM_RESET_CONFIRM"), function(id) YBP:ResetDebugMinimapTransform(id) end)
    end, "danger")

    group = addGroup(theme, tab, T("CURRENT_ROUTE"), T("CURRENT_NOTE"))
    addButton(theme, group, T("SAVE"), function()
        current(function(id)
            YBP:EnsureDebugTransform(id)
            YBP:EnsureDebugRouteNode(id, "start")
            local savedReference = YBP:SaveCurrentReferenceDisplayTransform(id)
            print(string.format(T("SAVED"),
                id, savedReference and T("REFERENCE") or T("ROUTE_START")))
        end)
    end, "default")
    addButton(theme, group, T("RESET"), function()
        confirm(T("RESET_CONFIRM"), function(id)
            YBP:ResetDebugTransform(id)
            YBP:ResetDebugMinimapTransform(id)
            YBP:ResetDebugRouteNode(id, "start")
        end)
    end, "danger")
end

local function buildFusion(theme, tab)
    local group = addGroup(theme, tab, T("RECALCULATE"), T("RECALCULATE_NOTE"))
    addButton(theme, group, T("RECALCULATE_CURRENT"), function()
        current(function(id) if YBP.ResolveRouteForPet then YBP:ResolveRouteForPet(id) end end)
    end, "default")
    addButton(theme, group, T("RECALCULATE_MAP"), function()
        local mapID = YBP.GetDebugContextMapID and YBP:GetDebugContextMapID() or YBP:GetCurrentWorldMapID()
        if mapID and YBP.ResolveRoutesForMap then YBP:ResolveRoutesForMap(mapID) end
    end)
    group = addGroup(theme, tab, T("LAYERS"), T("LAYERS_NOTE"))
    for _, spec in ipairs({ { T("RESOLVED"), "showResolved" }, { T("LEGACY"), "showLegacyOverlay" },
        { T("REFERENCE"), "showReference" }, { T("FOOTPRINT_LAYER"), "showFootprints" } }) do
        local label, key = spec[1], spec[2]
        local button = addButton(theme, group, label, function()
            local settings = YBP.GetRouteDisplaySettings and YBP:GetRouteDisplaySettings()
            if settings and YBP.SetRouteDisplaySetting then YBP:SetRouteDisplaySetting(key, not settings[key]) end
        end)
        button.settingKey, button.baseLabel = key, label
    end
    group.autoButton = addButton(theme, group, T("AUTO"), function()
        if YBP.SetRouteAutoResolveEnabled then
            YBP:SetRouteAutoResolveEnabled(not YBP:IsRouteAutoResolveEnabled())
        end
    end)
    group = addGroup(theme, tab, T("PRESETS"), T("PRESETS_NOTE"))
    addButton(theme, group, T("ALL"), function() if YBP.ApplyRouteDisplayPreset then YBP:ApplyRouteDisplayPreset("all") end end)
    addButton(theme, group, T("RESOLVED_ONLY"), function() if YBP.ApplyRouteDisplayPreset then YBP:ApplyRouteDisplayPreset("resolvedOnly") end end)
    addButton(theme, group, T("RESET_DISPLAY"), function()
        if YBP.ApplyRouteDisplayPreset then YBP:ApplyRouteDisplayPreset("default") end
        if YBP.ResetRouteVisualSettings then YBP:ResetRouteVisualSettings() end
    end)
    addButton(theme, group, T("EXPORT_FUSION"), function()
        YBP:SetActiveDebugTab("export")
        if view and view.exportBox then view.exportBox:SetText(YBP:ExportCurrentRouteFusionSnapshot() or "") end
    end, "default")
    addButton(theme, group, T("RESET_DETAILS"), function() if YBP.ResetRouteVisualSettings then YBP:ResetRouteVisualSettings() end end)

    group = addGroup(theme, tab, T("DETAILS"), T("DETAILS_NOTE"))
    for _, spec in ipairs({
        { T("MAIN_THIN"), "resolvedThickness", -0.5, 1, 8, 1 }, { T("MAIN_THICK"), "resolvedThickness", 0.5, 1, 8, 1 },
        { T("FOOT_SMALL"), "footprintSize", -1, 4, 24, 0 }, { T("FOOT_LARGE"), "footprintSize", 1, 4, 24, 0 },
        { T("FOOT_FADE"), "footprintAlpha", -0.05, 0.15, 1, 2 }, { T("FOOT_BRIGHT"), "footprintAlpha", 0.05, 0.15, 1, 2 },
        { T("REF_THIN"), "referenceThickness", -0.5, 1, 8, 1 }, { T("REF_THICK"), "referenceThickness", 0.5, 1, 8, 1 },
        { T("SPARSE"), "routeDensity", -1, 1, 8, 0 }, { T("DENSE"), "routeDensity", 1, 1, 8, 0 },
        { T("MM_FEWER"), "minimapNearbyPointLimit", -1, 0, 20, 0 },
        { T("MM_MORE"), "minimapNearbyPointLimit", 1, 0, 20, 0 },
    }) do
        local label, key, delta, low, high, decimals = unpack(spec)
        addButton(theme, group, label, function() visual(key, delta, low, high, decimals) end)
    end
    group = addGroup(theme, tab, T("FUSION_DETAILS"))
    group.detail = makeText(theme, group.frame, theme.Font.assist, theme.Colors.muted)
end

local function buildFootprints(theme, tab)
    local group = addGroup(theme, tab, T("CAPTURE"), T("CAPTURE_NOTE"))
    addButton(theme, group, T("RECORD"), function()
        local _, message = YBP:CaptureCurrentFootprintForSelectedPet()
        if message then print(T("DEBUG_PREFIX") .. message) end
    end, "default")
    addButton(theme, group, T("ARC_SHORT"), function() visual("footprintInfluenceArc", -0.1, 0.5, 2.5, 1) end)
    addButton(theme, group, T("ARC_LONG"), function() visual("footprintInfluenceArc", 0.1, 0.5, 2.5, 1) end)
    addButton(theme, group, T("DELETE_LAST"), function()
        if YBP.RemoveLastFootprintAnchor then
            confirm(T("DELETE_LAST_CONFIRM"), function(id) YBP:RemoveLastFootprintAnchor(id) end)
        end
    end, "danger")
    addButton(theme, group, T("CLEAR"), function()
        if YBP.ClearFootprintAnchors then
            confirm(T("CLEAR_CONFIRM"), function(id) YBP:ClearFootprintAnchors(id) end)
        end
    end, "danger")
    group = addGroup(theme, tab, T("FOOTPRINT_LIST"), T("FOOTPRINT_NOTE"))
    tab.rows = {}
    for i = 1, 6 do
        local row = CreateFrame("Frame", nil, group.frame, "BackdropTemplate")
        row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
        row:SetBackdropColor(unpack(theme.Colors.row))
        row.label = makeText(theme, row, theme.Font.assist, theme.Colors.text)
        row.toggle = theme:CreateButton(row, 84, T("DISABLE"), "secondary")
        row.delete = theme:CreateButton(row, 84, T("DELETE"), "danger")
        tab.rows[i] = row
    end
    tab.pageGroup = addGroup(theme, tab, T("PAGINATION"))
    tab.prev = addButton(theme, tab.pageGroup, T("PREVIOUS_PAGE"), function()
        local state = ui(); YBP:SetFootprintListOffset((state and state.footprintListOffset or 0) - 6)
    end)
    tab.next = addButton(theme, tab.pageGroup, T("NEXT_PAGE"), function()
        local state = ui(); YBP:SetFootprintListOffset((state and state.footprintListOffset or 0) + 6)
    end)
    tab.page = makeText(theme, tab.pageGroup.frame, theme.Font.assist, theme.Colors.muted)
end

local function buildExport(theme, tab)
    local group = addGroup(theme, tab, T("EXPORT_PARAMS"), T("EXPORT_NOTE"))
    for _, spec in ipairs({ { T("EXPORT_CURRENT"), "current" }, { T("EXPORT_FOOT"), "footprints" },
        { T("EXPORT_RESOLVED"), "resolved" }, { T("EXPORT_MAP"), "map" }, { T("EXPORT_MAP_FUSION"), "mapFusion" } }) do
        local label, key = spec[1], spec[2]
        local button = addButton(theme, group, label, function()
            YBP:SetDebugExportView(key)
            if view and view.exportBox then view.exportBox:SetText(YBP:GetDebugExportText(key) or "") end
        end)
        button.exportKey = key
    end
    addButton(theme, group, T("SELECT_ALL"), function()
        if view and view.exportBox then view.exportBox:SetFocus(); view.exportBox:HighlightText() end
    end, "default")
    local boxFrame = CreateFrame("Frame", nil, tab.frame, "BackdropTemplate")
    boxFrame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    boxFrame:SetBackdropColor(unpack(theme.Colors.bg))
    boxFrame:SetBackdropBorderColor(unpack(theme.Colors.lineSoft))
    local scroll = CreateFrame("ScrollFrame", nil, boxFrame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 8, -8)
    scroll:SetPoint("BOTTOMRIGHT", -28, 8)
    local box = theme:CreateInput(scroll, { width = 500, height = 700, maxLetters = 0 })
    box:SetMultiLine(true)
    -- Unlimited Lua snippets; Enter inserts a newline instead of submitting.
    -- Keep Core's IME, Escape and hide/focus lifecycle intact.
    box:SetScript("OnEnterPressed", nil)
    box:HookScript("OnTextChanged", function(self) self:GetParent():UpdateScrollChildRect() end)
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
        group.note:SetWidth(width - 40)
        local height = math.max(28, (group.note:GetStringHeight() or 28) + 4)
        group.note:SetHeight(height)
        top = top + height + 4
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
        group.detail:SetWidth(width - 40)
        local height = math.max(56, (group.detail:GetStringHeight() or 56) + 4)
        group.detail:SetHeight(height)
        top = top + height + 2
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
    local theme = _G.YiboCore.UITheme
    if theme.MeasureText then
        controlWidth = math.max(controlWidth, theme:MeasureText(theme.Font.body, T("PREVIOUS_ROUTE")) + 20,
            theme:MeasureText(theme.Font.body, T("NEXT_ROUTE")) + 20)
    end
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
    local step = state and state.stepMove == presets.fine[1] and T("STEP_FINE")
        or state and state.stepMove == presets.coarse[1] and T("STEP_COARSE") or T("STEP_MEDIUM")
    local index = id and YBP:GetPetIndexInCurrentMap(id) or 0
    panel.summary:SetText(string.format(
        T("SUMMARY"),
        pet and pet.zone or "—", mapID and (" [" .. mapID .. "]") or "",
        pet and (pet.name or pet.nameEN) or "—", id and (" [" .. id .. "]") or "",
        fmt(transform and transform.offsetX), fmt(transform and transform.offsetY), fmt(transform and transform.scale), step,
        fmt(id and YBP:GetDebugRouteThickness()), fmt(transform and transform.opacity),
        fmt(transform and transform.scaleX), fmt(transform and transform.scaleY),
        fmt(start and start.normalizedX), fmt(start and start.normalizedY), fmt(start and start.nodeScale),
        fmt(minimap and minimap.offsetX), fmt(minimap and minimap.offsetY), fmt(minimap and minimap.scale),
        fmt(minimap and minimap.scaleX), fmt(minimap and minimap.scaleY), fmt(minimap and minimap.lineThickness)))
    panel.routeCount:SetText(string.format(T("ROUTE_COUNT"), index, #ids))
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
                button.layoutLabel = (enabled and T("ON_PREFIX") or T("OFF_PREFIX")) .. button.baseLabel
                button:SetText(button.layoutLabel)
                button:SetState(enabled and "selected" or "default")
            end
        end
        if group.autoButton and YBP.IsRouteAutoResolveEnabled then
            local enabled = YBP:IsRouteAutoResolveEnabled()
            group.autoButton.layoutLabel = (enabled and T("ON_PREFIX") or T("OFF_PREFIX")) .. T("AUTO")
            group.autoButton:SetText(group.autoButton.layoutLabel)
            group.autoButton:SetState(enabled and "selected" or "default")
        end
        if group.detail then
            local settings = YBP.GetRouteVisualSettings and YBP:GetRouteVisualSettings() or {}
            local resolved = id and YBP.GetResolvedRoute and YBP:GetResolvedRoute(id)
            group.detail:SetText(string.format(
                T("FUSION_SUMMARY"),
                resolved and #(resolved.segments or {}) or 0, resolved and (resolved.resolvedAt or T("GENERATED")) or T("NOT_GENERATED"),
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
                point.enabled == false and T("OFF") or T("ON"), fmt(point.x), fmt(point.y),
                point.note and point.note ~= "" and ("  " .. point.note) or ""))
            row.toggle:SetText(point.enabled == false and T("ENABLE") or T("DISABLE"))
            row.toggle:SetScript("OnClick", function()
                YBP:SetFootprintAnchorEnabled(id, pointIndex, point.enabled == false)
                YBP:RefreshDebugPanel()
            end)
            row.delete:SetScript("OnClick", function()
                YBP:ConfirmDebugAction(T("DELETE_POINT_CONFIRM"), function()
                    YBP:RemoveFootprintAnchor(id, pointIndex)
                    YBP:RefreshDebugPanel()
                end)
            end)
        end
    end
    local pages = #points == 0 and 0 or math.ceil(#points / 6)
    tab.page:SetText(string.format(T("PAGE_COUNT"), #points,
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
    panel.previous = theme:CreateButton(panel, 90, T("PREVIOUS_ROUTE"), "secondary")
    panel.previous:SetScript("OnClick", function() cycleRoute(-1) end)
    panel.next = theme:CreateButton(panel, 90, T("NEXT_ROUTE"), "secondary")
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

function YBP:CancelCoreDebugInteraction()
    if view and view.tabs.export.box then view.tabs.export.box:ClearFocus() end
    if StaticPopup_Hide then StaticPopup_Hide("YIBO_BEAST_PATHS_CONFIRM_DEBUG_ACTION") end
end
