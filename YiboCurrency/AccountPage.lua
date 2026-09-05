local Addon, Core = _G.YiboCurrency, _G.YiboCore
local Theme = Core.UITheme
local PAGE_ID = "currency"
local ROW_HEIGHT = Theme.Table.rowHeight

local function Text(parent, justify) return Theme:CreateText(parent, Theme.Font.body, Theme.Colors.text, justify or "LEFT") end
local function Eligible(characters)
    local result = {}; for _, character in ipairs(characters or {}) do
        if Core.DataDomains:Get(character.id, "economy") or Core.DataDomains:Get(character.id, "economy-items") then result[#result + 1] = character end
    end; return result
end
local function DisplayName(character) return (character and character.name) or "未知角色" end
local function DisplayIdentity(character, context)
    local name = DisplayName(character)
    if context and context.scope == "all" and character and character.id ~= "empty" then return name .. "-" .. tostring(character.realm or "未知服务器") end
    return name
end
local function IconText(entry, size)
    size = size or 16
    return "|T" .. tostring(Addon:GetIcon(entry)) .. ":" .. size .. ":" .. size .. ":0:0|t " .. entry.title
end
local function EntryColumnWidth(entry, iconSize, fontSize)
    return math.max(52, Theme:MeasureText(fontSize or Theme.Font.assist, entry.title) + (iconSize or 18) + Theme.Space.md)
end
local function PreviewColumnWidth(entry)
    -- Header labels deliberately sit almost flush to their vertical dividers: the
    -- column width is driven by the text itself rather than decorative padding.
    local headerWidth = Theme:MeasureText(Theme.Font.assist, entry.title) + 2
    local valueWidth = 16 + Theme:MeasureText(Theme.Font.body, "294,000") + Theme.Space.xxs * 3
    return math.max(headerWidth, valueWidth, 44)
end
local function CharacterColor(character)
    local color = RAID_CLASS_COLORS and character and RAID_CLASS_COLORS[character.class or ""]
    return color and { color.r, color.g, color.b } or Theme.Colors.text
end
local function CharacterColumnWidth(character, context)
    local nameWidth = Theme:MeasureText(Theme.Font.assist, DisplayName(character))
    local realmWidth = context and context.scope == "all" and Theme:MeasureText(Theme.Font.meta, "-" .. tostring(character.realm or "未知服务器")) or 0
    -- The longest displayed value is a compact currency amount.  This keeps
    -- a narrow column narrow while ensuring neither amount nor header clips.
    local valueWidth = Theme:MeasureText(Theme.Font.body, "29.4万")
    return math.max(50, nameWidth, realmWidth, valueWidth) + Theme.Space.sm
end
local function CharacterLabelColumnWidth(characters, context)
    local width = Theme:MeasureText(Theme.Font.assist, "角色")
    for _, character in ipairs(characters or {}) do width = math.max(width, Theme:MeasureText(Theme.Font.body, DisplayIdentity(character, context))) end
    return math.max(64, width + Theme.Space.md)
end
local function MainFixedWidths(entries)
    local currencyWidth = Theme:MeasureText(Theme.Font.body, "货币") + Theme.Space.sm
    for _, entry in ipairs(entries or {}) do currencyWidth = math.max(currencyWidth, EntryColumnWidth(entry, 16, Theme.Font.body)) end
    local totalWidth = math.max(Theme:MeasureText(Theme.Font.body, "总计") + Theme.Space.sm, Theme:MeasureText(Theme.Font.body, "29.4万") + Theme.Space.md)
    return currencyWidth, totalWidth
end
local function StateColor(kind)
    if kind == "unknown" or kind == "na" or kind == "bank" then return Theme.Colors.muted end
    return Theme.Colors.text
end
local function SnapshotMeta(character)
    local economy, items = Core.DataDomains:Get(character.id, "economy"), Core.DataDomains:Get(character.id, "economy-items")
    return math.max(tonumber(economy and economy.updatedAt) or 0, tonumber(items and items.updatedAt) or 0), (economy and economy.state) or (items and items.state) or "not-yet-scanned"
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
local function AddEntryTooltip(row)
    local entry, characters = row.entry, row.tooltipCharacters or {}
    if not entry then return end
    GameTooltip:SetOwner(row, "ANCHOR_CURSOR"); GameTooltip:ClearLines()
    GameTooltip:AddLine(entry.title, Theme.Colors.accent[1], Theme.Colors.accent[2], Theme.Colors.accent[3])
    GameTooltip:AddLine((entry.sourceType or "货币") .. " · " .. entry.id, Theme.Colors.muted[1], Theme.Colors.muted[2], Theme.Colors.muted[3])
    GameTooltip:AddLine("状态：" .. (entry.status or "待核验"), Theme.Colors.muted[1], Theme.Colors.muted[2], Theme.Colors.muted[3])
    GameTooltip:AddLine("— 不适用  ·  ? 未同步/未知  ·  ~ 银行未完整扫描", Theme.Colors.muted[1], Theme.Colors.muted[2], Theme.Colors.muted[3])
    local total = Addon:TotalFor(characters, entry)
    local suffix = total.complete and "" or (total.bankPending and " ~ 银行未完整扫描" or " ? 有缺失数据")
    GameTooltip:AddDoubleLine("当前范围总计", Addon:FormatCompact({ quantity = total.quantity }, entry) .. suffix, Theme.Colors.text[1], Theme.Colors.text[2], Theme.Colors.text[3], Theme.Colors.text[1], Theme.Colors.text[2], Theme.Colors.text[3])
    GameTooltip:AddLine(string.format("已确认 %d 名；缺失 %d 名", total.confirmed, total.missing), Theme.Colors.muted[1], Theme.Colors.muted[2], Theme.Colors.muted[3])
    for _, character in ipairs(characters) do
        local value, state = Addon:GetValue(character, entry); local valueText, kind = Addon:FormatCell(value, state, entry)
        local detail = Addon:StateDescription(value, state)
        local weekly = Addon:FormatWeeklyProgress(value, entry)
        local exact = (kind == "known" or kind == "bank") and ("（" .. Addon:FormatExact(value, entry) .. "）") or ""
        GameTooltip:AddDoubleLine(DisplayName(character), valueText .. exact .. (weekly and " · " .. weekly or "") .. (detail and " · " .. detail or ""), Theme.Colors.muted[1], Theme.Colors.muted[2], Theme.Colors.muted[3], StateColor(kind)[1], StateColor(kind)[2], StateColor(kind)[3])
    end
    GameTooltip:AddLine("右键：切换悬停监控", Theme.Colors.muted[1], Theme.Colors.muted[2], Theme.Colors.muted[3])
    GameTooltip:Show()
end

local function ConfigureToolbar(parent, characters, shown, pageInfo)
    local toolbar = parent.currencyToolbar; toolbar:SetShown(true)
    local label = toolbar.label or Text(toolbar, "LEFT"); toolbar.label = label; label:ClearAllPoints(); label:SetPoint("LEFT", 0, 0)
    label:SetText(string.format("%d 项货币 · %d 名角色", #Addon:GetCatalog(), #characters)); label:SetTextColor(Theme.Colors.muted[1], Theme.Colors.muted[2], Theme.Colors.muted[3]); label:Show()
    -- Core owns the saved page state; its current compatibility implementation
    -- exposes one complete page, so these controls remain hidden until a core
    -- width pager supplies more than one slice.
    local previous = toolbar.buttons.previous or Theme:CreateButton(toolbar, 54, "‹", "secondary"); toolbar.buttons.previous = previous
    local nextButton = toolbar.buttons.next or Theme:CreateButton(toolbar, 54, "›", "secondary"); toolbar.buttons.next = nextButton
    local page = toolbar.buttons.page or Text(toolbar, "CENTER"); toolbar.buttons.page = page
    if pageInfo.pages and pageInfo.pages > 1 then
        previous:ClearAllPoints(); previous:SetPoint("RIGHT", toolbar, "RIGHT", -130, 0); previous:SetScript("OnClick", function() Core.AccountView:SetColumnPage(PAGE_ID, "matrix", pageInfo.page - 1, pageInfo.pages) end); previous:Show()
        page:ClearAllPoints(); page:SetPoint("RIGHT", toolbar, "RIGHT", -58, 0); page:SetWidth(66); page:SetText(pageInfo.page .. "/" .. pageInfo.pages); page:Show()
        nextButton:ClearAllPoints(); nextButton:SetPoint("RIGHT", toolbar, "RIGHT", 0, 0); nextButton:SetScript("OnClick", function() Core.AccountView:SetColumnPage(PAGE_ID, "matrix", pageInfo.page + 1, pageInfo.pages) end); nextButton:Show()
    else previous:Hide(); nextButton:Hide(); page:Hide() end
end

local function HideEmptyHover(parent)
    if parent.currencyEmpty then parent.currencyEmpty:Hide() end
end

local function PinHeaderToDivider(header, inset)
    header.label:ClearAllPoints(); header.label:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", inset, 1); header.label:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", -inset, 1); header.label:SetHeight(16)
end

local function Layout(parent, context, columns, rows, preview)
    HideEmptyHover(parent)
    local inset = Theme:GetMatrixInsets(preview); local headerHeight = preview and Theme.Table.headerHeight or Theme:GetCharacterHeaderHeight(context)
    parent.currencyHeader:ClearAllPoints(); parent.currencyHeader:SetPoint("TOPLEFT", parent, "TOPLEFT", inset.left, -(preview and inset.top or Theme.Size.compact + Theme.Space.sm)); parent.currencyHeader:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -inset.right, -(preview and inset.top or Theme.Size.compact + Theme.Space.sm)); parent.currencyHeader:SetHeight(headerHeight); parent.currencyHeader:Show()
    parent.currencyScroll:ClearAllPoints(); parent.currencyScroll:SetPoint("TOPLEFT", parent.currencyHeader, "BOTTOMLEFT", 0, 0); parent.currencyScroll:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -inset.right, inset.bottom)
    local x, currentX, currentWidth, current = 0, nil, nil, Core.Characters:GetCurrent()
    for index, column in ipairs(columns) do
        column.x = x; local header = parent.currencyHeaders[index] or Theme:CreateMatrixHeader(parent.currencyHeader); parent.currencyHeaders[index] = header
        header:ClearAllPoints(); header:SetPoint("TOPLEFT", parent.currencyHeader, "TOPLEFT", x, 0); header:SetSize(column.width, headerHeight)
        if column.character then local updated, state = SnapshotMeta(column.character); Theme:SetCharacterHeader(header, column.character, context, { name=DisplayName(column.character), color=CharacterColor(column.character), updatedAt=updated, state=state, recovery="登录该角色后同步货币与银行数据。" })
        else Theme:SetMatrixHeader(header, column.title, { height=headerHeight, justify=column.justify or "LEFT", color=Theme.Colors.accent, inset=1 }); PinHeaderToDivider(header, 1); header:SetScript("OnEnter", nil); header:SetScript("OnLeave", nil) end
        if not preview and current and column.character and column.character.id == current.id then currentX, currentWidth = x, column.width end
        x = x + column.width
    end
    for index = #columns + 1, #parent.currencyHeaders do parent.currencyHeaders[index]:Hide() end
    local y = 0
    for index, entry in ipairs(rows) do
        local row = parent.currencyRows[index] or CreateFrame("Button", nil, parent.currencyBody, "BackdropTemplate"); parent.currencyRows[index] = row
        row:ClearAllPoints(); row:SetPoint("TOPLEFT", parent.currencyBody, "TOPLEFT", 0, -y); row:SetSize(x, ROW_HEIGHT); row:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8x8" }); local color = Theme:GetDataRowColor(index); row:SetBackdropColor(color[1], color[2], color[3], color[4] or 1); row.cells = row.cells or {}; row.entry = entry; row.tooltipCharacters = entry.tooltipCharacters or {}
        for ci, column in ipairs(columns) do
            local cell = row.cells[ci] or Text(row, column.justify or "CENTER"); row.cells[ci] = cell; cell:ClearAllPoints(); cell:SetPoint("LEFT", row, "LEFT", column.x + Theme.Space.xs, 0); cell:SetWidth(column.width - Theme.Space.sm)
            if column.kind == "currency" then SetCell(cell, IconText(entry, 16), Theme.Colors.text, "LEFT")
            elseif column.kind == "total" then local total = Addon:TotalFor(row.tooltipCharacters or {}, entry); local text = Addon:FormatCompact({ quantity=total.quantity }, entry) .. (total.complete and "" or (total.bankPending and "~" or "?")); SetCell(cell, text, total.complete and Theme.Colors.text or Theme.Colors.muted, "CENTER")
            else local value, state = Addon:GetValue(column.character, entry); local text, kind = Addon:FormatCell(value, state, entry); SetCell(cell, text, StateColor(kind), "CENTER") end
            cell:Show()
        end
        for ci = #columns + 1, #row.cells do row.cells[ci]:Hide() end
        for _, icon in pairs(row.icons or {}) do icon:Hide() end
        row:SetScript("OnEnter", AddEntryTooltip); row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        -- Buttons only receive the left mouse button by default.  Monitoring
        -- is intentionally a secondary action so a right-click must be
        -- explicitly registered; otherwise the handler below is unreachable.
        row:RegisterForClicks("RightButtonUp")
        row:SetScript("OnClick", function(_, button)
            if button ~= "RightButton" then return end
            local enabling = not Addon:IsMonitored(entry)
            local ok, err = Addon:SetMonitored(entry, enabling)
            if not ok then Addon:Print(err); return end
            Addon:Print((enabling and "已加入悬停监控：" or "已取消悬停监控：") .. entry.title)
            Addon:NotifyChanged()
        end)
        row:Show(); y = y + ROW_HEIGHT
    end
    for index = #rows + 1, #parent.currencyRows do parent.currencyRows[index]:Hide() end
    parent.currencyBody:SetSize(x, math.max(1, y)); parent.currencyScroll:SetContentHeight(parent.currencyBody:GetHeight()); parent.currencyScroll:RefreshScrollbar()
    parent.currentColumnOutline:ClearAllPoints(); if currentX then parent.currentColumnOutline:SetPoint("TOPLEFT", parent.currencyHeader, "TOPLEFT", currentX, 0); parent.currentColumnOutline:SetPoint("BOTTOMRIGHT", parent.currencyScroll, "BOTTOMLEFT", currentX + currentWidth, 0); Theme:SetCurrentCharacterOutline(parent.currentColumnOutline, true) else Theme:SetCurrentCharacterOutline(parent.currentColumnOutline, false) end
end

function Addon:RefreshCurrencyPage(parent, context)
    local preview = context.preview == true; local characters = Eligible(context.characters); local entries = preview and self:GetMonitoredCatalog() or {}
    if not preview then for _, entry in ipairs(self:GetCatalog()) do if self:IsVisible(entry) then entries[#entries + 1] = entry end end end
    if preview and #entries == 0 then
        self:LayoutEmptyHover(parent, "尚未选择悬停监控货币", "在主矩阵中右键货币，或在“货币总览”设置中勾选“悬停监控”。")
        return
    end
    local inset = Theme:GetMatrixInsets(preview)
    -- The complete catalog is vertically scrollable in the main matrix.  Its
    -- shared scrollbar lives in a 14px gutter beside the data viewport, so it
    -- must participate in the character-column budget.  Otherwise the last
    -- column is laid out underneath that gutter once the thumb appears.
    local scrollbarGutter = preview and 0 or (Theme.Geometry.scrollbarGutter or 0)
    local available = math.max(1, (tonumber(context.surfaceAvailableWidth) or parent:GetWidth() or 1) - inset.left - inset.right - scrollbarGutter)
    local columns, shown, pageInfo
    if preview then
        columns = { { kind="currency", title="角色", width=CharacterLabelColumnWidth(characters, context), justify="LEFT" } }
        for _, entry in ipairs(entries) do columns[#columns + 1] = { kind="preview-entry", entry=entry, title=entry.title, width=PreviewColumnWidth(entry), justify="CENTER" } end
        -- The hover is transposed: construct character rows below, not currency rows.
        local characterRows = {}; for _, character in ipairs(characters) do characterRows[#characterRows + 1] = character end
        if #characterRows == 0 then characterRows[1] = { id="empty", name="暂无已同步角色" } end
        parent.currencyToolbar:Hide()
        -- A specialized row renderer keeps the preview semantically distinct from the main matrix.
        self:LayoutHover(parent, context, columns, characterRows, entries); return
    end
    local currencyWidth, totalWidth = MainFixedWidths(entries)
    shown, pageInfo = Core.AccountView:GetColumnPageByWidth(PAGE_ID, "matrix", characters, available, currencyWidth + totalWidth, function(character) return CharacterColumnWidth(character, context) end)
    ConfigureToolbar(parent, characters, shown, pageInfo)
    columns = { { kind="currency", title="货币", width=currencyWidth, justify="LEFT" }, { kind="total", title="总计", width=totalWidth, justify="CENTER" } }
    for _, character in ipairs(shown) do columns[#columns + 1] = { kind="character", character=character, width=CharacterColumnWidth(character, context), justify="CENTER" } end
    for _, entry in ipairs(entries) do entry.tooltipCharacters = characters end
    Layout(parent, context, columns, entries, false)
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

function Addon:LayoutHover(parent, context, columns, characters, entries)
    HideEmptyHover(parent)
    local inset, headerHeight = Theme:GetMatrixInsets(true), Theme.Table.headerHeight; parent.currencyHeader:ClearAllPoints(); parent.currencyHeader:SetPoint("TOPLEFT", parent, "TOPLEFT", inset.left, -inset.top); parent.currencyHeader:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -inset.right, -inset.top); parent.currencyHeader:SetHeight(headerHeight); parent.currencyHeader:Show()
    parent.currencyScroll:ClearAllPoints(); parent.currencyScroll:SetPoint("TOPLEFT", parent.currencyHeader, "BOTTOMLEFT"); parent.currencyScroll:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -inset.right, inset.bottom)
    local x = 0; for index, column in ipairs(columns) do column.x=x; local header=parent.currencyHeaders[index] or Theme:CreateMatrixHeader(parent.currencyHeader); parent.currencyHeaders[index]=header; header:ClearAllPoints(); header:SetPoint("TOPLEFT", parent.currencyHeader,"TOPLEFT",x,0); header:SetSize(column.width,headerHeight); Theme:SetMatrixHeader(header,column.title,{height=headerHeight,justify=column.justify,color=Theme.Colors.accent,inset=1}); PinHeaderToDivider(header, 1); if column.entry then Theme:BindTooltip(header,column.entry.title,{{kind="pair",label="来源",value=column.entry.sourceType or "货币"},{kind="pair",label="状态",value=column.entry.status or "待核验"},{kind="pair",label="稳定 ID",value=column.entry.id}}) else header:SetScript("OnEnter",nil); header:SetScript("OnLeave",nil) end; header:Show(); x=x+column.width end
    for index=#columns+1,#parent.currencyHeaders do parent.currencyHeaders[index]:Hide() end
    local function DrawRow(index, character, total)
        local row=parent.currencyRows[index] or CreateFrame("Button",nil,parent.currencyBody,"BackdropTemplate"); parent.currencyRows[index]=row; row:ClearAllPoints(); row:SetPoint("TOPLEFT",parent.currencyBody,"TOPLEFT",0,-((index-1)*ROW_HEIGHT)); row:SetSize(x,ROW_HEIGHT); row:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8x8"}); local bg=Theme:GetDataRowColor(index); row:SetBackdropColor(bg[1],bg[2],bg[3],bg[4] or 1); row.cells=row.cells or {}; row.icons=row.icons or {}
        for ci,column in ipairs(columns) do local cell=row.cells[ci] or Text(row,column.justify); row.cells[ci]=cell; cell:ClearAllPoints(); cell:SetPoint("LEFT",row,"LEFT",column.x+Theme.Space.xs,0); cell:SetWidth(column.width-Theme.Space.sm)
            if ci==1 then SetCell(cell,total and "总计" or DisplayIdentity(character, context),total and Theme.Colors.accent or CharacterColor(character),"LEFT")
            else local entry=entries[ci-1]; local icon=row.icons[ci] or row:CreateTexture(nil,"OVERLAY"); row.icons[ci]=icon; icon:ClearAllPoints(); icon:SetPoint("RIGHT",row,"LEFT",column.x+column.width-Theme.Space.xxs,0); icon:SetSize(16,16); icon:SetTexture(Addon:GetIcon(entry)); icon:Show(); cell:SetWidth(column.width-16-Theme.Space.xxs*3)
                if entry.source == "empty" then SetCell(cell,"",Theme.Colors.muted,"RIGHT") elseif total then local summary=Addon:TotalFor(characters,entry); local value=Addon:FormatFull({quantity=summary.quantity},entry)..(summary.complete and "" or (summary.bankPending and "~" or "?")); SetCell(cell,value,summary.complete and Theme.Colors.text or Theme.Colors.muted,"RIGHT") else local value,state=Addon:GetValue(character,entry); local valueText,kind=Addon:FormatFullCell(value,state,entry); SetCell(cell,valueText,StateColor(kind),"RIGHT") end end; cell:Show()
            if ci == 1 and row.icons[ci] then row.icons[ci]:Hide() end
        end
        for ci=#columns+1,#row.cells do row.cells[ci]:Hide() end; for ci,icon in pairs(row.icons) do if ci > #columns then icon:Hide() end end; row:Show()
    end
    for index,character in ipairs(characters) do DrawRow(index,character,false) end; DrawRow(#characters+1,nil,true)
    for index=#characters+2,#parent.currencyRows do parent.currencyRows[index]:Hide() end
    parent.currencyBody:SetSize(x, math.max(1,(#characters+1)*ROW_HEIGHT)); parent.currencyScroll:SetContentHeight(parent.currencyBody:GetHeight()); parent.currencyScroll:RefreshScrollbar(); Theme:SetCurrentCharacterOutline(parent.currentColumnOutline,false)
end

function Addon:GetCurrencySurfaceMetrics(context)
    local preview=context and context.preview; local inset=Theme:GetMatrixInsets(preview); local characters=Eligible(context and context.characters or {}); local entries=preview and self:GetMonitoredCatalog() or self:GetCatalog()
    if preview and #entries == 0 then return { minContentWidth=420+inset.left+inset.right, naturalContentWidth=420+inset.left+inset.right, minContentHeight=68+inset.top+inset.bottom, naturalContentHeight=68+inset.top+inset.bottom, horizontalOverflow="none",verticalOverflow="none" } end
    if preview then
        local width = CharacterLabelColumnWidth(characters, context)
        for _, entry in ipairs(entries) do width = width + PreviewColumnWidth(entry) end
        return { minContentWidth=width+inset.left+inset.right, naturalContentWidth=width+inset.left+inset.right, minContentHeight=inset.top+Theme.Table.headerHeight+ROW_HEIGHT+inset.bottom, naturalContentHeight=inset.top+Theme.Table.headerHeight+math.min(#characters+1,21)*ROW_HEIGHT+inset.bottom, fixedLeftWidth=CharacterLabelColumnWidth(characters, context),fixedTopHeight=Theme.Table.headerHeight,horizontalOverflow="content",verticalOverflow="content" }
    end
    local currencyWidth, totalWidth = MainFixedWidths(entries); local characterWidth = 0
    for _, character in ipairs(characters) do characterWidth = characterWidth + CharacterColumnWidth(character, context) end
    local gutter=Theme.Geometry.scrollbarGutter or 0; local width=currencyWidth+totalWidth+characterWidth
    return { minContentWidth=currencyWidth+totalWidth+(characters[1] and CharacterColumnWidth(characters[1], context) or 50)+inset.left+inset.right+gutter,naturalContentWidth=width+inset.left+inset.right+gutter,minContentHeight=inset.top+Theme.Size.compact+Theme.Space.sm+Theme.Table.headerHeight+ROW_HEIGHT+inset.bottom,naturalContentHeight=inset.top+Theme.Size.compact+Theme.Space.sm+Theme.Table.headerHeight+math.min(#entries,20)*ROW_HEIGHT+inset.bottom,fixedLeftWidth=currencyWidth+totalWidth,fixedTopHeight=Theme.Table.headerHeight,horizontalOverflow="paginate",verticalOverflow="content" }
end
