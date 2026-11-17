local Addon, Core = _G.YiboCurrency, _G.YiboCore or {}
local Page, Theme = {}, Core.UITheme; Addon.AccountPage = Page
function Page:Fields()
    local fields = {}
    local ids, items, custom = {}, Addon.Store:Items(), {}
    for id in pairs(items) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do
        local info = Core.ItemResolver:GetInfo(id)
        custom[#custom + 1] = { itemID = id, title = info.name or items[id] }
    end
    local nativeDir = Addon.Store and Addon.Store:GetNativeDirectory()
    local catalog = Addon:BuildDiscoveredCatalog(Addon.Catalog, nativeDir, custom)
    for _, entry in ipairs(catalog) do
        fields[#fields + 1] = { id = entry.id, title = entry.title or (entry.titleKey and Addon:T(entry.titleKey)), defaultVisible = true }
    end
    return fields
end
local function StatusText(state)
    local keys = { known = "FOREVER.KNOWN", stale = "FOREVER.STALE", error = "FOREVER.ERROR", unknown = "FOREVER.UNKNOWN" }
    return Addon:T(keys[state] or "FOREVER.UNKNOWN")
end
function Page:Status()
    local _, state = Addon.Store:Get(Core.Characters:GetCurrentID())
    return StatusText(state)
end
function Page:Format(copper)
    return Addon:T("FOREVER.AMOUNT", string.format("%.0f", math.floor(copper / 10000)),
        string.format("%.0f", math.floor(copper / 100) % 100), string.format("%.0f", copper % 100))
end
local function FormatCoinIcons(copper)
    local gold = math.floor(copper / 10000)
    local silver = math.floor(copper / 100) % 100
    return string.format("%.0f |TInterface\\MoneyFrame\\UI-GoldIcon:14:14|t    %02d |TInterface\\MoneyFrame\\UI-SilverIcon:14:14|t    %02d |TInterface\\MoneyFrame\\UI-CopperIcon:14:14|t",
        gold, silver, copper % 100)
end
function Page:Create(parent)
    parent.heading = Theme:CreateText(parent, Theme.Font.section, Theme.Colors.text)
    parent.heading:SetPoint("TOPLEFT", 12, -12); parent.heading:SetPoint("RIGHT", -130, 0); parent.heading:SetHeight(30)
    parent.refresh = Theme:CreateButton(parent, 100, Addon:T("FOREVER.REFRESH"))
    parent.refresh:SetPoint("TOPRIGHT", -12, -10)
    parent.refresh:SetScript("OnClick", function() Addon.Scanner:Scan(true) end)
    parent.status = Theme:CreateText(parent, Theme.Font.assist, Theme.Colors.muted)
    parent.status:SetPoint("TOPLEFT", 12, -52); parent.status:SetPoint("RIGHT", -12, 0); parent.status:SetHeight(36)
    parent.balanceTitle = Theme:CreateText(parent, Theme.Font.assist, Theme.Colors.muted)
    parent.balanceTitle:SetPoint("TOPLEFT", 12, -100); parent.balanceTitle:SetPoint("RIGHT", -12, 0); parent.balanceTitle:SetHeight(26)
    parent.balance = Theme:CreateText(parent, Theme.Font.section, Theme.Colors.text)
    parent.balance:SetPoint("TOPLEFT", 12, -132); parent.balance:SetPoint("RIGHT", -12, 0); parent.balance:SetHeight(32)
    parent.sessionTitle = Theme:CreateText(parent, Theme.Font.assist, Theme.Colors.muted)
    parent.sessionTitle:SetPoint("TOPLEFT", 12, -181); parent.sessionTitle:SetPoint("RIGHT", -12, 0); parent.sessionTitle:SetHeight(26)
    parent.sessionTitle:SetText(Addon:T("FOREVER.SESSION_TITLE"))
    parent.sessionChange = Theme:CreateText(parent, Theme.Font.section, Theme.Colors.text)
    parent.sessionChange:SetPoint("TOPLEFT", 12, -211); parent.sessionChange:SetPoint("RIGHT", -12, 0); parent.sessionChange:SetHeight(32)
    parent.itemSearch = Theme:CreateInput(parent, {
        width=220,height=28,maxLetters=100,clearable=true,placeholder=Addon:T("FOREVER.CUSTOM_SEARCH"),
        OnChanged=function()
            parent.itemScroll:SetVerticalScroll(0)
            Addon:NotifyChanged()
        end,
    })
    parent.itemMatches = Theme:CreateText(parent, Theme.Font.assist, Theme.Colors.muted)
    parent.itemMatches:SetHeight(28)
    parent.itemTitle = Theme:CreateText(parent, Theme.Font.assist, Theme.Colors.muted)
    parent.itemTitle:SetHeight(24)
    parent.itemTitle:SetText(Addon:T("FOREVER.CUSTOM_SECTION"))
    parent.itemChangeTitle = Theme:CreateText(parent, Theme.Font.assist, Theme.Colors.muted, "RIGHT")
    parent.itemChangeTitle:SetHeight(24)
    parent.itemChangeTitle:SetWidth(96)
    parent.itemChangeTitle:SetText(Addon:T("FOREVER.CUSTOM_SESSION"))
    parent.itemScroll = Theme:CreateScrollFrame(parent)
    parent.itemContent = CreateFrame("Frame", nil, parent.itemScroll)
    parent.itemScroll:SetScrollChild(parent.itemContent)
    parent.itemRows = {}
    parent.itemScroll:HookScript("OnSizeChanged", function(scroll)
        parent.itemContent:SetWidth(math.max(1, scroll:GetWidth() - 20))
    end)
end
local function ItemCountText(count, fresh)
    if count==nil then return Addon:T("FOREVER.CUSTOM_UNKNOWN") end
    local value=string.format("%.0f",count)
    return fresh and value or Addon:T("FOREVER.CUSTOM_STALE",value)
end

local function HideItemDetail(row)
    if GameTooltip.IsOwned and GameTooltip:IsOwned(row) then GameTooltip:Hide() end
end

local function ShowItemDetail(row)
    if not row.itemID then return end
    GameTooltip:SetOwner(row,"ANCHOR_RIGHT")
    GameTooltip:ClearLines()
    GameTooltip:AddLine(row.name:GetText())
    GameTooltip:AddDoubleLine(Addon:T("FOREVER.CUSTOM_CARRIED"),row.count:GetText())
    local labels={equipment="FOREVER.CUSTOM_VAULT_EQUIPPED",bank="FOREVER.CUSTOM_VAULT_BANK"}
    for _, detail in ipairs(Addon.CustomItems:GetVaultDetails(row.characterID,row.itemID) or {}) do
        GameTooltip:AddDoubleLine(Addon:T(labels[detail.source]),ItemCountText(detail.count,detail.fresh))
    end
    GameTooltip:Show()
end

local function RenderItems(parent, fields, id, top, preview)
    local query=preview and "" or parent.itemSearch:GetText():match("^%s*(.-)%s*$"):lower()
    local byID=query:match("^%d+$") and tonumber(query)
    local visible,total = 0,0
    local items=Addon.Store:Items()
    for _, field in ipairs(fields) do
        local itemID = tonumber(field.id:match("^item:(%d+)$"))
        local savedName=itemID and items[itemID]
        if savedName then total=total+1 end
        local matches=savedName and (query=="" or byID==itemID or (not byID
            and (field.title:lower():find(query,1,true) or savedName:lower():find(query,1,true))))
        if matches then
            visible = visible + 1
            local row = parent.itemRows[visible]
            if not row then
                row = CreateFrame("Frame", nil, parent.itemContent, "BackdropTemplate")
                row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
                row:SetHeight(28)
                row.name = Theme:CreateText(row, Theme.Font.body, Theme.Colors.text)
                row.name:SetPoint("LEFT", 8, 0); row.name:SetWordWrap(false)
                row.count = Theme:CreateText(row, Theme.Font.body, Theme.Colors.text, "RIGHT")
                row.count:SetWidth(112)
                row.name:SetPoint("RIGHT",row.count,"LEFT",-8,0)
                row.change = Theme:CreateText(row, Theme.Font.body, Theme.Colors.muted, "RIGHT")
                row.change:SetPoint("RIGHT", -8, 0); row.change:SetWidth(96)
                row:EnableMouse(true)
                row:SetScript("OnEnter",ShowItemDetail)
                row:SetScript("OnLeave",HideItemDetail)
                row:SetScript("OnHide",HideItemDetail)
                parent.itemRows[visible] = row
            end
            if row.itemID~=itemID or row.characterID~=id then HideItemDetail(row) end
            row.itemID,row.characterID=itemID,id
            row:SetPoint("TOPLEFT", 0, -(visible - 1) * 28)
            row:SetPoint("TOPRIGHT", 0, -(visible - 1) * 28)
            row:SetBackdropColor(unpack(visible % 2 == 0 and Theme.Colors.alternate or Theme.Colors.row))
            row.count:SetPoint("RIGHT", preview and -8 or -112, 0)
            local count, fresh, change = Addon.Store:GetItemCount(id, itemID)
            row.name:SetText(Addon:T("FOREVER.CUSTOM_ITEM_LABEL", field.title, tostring(itemID)))
            row.count:SetText(ItemCountText(count,fresh))
            row.count:SetTextColor(unpack(fresh and Theme.Colors.text or Theme.Colors.muted))
            if not preview then
                local text = change and string.format(change > 0 and "%+.0f" or "%.0f", change) or Addon:T("FOREVER.CUSTOM_NO_SESSION")
                local color = change and (change > 0 and Theme.Colors.accent or change < 0 and Theme.Colors.warning) or Theme.Colors.muted
                row.change:SetText(text)
                row.change:SetTextColor(unpack(color))
            end
            row.change:SetShown(not preview)
            row:Show()
        end
    end
    for index = visible + 1, #parent.itemRows do parent.itemRows[index]:Hide() end
    local showSearch=not preview and total>0
    parent.itemSearch:SetShown(showSearch)
    parent.itemMatches:SetShown(showSearch)
    if showSearch then
        parent.itemSearch:SetPoint("TOPLEFT",12,top)
        parent.itemMatches:ClearAllPoints()
        parent.itemMatches:SetPoint("TOPLEFT",parent.itemSearch,"TOPRIGHT",12,0)
        parent.itemMatches:SetPoint("TOPRIGHT",-12,top)
        parent.itemMatches:SetText(visible==0 and Addon:T("FOREVER.CUSTOM_NO_MATCH")
            or Addon:T("FOREVER.CUSTOM_MATCHES",visible,total))
        top=top-36
    end
    parent.itemTitle:ClearAllPoints()
    parent.itemTitle:SetPoint("TOPLEFT", 12, top); parent.itemTitle:SetPoint("RIGHT", -12, 0)
    parent.itemTitle:SetShown(visible > 0)
    parent.itemChangeTitle:SetPoint("TOPRIGHT", -40, top)
    parent.itemChangeTitle:SetShown(visible > 0 and not preview)
    parent.itemScroll:ClearAllPoints()
    parent.itemScroll:SetPoint("TOPLEFT", 12, top - 26); parent.itemScroll:SetPoint("BOTTOMRIGHT", -12, 10)
    parent.itemContent:SetWidth(math.max(1, parent.itemScroll:GetWidth() - 20))
    parent.itemContent:SetHeight(math.max(1, visible * 28))
    parent.itemScroll:SetContentHeight(visible * 28)
    parent.itemScroll:SetShown(visible > 0)
end
local function MatrixValue(page, fieldID, value, complete)
    if value == nil then return Addon:T("FOREVER.CUSTOM_UNKNOWN") end
    local text = fieldID == "money" and page:Format(value) or string.format("%.0f", value)
    return complete and text or Addon:T("FOREVER.CUSTOM_STALE", text)
end

local function MatrixCell(row, id)
    local cell = row.cells[id]
    if cell then return cell end
    cell = CreateFrame("Frame", nil, row)
    cell.count = Theme:CreateText(cell, Theme.Font.body, Theme.Colors.text, "CENTER")
    cell.count:SetAllPoints(cell)
    cell.count:SetWordWrap(false)
    cell:SetScript("OnEnter", ShowItemDetail)
    cell:SetScript("OnLeave", HideItemDetail)
    cell:SetScript("OnHide", HideItemDetail)
    row.cells[id] = cell
    return cell
end

function Page:RefreshMatrix(parent, context)
    if not parent.matrixHeader then
        parent.matrixHeader = CreateFrame("Frame", nil, parent)
        parent.matrixHeader:SetPoint("TOPLEFT", 12, -6)
        parent.matrixHeader:SetHeight(30)
        parent.matrixScroll = Theme:CreateScrollFrame(parent)
        parent.matrixScroll:SetPoint("TOPLEFT", 12, -37)
        parent.matrixScroll:SetPoint("BOTTOMRIGHT", -12, 8)
        parent.matrixContent = CreateFrame("Frame", nil, parent.matrixScroll)
        parent.matrixScroll:SetScrollChild(parent.matrixContent)
        parent.matrixHeader.cells, parent.matrixRows = {}, {}
    end
    for _, control in ipairs({parent.heading,parent.refresh,parent.status,parent.balanceTitle,parent.balance,
        parent.sessionTitle,parent.sessionChange,parent.itemSearch,parent.itemMatches,parent.itemTitle,parent.itemChangeTitle,parent.itemScroll}) do control:Hide() end
    parent.matrixHeader:Show()
    parent.matrixScroll:Show()

    local characters = context.characters or {}
    local width = math.max(1, (context.surfaceAvailableWidth or parent.matrixScroll:GetWidth()) - 36)
    local currencyWidth, totalWidth, characterWidth = 154, 112, 112
    local visible, pageInfo = Core.AccountView:GetColumnPage(Addon.PAGE_ID, "currency-matrix", characters,
        width, currencyWidth + totalWidth, characterWidth)
    Core.AccountView:UpdateColumnPager(parent, Addon.PAGE_ID, "currency-matrix", pageInfo, nil, Core:Text("CORE.CHARACTER"))
    local function Place(cell, x, w)
        cell:SetPoint("TOPLEFT", x, 0)
        cell:SetSize(w, 30)
        cell:Show()
    end
    local function Header(id, x, w, title)
        local cell = MatrixCell(parent.matrixHeader, id)
        cell.count:SetText(title)
        Place(cell, x, w)
    end
    for _, cell in pairs(parent.matrixHeader.cells) do cell:Hide() end
    Header("currency", 0, currencyWidth, Addon:T("FOREVER.MATRIX_CURRENCY"))
    Header("total", currencyWidth, totalWidth, Addon:T("FOREVER.MATRIX_TOTAL"))
    for index, character in ipairs(visible) do
        Header(character.id, currencyWidth + totalWidth + (index-1)*characterWidth,
            characterWidth, Core.Characters:FormatName(character, {realmMode="full"}))
    end

    local count = 0
    local preferences = self:GetMatrixPreferences()
    for _, field in ipairs(self:Fields()) do
        if preferences[field.id] then
            count = count + 1
            local row = parent.matrixRows[count]
            if not row then
                row = CreateFrame("Frame", nil, parent.matrixContent, "BackdropTemplate")
                row:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8x8"})
                row.cells = {}
                parent.matrixRows[count] = row
            end
            local itemID = tonumber(field.id:match("^item:(%d+)$"))
            local currencyID = tonumber(field.id:match("^currency:(%d+)$"))
            local values, fresh, total, observed, complete = {}, {}, 0, 0, true
            for _, character in ipairs(characters) do
                local id = character.id
                if itemID then
                    values[id], fresh[id] = Addon.Store:GetCachedItemCount(id, itemID)
                elseif currencyID then
                    local quantity, state = Addon.Store:GetNativeCurrency(id, currencyID)
                    values[id] = quantity
                    fresh[id] = (state == "known")
                else
                    local money = Addon:ReadArchiveMoney(id)
                    values[id], fresh[id] = money.value, money.state == "known"
                end
                if values[id] ~= nil then
                    total = total + values[id]
                    observed = observed + 1
                end
                complete = complete and fresh[id]
            end
            row.fieldID = field.id
            row:SetPoint("TOPLEFT", 0, -(count-1)*30)
            row:SetSize(currencyWidth + totalWidth + #visible * characterWidth, 30)
            row:SetBackdropColor(unpack(count % 2 == 0 and Theme.Colors.alternate or Theme.Colors.row))
            local name = MatrixCell(row, "currency")
            local nativeDir = Addon.Store:GetNativeDirectory()
            local icon = itemID and Core.ItemResolver:GetInfo(itemID).icon
                or (currencyID and nativeDir[currencyID] and nativeDir[currencyID].icon)
                or (not itemID and not currencyID and "Interface\\MoneyFrame\\UI-GoldIcon")
            name.count:SetText(icon and ("|T" .. icon .. ":15:15|t " .. field.title) or field.title)
            name.count:SetJustifyH("LEFT")
            Place(name, 0, currencyWidth)
            local totalCell = MatrixCell(row, "total")
            totalCell.count:SetText(MatrixValue(self, field.id, observed > 0 and total or nil, complete))
            Place(totalCell, currencyWidth, totalWidth)
            local shown = {currency=true, total=true}
            for index, character in ipairs(visible) do
                local id = character.id
                local cell = MatrixCell(row, id)
                shown[id] = true
                cell.count:SetText(MatrixValue(self, field.id, values[id], fresh[id]))
                cell.itemID, cell.characterID, cell.name = itemID, id, name.count
                cell:EnableMouse(itemID ~= nil)
                Place(cell, currencyWidth + totalWidth + (index-1)*characterWidth, characterWidth)
            end
            for id, cell in pairs(row.cells) do if not shown[id] then cell:Hide() end end
            row:Show()
        end
    end
    for index = count + 1, #parent.matrixRows do parent.matrixRows[index]:Hide() end
    parent.matrixRowCount = count
    parent.matrixContent:SetSize(width, math.max(1, count * 30))
    parent.matrixScroll:SetContentHeight(count * 30)
end

function Page:GetMatrixPreferences()
    local saved = Addon.Store.db.settings.previewColumns
    local result = {money=saved.money ~= false}
    for itemID in pairs(Addon.Store:Items()) do
        local key = "item:" .. itemID
        result[key] = saved[key] == true
    end
    return result
end

function Page:Refresh(parent, context)
    if context.preview then self:RefreshMatrix(parent, context); return end
    if parent.matrixHeader then parent.matrixHeader:Hide(); parent.matrixScroll:Hide() end
    parent.heading:Show(); parent.status:Show()
    if parent.itemPreview~=context.preview then parent.itemScroll:SetVerticalScroll(0) end
    parent.itemPreview=context.preview
    local id = Core.Characters:GetCurrentID()
    local character = context.characters and context.characters[1]
    if character and character.id ~= id then character = nil end
    local snapshot, state
    if character then snapshot, state = Addon.Store:Get(id) end
    parent.heading:SetText(character and Core.Characters:FormatName(character, { realmMode = "full" }) or Addon:T("FOREVER.CURRENT"))
    parent.status:SetText(StatusText(state))
    parent.refresh:SetShown(not context.preview)
    parent.refresh:SetState(Addon.Scanner.inWorld and id and "default" or "disabled")
    local show = false
    local fields = context.fields or self:Fields()
    for _, field in ipairs(fields) do if field.id == "money" then show = true end end
    parent.balanceTitle:SetText(Addon:T("FOREVER.BALANCE")); parent.balanceTitle:SetShown(show)
    local balance = Addon:T("FOREVER.NO_BALANCE")
    if snapshot then
        balance = context.preview and self:Format(snapshot.moneyCopper) or FormatCoinIcons(snapshot.moneyCopper)
    end
    parent.balance:SetText(balance); parent.balance:SetShown(show)
    local showSession = show and not context.preview
    parent.sessionTitle:SetShown(showSession)
    parent.sessionChange:SetShown(showSession)
    if showSession then
        local change = Addon.Store:GetSessionChange(id, snapshot, state)
        local value = Addon:T("FOREVER.SESSION_UNAVAILABLE")
        local color = Theme.Colors.muted
        if change == 0 then
            value, color = Addon:T("FOREVER.SESSION_UNCHANGED"), Theme.Colors.text
        elseif change then
            local key = change > 0 and "FOREVER.SESSION_GAIN" or "FOREVER.SESSION_LOSS"
            value = Addon:T(key, FormatCoinIcons(math.abs(change)))
            color = change > 0 and Theme.Colors.accent or Theme.Colors.warning
        end
        parent.sessionChange:SetText(value)
        parent.sessionChange:SetTextColor(unpack(color))
    end
    RenderItems(parent, fields, character and id or nil, showSession and -253 or show and -174 or -96, context.preview)
    parent.renderedSnapshot = snapshot
end
function Page:Register()
    local ok, err = Core.AccountView:RegisterPage(Addon.NAME, { id = Addon.PAGE_ID,
        title = Addon:T("FOREVER.TITLE"), fields = self:Fields(), defaultEnabled = true, previewEnabled = true,
        GetFieldDefinitions = function() return Page:Fields() end,
        settings = { title = Addon:T("FOREVER.TITLE"), description = Addon:T("FOREVER.CUSTOM_HELP"),
            CreateSettingsPanel = function(parent, context) return Addon.CustomItems:CreateSettingsPanel(parent, context) end },
        scope = {mode="realms", previewOnly=true},
        GetPreviewFieldDefinitions = function()
            local fields = Page:Fields()
            for _, field in ipairs(fields) do field.defaultVisible = field.id == "money" end
            return fields
        end,
        GetPreviewFields = function() return Page:GetMatrixPreferences() end,
        SetPreviewFieldVisible = function(id, visible)
            if type(id) ~= "string" then return false end
            if id ~= "money" then
                local itemID = tonumber(id:match("^item:(%d+)$"))
                local currencyID = tonumber(id:match("^currency:(%d+)$"))
                if not (itemID and id == "item:" .. itemID and Addon.Store:Items()[itemID])
                    and not (currencyID and id == "currency:" .. currencyID and Addon.Store:GetNativeDirectory()[currencyID]) then
                    return false
                end
            end
            Addon.Store.db.settings.previewColumns[id] = visible == true; Addon:NotifyChanged(); return true
        end,
        HasCharacterSnapshot = function(character)
            local db, id = Addon.Store.db, character.id
            local nativeChars = db.nativeDiscovery and db.nativeDiscovery.characters
            return db.characters[id] ~= nil
                or (db.itemSnapshots or {})[id] ~= nil
                or (nativeChars and nativeChars[id] ~= nil and next(nativeChars[id]) ~= nil)
        end,
        GetEligibleCharacters = function(characters, context)
            local result = {}
            for _, character in ipairs(characters or {}) do
                local db, id = Addon.Store.db, character.id
                local nativeChars = db.nativeDiscovery and db.nativeDiscovery.characters
                local hasSnapshot = db.characters[id] or (db.itemSnapshots or {})[id]
                    or (nativeChars and nativeChars[id] ~= nil and next(nativeChars[id]) ~= nil)
                if (context.preview and hasSnapshot) or (not context.preview and id == Core.Characters:GetCurrentID()) then
                    result[#result + 1] = character
                end
            end
            return result
        end,
        GetSurfaceMetrics = function(context)
            local preview = context and context.preview
            if preview then
                local rows = 0
                for _, shown in pairs(Page:GetMatrixPreferences()) do if shown then rows = rows + 1 end end
                return {minContentWidth=420, naturalContentWidth=302 + #context.characters * 112,
                    minContentHeight=80, naturalContentHeight=48 + math.max(1, rows) * 30}
            end
            local items = 0
            for _, field in ipairs(context and context.fields or Page:Fields()) do
                if field.id:match("^item:") then items = items + 1 end
            end
            local toolbar = not preview and items > 0 and 36 or 0
            local extra = items > 0 and 26 + math.min(6, items) * 28 or 0
            return { minContentWidth = 420, naturalContentWidth = 640,
                minContentHeight = (preview and 180 or 253) + (items > 0 and 64 or 0) + toolbar,
                naturalContentHeight = (preview and 220 or 265) + extra + toolbar }
        end,
        Create = function(parent) Page:Create(parent) end,
        Refresh = function(parent, context) Page:Refresh(parent, context) end })
    if not ok then return nil, err end
    return Core.Entry:RegisterBusinessEntry(Addon.NAME, { id = "ycu", brokerName = "YiboCurrency", pageID = Addon.PAGE_ID,
        text = Addon:T("FOREVER.TITLE"), icon = "Interface\\AddOns\\YiboCurrency\\Media\\YiboCurrencyIcon",
        defaultChannels = { minimap = false, broker = false, builtinBar = false } })
end
