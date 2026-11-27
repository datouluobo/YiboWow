local Addon, Core = _G.YiboReputation, _G.YiboCore
local Theme = Core and Core.UITheme
-- Keep the matrix's measurement contract beside the renderer.  Core uses
-- these values when it chooses the account-window width, so a character is
-- never paged merely because the measurement and the rendered columns drift.
Addon.MatrixColumnLayout = {
    nameWidth = 200,
    minimumNameWidth = 120,
    starWidth = 20,
}

local function Text(parent, size, color, justify) return Theme:CreateText(parent, size, color, justify or "LEFT") end
local function Snapshot(character)
    -- Store returns a defensive deep copy. A matrix refresh consults the
    -- same character many times while building nodes and cells, so retain that
    -- immutable-for-render copy until a reputation update invalidates it.
    Addon._matrixSnapshotCache = Addon._matrixSnapshotCache or {}
    local cached = Addon._matrixSnapshotCache[character.id]
    if cached ~= nil then return cached or nil end
    local snapshot = Addon:GetSnapshot(character.id)
    Addon._matrixSnapshotCache[character.id] = snapshot or false
    return snapshot
end
local function HideMatrixTooltip()
    if GameTooltip and GameTooltip.YiboReputationMatrix then
        GameTooltip:Hide()
        GameTooltip.YiboReputationMatrix = nil
        GameTooltip.YiboReputationMatrixRow = nil
    end
end

local function UpdateMatrixTooltip(row)
    if not (row.tooltipNode and row.tooltipNode.kind == "faction" and row.tooltipColumns) then HideMatrixTooltip(); return end
    -- Compare coordinates in the row's own effective scale.  UIParent's
    -- scale is not necessarily the scale of an account view embedded in a
    -- scaled parent, which could otherwise shift hit testing into a neighbor.
    local scale = (row.GetEffectiveScale and row:GetEffectiveScale()) or (UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
    local cursorX = (GetCursorPosition and GetCursorPosition() or 0) / scale
    local offset = cursorX - (row:GetLeft() or cursorX)
    local columnIndex
    for index = 2, #row.tooltipColumns do
        local column = row.tooltipColumns[index]
        if offset >= column.left and offset < column.left + column.width then columnIndex = index; break end
    end
    -- The game uses one shared GameTooltip.  Only retain the per-row cache
    -- when this exact row still owns that tooltip; otherwise a tooltip left by
    -- another row must be rebuilt even if it happens to be the same column.
    if row.tooltipColumn == columnIndex and GameTooltip.YiboReputationMatrixRow == row and GameTooltip:IsShown() then return end
    row.tooltipColumn = columnIndex
    if not columnIndex then HideMatrixTooltip(); return end
    local display = row.displays[columnIndex - 1]
    if not display or #display.details == 0 then HideMatrixTooltip(); return end
    GameTooltip:SetOwner(row, "ANCHOR_CURSOR")
    GameTooltip:ClearLines()
    GameTooltip:AddLine(row.tooltipNode.title, unpack(Theme.Colors.text))
    for _, line in ipairs(display.details) do
        GameTooltip:AddLine(line, unpack(Theme.Colors.text))
    end
    GameTooltip:Show()
    GameTooltip.YiboReputationMatrix = true
    GameTooltip.YiboReputationMatrixRow = row
end

function Addon:CreateMatrixView(parent)
    parent:SetClipsChildren(true)
    parent.matrixToolbar = CreateFrame("Frame", nil, parent)
    parent.matrixToolbar.filterButtons = {}
    parent.matrixHeader = CreateFrame("Frame", nil, parent)
    parent.matrixHeader:SetClipsChildren(true)
    parent.matrixPreviewFooter = CreateFrame("Frame", nil, parent)
    parent.matrixScroll = Theme:CreateScrollFrame(parent)
    parent.matrixScroll:BindScrollbarGutter(parent.matrixHeader)
    parent.matrixBody = CreateFrame("Frame", nil, parent.matrixScroll)
    parent.matrixScroll:SetScrollChild(parent.matrixBody)
    parent.currentCharacterOutline = Theme:CreateCurrentCharacterOutline(parent)
    parent.matrixScroll:HookScript("OnSizeChanged", function() self:PaintMatrixRows(parent) end)
    parent.matrixRows, parent.matrixHeaders = {}, {}
    parent.matrixEmpty = Text(parent.matrixBody, Theme.Font.body, Theme.Colors.muted)
    parent.matrixScroll:HookScript("OnVerticalScroll", function()
        self:PaintMatrixRows(parent)
    end)
end

function Addon:GetMatrixNodeCache(characters)
    local characterIDs = {}
    for _, character in ipairs(characters or {}) do characterIDs[#characterIDs + 1] = character.id end
    local cacheKey = table.concat(characterIDs, "|") .. ":" .. tostring(self._matrixDataRevision or 0)
    self._matrixNodeCaches = self._matrixNodeCaches or {}
    local nodes = self._matrixNodeCaches[cacheKey]
    if not nodes then
        nodes = self:GetMatrixNodes(characters or {}, Snapshot)
        self._matrixNodeCaches[cacheKey] = nodes
    end
    return nodes
end

local function IsOpen(expanded, node)
    if expanded[node.key] ~= nil then return expanded[node.key] end
    if expanded.__all ~= nil then return expanded.__all == true end
    return node.defaultExpanded == true
end
local function BuildRows(addon, context)
    local settings, expanded = addon:GetSettings(), addon:GetMatrixExpansion()
    local nodes = addon:GetMatrixNodeCache(context.characters or {})
    local selectedRank = not context.preview and settings.matrixRankFilter or "all"
    local sort = not context.preview and settings.matrixSort or "default"
    local compare = selectedRank ~= "all" or (sort ~= "default" and sort ~= "name")
    local current = compare and Core.Characters:GetCurrent({ identityOnly = true })
    local snapshot = current and Snapshot(current)
    local ordered = {}
    for index, id in ipairs(addon:GetMonitoredFactions()) do ordered[id] = index end
    local rows = {}
    local query = context.preview and "" or (settings.matrixSearch or ""):match("^%s*(.-)%s*$"):lower()
    local monitored = context.preview or (settings.matrixFilter or settings.defaultMatrixFilter) == "monitored"
    local filtering = query ~= "" or monitored or selectedRank ~= "all" or sort ~= "default"
    local function Add(node, depth)
        if not filtering then
            rows[#rows + 1] = { node = node, depth = depth }
            if IsOpen(expanded, node) then for _, child in ipairs(node.children) do Add(child, depth + 1) end end
            return
        end
        if node.kind == "faction" and (not monitored or ordered[node.factionID])
            and (query == "" or node.title:lower():find(query, 1, true) or tostring(node.factionID):find(query, 1, true)) then
            local fact = current and addon:GetMatrixCell(snapshot, node, current) or {}
            if selectedRank == "all" or selectedRank == (fact.rank or "unknown") then
                rows[#rows + 1] = { node = node, depth = 0, fact = fact, flat = true }
            end
        end
        for _, child in ipairs(node.children) do Add(child, depth + 1) end
    end
    for _, node in ipairs(nodes) do Add(node, 0) end
    if monitored then
        table.sort(rows, function(a, b)
            local left, right = ordered[a.node.factionID], ordered[b.node.factionID]
            if left == right then return a.node.key < b.node.key end
            return left < right
        end)
    elseif sort ~= "default" then
        local function SortValue(row)
            local fact = row.fact
            if sort == "rank" then return fact.rank end
            if sort == "session" then return fact.session end
            if sort == "progress" then
                if fact.complete then return 1 end
                if fact.current and fact.maximum and fact.maximum > 0 then return fact.current / fact.maximum end
            end
        end
        table.sort(rows, function(a, b)
            local left, right = SortValue(a), SortValue(b)
            if left ~= right then
                if left == nil then return false end
                if right == nil then return true end
                return left > right
            end
            if a.node.title == b.node.title then return a.node.key < b.node.key end
            return a.node.title < b.node.title
        end)
    end
    return rows
end

function Addon:GetMatrixLayout(context)
    local rows, characters = BuildRows(self, context), context.characters or {}
    local fields = {}
    for _, field in ipairs(context.fields or self:GetMatrixFields()) do fields[field.id] = true end
    local labelWidths = {}
    local body = Theme.Font.body
    local function Width(cache, font, text)
        if not text then return 0 end
        if cache[text] == nil then cache[text] = Theme:MeasureText(font, text) end
        return cache[text]
    end
    local starWidth = context.preview and 0 or self.MatrixColumnLayout.starWidth
    local nameWidth = self.MatrixColumnLayout.minimumNameWidth
    local characterWidth = Theme:GetCharacterMatrixColumnWidth(context)
    for _, entry in ipairs(rows) do
        local node = entry.node
        local indent = entry.depth * 8 + (node.icon and 16 or 0) + (#node.children > 0 and not entry.flat and 14 or 0)
        nameWidth = math.max(nameWidth, Width(labelWidths, body, node.title) + indent + starWidth + Theme.Space.xs * 2)
        if node.kind == "faction" then
            for _, character in ipairs(characters) do
                local text = self.Display:ForCell(self:GetMatrixCell(Snapshot(character), node, character), fields, true)
                characterWidth = math.max(characterWidth, Width(labelWidths, body, text)
                    + Theme.Space.xs * 2)
            end
        end
    end
    return rows, fields, math.min(nameWidth, self.MatrixColumnLayout.nameWidth), characterWidth, starWidth
end

function Addon:RefreshMatrixView(parent, context)
    local settings, expanded = self:GetSettings(), self:GetMatrixExpansion()
    local inset = Theme:GetMatrixInsets(context.preview)
    local filter = settings.matrixFilter or settings.defaultMatrixFilter or "all"
    local toolbar = parent.matrixToolbar
    toolbar:ClearAllPoints()
    toolbar:SetPoint("TOPLEFT", parent, "TOPLEFT", inset.left, -inset.top)
    toolbar:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -inset.right, -inset.top)
    if parent.matrixView and (parent.matrixView.context.preview == true) ~= (context.preview == true) then
        parent.matrixScroll:SetVerticalScroll(0)
    end
    toolbar:SetShown(not context.preview)
    local toolbarHeight = 0
    if not context.preview then
        if not toolbar.search then
            local function ChangeFilter(key, value)
                settings[key] = value
                parent.matrixScroll:SetVerticalScroll(0)
                Addon:NotifyChanged()
            end
            local ranks = { { value = "all", label = self:T("MATRIX.ALL_RANKS") } }
            for rank = 1, 8 do ranks[#ranks + 1] = { value = rank, label = self.Display:Standing(rank) } end
            ranks[#ranks + 1] = { value = "unknown", label = self:T("STATE.ATYPICAL") }
            toolbar.rank = Theme:CreateDropdown(toolbar, 108, ranks)
            toolbar.rank:SetValue(settings.matrixRankFilter or "all")
            toolbar.rank:SetOnValueChanged(function(value) ChangeFilter("matrixRankFilter", value) end)
            local sorting = {
                { value = "default", label = self:T("MATRIX.SORT_DEFAULT") },
                { value = "name", label = self:T("MATRIX.SORT_NAME") },
                { value = "rank", label = self:T("MATRIX.SORT_RANK") },
                { value = "progress", label = self:T("MATRIX.SORT_PROGRESS") },
            }
            if self.MatrixExtraFields then
                sorting[#sorting + 1] = { value = "session", label = self:T("MATRIX.SORT_SESSION") }
            end
            toolbar.sort = Theme:CreateDropdown(toolbar, 138, sorting)
            toolbar.sort:SetValue(settings.matrixSort or "default")
            toolbar.sort:SetOnValueChanged(function(value) ChangeFilter("matrixSort", value) end)
            toolbar.search = Theme:CreateInput(toolbar, {
                width = 124, size = "compact", value = settings.matrixSearch,
                placeholder = self:T("MATRIX.SEARCH"), clearable = true,
                OnChanged = function(text, userInput)
                    if userInput then ChangeFilter("matrixSearch", text or "") end
                end,
                clearButtonOptions = { OnClear = function()
                    ChangeFilter("matrixSearch", "")
                end },
            })
        end
        local x, y, rowHeight = 0, 0, Theme.Size.compact
        local toolbarWidth = math.max(1, (context.surfaceAvailableWidth or parent:GetWidth()) - inset.left - inset.right)
        local function PlaceControl(control, width)
            width = math.min(width, toolbarWidth)
            if x > 0 and x + width > toolbarWidth then x, y = 0, y + rowHeight + Theme.Space.xxs end
            control:ClearAllPoints()
            control:SetPoint("TOPLEFT", toolbar, "TOPLEFT", x, -y)
            control:SetSize(width, rowHeight)
            x = x + width + Theme.Space.xxs
        end
        PlaceControl(toolbar.search, 124)
        toolbar.search:SetValue(settings.matrixSearch or "")
        for index, choice in ipairs({ {"all", self:T("MATRIX.ALL")}, {"monitored", self:T("MATRIX.MONITORED")} }) do
            local button = toolbar.filterButtons[index] or Theme:CreateButton(toolbar, 68, choice[2], "secondary")
            toolbar.filterButtons[index] = button
            PlaceControl(button, math.max(48, Theme:MeasureText(Theme.Font.body, choice[2]) + 14))
            button:SetText(choice[2])
            button:SetState(filter == choice[1] and "selected" or "default")
            button:SetScript("OnClick", function() settings.matrixFilter = choice[1]; parent.matrixScroll:SetVerticalScroll(0); Addon:RefreshMatrixView(parent, context) end)
        end
        for index = 3, #toolbar.filterButtons do toolbar.filterButtons[index]:Hide() end
        local function SetAllExpanded(value)
            -- Per-node overrides must not defeat an explicit global command. The
            -- table is tiny compared with the matrix; clearing it is not the
            -- source of the old hitch, which was the full account-page rebuild.
            for key in pairs(expanded) do if key ~= "__all" then expanded[key] = nil end end
            expanded.__all = value
            Addon:RefreshMatrixView(parent, context)
        end
        PlaceControl(toolbar.rank, math.max(80, Theme:MeasureText(Theme.Font.body, toolbar.rank.label:GetText()) + 28))
        PlaceControl(toolbar.sort, math.max(100, Theme:MeasureText(Theme.Font.body, toolbar.sort.label:GetText()) + 28))
        if self.RefreshCurrentReputation then
            local label = self:T("MATRIX.REFRESH")
            toolbar.refresh = toolbar.refresh or Theme:CreateButton(toolbar, 60, label, "secondary")
            PlaceControl(toolbar.refresh, math.max(46, Theme:MeasureText(Theme.Font.body, label) + 14))
            toolbar.refresh:SetScript("OnClick", function() self:RefreshCurrentReputation() end)
        end
        local hasGroups = false
        for _, node in ipairs(self:GetMatrixNodeCache(context.characters or {})) do
            if #node.children > 0 then hasGroups = true; break end
        end
        if hasGroups then
            for _, action in ipairs({ { key = "expand", open = true }, { key = "collapse", open = false } }) do
                local label = self:T(action.open and "MATRIX.EXPAND" or "MATRIX.COLLAPSE")
                local button = toolbar[action.key] or Theme:CreateButton(toolbar, 72, "", "secondary")
                toolbar[action.key] = button
                PlaceControl(button, math.max(60, Theme:MeasureText(Theme.Font.body, label) + 14))
                button:SetText(label)
                button:SetScript("OnClick", function() SetAllExpanded(action.open) end)
                button:Show()
            end
        elseif toolbar.expand then
            toolbar.expand:Hide()
            toolbar.collapse:Hide()
        end
        toolbarHeight = y + rowHeight
        toolbar:SetHeight(toolbarHeight)
    end
    local headerHeight = Theme:GetCharacterHeaderHeight(context)
    local headerTop = context.preview and inset.top or inset.top + toolbarHeight + Theme.Space.xs
    parent.matrixHeader:ClearAllPoints()
    parent.matrixHeader:SetPoint("TOPLEFT", parent, "TOPLEFT", inset.left, -headerTop)
    parent.matrixHeader:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -inset.right, -headerTop)
    parent.matrixHeader:SetHeight(headerHeight)
    parent.matrixScroll:ClearAllPoints()
    parent.matrixScroll:SetPoint("TOPLEFT", parent.matrixHeader, "BOTTOMLEFT", 0, 0)
    local allCharacters = context.characters or {}
    local display, fields, nameWidth, minimumWidth, starWidth = self:GetMatrixLayout(context)
    local rowHeight = self:GetMatrixRowHeight()
    local fixedHeight = headerTop + headerHeight + inset.bottom
    local bodyHeight = #display * rowHeight
    local horizontalInsets = inset.left + inset.right
    local availableWidth = math.max(1, Core.AccountView:GetScrollSurfaceWidth(context, parent, bodyHeight, fixedHeight) - horizontalInsets)
    local footerHeight = self:GetMatrixPreviewFooterHeight(context, availableWidth, nameWidth, minimumWidth)
    if footerHeight > 0 then
        availableWidth = math.max(1, Core.AccountView:GetScrollSurfaceWidth(context, parent, bodyHeight, fixedHeight + footerHeight) - horizontalInsets)
    end
    parent.matrixScroll:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -inset.right, inset.bottom + footerHeight)
    local footer = parent.matrixPreviewFooter
    footer:ClearAllPoints()
    footer:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", inset.left, inset.bottom)
    footer:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -inset.right, inset.bottom)
    footer:SetHeight(Theme.Size.compact)
    footer:SetShown(footerHeight > 0)
    local characterWidth = Core.AccountView:FitRepeatedColumnWidth(availableWidth, nameWidth, #allCharacters,
        minimumWidth + Theme.Space.xs, minimumWidth)
    local surface = context.preview and "preview" or "matrix"
    local characters, pageInfo = Core.AccountView:GetColumnPage("reputation", surface, allCharacters, availableWidth, nameWidth, characterWidth)
    Core.AccountView:UpdateColumnPager(parent, "reputation", surface, pageInfo,
        context.preview and footer or parent.matrixHeader, self:T("MATRIX.CHARACTERS"))
    if pageInfo.pages > 1 then characterWidth = (availableWidth - nameWidth) / pageInfo.capacity end
    local columns = { { title=self:T("MATRIX.REPUTATION"), width=nameWidth } }
    for _, character in ipairs(characters) do columns[#columns + 1] = { width=characterWidth, character=character } end
    local tableWidth, currentColumnX = 0, nil
    local currentCharacter = Core.Characters:GetCurrent({ identityOnly = true })
    local currentColumnHeader
    for index, column in ipairs(columns) do
        local header = parent.matrixHeaders[index] or Theme:CreateMatrixHeader(parent.matrixHeader)
        parent.matrixHeaders[index] = header
        header:ClearAllPoints(); header:SetPoint("TOPLEFT", parent.matrixHeader, "TOPLEFT", tableWidth, 0); header:SetSize(column.width, headerHeight)
        if column.character then
            local snapshot = Snapshot(column.character)
            Theme:SetCharacterHeader(header, column.character, context, { updatedAt=snapshot and snapshot.updatedAt, state=snapshot and snapshot.state or "unsynced", recovery=self:T("PAGE.SNAPSHOT_HINT") })
        else
            Theme:SetMatrixHeader(header, column.title, { height=headerHeight, justify="LEFT", color=Theme.Colors.muted, inset=Theme.Space.xxs+starWidth })
            header:SetScript("OnEnter", nil); header:SetScript("OnLeave", nil)
        end
        if currentCharacter and column.character and column.character.id == currentCharacter.id then currentColumnHeader, currentColumnX = header, tableWidth end
        tableWidth = tableWidth + column.width
    end
    for index = #columns + 1, #parent.matrixHeaders do parent.matrixHeaders[index]:Hide() end
    parent.matrixEmpty:SetPoint("TOPLEFT", parent.matrixBody, "TOPLEFT", Theme.Space.xs, -Theme.Space.xs)
    parent.matrixEmpty:SetText(self:T((context.preview or filter == "monitored") and "MATRIX.NO_WATCHED" or "MATRIX.NO_ROWS"))
    parent.matrixEmpty:SetShown(#display == 0)
    parent.matrixView = { rows = display, context = context, fields = fields, columns = columns, characters = characters,
        rowHeight = rowHeight, tableWidth = tableWidth, starWidth = starWidth, expanded = expanded }
    parent.matrixBody:SetSize(tableWidth, math.max(rowHeight, #display * rowHeight))
    parent.matrixScroll:SetContentHeight(parent.matrixBody:GetHeight())
    self:PaintMatrixRows(parent)
    Theme:UpdateCurrentCharacterColumnOutline(parent.currentCharacterOutline, parent.matrixHeader, parent.matrixScroll, currentColumnX, characterWidth, currentColumnHeader ~= nil)
end

function Addon:PaintMatrixRows(parent)
    local view = parent.matrixView
    if not view then return end
    local display, context, fields, columns, characters = view.rows, view.context, view.fields, view.columns, view.characters
    local rowHeight, tableWidth, starWidth, expanded = view.rowHeight, view.tableWidth, view.starWidth, view.expanded
    local scroll = parent.matrixScroll
    local offset = scroll:GetVerticalScroll()
    local first = math.floor(offset / rowHeight) + 1
    local last = math.min(#display, math.ceil((offset + math.max(rowHeight, scroll:GetHeight())) / rowHeight) + 1)
    local count = math.max(0, last - first + 1)
    for index = 1, count do
        local rowIndex = first + index - 1
        local entry = display[rowIndex]
        local node = entry.node
        local row = parent.matrixRows[index] or CreateFrame("Button", nil, parent.matrixBody, "BackdropTemplate")
        parent.matrixRows[index] = row
        if row.matrixNode ~= node and row.tooltipTracking then
            row.tooltipTracking = false
            HideMatrixTooltip()
        end
        row:SetSize(tableWidth, rowHeight)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", parent.matrixBody, "TOPLEFT", 0, -((rowIndex - 1) * rowHeight))
        row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
        row.matrixNode = node
        Theme:CreatePixelBorder(row, { color = Theme.Colors.matrixLine,
            sides = { top = rowIndex == 1, right = true, bottom = true, left = true } })
        local faction = node.kind == "faction"
        local grouped = #node.children > 0 and not context.preview and not entry.flat
        local shade = node.kind == "expansion" and Theme.Colors.selected
            or (node.kind == "category" and Theme.Colors.toolbar or Theme:GetDataRowColor(rowIndex))
        row:SetBackdropColor(unpack(shade))
        Theme:ApplyDataColumnTints(row, columns, rowHeight)
        row.cells, row.progressBars = row.cells or {}, row.progressBars or {}
        if not row.star then
            row.star = Theme:CreateButton(row, self.MatrixColumnLayout.starWidth, "", "secondary")
            row.star:SetHeight(20)
            row.star:SetPoint("LEFT")
            row.star:EnableMouse(true)
            row.star:RegisterForClicks("LeftButtonUp")
            row.star:SetFrameLevel(row:GetFrameLevel() + 5)
        end
        row.star:SetShown(faction and not context.preview)
        if faction and not context.preview then
            local monitored = self:IsMonitored(node.factionID)
            local canToggle = not self.CanToggleMonitored or self:CanToggleMonitored(node.factionID)
            row.star:SetText(monitored and "\226\152\133" or "\226\152\134")
            row.star:SetState(not canToggle and "disabled" or (monitored and "selected" or "default"))
            row.star:SetScript("OnClick", function()
                if canToggle then self:ToggleMonitored(node.factionID) end
            end)
        end
        local groupPrefix = grouped and (IsOpen(expanded, node) and "- " or "+ ") or ""
        local label = string.rep("  ", entry.depth) .. groupPrefix .. (node.icon and "   " or "") .. node.title
        row.icon = row.icon or row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(14, 14)
        row.icon:ClearAllPoints()
        row.icon:SetPoint("LEFT", row, "LEFT", starWidth + entry.depth * 8 + (grouped and 14 or 0), 0)
        row.icon:SetTexture(node.icon)
        row.icon:SetShown(node.icon ~= nil)
        row:SetScript("OnClick", grouped and function()
            expanded[node.key] = not IsOpen(expanded, node)
            Addon:RefreshMatrixView(parent, context)
        end or nil)
        row.tooltipNode, row.tooltipColumns, row.tooltipColumn, row.displays = node, {}, nil, {}
        local left = 0
        for ci, column in ipairs(columns) do
            row.tooltipColumns[ci] = { left = left, width = column.width }
            local cell = row.cells[ci] or Text(row, Theme.Font.body, Theme.Colors.text, ci == 1 and "LEFT" or "CENTER")
            row.cells[ci] = cell
            local contentWidth = column.width - Theme.Space.xs - (ci == 1 and starWidth or 0)
            cell:ClearAllPoints()
            cell:SetPoint("LEFT", row, "LEFT", left + Theme.Space.xxs + (ci == 1 and starWidth or 0), 0)
            cell:SetWidth(contentWidth)
            cell:SetHeight(rowHeight)
            cell:SetWordWrap(false)
            local character = column.character
            if ci == 1 then
                cell:SetText(label)
            elseif faction and character then
                local value = self.Display:ForCell(self:GetMatrixCell(Snapshot(character), node, character), fields)
                row.displays[ci - 1] = value
                local bar = row.progressBars[ci]
                if not bar then
                    bar = {
                        track = row:CreateTexture(nil, "ARTWORK", nil, 0),
                        base = row:CreateTexture(nil, "ARTWORK", nil, 1),
                        gain = row:CreateTexture(nil, "ARTWORK", nil, 2),
                    }
                    row.progressBars[ci] = bar
                    bar.align = function()
                        local inset = Theme:GetPixelSize(row, 3)
                        local width = math.max(0, bar.width - 2 * inset)
                        local height = math.max(0, row:GetHeight() - 2 * inset)
                        bar.track:ClearAllPoints()
                        bar.track:SetPoint("LEFT", row, "LEFT", bar.left + inset, 0)
                        bar.track:SetSize(width, height)
                        bar.base:ClearAllPoints()
                        bar.gain:ClearAllPoints()
                        bar.base:SetPoint("LEFT", bar.track, "LEFT")
                        bar.base:SetSize(width * bar.previousFraction, height)
                        bar.gain:SetPoint("LEFT", bar.track, "LEFT", width * bar.previousFraction, 0)
                        bar.gain:SetSize(width * (bar.fraction - bar.previousFraction), height)
                    end
                end
                local color = value.color or Theme.Colors.muted
                local background = Theme.Colors.chrome
                bar.left, bar.width = left, column.width
                bar.fraction, bar.previousFraction = value.fraction or 0, value.previousFraction or 0
                Theme:SetPixelAnchor(bar.track, bar.align)
                bar.track:SetColorTexture(background[1] + color[1] * 0.08, background[2] + color[2] * 0.08, background[3] + color[3] * 0.08)
                if value.baseColor then
                    bar.base:SetColorTexture(unpack(value.baseColor))
                else
                    bar.base:SetColorTexture(color[1] * 0.30, color[2] * 0.30, color[3] * 0.30)
                end
                if value.gainColor then
                    bar.gain:SetColorTexture(unpack(value.gainColor))
                else
                    bar.gain:SetColorTexture(color[1] * 0.48, color[2] * 0.48, color[3] * 0.48)
                end
                bar.track:SetShown(value.fraction ~= nil)
                bar.base:SetShown(bar.previousFraction > 0)
                bar.gain:SetShown(bar.fraction > bar.previousFraction)

                local text = value.text
                if value.delta then
                    local withDelta = self:T("FORMAT.CELL_DELTA", text, value.delta)
                    if Theme:MeasureText(Theme.Font.body, withDelta) <= contentWidth - Theme.Space.xxs then text = withDelta end
                end
                cell:SetText(text)
                cell:SetTextColor(unpack(value.muted and Theme.Colors.muted or value.textColor or Theme.Colors.text))
            else
                cell:SetText("")
                local bar = row.progressBars[ci]
                if bar then bar.track:Hide(); bar.base:Hide(); bar.gain:Hide() end
            end
            cell:Show()
            left = left + column.width
        end
        if self.BindMatrixRow and not context.preview then self:BindMatrixRow(row, node, characters)
        elseif row.goalHits then
            for _, hit in ipairs(row.goalHits) do hit:Hide() end
        end
        row:SetScript("OnEnter",function(control)
            control.tooltipTracking=true
            control.tooltipColumn=nil
            control:SetScript("OnUpdate", UpdateMatrixTooltip)
            UpdateMatrixTooltip(control)
        end)
        -- A matrix row is one hit target.  Refresh while the cursor moves
        -- inside it so the tooltip follows the character column instead
        -- of retaining the value from the column first entered.
        row:SetScript("OnUpdate", row.tooltipTracking and UpdateMatrixTooltip or nil)
        row:SetScript("OnLeave",function(control)
            control.tooltipTracking=false
            control:SetScript("OnUpdate", nil)
            control.tooltipColumn=nil
            HideMatrixTooltip()
        end)
        row:SetScript("OnHide", function(control)
            control.tooltipTracking, control.tooltipColumn = false, nil
            control:SetScript("OnUpdate", nil)
            if GameTooltip and GameTooltip.YiboReputationMatrixRow == control then HideMatrixTooltip() end
        end)
        for ci = #columns + 1, #row.cells do
            row.cells[ci]:Hide()
            local bar = row.progressBars[ci]
            if bar then bar.track:Hide(); bar.base:Hide(); bar.gain:Hide() end
        end
        row:Show()
    end
    for index = count + 1, #parent.matrixRows do parent.matrixRows[index]:Hide() end
end

function Addon:GetMatrixRowHeight()
    return Theme.Table.rowHeight
end

function Addon:GetMatrixPreviewFooterHeight(context, width, nameWidth, columnWidth)
    if context.preview and #(context.characters or {}) > 1
        and nameWidth + #context.characters * columnWidth > width + 0.0001 then
        return Theme.Size.compact + Theme.Space.xs
    end
    return 0
end
