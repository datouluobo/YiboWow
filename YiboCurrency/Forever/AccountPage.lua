local Addon, Core = _G.YiboCurrency, _G.YiboCore or {}
local Page, Theme = {}, Core.UITheme; Addon.AccountPage = Page
function Addon:GetCatalog()
    local ids, items, custom = {}, self.Store:Items(), {}
    for id in pairs(items) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do
        local info = Core.ItemResolver:GetInfo(id)
        custom[#custom + 1] = { itemID = id, title = info.name or items[id], icon = info.icon }
    end
    return self:BuildDiscoveredCatalog(self.Catalog, self.Store:GetNativeDirectory(), custom, self.NativeCatalog)
end

function Page:Fields()
    local catalog, visible = Addon:GetCatalog(), {}
    for _, entry in ipairs(catalog) do
        if entry.source == "currency" then visible[entry.id] = false end
    end
    return Addon:BuildDisplayFields(catalog, visible)
end

function Addon:IsMonitored(entry)
    local saved = self:GetSettings().previewColumns[entry.id]
    if saved == nil then return entry.id == "money" end
    return saved == true
end

function Addon:GetIcon(entry)
    return entry.icon or "Interface\\Icons\\INV_Misc_QuestionMark"
end

function Addon:GetProjectionSnapshots(character)
    return { money = self:ReadArchiveMoney(character.id) }
end

function Addon:GetProjectionCharacterMeta(character, projection)
    local money = projection.snapshots[character.id].money
    return money.observedAt or 0, money.state
end

function Addon:GetValue(character, entry, projection)
    local id = character.id
    local quantity, state
    if entry.source == "item" then
        local fresh
        quantity, fresh = self.Store:GetCachedItemCount(id, entry.itemID)
        state = fresh and "known" or "stale"
    elseif entry.source == "currency" then
        quantity, state = self.Store:GetNativeCurrency(id, entry.currencyID)
        if id == Core.Characters:GetCurrentID() and self.Scanner.inWorld then
            if state ~= "known" then return nil, "unknown" end
        elseif state == "known" then
            state = "stale"
        end
    else
        local money = projection and projection.snapshots[id].money or self:ReadArchiveMoney(id)
        quantity, state = money.value, money.state
    end
    if quantity ~= nil then return { quantity = quantity }, state end
    return nil, "unknown"
end

function Addon:ValueState(value, state)
    if not value then return "unknown" end
    return state == "known" and "known" or "bank"
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

local function ShowItemDetail(row, characterID, itemID, title, count)
    GameTooltip:SetOwner(row,"ANCHOR_RIGHT")
    GameTooltip:ClearLines()
    GameTooltip:AddLine(title)
    GameTooltip:AddDoubleLine(Addon:T("FOREVER.CUSTOM_CARRIED"),count)
    local labels={equipment="FOREVER.CUSTOM_VAULT_EQUIPPED",bank="FOREVER.CUSTOM_VAULT_BANK"}
    for _, detail in ipairs(Addon.CustomItems:GetVaultDetails(characterID, itemID) or {}) do
        GameTooltip:AddDoubleLine(Addon:T(labels[detail.source]),ItemCountText(detail.count,detail.fresh))
    end
    GameTooltip:Show()
end

function Addon:ShowCurrencyDetail(row, character, entry)
    if not character or not entry.itemID then return end
    local value, state = self:ProjectionValue(row.projection, character, entry)
    ShowItemDetail(row, character.id, entry.itemID, entry.title,
        ItemCountText(value and value.quantity, state == "known"))
    return true
end

function Addon:FormatCompact(value, entry)
    if not value then return self:T("FOREVER.CUSTOM_UNKNOWN") end
    if entry and entry.source == "money" then return Page:Format(value.quantity) end
    return string.format("%.0f", value.quantity)
end

function Addon:FormatCell(value, state, entry)
    local text = self:FormatCompact(value, entry)
    if value and state ~= "known" then return self:T("FOREVER.CUSTOM_STALE", text), "bank" end
    return text, self:ValueState(value, state)
end

Addon.FormatExact = Addon.FormatCompact

function Addon:FormatLimitCell(value, state, entry, formatter)
    return formatter(self, value, state, entry)
end

function Addon:FormatProjectionTotal(total, entry)
    if entry.totalAllowed == false then return "—" end
    local value = total.confirmed > 0 and { quantity = total.quantity } or nil
    local text = self:FormatCell(value, total.complete and "known" or "stale", entry)
    return text
end

local function RenderBalances(parent, entries, character, top, projection)
    local query = parent.itemSearch:GetText():match("^%s*(.-)%s*$"):lower()
    local byID = query:match("^%d+$") and tonumber(query)
    local matches, total = {}, 0
    local hasNative = false
    local items = Addon.Store:Items()
    for _, entry in ipairs(entries) do
        local itemID = entry.itemID
        if entry.source == "currency" then
            hasNative = true
            matches[#matches + 1] = entry
        elseif itemID then
            total = total + 1
            if query == "" or byID == itemID or (not byID
                and (entry.title:lower():find(query, 1, true) or items[itemID]:lower():find(query, 1, true))) then
                matches[#matches + 1] = entry
            end
        end
    end
    local id = character and character.id
    local width = math.max(1, parent.itemScroll:GetWidth() - 20)
    local height = Addon:RenderCurrencyTable(parent.itemScroll, parent.itemContent, parent.itemRows, matches, width, 28, function(row, entry)
        if not row.name then
            row.name = Theme:CreateText(row, Theme.Font.body, Theme.Colors.text)
            row.name:SetPoint("LEFT", 8, 0)
            row.name:SetWordWrap(false)
            row.count = Theme:CreateText(row, Theme.Font.body, Theme.Colors.text, "RIGHT")
            row.count:SetWidth(112)
            row.count:SetPoint("RIGHT", -112, 0)
            row.name:SetPoint("RIGHT", row.count, "LEFT", -8, 0)
            row.change = Theme:CreateText(row, Theme.Font.body, Theme.Colors.muted, "RIGHT")
            row.change:SetPoint("RIGHT", -8, 0)
            row.change:SetWidth(96)
            row:SetScript("OnLeave", HideItemDetail)
            row:SetScript("OnHide", HideItemDetail)
        end
        if row.itemID ~= entry.itemID or row.characterID ~= id then HideItemDetail(row) end
        row.itemID, row.characterID = entry.itemID, id
        row:SetScript("OnEnter", entry.itemID and function()
            ShowItemDetail(row, id, entry.itemID, row.name:GetText(), row.count:GetText())
        end or nil)
        local value, state, change
        if character then
            value, state = Addon:ProjectionValue(projection, character, entry)
            if entry.itemID then
                local _, _, sessionChange = Addon.Store:GetItemCount(id, entry.itemID)
                change = sessionChange
            end
        end
        row.name:SetText(entry.itemID and Addon:T("FOREVER.CUSTOM_ITEM_LABEL", entry.title, tostring(entry.itemID))
            or ("|T" .. tostring(Addon:GetIcon(entry)) .. ":16:16|t " .. entry.title))
        local countText = Addon:FormatCell(value, state, entry)
        row.count:SetText(countText)
        row.count:SetTextColor(unpack(state == "known" and Theme.Colors.text or Theme.Colors.muted))
        local label = change and string.format(change > 0 and "%+.0f" or "%.0f", change) or Addon:T("FOREVER.CUSTOM_NO_SESSION")
        local color = change and (change > 0 and Theme.Colors.accent or change < 0 and Theme.Colors.warning) or Theme.Colors.muted
        row.change:SetText(label)
        row.change:SetTextColor(unpack(color))
    end)

    parent.itemSearch:SetShown(total > 0)
    parent.itemMatches:SetShown(total > 0)
    if total > 0 then
        parent.itemSearch:SetPoint("TOPLEFT", 12, top)
        parent.itemMatches:ClearAllPoints()
        parent.itemMatches:SetPoint("TOPLEFT", parent.itemSearch, "TOPRIGHT", 12, 0)
        parent.itemMatches:SetPoint("TOPRIGHT", -12, top)
        parent.itemMatches:SetText(#matches == 0 and Addon:T("FOREVER.CUSTOM_NO_MATCH")
            or Addon:T("FOREVER.CUSTOM_MATCHES", #matches, total))
        top = top - 36
    end
    parent.itemTitle:ClearAllPoints()
    parent.itemTitle:SetPoint("TOPLEFT", 12, top)
    parent.itemTitle:SetPoint("RIGHT", -12, 0)
    local titleKey = hasNative and (total > 0 and "FOREVER.CURRENCIES_AND_ITEMS" or "CURRENCY.STANDARD_CURRENCY_F0C941")
        or "FOREVER.CUSTOM_SECTION"
    parent.itemTitle:SetText(Addon:T(titleKey))
    parent.itemTitle:SetShown(height > 0)
    parent.itemChangeTitle:SetPoint("TOPRIGHT", -40, top)
    parent.itemChangeTitle:SetShown(height > 0)
    parent.itemScroll:ClearAllPoints()
    parent.itemScroll:SetPoint("TOPLEFT", 12, top - 26)
    parent.itemScroll:SetPoint("BOTTOMRIGHT", -12, 10)
    parent.itemScroll:SetShown(height > 0)
end

function Page:Refresh(host, context)
    local preview = context.preview == true
    host.currencyMain:SetShown(not preview)
    host.currencyPreview:SetShown(preview)

    if preview then
        local parent = host.currencyPreview
        if not parent.currencyHeader then Addon:CreateCurrencyPage(parent) end
        Addon:RefreshCurrencyPage(parent, context)
        return
    end

    local parent = host.currencyMain
    if not parent.heading then self:Create(parent) end
    local id = Core.Characters:GetCurrentID()
    local character = context.characters and context.characters[1]
    if character and character.id ~= id then character = nil end
    local snapshot, state
    if character then snapshot, state = Addon.Store:Get(id) end
    parent.heading:SetText(character and Core.Characters:FormatName(character, { realmMode = "full" }) or Addon:T("FOREVER.CURRENT"))
    parent.status:SetText(StatusText(state))
    parent.refresh:Show()
    parent.refresh:SetState(Addon.Scanner.inWorld and id and "default" or "disabled")
    local moneyEntry
    local entries = Addon:GetDisplayCatalog(false, context.fields)
    for _, entry in ipairs(entries) do
        if entry.source == "money" then moneyEntry = entry end
    end
    local projection = Addon:GetCurrencyProjection(context, character and { character } or {}, entries)
    local show = moneyEntry ~= nil
    parent.balanceTitle:SetText(Addon:T("FOREVER.BALANCE")); parent.balanceTitle:SetShown(show)
    local balance = Addon:T("FOREVER.NO_BALANCE")
    if moneyEntry and character then
        local value = Addon:ProjectionValue(projection, character, moneyEntry)
        if value then balance = FormatCoinIcons(value.quantity) end
    end
    parent.balance:SetText(balance); parent.balance:SetShown(show)
    if show and character and Addon.GoalTargets.ref then
        local hit = parent.balanceGoal or CreateFrame("Button", nil, parent)
        parent.balanceGoal = hit
        hit:SetAllPoints(parent.balance)
        Addon.GoalTargets:Bind(hit, moneyEntry.id, character.id)
        Theme:BindTooltip(hit, moneyEntry.title, { Addon:T("UI.GOAL_HINT", Core.BusinessItemActions:GestureLabel()) })
        hit:Show()
    elseif parent.balanceGoal then
        parent.balanceGoal:Hide()
    end
    local showSession = show
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
    RenderBalances(parent, entries, character, showSession and -253 or -96, projection)
    parent.renderedSnapshot = snapshot
end
function Page:Register()
    local ok, err = Core.AccountView:RegisterPage(Addon.NAME, { id = Addon.PAGE_ID, columnPager = true,
        title = Addon:T("FOREVER.TITLE"), fields = self:Fields(), defaultEnabled = true, previewEnabled = true,
        GetFieldDefinitions = function() return Page:Fields() end,
        settings = { title = Addon:T("FOREVER.TITLE"), description = Addon:T("FOREVER.CUSTOM_HELP"),
            CreateSettingsPanel = function(parent, context) return Addon:CreateSettingsPanel(parent, context) end },
        scope = {mode="realms", previewOnly=true},
        GetPreviewFieldDefinitions = function()
            local fields = Page:Fields()
            for _, field in ipairs(fields) do field.defaultVisible = field.id == "money" end
            return fields
        end,
        GetPreviewFields = function()
            local result = {}
            for _, entry in ipairs(Addon:GetCatalog()) do result[entry.id] = Addon:IsMonitored(entry) end
            return result
        end,
        SetPreviewFieldVisible = function(id, visible)
            return Addon:SetCurrencyDisplay(id, "hover", visible)
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
            if preview then return Addon:GetCurrencySurfaceMetrics(context) end
            local rows, hasItems = 0, false
            for _, field in ipairs(context and context.fields or Page:Fields()) do
                if field.id ~= "money" then rows = rows + 1 end
                if field.id:match("^item:") then hasItems = true end
            end
            local toolbar = hasItems and 36 or 0
            local extra = rows > 0 and 26 + math.min(6, rows) * 28 or 0
            return { minContentWidth = 420, naturalContentWidth = 640,
                minContentHeight = 253 + (rows > 0 and 64 or 0) + toolbar,
                naturalContentHeight = 265 + extra + toolbar }
        end,
        Create = function(parent)
            -- Core reuses this page instance when switching between main and preview.
            parent.currencyMain = CreateFrame("Frame", nil, parent)
            parent.currencyMain:SetAllPoints(parent)
            parent.currencyPreview = CreateFrame("Frame", nil, parent)
            parent.currencyPreview:SetAllPoints(parent)
        end,
        Refresh = function(parent, context) Page:Refresh(parent, context) end })
    if not ok then return nil, err end
    return Core.Entry:RegisterBusinessEntry(Addon.NAME, { id = "ycu", brokerName = "YiboCurrency", pageID = Addon.PAGE_ID,
        text = Addon:T("FOREVER.TITLE"), icon = "Interface\\AddOns\\YiboCurrency\\Media\\YiboCurrencyIcon",
        defaultChannels = { minimap = false, broker = false, builtinBar = false } })
end
