local Addon, Core = _G.YiboCurrency, _G.YiboCore
if not (Core and Core.UITheme and Core.UITheme.Table) then return end
local Theme = Core.UITheme
local PAGE_ID = "currency"
local ROW_HEIGHT = Theme.Table.rowHeight

local function Text(parent, justify) return Theme:CreateText(parent, Theme.Font.body, Theme.Colors.text, justify or "LEFT") end
-- Core already applied this page's GetEligibleCharacters rule in BuildContext.
local function Eligible(characters) return characters or {} end
local function DisplayName(character)
    return Core.Characters:FormatName(character, { nameMode = "short", realmMode = "full" }) or Addon:T("UI.UNKNOWN_CHARACTER")
end
local function IconText(entry, size)
    size = size or 16
    return "|T" .. tostring(Addon:GetIcon(entry)) .. ":" .. size .. ":" .. size .. ":0:0|t " .. entry.title
end
local function EntryColumnWidth(entry, iconSize, fontSize)
    return math.max(52, Theme:MeasureText(fontSize or Theme.Font.assist, entry.title) + (iconSize or 18) + Theme.Space.md)
end
local function CharacterColor(character)
    local color = RAID_CLASS_COLORS and character and RAID_CLASS_COLORS[character.class or ""]
    return color and { color.r, color.g, color.b } or Theme.Colors.text
end
local function CharacterColumnWidth(characters, context, entries, projection)
    -- Size character columns from their actual rendered values as well as the
    -- shared name floor.
    local width = Theme:GetCharacterMatrixColumnWidth(context, characters)
    for _, character in ipairs(characters or {}) do
        for _, entry in ipairs(entries or {}) do
            local value, state = Addon:ProjectionValue(projection, character, entry)
            local text = Addon:FormatLimitCell(value, state, entry, Addon.FormatCell)
            width = math.max(width, Theme:MeasureText(Theme.Font.body, text) + Theme.Space.sm)
        end
    end
    return width
end
local function MinimumCharacterWidth(characters, context, entries, projection)
    local width = 52
    for _, character in ipairs(characters) do
        local name = Core.Characters:FormatName(character, { nameMode = "short", realmMode = "omit" })
        width = math.max(width, Theme:MeasureText(Theme.Font.assist, name) + Theme.Space.sm)
        if context.scope == "all" then width = math.max(width, Theme:MeasureText(Theme.Font.meta, character.realm or "") + Theme.Space.sm) end
        for _, entry in ipairs(entries) do
            local value, state = Addon:ProjectionValue(projection, character, entry)
            width = math.max(width, Theme:MeasureText(Theme.Font.body, Addon:FormatLimitCell(value, state, entry, Addon.FormatCell)) + Theme.Space.sm)
        end
    end
    return width
end
local function HoverControlWidth()
    return math.max(Theme.Size.standard, Theme:MeasureText(Theme.Font.assist, Addon:T("UI.DISPLAY_HOVER")) + Theme.Space.sm)
end
local function MainFixedWidths(entries, characters, projection, preview)
    local currencyWidth = Theme:MeasureText(Theme.Font.body, Addon:T("CURRENCY.CURRENCY_219994")) + Theme.Space.sm
    for _, entry in ipairs(entries or {}) do currencyWidth = math.max(currencyWidth, EntryColumnWidth(entry, 16, Theme.Font.body)) end
    local totalWidth = math.max(Theme:MeasureText(Theme.Font.body, Addon:T("CURRENCY.TOTAL_3AF1AC")) + Theme.Space.sm, Theme:MeasureText(Theme.Font.body, Addon:FormatCompact({ quantity = 294000 })) + Theme.Space.md)
    for _, entry in ipairs(entries or {}) do
        local total = Addon:ProjectionTotal(projection, characters or {}, entry)
        local text = Addon:FormatCompact({ quantity = total.quantity }, entry) .. (total.complete and "" or (total.bankPending and "~" or "?"))
        totalWidth = math.max(totalWidth, Theme:MeasureText(Theme.Font.body, text) + Theme.Space.sm)
    end
    return currencyWidth + (preview and 0 or HoverControlWidth()), totalWidth
end
local function StateColor(kind)
    if kind == "unknown" or kind == "na" or kind == "bank" then return Theme.Colors.muted end
    return Theme.Colors.text
end
local function ValueColor(value, state, entry)
    local kind = Addon:ValueState(value, state)
    if kind == "known" then
        local limitState = Addon:GetLimitState(value, entry)
        if limitState == "capped" then return Theme.Colors.limitReached or { 1.00, 0.42, 0.36 } end
        if limitState == "near-cap" then return Theme.Colors.warning or { 0.96, 0.70, 0.25 } end
    end
    return StateColor(kind)
end
local function SnapshotMeta(character, projection)
    local cached = projection and projection.snapshots[character.id]
    local economy, items = cached and cached.native, cached and cached.carriedTokens
    if not cached then economy, items = Addon.Store:Get(character.id, "native"), Addon.Store:Get(character.id, "carriedTokens") end
    return math.max(tonumber(economy and economy.observedAt) or 0, tonumber(items and items.observedAt) or 0), (economy and economy.state) or (items and items.state) or "not-yet-scanned"
end

function Addon:CreateCurrencyPage(parent)
    parent.currencyToolbar = CreateFrame("Frame", nil, parent); parent.currencyToolbar.buttons = {}
    parent.currencyHeader = CreateFrame("Frame", nil, parent); parent.currencyHeader:SetClipsChildren(true)
    parent.currencyScroll = Theme:CreateScrollFrame(parent); parent.currencyScroll:BindScrollbarGutter(parent.currencyHeader)
    parent.currencyBody = CreateFrame("Frame", nil, parent.currencyScroll); parent.currencyScroll:SetScrollChild(parent.currencyBody)
    parent.currencyRows, parent.currencyHeaders = {}, {}
    parent.currentColumnOutline = Theme:CreateCurrentCharacterOutline(parent)
end

local function SetCell(cell, text, color, justify)
    cell:SetJustifyH(justify or "CENTER"); cell:SetWordWrap(false); cell:SetText(text); cell:SetTextColor(color[1], color[2], color[3])
end
local function AddEntryTooltip(row, character)
    local entry, characters = row.entry, row.tooltipCharacters or {}
    character = type(character) == "table" and character or row.tooltipCharacter
    if not entry then return end
    GameTooltip:SetOwner(row, "ANCHOR_CURSOR"); GameTooltip:ClearLines()
    GameTooltip:AddLine(entry.title, Theme.Colors.accent[1], Theme.Colors.accent[2], Theme.Colors.accent[3])
    local total = Addon:ProjectionTotal(row.projection, characters, entry)
    local suffix = total.complete and "" or (total.bankPending and Addon:T("CURRENCY.INCOMPLETE_PERSONAL_INVENTORY_87D2C2") or Addon:T("CURRENCY.MISSING_DATA_DBC7DE"))
    GameTooltip:AddDoubleLine(Addon:T("CURRENCY.SCOPE_TOTAL_08CD4A"), Addon:FormatCompact({ quantity = total.quantity }, entry) .. suffix)
    if character then
        local value, state = Addon:ProjectionValue(row.projection, character, entry)
        local text, kind = Addon:FormatLimitCell(value, state, entry, Addon.FormatCell)
        if kind == "known" or kind == "bank" then text = Addon:FormatExact(value, entry) end
        GameTooltip:AddDoubleLine(DisplayName(character), text)
        local weekly = Addon:FormatWeeklyProgress(value, entry)
        if weekly then GameTooltip:AddLine(weekly, Theme.Colors.muted[1], Theme.Colors.muted[2], Theme.Colors.muted[3]) end
        if state ~= "known" then
            local detail = Addon:StateDescription(value, state)
            if detail then GameTooltip:AddLine(detail, Theme.Colors.muted[1], Theme.Colors.muted[2], Theme.Colors.muted[3]) end
        end
    end
    if not row.preview then GameTooltip:AddLine(Addon:T("CURRENCY.RIGHT_CLICK_TOGGLE_HOVER_SELECTION_1603F1"), Theme.Colors.muted[1], Theme.Colors.muted[2], Theme.Colors.muted[3]) end
    GameTooltip:Show()
end

local function ConfigureToolbar(parent, characters, shown, pageInfo)
    local toolbar = parent.currencyToolbar; toolbar:SetShown(true)
    local label = toolbar.label or Text(toolbar, "LEFT"); toolbar.label = label; label:ClearAllPoints(); label:SetPoint("LEFT", 0, 0)
    label:SetText(Addon:T("UI.DISPLAY_SUMMARY", #Addon:GetDisplayCatalog(false), #Addon:GetCatalog(), Addon:GetMonitoredCount(), #characters)); label:SetTextColor(Theme.Colors.muted[1], Theme.Colors.muted[2], Theme.Colors.muted[3]); label:Show()
    -- The page summary belongs to this toolbar, but all paging chrome belongs
    -- to Core at the matrix header. Hide any legacy controls retained by an
    -- already-created frame pool.
    for _, control in pairs(toolbar.buttons or {}) do control:Hide() end
end

local function HideEmptyHover(parent)
    if parent.currencyEmpty then parent.currencyEmpty:Hide() end
end

local function PinHeaderToDivider(header, inset)
    -- Single-line matrix headings use the full header box so the shared
    -- vertical-middle justification can place them at the visual center.
    header.label:ClearAllPoints(); header.label:SetPoint("TOPLEFT", header, "TOPLEFT", inset, 0); header.label:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", -inset, 0)
end

local function Layout(parent, context, columns, rows, preview, projection)
    HideEmptyHover(parent)
    local inset = Theme:GetMatrixInsets(preview); local headerHeight = Theme:GetCharacterHeaderHeight(context)
    parent.currencyToolbar:ClearAllPoints()
    if preview then parent.currencyToolbar:Hide()
    else parent.currencyToolbar:SetPoint("TOPLEFT", parent, "TOPLEFT", inset.left, -inset.top); parent.currencyToolbar:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -inset.right, -inset.top); parent.currencyToolbar:SetHeight(Theme.Size.compact); parent.currencyToolbar:Show() end
    parent.currencyHeader:ClearAllPoints()
    if preview then parent.currencyHeader:SetPoint("TOPLEFT", parent, "TOPLEFT", inset.left, -inset.top); parent.currencyHeader:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -inset.right, -inset.top)
    else parent.currencyHeader:SetPoint("TOPLEFT", parent.currencyToolbar, "BOTTOMLEFT", 0, -Theme.Space.sm); parent.currencyHeader:SetPoint("TOPRIGHT", parent.currencyToolbar, "BOTTOMRIGHT", 0, -Theme.Space.sm) end
    parent.currencyHeader:SetHeight(headerHeight); parent.currencyHeader:Show()
    parent.currencyScroll:ClearAllPoints(); parent.currencyScroll:SetPoint("TOPLEFT", parent.currencyHeader, "BOTTOMLEFT", 0, 0); parent.currencyScroll:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -inset.right, inset.bottom)
    local x, currentX, currentWidth, current = 0, nil, nil, Core.Characters:GetCurrent()
    for index, column in ipairs(columns) do
        column.x = x; local header = parent.currencyHeaders[index] or Theme:CreateMatrixHeader(parent.currencyHeader); parent.currencyHeaders[index] = header
        header:ClearAllPoints(); header:SetPoint("TOPLEFT", parent.currencyHeader, "TOPLEFT", x, 0); header:SetSize(column.width, headerHeight)
        if column.character then local updated, state = SnapshotMeta(column.character, projection); Theme:SetCharacterHeader(header, column.character, context, { color=CharacterColor(column.character), updatedAt=updated, state=state, recovery=Addon:T("CURRENCY.LOG_IN_TO_SYNC_CURRENCY_AND_BANK_DATA_73D2FF") })
        else Theme:SetMatrixHeader(header, column.entry and IconText(column.entry, 16) or column.title, { height=headerHeight, justify=column.justify or "LEFT", color=Theme.Colors.muted, inset=1 }); PinHeaderToDivider(header, 1); header:SetScript("OnEnter", nil); header:SetScript("OnLeave", nil) end
        if column.kind == "currency" and not preview then
            header.hoverLabel = header.hoverLabel or Theme:CreateText(header, Theme.Font.assist, Theme.Colors.muted, "CENTER")
            header.hoverLabel:ClearAllPoints(); header.hoverLabel:SetPoint("RIGHT", header, "RIGHT", 0, 0); header.hoverLabel:SetWidth(HoverControlWidth())
            header.hoverLabel:SetText(Addon:T("UI.DISPLAY_HOVER")); header.hoverLabel:Show()
        elseif header.hoverLabel then header.hoverLabel:Hide() end
        if not preview and current and column.character and column.character.id == current.id then currentX, currentWidth = x, column.width end
        x = x + column.width
    end
    for index = #columns + 1, #parent.currencyHeaders do parent.currencyHeaders[index]:Hide() end
    local y = 0
    for index, entry in ipairs(rows) do
        local rowEntry = entry
        local row = parent.currencyRows[index] or CreateFrame("Button", nil, parent.currencyBody, "BackdropTemplate"); parent.currencyRows[index] = row
        row.preview = preview
        if row.hoverToggle then row.hoverToggle:Hide() end
        row:ClearAllPoints(); row:SetPoint("TOPLEFT", parent.currencyBody, "TOPLEFT", 0, -y); row:SetSize(x, ROW_HEIGHT); row:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8x8" }); local color = Theme:GetDataRowColor(index); row:SetBackdropColor(color[1], color[2], color[3], color[4] or 1); row.cells = row.cells or {}; row.entry = entry; row.tooltipCharacters = entry.tooltipCharacters or {}; row.projection = projection
        if row.currentOutline then Theme:SetCurrentCharacterOutline(row.currentOutline, false) end
        for ci, column in ipairs(columns) do
            local cell = row.cells[ci] or Text(row, column.justify or "CENTER"); row.cells[ci] = cell; cell:ClearAllPoints(); cell:SetPoint("LEFT", row, "LEFT", column.x + Theme.Space.xs, 0); cell:SetWidth(column.width - Theme.Space.sm)
            if column.kind == "identity" then
                SetCell(cell, entry.character and DisplayName(entry.character) or Addon:T("CURRENCY.TOTAL_3AF1AC"), entry.character and CharacterColor(entry.character) or Theme.Colors.muted, "LEFT")
            elseif column.entry then
                if entry.kind == "total" then
                    local total = Addon:ProjectionTotal(projection, row.tooltipCharacters, column.entry)
                    SetCell(cell, Addon:FormatCompact({ quantity = total.quantity }, column.entry) .. (total.complete and "" or (total.bankPending and "~" or "?")), total.complete and Theme.Colors.text or Theme.Colors.muted, "CENTER")
                else
                    local value, state = Addon:ProjectionValue(projection, entry.character, column.entry)
                    SetCell(cell, Addon:FormatLimitCell(value, state, column.entry, Addon.FormatCell), ValueColor(value, state, column.entry), "CENTER")
                end
            elseif column.kind == "currency" then
                SetCell(cell, IconText(entry, 16), Theme.Colors.text, "LEFT")
                if not preview then
                    cell:SetWidth(math.max(1, column.width - Theme.Space.sm - HoverControlWidth()))
                    row.hoverToggle = row.hoverToggle or Theme:CreateCheckbox(row, "")
                    row.hoverToggle:ClearAllPoints(); row.hoverToggle:SetPoint("LEFT", row, "LEFT", column.x + column.width - HoverControlWidth() / 2 - 8, 0)
                    row.hoverToggle:SetSize(24, ROW_HEIGHT); row.hoverToggle:SetFrameLevel(row:GetFrameLevel() + 3)
                    row.hoverToggle:SetChecked(Addon:IsMonitored(entry)); row.hoverToggle:Show()
                    row.hoverToggle:SetScript("OnClick", function() Addon:ToggleHoverCurrency(rowEntry.id) end)
                    Theme:BindTooltip(row.hoverToggle, entry.title, { Addon:T("UI.DISPLAY_HOVER_HINT") })
                end
            elseif column.kind == "total" then local total = Addon:ProjectionTotal(projection, row.tooltipCharacters or {}, entry); local text = Addon:FormatCompact({ quantity=total.quantity }, entry) .. (total.complete and "" or (total.bankPending and "~" or "?")); SetCell(cell, text, total.complete and Theme.Colors.text or Theme.Colors.muted, "CENTER")
            else local value, state = Addon:ProjectionValue(projection, column.character, entry); local text, kind = Addon:FormatLimitCell(value, state, entry, Addon.FormatCell); SetCell(cell, text, ValueColor(value, state, entry), "CENTER") end
            cell:Show()
        end
        for ci = #columns + 1, #row.cells do row.cells[ci]:Hide() end
        for _, icon in pairs(row.icons or {}) do icon:Hide() end
        row:SetScript("OnEnter", AddEntryTooltip); if entry.kind then row:SetScript("OnEnter", nil) end; row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        row:RegisterForClicks("RightButtonUp")
        row:SetScript("OnClick", function(_, button)
            if button ~= "RightButton" or rowEntry.kind or preview then return end
            Addon:ToggleHoverCurrency(rowEntry.id)
        end)
        row.goalHits = row.goalHits or {}
        for _, hit in pairs(row.goalHits) do hit:Hide(); if Core.BusinessItemActions then Core.BusinessItemActions:Unbind(hit) end end
        if entry.kind then
            for ci, column in ipairs(columns) do if column.entry then
                local selectedEntry = column.entry
                local hit = row.goalHits[ci] or CreateFrame("Button", nil, row); row.goalHits[ci] = hit
                hit:ClearAllPoints(); hit:SetAllPoints(row.cells[ci]); hit:SetFrameLevel(row:GetFrameLevel() + 2)
                hit.entry, hit.tooltipCharacters, hit.projection, hit.tooltipCharacter, hit.preview = selectedEntry, row.tooltipCharacters, projection, entry.character, preview
                hit:SetScript("OnEnter", AddEntryTooltip); hit:SetScript("OnLeave", function() GameTooltip:Hide() end)
                hit:RegisterForClicks("RightButtonUp")
                hit:SetScript("OnClick", nil); hit:Show()
            end end
        end
        if not entry.kind then
            for ci, column in ipairs(columns) do if column.character or column.kind == "currency" then
                local hit = row.goalHits[ci] or CreateFrame("Button", nil, row); row.goalHits[ci] = hit
                hit:ClearAllPoints(); hit:SetAllPoints(row.cells[ci]); hit:SetFrameLevel(row:GetFrameLevel() + 2)
                local target = column.character
                hit.entry, hit.tooltipCharacters, hit.projection, hit.tooltipCharacter = nil, nil, nil, nil
                hit:RegisterForClicks("RightButtonUp"); hit:SetScript("OnClick", row:GetScript("OnClick"))
                local goals = Addon.GoalTargets and Addon.GoalTargets.ref and not preview and (entry.source == "currency" or entry.source == "money")
                if goals then Addon.GoalTargets:Bind(hit, entry.id, target and target.id, row:GetScript("OnClick")) end
                hit:SetScript("OnEnter", function()
                    AddEntryTooltip(row, target)
                    if goals then GameTooltip:AddLine(Addon:T("UI.GOAL_HINT", Core.BusinessItemActions:GestureLabel())); GameTooltip:Show() end
                end)
                hit:SetScript("OnLeave", function() GameTooltip:Hide() end); hit:Show()
            end end
        end
        if entry.character then
            row.currentOutline = row.currentOutline or Theme:CreateCurrentCharacterOutline(row)
            Theme:SetCurrentCharacterOutline(row.currentOutline, current and current.id == entry.character.id)
        end
        row:Show(); y = y + ROW_HEIGHT
    end
    for index = #rows + 1, #parent.currencyRows do parent.currencyRows[index]:Hide() end
    parent.currencyBody:SetSize(x, math.max(1, y)); parent.currencyScroll:SetContentHeight(parent.currencyBody:GetHeight()); parent.currencyScroll:RefreshScrollbar()
    Theme:UpdateCurrentCharacterColumnOutline(parent.currentColumnOutline, parent.currencyHeader, parent.currencyScroll, currentX, currentWidth, currentX ~= nil)
end

local function TransposedColumns(characters, entries, projection, context)
    local columns = { { kind = "identity", title = Addon:T("CURRENCY.CHARACTERS_6B2669"),
        width = Theme:GetCharacterRowHeaderWidth(false, context, characters), justify = "LEFT" } }
    for _, entry in ipairs(entries) do
        local width = EntryColumnWidth(entry, 16, Theme.Font.body)
        local total = Addon:ProjectionTotal(projection, characters, entry)
        width = math.max(width, Theme:MeasureText(Theme.Font.body, Addon:FormatCompact({ quantity = total.quantity }, entry) .. "~") + Theme.Space.sm)
        for _, character in ipairs(characters) do
            local value, state = Addon:ProjectionValue(projection, character, entry)
            width = math.max(width, Theme:MeasureText(Theme.Font.body, Addon:FormatLimitCell(value, state, entry, Addon.FormatCell)) + Theme.Space.sm)
        end
        columns[#columns + 1] = { entry = entry, width = width, justify = "CENTER" }
    end
    return columns
end

function Addon:RefreshCurrencyPage(parent, context)
    local preview = context.preview == true
    local characters = Eligible(context.characters)
    local entries = self:GetDisplayCatalog(preview)
    local projection = self:GetCurrencyProjection(context, characters, entries)
    if #entries == 0 then
        self:LayoutEmptyHover(parent, Addon:T("CURRENCY.NO_CURRENCIES_SELECTED_A32524"), Addon:T("CURRENCY.CHOOSE_MAIN_VIEW_OR_HOVER_CURRENCIES_IN_CORE_SETTINGS_D_E1E09E"))
        return
    end
    local inset = Theme:GetMatrixInsets(preview)
    local available = math.max(1, (tonumber(context.surfaceAvailableWidth) or parent:GetWidth() or 1) - inset.left - inset.right)
    local transposed = preview and self:GetSettings().hoverTranspose
    local rowCount = transposed and (#characters + 1) or #entries
    local fixedHeight = inset.top + inset.bottom + Theme:GetCharacterHeaderHeight(context)
        + (preview and 0 or Theme.Size.compact + Theme.Space.sm)
    available = math.max(1, Core.AccountView:GetScrollSurfaceWidth(context, parent, rowCount * ROW_HEIGHT, fixedHeight) - inset.left - inset.right)
    local columns, shown, pageInfo
    if transposed then
        columns = TransposedColumns(characters, entries, projection, context)
        local fieldColumns = {}; for i = 2, #columns do fieldColumns[#fieldColumns + 1] = columns[i] end
        local visible; visible, pageInfo = Core.AccountView:GetColumnPageByWidth(PAGE_ID, "hover-transpose", fieldColumns, available, columns[1].width, function(column) return column.width end)
        local identity = columns[1]; columns = { identity }; for _, column in ipairs(visible) do columns[#columns + 1] = column end
        local rows = { { kind = "total", tooltipCharacters = characters } }
        for _, character in ipairs(characters) do rows[#rows + 1] = { kind = "character", character = character, tooltipCharacters = characters } end
        Layout(parent, context, columns, rows, true, projection)
        Core.AccountView:UpdateColumnPager(parent, PAGE_ID, "hover-transpose", pageInfo, parent.currencyHeader, Addon:T("CURRENCY.CURRENCY_219994"))
        return
    end
    local currencyWidth, totalWidth = MainFixedWidths(entries, characters, projection, preview)
    local characterWidth = CharacterColumnWidth(characters, context, entries, projection)
    local minimum = MinimumCharacterWidth(characters, context, entries, projection)
    currencyWidth = math.min(currencyWidth, math.max(160, available - totalWidth - #characters * minimum))
    characterWidth = Core.AccountView:FitRepeatedColumnWidth(available, currencyWidth + totalWidth, #characters, characterWidth, minimum)
    shown, pageInfo = Core.AccountView:GetColumnPage(PAGE_ID, "matrix", characters, available, currencyWidth + totalWidth, characterWidth)
    ConfigureToolbar(parent, characters, shown, pageInfo)
    columns = { { kind="currency", title=Addon:T("CURRENCY.CURRENCY_219994"), width=currencyWidth, justify="LEFT" }, { kind="total", title=Addon:T("CURRENCY.TOTAL_3AF1AC"), width=totalWidth, justify="CENTER" } }
    for _, character in ipairs(shown) do columns[#columns + 1] = { kind="character", character=character, width=characterWidth, justify="CENTER" } end
    for _, entry in ipairs(entries) do entry.tooltipCharacters = characters end
    Layout(parent, context, columns, entries, preview, projection)
    Core.AccountView:UpdateColumnPager(parent, PAGE_ID, "matrix", pageInfo, parent.currencyHeader, Addon:T("CURRENCY.CHARACTERS_6B2669"))
end

function Addon:LayoutEmptyHover(parent, title, hint)
    local inset = Theme:GetMatrixInsets(true)
    parent.currencyToolbar:Hide(); parent.currencyHeader:Hide()
    parent.currencyScroll:ClearAllPoints(); parent.currencyScroll:SetPoint("TOPLEFT", parent, "TOPLEFT", inset.left, -inset.top); parent.currencyScroll:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -inset.right, inset.bottom)
    -- Do not reuse a matrix row for the empty state.  A row may already be a
    -- clickable table Button with cells and scripts, which makes state changes
    -- between the full matrix and the compact preview fragile.
    local empty = parent.currencyEmpty or CreateFrame("Frame", nil, parent.currencyBody); parent.currencyEmpty = empty
    empty:ClearAllPoints(); empty:SetPoint("TOPLEFT", parent.currencyBody, "TOPLEFT", 0, 0); empty:SetSize(420, 68)
    empty.title = empty.title or Text(empty, "LEFT"); empty.title:ClearAllPoints(); empty.title:SetPoint("TOPLEFT", empty, "TOPLEFT", 0, -8); empty.title:SetText(title); empty.title:SetTextColor(Theme.Colors.accent[1], Theme.Colors.accent[2], Theme.Colors.accent[3]); empty.title:Show()
    empty.hint = empty.hint or Theme:CreateText(empty, Theme.Font.assist, Theme.Colors.muted, "LEFT"); empty.hint:ClearAllPoints(); empty.hint:SetPoint("TOPLEFT", empty.title, "BOTTOMLEFT", 0, -8); empty.hint:SetWidth(400); empty.hint:SetWordWrap(true); empty.hint:SetText(hint); empty.hint:Show(); empty:Show()
    for index = 1, #parent.currencyRows do parent.currencyRows[index]:Hide() end
    for index = 1, #parent.currencyHeaders do parent.currencyHeaders[index]:Hide() end
    parent.currencyBody:SetSize(420, 68); parent.currencyScroll:SetContentHeight(68); parent.currencyScroll:RefreshScrollbar(); Theme:SetCurrentCharacterOutline(parent.currentColumnOutline, false)
end

function Addon:GetCurrencySurfaceMetrics(context)
    local preview = context.preview == true
    local inset = Theme:GetMatrixInsets(preview)
    local characters, entries = Eligible(context.characters), self:GetDisplayCatalog(preview)
    local projection = self:GetCurrencyProjection(context, characters, entries)
    if #entries == 0 then
        return { minContentWidth = 420 + inset.left + inset.right, naturalContentWidth = 420 + inset.left + inset.right,
            minContentHeight = 68 + inset.top + inset.bottom, naturalContentHeight = 68 + inset.top + inset.bottom,
            horizontalOverflow = "none", verticalOverflow = "none" }
    end
    if preview and self:GetSettings().hoverTranspose then
        local columns = TransposedColumns(characters, entries, projection, context)
        local width = inset.left + inset.right
        for _, column in ipairs(columns) do width = width + column.width end
        local fixedHeight = inset.top + Theme:GetCharacterHeaderHeight(context) + inset.bottom
        return { minContentWidth = columns[1].width + (columns[2] and columns[2].width or 0) + inset.left + inset.right,
            naturalContentWidth = width, scrollContentHeight = (#characters + 1) * ROW_HEIGHT, scrollFixedHeight = fixedHeight, minContentHeight = fixedHeight + ROW_HEIGHT,
            naturalContentHeight = fixedHeight + (#characters + 1) * ROW_HEIGHT, horizontalOverflow = "paginate", verticalOverflow = "content" }
    end
    local currencyWidth, totalWidth = MainFixedWidths(entries, characters, projection, preview)
    local columnWidth = CharacterColumnWidth(characters, context, entries, projection)
    local fixedHeight = inset.top + Theme:GetCharacterHeaderHeight(context) + inset.bottom
        + (preview and 0 or Theme.Size.compact + Theme.Space.sm)
    return { minContentWidth = currencyWidth + totalWidth + (#characters > 0 and columnWidth or 0) + inset.left + inset.right,
        naturalContentWidth = currencyWidth + totalWidth + #characters * columnWidth + inset.left + inset.right,
        scrollContentHeight = #entries * ROW_HEIGHT, scrollFixedHeight = fixedHeight,
        minContentHeight = fixedHeight + ROW_HEIGHT, naturalContentHeight = fixedHeight + math.min(#entries, 20) * ROW_HEIGHT,
        fixedLeftWidth = currencyWidth + totalWidth, fixedTopHeight = Theme:GetCharacterHeaderHeight(context),
        horizontalOverflow = "paginate", verticalOverflow = "content" }
end
