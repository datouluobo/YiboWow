local Addon, Core = _G.YiboCurrency, _G.YiboCore
local Theme = Core.UITheme
local PAGE_ID = "currency"

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
        output[#output + 1] = { kind = "empty", title = "尚未监控货币；请在“货币管家”设置中勾选悬停监控。" }
    end
    return output
end

function Addon:CreateCurrencyPage(parent)
    parent.currencyToolbar = CreateFrame("Frame", nil, parent)
    parent.currencyToolbar.buttons = {}
    parent.currencyHeader = CreateFrame("Frame", nil, parent)
    parent.currencyScroll = Theme:CreateScrollFrame(parent)
    parent.currencyBody = CreateFrame("Frame", nil, parent.currencyScroll)
    parent.currencyScroll:SetScrollChild(parent.currencyBody)
    parent.currencyRows, parent.currencyHeaders = {}, {}
end

local function Tooltip(row)
    if not row.entry then return end
    GameTooltip:SetOwner(row, "ANCHOR_CURSOR")
    GameTooltip:AddLine(row.entry.title, Theme.Colors.accent[1], Theme.Colors.accent[2], Theme.Colors.accent[3])
    GameTooltip:AddLine("稳定键：" .. row.entry.id, Theme.Colors.muted[1], Theme.Colors.muted[2], Theme.Colors.muted[3])
    if row.entry.source == "item" then GameTooltip:AddLine("物品代币；银行数据需在打开银行后确认。", Theme.Colors.text[1], Theme.Colors.text[2], Theme.Colors.text[3])
    elseif not row.entry.verified then GameTooltip:AddLine("此目录项待 5.5.4 客户端探针验证。", 1, 0.78, 0.34) end
    GameTooltip:Show()
end

function Addon:RefreshCurrencyPage(parent, context)
    local preview = context.preview == true
    local inset = Theme:GetMatrixInsets(preview)
    local characters = Eligible(context.characters)
    local rows = EntryRows(self:GetCatalog(), preview)
    parent.currencyToolbar:SetShown(not preview)
    parent.currencyToolbar:ClearAllPoints(); parent.currencyToolbar:SetPoint("TOPLEFT", parent, "TOPLEFT", inset.left, -inset.top); parent.currencyToolbar:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -inset.right, -inset.top); parent.currencyToolbar:SetHeight(Theme.Size.standard)
    local top = parent.currencyToolbar
    if not preview then
        local x = 0
        for index, expansion in ipairs(self.ExpansionOrder) do
            local button = parent.currencyToolbar.buttons[index] or Theme:CreateButton(parent.currencyToolbar, 92, expansion, "secondary")
            parent.currencyToolbar.buttons[index] = button; button:ClearAllPoints(); button:SetPoint("LEFT", parent.currencyToolbar, "LEFT", x, 0); button:SetText(expansion:gsub("（60 年代）", ""):gsub("其它与未归类", "其它")); button:SetScript("OnClick", function() local y = parent.currencyAnchors and parent.currencyAnchors[expansion]; if y then parent.currencyScroll:SetVerticalScroll(y) end end); button:Show(); x = x + 96
        end
        top = parent.currencyToolbar
    end
    parent.currencyHeader:ClearAllPoints(); parent.currencyHeader:SetPoint("TOPLEFT", top, "BOTTOMLEFT", 0, -Theme.Space.sm); parent.currencyHeader:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -inset.right, 0); parent.currencyHeader:SetHeight(Theme.Table.headerHeight)
    parent.currencyScroll:ClearAllPoints(); parent.currencyScroll:SetPoint("TOPLEFT", parent.currencyHeader, "BOTTOMLEFT", 0, Theme.Space.xxs); parent.currencyScroll:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -inset.right, inset.bottom)
    local nameWidth, characterWidth = preview and 170 or 220, preview and 92 or 110
    local width = parent.currencyHeader:GetWidth() > 1 and parent.currencyHeader:GetWidth() or parent:GetWidth()
    local shown, pageInfo = Core.AccountView:GetColumnPage(PAGE_ID, preview and "preview" or "matrix", characters, width, nameWidth, characterWidth)
    if pageInfo.pages > 1 then shown, pageInfo = Core.AccountView:GetColumnPage(PAGE_ID, preview and "preview" or "matrix", characters, width - Core.AccountView:GetColumnPagerWidth(), nameWidth, characterWidth) end
    Core.AccountView:UpdateColumnPager(parent, PAGE_ID, preview and "preview" or "matrix", pageInfo, parent.currencyHeader, "角色")
    local columns = { { title = "货币", width = nameWidth } }
    for _, character in ipairs(shown) do columns[#columns + 1] = { title = Core.Characters:GetDisplayName(character, "short") or "未知", width = characterWidth, character = character } end
    local tableWidth = 0
    for index, column in ipairs(columns) do
        local header = parent.currencyHeaders[index] or Text(parent.currencyHeader, Theme.Font.assist, Theme.Colors.accent, index == 1 and "LEFT" or "CENTER")
        parent.currencyHeaders[index] = header; header:ClearAllPoints(); header:SetPoint("LEFT", parent.currencyHeader, "LEFT", tableWidth + Theme.Space.xs, 0); header:SetWidth(column.width - Theme.Space.sm); header:SetJustifyH(index == 1 and "LEFT" or "CENTER"); header:SetText(column.title); header:Show(); tableWidth = tableWidth + column.width
    end
    for index = #columns + 1, #parent.currencyHeaders do parent.currencyHeaders[index]:Hide() end
    parent.currencyAnchors = {}
    for index, item in ipairs(rows) do
        local row = parent.currencyRows[index] or CreateFrame("Button", nil, parent.currencyBody, "BackdropTemplate")
        parent.currencyRows[index] = row; row:ClearAllPoints(); row:SetPoint("TOPLEFT", parent.currencyBody, "TOPLEFT", 0, -((index - 1) * Theme.Table.rowHeight)); row:SetSize(tableWidth, Theme.Table.rowHeight); row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" }); row.cells = row.cells or {}
        local colors = item.kind == "expansion" and Theme.Colors.selected or (item.kind == "category" and Theme.Colors.toolbar or (index % 2 == 0 and Theme.Colors.alternate or Theme.Colors.row)); row:SetBackdropColor(colors[1], colors[2], colors[3], colors[4] or 1); row.entry = item.entry
        if item.kind == "expansion" then parent.currencyAnchors[item.key] = (index - 1) * Theme.Table.rowHeight end
        for ci, column in ipairs(columns) do
            local cell = row.cells[ci] or Text(row, Theme.Font.body, Theme.Colors.text, ci == 1 and "LEFT" or "CENTER"); row.cells[ci] = cell; cell:ClearAllPoints(); cell:SetPoint("LEFT", row, "LEFT", tableWidth - (function() local total = 0; for n = ci, #columns do total = total + columns[n].width end; return total end)() + Theme.Space.xs, 0); cell:SetWidth(column.width - Theme.Space.sm); cell:SetJustifyH(ci == 1 and "LEFT" or "CENTER")
            if ci == 1 then
                cell:SetText((item.kind == "category" and "  " or "") .. (item.title or item.entry.title))
                local color = item.kind == "currency" and Theme.Colors.text or (item.kind == "empty" and Theme.Colors.muted or Theme.Colors.accent)
                cell:SetTextColor(color[1], color[2], color[3])
            elseif item.kind == "currency" then local value, state = self:GetValue(column.character, item.entry); cell:SetText(self:FormatValue(value, state)); cell:SetTextColor(state == "known" and Theme.Colors.text[1] or Theme.Colors.muted[1], state == "known" and Theme.Colors.text[2] or Theme.Colors.muted[2], state == "known" and Theme.Colors.text[3] or Theme.Colors.muted[3])
            else cell:SetText("") end
            cell:Show()
        end
        for ci = #columns + 1, #row.cells do row.cells[ci]:Hide() end
        row:SetScript("OnEnter", Tooltip); row:SetScript("OnLeave", function() GameTooltip:Hide() end); row:Show()
    end
    for index = #rows + 1, #parent.currencyRows do parent.currencyRows[index]:Hide() end
    parent.currencyBody:SetSize(tableWidth, math.max(1, #rows * Theme.Table.rowHeight)); parent.currencyScroll:SetContentHeight(parent.currencyBody:GetHeight()); parent.currencyScroll:RefreshScrollbar()
end

function Addon:GetCurrencySurfaceMetrics(context)
    local preview = context and context.preview
    local inset, count = Theme:GetMatrixInsets(preview), #Eligible(context and context.characters or {})
    local label, character = preview and 170 or 220, preview and 92 or 110
    return { minContentWidth = label + character + inset.left + inset.right, naturalContentWidth = label + math.max(1, math.min(8, count)) * character + inset.left + inset.right, minContentHeight = inset.top + Theme.Table.headerHeight + Theme.Table.rowHeight + inset.bottom, naturalContentHeight = inset.top + Theme.Table.headerHeight + math.min(preview and 12 or 20, math.max(1, #EntryRows(self:GetCatalog(), preview))) * Theme.Table.rowHeight + inset.bottom, fixedLeftWidth = label, fixedTopHeight = Theme.Table.headerHeight, horizontalOverflow = "paginate", verticalOverflow = "content" }
end
