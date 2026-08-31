local Addon, Core = _G.YiboCurrency, _G.YiboCore
local Theme = Core.UITheme
local PAGE_ID = "currency"
local WARNING = { 1, 0.78, 0.34 }

local function Text(parent, size, color, justify)
    return Theme:CreateText(parent, size, color, justify or "LEFT")
end
local function Eligible(characters)
    local result = {}
    for _, character in ipairs(characters or {}) do
        if Core.DataDomains:Get(character.id, "economy") or Core.DataDomains:Get(character.id, "economy-items") then result[#result + 1] = character end
    end
    return result
end
local function EntryRows(entries, monitoredOnly)
    local output, groups, categories = {}, {}, {}
    for _, expansion in ipairs(Addon.ExpansionOrder) do groups[expansion] = {} end
    for _, entry in ipairs(entries) do
        if (not monitoredOnly or Addon:IsMonitored(entry)) and (monitoredOnly or Addon:IsVisible(entry)) then
            groups[entry.expansion or "其它与未归类"] = groups[entry.expansion or "其它与未归类"] or {}
            groups[entry.expansion or "其它与未归类"][#groups[entry.expansion or "其它与未归类"] + 1] = entry
        end
    end
    for _, expansion in ipairs(Addon.ExpansionOrder) do
        local list = groups[expansion]
        if list and #list > 0 then
            output[#output + 1] = { kind = "expansion", title = expansion, key = expansion }
            categories[expansion] = {}
            for _, category in ipairs(Addon.CategoryOrder) do categories[expansion][category] = {} end
            for _, entry in ipairs(list) do
                local category = entry.category or "常规货币"
                categories[expansion][category] = categories[expansion][category] or {}
                categories[expansion][category][#categories[expansion][category] + 1] = entry
            end
            for _, category in ipairs(Addon.CategoryOrder) do
                local rows = categories[expansion][category]
                if rows and #rows > 0 then
                    output[#output + 1] = { kind = "category", title = category }
                    table.sort(rows, function(a, b) return a.title < b.title end)
                    for _, entry in ipairs(rows) do output[#output + 1] = { kind = "currency", entry = entry } end
                end
            end
        end
    end
    -- A blank hover looked like a failed page in the screenshot.  Monitoring
    -- remains opt-in, but its empty state must explain that choice directly.
    if monitoredOnly and #output == 0 then
        output[#output + 1] = { kind = "empty", title = "未监控货币 · 在“货币管家”中勾选“悬停监控”" }
    end
    return output
end

local function VisibleFields(context)
    local fields = {}
    for _, field in ipairs((context and context.fields) or {}) do fields[#fields + 1] = field end
    return fields
end

local function CompactNumber(value)
    value = tonumber(value)
    if not value then return nil end
    if value >= 10000 then
        local result = string.format("%.1f万", value / 10000)
        return result:gsub("%.0万$", "万")
    end
    if value >= 1000 then
        local result = string.format("%.1fk", value / 1000)
        return result:gsub("%.0k$", "k")
    end
    return BreakUpLargeNumbers(value)
end

local function HasField(fields, id)
    for _, field in ipairs(fields or {}) do if field.id == id then return true end end
    return false
end

local function CompactMoney(value)
    value = tonumber(value) or 0
    local gold = math.floor(value / 10000)
    return CompactNumber(gold) .. "金"
end

local function PrimaryValue(addon, value, state, entry)
    if state ~= "known" then return addon:FormatValue(value, state) end
    if not value then return "—" end
    if entry and entry.source == "money" then return CompactMoney(value.quantity) end
    if value.itemID then return CompactNumber(value.bankKnown and value.total or value.carried) or "—" end
    return value.quantity ~= nil and CompactNumber(value.quantity) or addon:FormatValue(value, state)
end

local function LimitSignal(value)
    if not value then return nil end
    local function Signal(current, maximum, kind)
        current, maximum = tonumber(current), tonumber(maximum)
        if not current or not maximum or maximum <= 0 then return nil end
        if current >= maximum then return "full", kind end
        if current / maximum >= 0.8 then return "near", kind end
        return nil
    end
    -- Weekly progress measures this week's gains; a quantity ceiling measures
    -- what is currently carried.  They are distinct limits and therefore
    -- stay distinct in the detail tooltip.
    return Signal(value.weeklyQuantity, value.maxWeeklyQuantity, "weekly")
        or Signal(value.quantity, value.maxQuantity, "quantity")
end

local function ValueText(addon, value, state, fields, entry)
    if state ~= "known" then return addon:FormatValue(value, state) end
    if not value then return "—" end
    -- The matrix is for scanning balances.  Limits belong in the row tooltip,
    -- where both weekly and total semantics can be read without widening every
    -- character column.  A compact marker keeps the warning non-colour-only.
    local signal = LimitSignal(value)
    return PrimaryValue(addon, value, state, entry) .. (signal == "full" and "!" or (signal == "near" and "~" or ""))
end

local function CurrencyRowHeight(item)
    return Theme.Table.rowHeight
end

local function FieldLegend(fields)
    return "货币 · 余额"
end

local function RowsHeight(rows, fields, limit)
    local height = 0
    for index, item in ipairs(rows or {}) do
        if limit and index > limit then break end
        height = height + CurrencyRowHeight(item, fields)
    end
    return math.max(Theme.Table.rowHeight, height)
end

function Addon:CreateCurrencyPage(parent)
    parent.currencyToolbar = CreateFrame("Frame", nil, parent)
    parent.currencyToolbar.buttons = {}
    parent.currencyHeader = CreateFrame("Frame", nil, parent)
    parent.currencyHeader:SetClipsChildren(true)
    parent.currencyScroll = Theme:CreateScrollFrame(parent)
    parent.currencyBody = CreateFrame("Frame", nil, parent.currencyScroll)
    parent.currencyScroll:SetScrollChild(parent.currencyBody)
    parent.currentColumnOutline = Theme:CreateCurrentCharacterOutline(parent)
    parent.currencyRows, parent.currencyHeaders = {}, {}
end

local function AddLimitLine(tooltip, character, addon, value, state, entry)
    local name = Core.Characters:GetDisplayName(character, "short") or character.name or "未知角色"
    if state ~= "known" then
        tooltip:AddDoubleLine(name, addon:FormatValue(value, state), Theme.Colors.muted[1], Theme.Colors.muted[2], Theme.Colors.muted[3], Theme.Colors.muted[1], Theme.Colors.muted[2], Theme.Colors.muted[3])
        return
    end
    local parts = { "余额 " .. PrimaryValue(addon, value, state, entry) }
    if value.weeklyQuantity ~= nil and tonumber(value.maxWeeklyQuantity) and tonumber(value.maxWeeklyQuantity) > 0 then
        parts[#parts + 1] = "本周 " .. CompactNumber(value.weeklyQuantity) .. " / " .. CompactNumber(value.maxWeeklyQuantity)
    end
    if tonumber(value.maxQuantity) and tonumber(value.maxQuantity) > 0 then
        parts[#parts + 1] = "持有 " .. CompactNumber(value.quantity) .. " / " .. CompactNumber(value.maxQuantity)
    end
    local signal = LimitSignal(value)
    local color = signal == "full" and Theme.Colors.danger or (signal == "near" and WARNING or Theme.Colors.text)
    tooltip:AddDoubleLine(name, table.concat(parts, " · "), color[1], color[2], color[3], color[1], color[2], color[3])
end

local function Tooltip(row)
    if not row.entry then return end
    GameTooltip:SetOwner(row, "ANCHOR_CURSOR")
    GameTooltip:ClearLines()
    GameTooltip:AddLine(row.entry.title, Theme.Colors.accent[1], Theme.Colors.accent[2], Theme.Colors.accent[3])
    GameTooltip:AddLine("! 已达上限 · ~ 接近上限", Theme.Colors.muted[1], Theme.Colors.muted[2], Theme.Colors.muted[3])
    if row.entry.source == "item" then GameTooltip:AddLine("物品代币；总数需在打开银行后更新。", Theme.Colors.text[1], Theme.Colors.text[2], Theme.Colors.text[3]) end
    for _, character in ipairs(row.tooltipCharacters or {}) do
        local value, state = Addon:GetValue(character, row.entry)
        AddLimitLine(GameTooltip, character, Addon, value, state, row.entry)
    end
    GameTooltip:Show()
end

function Addon:RefreshCurrencyPage(parent, context)
    local preview = context.preview == true
    local inset = Theme:GetMatrixInsets(preview)
    local characters = Eligible(context.characters)
    local rows = EntryRows(self:GetCatalog(), preview)
    local fields = VisibleFields(context)
    local emptyPreview = preview and #rows == 1 and rows[1].kind == "empty"
    parent.currencyToolbar:SetShown(not preview)
    parent.currencyToolbar:ClearAllPoints(); parent.currencyToolbar:SetPoint("TOPLEFT", parent, "TOPLEFT", inset.left, -inset.top); parent.currencyToolbar:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -inset.right, -inset.top); parent.currencyToolbar:SetHeight(Theme.Size.compact)
    local top = preview and parent or parent.currencyToolbar
    if not preview then
        local x = 0
        for index, expansion in ipairs(self.ExpansionOrder) do
            local button = parent.currencyToolbar.buttons[index] or Theme:CreateButton(parent.currencyToolbar, 84, expansion, "secondary")
            parent.currencyToolbar.buttons[index] = button; button:SetHeight(Theme.Size.compact); button:ClearAllPoints(); button:SetPoint("LEFT", parent.currencyToolbar, "LEFT", x, 0); button:SetText(expansion:gsub("（60 年代）", ""):gsub("其它与未归类", "其它")); button:SetScript("OnClick", function() local y = parent.currencyAnchors and parent.currencyAnchors[expansion]; if y then parent.currencyScroll:SetVerticalScroll(y) end end); button:Show(); x = x + 88
        end
        top = parent.currencyToolbar
    end
    parent.currencyHeader:SetShown(not emptyPreview)
    parent.currencyHeader:ClearAllPoints()
    if preview and not emptyPreview then
        parent.currencyHeader:SetPoint("TOPLEFT", parent, "TOPLEFT", inset.left, -inset.top)
    elseif not preview then
        parent.currencyHeader:SetPoint("TOPLEFT", top, "BOTTOMLEFT", 0, -Theme.Space.xs)
    end
    parent.currencyHeader:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -inset.right, preview and -inset.top or 0)
    parent.currencyHeader:SetHeight(Theme.Table.headerHeight)
    parent.currencyScroll:ClearAllPoints()
    if emptyPreview then
        parent.currencyScroll:SetPoint("TOPLEFT", parent, "TOPLEFT", inset.left, -inset.top)
    else
        parent.currencyScroll:SetPoint("TOPLEFT", parent.currencyHeader, "BOTTOMLEFT", 0, Theme.Space.xxs)
    end
    parent.currencyScroll:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -inset.right, inset.bottom)
    -- The matrix is designed for a full account roster.  Compact values and
    -- short character names fit in 76px, leaving room for up to 20 columns
    -- on a 2560px screen without pagination.
    local nameWidth, characterWidth = 136, 64
    -- ApplyPageSize calculates the target surface before WoW has necessarily
    -- delivered its resize event.  Use that same width on this first render so
    -- a full roster is not temporarily cut down to the previous 1120px shell.
    local measuredWidth = parent.currencyHeader:GetWidth() > 1 and parent.currencyHeader:GetWidth() or parent:GetWidth()
    local rosterWidth = nameWidth + math.max(1, math.min(20, #characters)) * characterWidth + inset.left + inset.right
    local width = preview and measuredWidth or math.max(measuredWidth, rosterWidth)
    local shown, pageInfo = {}, { page = 1, pages = 1, first = 0, last = 0, total = 0 }
    if not emptyPreview then
        shown, pageInfo = Core.AccountView:GetColumnPage(PAGE_ID, preview and "preview" or "matrix", characters, width, nameWidth, characterWidth)
        if pageInfo.pages > 1 then shown, pageInfo = Core.AccountView:GetColumnPage(PAGE_ID, preview and "preview" or "matrix", characters, width - Core.AccountView:GetColumnPagerWidth(), nameWidth, characterWidth) end
    end
    Core.AccountView:UpdateColumnPager(parent, PAGE_ID, preview and "preview" or "matrix", pageInfo, parent.currencyHeader, "角色")
    local columns = emptyPreview and { { title = "", width = 420 } } or { { title = FieldLegend(fields), width = nameWidth } }
    for _, character in ipairs(shown) do columns[#columns + 1] = { title = Core.Characters:GetDisplayName(character, "short") or "未知", width = characterWidth, character = character } end
    local tableWidth = 0
    local current = Core.Characters:GetCurrent()
    local currentColumnX, currentColumnWidth
    for index, column in ipairs(columns) do
        local header = parent.currencyHeaders[index] or Text(parent.currencyHeader, Theme.Font.assist, Theme.Colors.accent, index == 1 and "LEFT" or "CENTER")
        parent.currencyHeaders[index] = header; header:ClearAllPoints(); header:SetPoint("LEFT", parent.currencyHeader, "LEFT", tableWidth + Theme.Space.xs, 0); header:SetWidth(column.width - Theme.Space.sm); header:SetJustifyH(index == 1 and "LEFT" or "CENTER"); header:SetText(column.title); header:Show()
        if current and column.character and column.character.id == current.id then
            currentColumnX, currentColumnWidth = tableWidth, column.width
        end
        tableWidth = tableWidth + column.width
    end
    for index = #columns + 1, #parent.currencyHeaders do parent.currencyHeaders[index]:Hide() end
    parent.currencyAnchors = {}
    local y = 0
    for index, item in ipairs(rows) do
        local row = parent.currencyRows[index] or CreateFrame("Button", nil, parent.currencyBody, "BackdropTemplate")
        local rowHeight = CurrencyRowHeight(item)
        parent.currencyRows[index] = row; row:ClearAllPoints(); row:SetPoint("TOPLEFT", parent.currencyBody, "TOPLEFT", 0, -y); row:SetSize(tableWidth, rowHeight); row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" }); row.cells = row.cells or {}
        local colors = item.kind == "expansion" and Theme.Colors.selected or (item.kind == "category" and Theme.Colors.toolbar or (index % 2 == 0 and Theme.Colors.alternate or Theme.Colors.row)); row:SetBackdropColor(colors[1], colors[2], colors[3], colors[4] or 1); row.entry = item.entry
        if item.kind == "expansion" then parent.currencyAnchors[item.key] = y end
        for ci, column in ipairs(columns) do
            local cell = row.cells[ci] or Text(row, Theme.Font.body, Theme.Colors.text, ci == 1 and "LEFT" or "CENTER"); row.cells[ci] = cell; cell:ClearAllPoints(); cell:SetPoint("LEFT", row, "LEFT", tableWidth - (function() local total = 0; for n = ci, #columns do total = total + columns[n].width end; return total end)() + Theme.Space.xs, 0); cell:SetWidth(column.width - Theme.Space.sm); cell:SetJustifyH(ci == 1 and "LEFT" or "CENTER")
            if ci == 1 then
                cell:SetText((item.kind == "category" and "  " or "") .. (item.title or item.entry.title))
                local color = item.kind == "currency" and Theme.Colors.text or (item.kind == "empty" and Theme.Colors.muted or Theme.Colors.accent)
                cell:SetTextColor(color[1], color[2], color[3])
            elseif item.kind == "currency" then
                local value, state = self:GetValue(column.character, item.entry)
                cell:SetWordWrap(false); cell:SetText(ValueText(self, value, state, fields, item.entry))
                local signal = state == "known" and LimitSignal(value) or nil
                local color = state ~= "known" and Theme.Colors.muted or (signal == "full" and Theme.Colors.danger or (signal == "near" and WARNING or Theme.Colors.text))
                cell:SetTextColor(color[1], color[2], color[3])
            else cell:SetText("") end
            cell:Show()
        end
        for ci = #columns + 1, #row.cells do row.cells[ci]:Hide() end
        row.tooltipCharacters = shown
        row:SetScript("OnEnter", Tooltip); row:SetScript("OnLeave", function() GameTooltip:Hide() end); row:Show()
        y = y + rowHeight
    end
    for index = #rows + 1, #parent.currencyRows do parent.currencyRows[index]:Hide() end
    parent.currencyBody:SetSize(tableWidth, math.max(1, y)); parent.currencyScroll:SetContentHeight(parent.currencyBody:GetHeight()); parent.currencyScroll:RefreshScrollbar()
    parent.currentColumnOutline:ClearAllPoints()
    if currentColumnX then
        parent.currentColumnOutline:SetPoint("TOPLEFT", parent.currencyHeader, "TOPLEFT", currentColumnX, 0)
        parent.currentColumnOutline:SetPoint("BOTTOMRIGHT", parent.currencyBody, "TOPLEFT", currentColumnX + currentColumnWidth, -y)
        Theme:SetCurrentCharacterOutline(parent.currentColumnOutline, true)
    else
        Theme:SetCurrentCharacterOutline(parent.currentColumnOutline, false)
    end
end

function Addon:GetCurrencySurfaceMetrics(context)
    local preview = context and context.preview
    local inset, count = Theme:GetMatrixInsets(preview), #Eligible(context and context.characters or {})
    local label, character = 136, 64
    local fields, rows = VisibleFields(context), EntryRows(self:GetCatalog(), preview)
    if preview and #rows == 1 and rows[1].kind == "empty" then
        return {
            minContentWidth = 420 + inset.left + inset.right,
            naturalContentWidth = 420 + inset.left + inset.right,
            minContentHeight = inset.top + Theme.Table.rowHeight + inset.bottom,
            naturalContentHeight = inset.top + Theme.Table.rowHeight + inset.bottom,
            fixedLeftWidth = 0,
            fixedTopHeight = 0,
            horizontalOverflow = "none",
            verticalOverflow = "none",
        }
    end
    local minimumRows = { { kind = "currency" } }
    local toolbarHeight = preview and 0 or Theme.Size.compact + Theme.Space.xs
    return {
        -- Describe every retained character column.  Core grows the account
        -- window through the screen-safe width first, then this page's shared
        -- pager takes over only for columns that physically cannot fit.
        minContentWidth = label + math.max(1, count) * character + inset.left + inset.right,
        naturalContentWidth = label + math.max(1, count) * character + inset.left + inset.right,
        minContentHeight = inset.top + toolbarHeight + Theme.Table.headerHeight + RowsHeight(minimumRows, fields) + inset.bottom,
        naturalContentHeight = inset.top + toolbarHeight + Theme.Table.headerHeight + RowsHeight(rows, fields, preview and 12 or 20) + inset.bottom,
        fixedLeftWidth = label,
        fixedTopHeight = Theme.Table.headerHeight,
        horizontalOverflow = "paginate",
        verticalOverflow = "content",
    }
end
