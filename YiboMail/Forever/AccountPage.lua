local Addon, Core = _G.YiboMail, _G.YiboCore
local Page, Theme, PAGE_ID = { pendingItems = {} }, Core.UITheme, "mail-inbox"
Addon.AccountPage = Page
local function Fields()
    return { { id = "sender", title = Addon:T("FOREVER.SENDER"), defaultVisible = true },
        { id = "subject", title = Addon:T("FOREVER.SUBJECT"), defaultVisible = true },
        { id = "attachments", title = Addon:T("FOREVER.ATTACHMENTS"), defaultVisible = true },
        { id = "money", title = Addon:T("FOREVER.MONEY"), defaultVisible = true },
        { id = "cod", title = Addon:T("FOREVER.COD"), defaultVisible = true } }
end
local function SummaryFields()
    return {
        {id="character", title=Addon:T("FOREVER.SUMMARY_CHARACTER"), weight=2.4},
        {id="mailCount", title=Addon:T("FOREVER.SUMMARY_MAIL"), weight=1},
        {id="attachmentCount", title=Addon:T("FOREVER.SUMMARY_ATTACHMENTS"), weight=1},
        {id="claimable", title=Addon:T("FOREVER.SUMMARY_MONEY"), weight=1.15},
        {id="expiry", title=Addon:T("FOREVER.SUMMARY_EXPIRY"), weight=1.2},
        {id="updated", title=Addon:T("FOREVER.SUMMARY_UPDATED"), weight=1.8},
    }
end

function Page:Status()
    if Addon.Scanner.pending then return Addon:T("FOREVER.PENDING") end
    local current = Core.Characters:GetCurrentID()
    local state = current and Addon.Items:GetState(current)
    local labels = { ["not-yet-scanned"] = Addon:T("FOREVER.UNSEEN"), stale = Addon:T("FOREVER.STALE"),
        error = Addon:T("FOREVER.ERROR"), known = Addon:T("FOREVER.KNOWN"), ["known-empty"] = Addon:T("FOREVER.EMPTY") }
    return labels[state and state.status or "not-yet-scanned"] or labels["not-yet-scanned"]
end
function Page:Create(parent)
    parent.heading = Theme:CreateText(parent, Theme.Font.section, Theme.Colors.text)
    parent.heading:SetPoint("TOPLEFT", 12, -10); parent.heading:SetPoint("RIGHT", -130, 0); parent.heading:SetHeight(26)
    parent.refresh = Theme:CreateButton(parent, 100, Addon:T("FOREVER.REFRESH"))
    parent.refresh:SetPoint("TOPRIGHT", -12, -10)
    parent.refresh:SetScript("OnClick", function() if Addon.Scanner:IsOpen() then Addon.Scanner:Scan(true) end end)
    parent.status = Theme:CreateText(parent, Theme.Font.assist, Theme.Colors.muted)
    parent.status:SetPoint("TOPLEFT", 12, -49); parent.status:SetPoint("RIGHT", -12, 0); parent.status:SetHeight(28)
    local toolbar = CreateFrame("Frame", nil, parent)
    parent.toolbar = toolbar
    toolbar:SetPoint("TOPLEFT", 12, -83); toolbar:SetPoint("TOPRIGHT", -12, -83); toolbar:SetHeight(30)
    local function FilterChanged()
        parent.scroll:SetVerticalScroll(0)
        Core.AccountView:NotifyPageChanged(PAGE_ID)
    end
    parent.search = Theme:CreateInput(toolbar, {
        width = 290, height = 28, maxLetters = 100, clearable = true,
        placeholder = Addon:T("FOREVER.SEARCH_INBOX"),
        OnChanged = FilterChanged,
    })
    parent.search:SetPoint("LEFT")
    parent.filter = Theme:CreateDropdown(toolbar, 185)
    parent.filter:SetPoint("LEFT", parent.search, "RIGHT", 8, 0)
    parent.filter:SetOptions({
        { value = "all", label = Addon:T("UI.TEXT_0138") },
        { value = "items", label = Addon:T("UI.TEXT_0205") },
        { value = "money", label = Addon:T("UI.TEXT_0204") },
        { value = "cod", label = Addon:T("UI.TEXT_0110") },
        { value = "returned", label = Addon:T("FOREVER.FILTER_RETURNED") },
        { value = "urgent", label = Addon:T("UI.TEXT_0084") },
    })
    parent.filter:SetValue("all")
    parent.filter:SetOnValueChanged(FilterChanged)
    parent.matchCount = Theme:CreateText(toolbar, Theme.Font.assist, Theme.Colors.muted)
    parent.matchCount:SetPoint("LEFT", parent.filter, "RIGHT", 10, 0); parent.matchCount:SetPoint("RIGHT")
    parent.header = CreateFrame("Frame", nil, parent); parent.header:SetPoint("TOPLEFT", 12, -84); parent.header:SetPoint("TOPRIGHT", -12, -84); parent.header:SetHeight(26)
    parent.scroll = Theme:CreateScrollFrame(parent); parent.scroll:SetPoint("TOPLEFT", 12, -114); parent.scroll:SetPoint("BOTTOMRIGHT", -12, 10)
    parent.content = CreateFrame("Frame", nil, parent.scroll); parent.scroll:SetScrollChild(parent.content)
    parent.labels, parent.rows = {}, {}
    for _, field in ipairs(Fields()) do parent.labels[field.id] = Theme:CreateText(parent.header, Theme.Font.assist, Theme.Colors.muted) end
end
local function Columns(container, labels, columns)
    for _, label in pairs(labels) do label:Hide() end
    for _, column in ipairs(columns) do
        local label = labels[column.id]; label:ClearAllPoints(); label:SetPoint("TOPLEFT", container, "TOPLEFT", column.x, 0)
        label:SetSize(column.width, 30); label:Show()
    end
end
local function ItemName(itemID)
    local info = Core.ItemResolver:GetInfo(itemID)
    if info and info.state == "unloaded" and not Page.pendingItems[itemID] then
        Page.pendingItems[itemID] = true
        Core.ItemResolver:Request(itemID, function(result)
            Page.pendingItems[itemID] = nil
            if result and result.state == "ready" then Core.AccountView:NotifyPageChanged(PAGE_ID) end
        end)
    end
    return info and info.name
end
local function ItemSummary(mail)
    local parts = {}
    for _, item in ipairs(mail.attachments) do
        parts[#parts + 1] = Addon:T("FOREVER.ITEM_COUNT", ItemName(item.itemID) or Addon:T("FOREVER.ITEM_ID", item.itemID), item.quantity)
    end
    return #parts > 0 and table.concat(parts, ", ") or Addon:T("FOREVER.NO_ITEMS")
end
local function MatchesKind(mail, kind, now)
    if kind == "all" then return true end
    if kind == "items" then return #mail.attachments > 0 end
    if kind == "money" then return mail.money > 0 end
    if kind == "cod" then return mail.cod > 0 end
    if kind == "returned" then return mail.wasReturned == true or mail.mailType == "returned" end
    local expires = tonumber(mail.expiresAtEstimate)
    return expires and expires > now and expires - now <= 3 * 86400
end
local function MatchesText(mail, query, names)
    if query == "" or (mail.sender or ""):lower():find(query, 1, true) or mail.subject:lower():find(query, 1, true) then return true end
    for _, item in ipairs(mail.attachments) do
        local itemID = item.itemID
        if tostring(itemID):find(query, 1, true) then return true end
        if names[itemID] == nil then names[itemID] = (ItemName(itemID) or ""):lower() end
        if names[itemID]:find(query, 1, true) then return true end
    end
    return false
end
local function Summarize(snapshot, now)
    local summary = {mailCount=0, attachmentCount=0, claimable=0, expired=0, urgent=0, soon=0}
    for _, key in ipairs(snapshot.visibleKeys) do
        local mail = snapshot.records[key]
        if mail then
            summary.mailCount = summary.mailCount + 1
            summary.attachmentCount = summary.attachmentCount + #mail.attachments
            if mail.cod == 0 then summary.claimable = summary.claimable + mail.money end
            local expires = tonumber(mail.expiresAtEstimate)
            if expires and expires > 0 then
                local remaining = expires - now
                if remaining <= 0 then
                    summary.expired = summary.expired + 1
                else
                    summary.earliest = math.min(summary.earliest or remaining, remaining)
                    if remaining <= 3 * 86400 then summary.urgent = summary.urgent + 1
                    elseif remaining <= 7 * 86400 then summary.soon = summary.soon + 1 end
                end
            end
        end
    end
    return summary
end

function Page:RefreshSummary(parent, context)
    if not parent.summaryHeader then
        parent.summaryHeader = CreateFrame("Frame", nil, parent)
        parent.summaryHeader:SetPoint("TOPLEFT", 12, -39)
        parent.summaryHeader:SetHeight(26)
        parent.summaryLabels, parent.summaryRows = {}, {}
        parent.openInbox = Theme:CreateButton(parent, 142, Addon:T("FOREVER.SUMMARY_OPEN"))
        parent.openInbox:SetPoint("TOPRIGHT", -12, -5)
        parent.openInbox:SetScript("OnClick", function() Core.AccountView:Toggle(PAGE_ID) end)
        parent.expiryNotice = Theme:CreateText(parent, Theme.Font.assist, Theme.Colors.warning)
        parent.expiryNotice:SetPoint("TOPLEFT", 12, -5)
        parent.expiryNotice:SetPoint("TOPRIGHT", -164, -5)
        parent.expiryNotice:SetHeight(28)
    end
    parent.heading:Hide(); parent.status:Hide(); parent.refresh:Hide(); parent.toolbar:Hide(); parent.header:Hide()
    for _, row in ipairs(parent.rows) do row:Hide() end
    parent.openInbox:Show(); parent.summaryHeader:Show()
    parent.scroll:SetPoint("TOPLEFT", 12, -65)
    local fields = SummaryFields()
    local width = math.max(1, (context.surfaceAvailableWidth or parent.scroll:GetWidth()) - 36)
    local columns, x, total = {}, 0, 0
    local choices = Addon.db.settings.previewColumns
    for _, field in ipairs(fields) do
        if field.id == "character" or choices[field.id] ~= false then total = total + field.weight end
    end
    for _, field in ipairs(fields) do
        if field.id == "character" or choices[field.id] ~= false then
            local w = width * field.weight / total
            columns[#columns + 1] = {id=field.id, x=x, width=math.max(1,w-6)}
            x = x + w
            local label = parent.summaryLabels[field.id] or Theme:CreateText(parent.summaryHeader, Theme.Font.assist, Theme.Colors.muted)
            parent.summaryLabels[field.id] = label
            label:SetText(field.title)
        end
    end
    Columns(parent.summaryHeader, parent.summaryLabels, columns)
    local now, count, expired, urgent, soon = Addon:Now(), 0, 0, 0, 0
    local current = Core.Characters:GetCurrentID()
    local earliest
    for _, character in ipairs(context.characters or {}) do
        local snapshot = Addon.db.byCharacter[character.id]
        if snapshot and snapshot.coverage.observedAt then
            count = count + 1
            local summary = Summarize(snapshot, now)
            expired = expired + summary.expired
            urgent = urgent + summary.urgent
            soon = soon + summary.soon
            if summary.earliest then earliest = math.min(earliest or summary.earliest, summary.earliest) end
            local row = parent.summaryRows[count]
            if not row then
                row = CreateFrame("Frame", nil, parent.content, "BackdropTemplate")
                row:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8x8"})
                row.labels = {}
                for _, field in ipairs(fields) do
                    row.labels[field.id] = Theme:CreateText(row, Theme.Font.body, Theme.Colors.text)
                    row.labels[field.id]:SetWordWrap(false)
                end
                parent.summaryRows[count] = row
            end
            local state = character.id == current and Addon.Items:GetState(character.id)
            local live = state and (state.status == "known" or state.status == "known-empty")
            local ok, stamp = pcall(date, "%m-%d %H:%M", snapshot.coverage.observedAt)
            if not ok or not stamp then stamp = "—" end
            row.labels.character:SetText(Core.Characters:FormatName(character, {realmMode="full"}))
            row.labels.mailCount:SetText(tostring(summary.mailCount))
            row.labels.attachmentCount:SetText(tostring(summary.attachmentCount))
            row.labels.claimable:SetText(summary.claimable > 0 and string.format("%.0f", summary.claimable) or "—")
            row.labels.expiry:SetText(summary.earliest and Addon:T("FOREVER.SUMMARY_DAYS", summary.earliest / 86400) or "—")
            row.labels.updated:SetText(live and stamp or Addon:T("FOREVER.SUMMARY_HISTORY", stamp))
            row:SetPoint("TOPLEFT", 0, -(count - 1) * 30)
            row:SetSize(width, 30)
            row:SetBackdropColor(unpack(count % 2 == 0 and Theme.Colors.alternate or Theme.Colors.row))
            Columns(row, row.labels, columns)
            row:Show()
        end
    end
    for index = count + 1, #parent.summaryRows do parent.summaryRows[index]:Hide() end
    parent.expiryNotice:SetText(count == 0 and Addon:T("FOREVER.UNSEEN")
        or expired > 0 and Addon:T("FOREVER.SUMMARY_EXPIRED", expired)
        or urgent > 0 and Addon:T("FOREVER.SUMMARY_URGENT", urgent, earliest / 86400)
        or soon > 0 and Addon:T("FOREVER.SUMMARY_SOON", soon, earliest / 86400) or "")
    parent.expiryNotice:Show()
    parent.summaryHeader:SetShown(count > 0)
    parent.content:SetSize(width, math.max(1, count * 30))
    parent.scroll:SetContentHeight(count * 30)
end

function Page:Refresh(parent, context)
    if parent.wasPreview ~= context.preview then parent.scroll:SetVerticalScroll(0) end
    parent.wasPreview = context.preview
    if context.preview then self:RefreshSummary(parent, context); return end
    if parent.summaryHeader then
        parent.summaryHeader:Hide(); parent.openInbox:Hide(); parent.expiryNotice:Hide()
        for _, row in ipairs(parent.summaryRows) do row:Hide() end
    end
    parent.heading:Show(); parent.status:Show(); parent.header:Show()
    local character = context.characters and context.characters[1]
    local snapshot = character and Addon.db.byCharacter[character.id]
    local mails, names, total = {}, {}, 0
    local query = context.preview and "" or parent.search:GetText():match("^%s*(.-)%s*$"):lower()
    local kind = context.preview and "all" or parent.filter.value
    local now = kind == "urgent" and Addon:Now()
    for _, key in ipairs(snapshot and snapshot.visibleKeys or {}) do
        local mail = snapshot.records[key]
        if mail then
            total = total + 1
            if MatchesKind(mail, kind, now) and MatchesText(mail, query, names) then mails[#mails + 1] = mail end
        end
    end
    parent.toolbar:SetShown(not context.preview)
    if not context.preview then
        local label = ""
        if total > 0 then
            label = #mails > 0 and Addon:T("FOREVER.MATCH_COUNT", #mails, total) or Addon:T("FOREVER.NO_MATCH")
        end
        parent.matchCount:SetText(label)
    end
    local headerY = context.preview and -84 or -121
    parent.header:SetPoint("TOPLEFT", 12, headerY); parent.header:SetPoint("TOPRIGHT", -12, headerY)
    parent.scroll:SetPoint("TOPLEFT", 12, headerY - 30)
    parent.heading:SetText(character and Core.Characters:FormatName(character, { realmMode = "full" }) or Addon:T("FOREVER.CURRENT"))
    parent.status:SetText(self:Status()); parent.refresh:SetShown(not context.preview)
    parent.refresh:SetState(Addon.Scanner:IsOpen() and "default" or "disabled")
    local width = math.max(320, parent.scroll:GetWidth() - 20)
    parent.content:SetWidth(width)
    local visible, columns, x, weight = context.fields or Fields(), {}, 0, 0
    local weights = { sender = 1.3, subject = 2, attachments = 2.6, money = 1.1, cod = 1.1 }
    for _, field in ipairs(visible) do weight = weight + (weights[field.id] or 1) end
    for _, field in ipairs(visible) do
        local w = width * (weights[field.id] or 1) / math.max(1, weight)
        columns[#columns + 1] = { id = field.id, x = x, width = math.max(1, w - 8) }; x = x + w
        parent.labels[field.id]:SetText(field.title)
    end
    Columns(parent.header, parent.labels, columns)
    for index, mail in ipairs(mails) do
        local row = parent.rows[index]
        if not row then
            row = CreateFrame("Button", nil, parent.content, "BackdropTemplate"); row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" }); row.labels = {}
            for _, field in ipairs(Fields()) do row.labels[field.id] = Theme:CreateText(row, Theme.Font.body, Theme.Colors.text) end
            row:SetScript("OnEnter", function(self)
                if not self.mail then return end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:AddLine(self.mail.subject)
                GameTooltip:AddLine(Addon:T("FOREVER.SENDER_VALUE", self.mail.sender or Addon:T("FOREVER.UNKNOWN_SENDER")))
                GameTooltip:AddLine(ItemSummary(self.mail), 1, 1, 1, true); GameTooltip:Show()
            end)
            row:SetScript("OnLeave", function() GameTooltip:Hide() end)
            parent.rows[index] = row
        end
        row.mail = mail; row:ClearAllPoints(); row:SetPoint("TOPLEFT", 0, -(index - 1) * 30); row:SetSize(width, 30)
        row:SetBackdropColor(unpack(index % 2 == 0 and Theme.Colors.alternate or Theme.Colors.row))
        row.labels.sender:SetText(mail.sender or Addon:T("FOREVER.UNKNOWN_SENDER")); row.labels.subject:SetText(mail.subject)
        row.labels.attachments:SetText(ItemSummary(mail)); row.labels.money:SetText(string.format("%.0f", mail.money)); row.labels.cod:SetText(string.format("%.0f", mail.cod))
        Columns(row, row.labels, columns); row:Show()
    end
    for index = #mails + 1, #parent.rows do parent.rows[index].mail = nil; parent.rows[index]:Hide() end
    parent.content:SetHeight(math.max(1, #mails * 30)); parent.scroll:SetContentHeight(#mails * 30)
    parent.renderedMails = mails
end
function Page:Register()
    local page, err = Core.AccountView:RegisterPage(Addon.NAME, { id = PAGE_ID, title = Addon:T("FOREVER.TITLE"),
        fields = Fields(), defaultEnabled = true, previewEnabled = true,
        scope = {mode = "realms", previewOnly = true},
        GetPreviewFields = function() return Addon.db.settings.previewColumns end,
        GetPreviewFieldDefinitions = function()
            local fields = SummaryFields()
            table.remove(fields, 1)
            for _, field in ipairs(fields) do field.defaultVisible = true end
            return fields
        end,
        SetPreviewFieldVisible = function(id, visible)
            for _, field in ipairs(SummaryFields()) do
                if field.id == id and id ~= "character" then
                    Addon.db.settings.previewColumns[id] = visible == true
                    Core.AccountView:NotifyPageChanged(PAGE_ID)
                    return true
                end
            end
            return false
        end,
        HasCharacterSnapshot = function(character)
            local snapshot = Addon.db.byCharacter[character.id]
            return snapshot and snapshot.coverage.observedAt ~= nil
        end,
        GetEligibleCharacters = function(characters, context)
            local current, result = Core.Characters:GetCurrentID(), {}
            for _, character in ipairs(characters) do
                local snapshot = Addon.db.byCharacter[character.id]
                if (context.preview or character.id == current) and snapshot and snapshot.coverage.observedAt then result[#result + 1] = character end
            end
            return result
        end,
        GetSurfaceMetrics = function(context)
            if context.preview then
                return {minContentWidth=500, naturalContentWidth=655, minContentHeight=94,
                    naturalContentHeight=75 + math.max(1, #context.characters) * 30}
            end
            return {minContentWidth=700, naturalContentWidth=1040, minContentHeight=237, naturalContentHeight=477}
        end,
        Create = function(parent) Page:Create(parent) end, Refresh = function(parent, context) Page:Refresh(parent, context) end })
    if not page then return nil, err end
    return Core.Entry:RegisterBusinessEntry(Addon.NAME, { id = "yma", brokerName = "YiboMail", pageID = PAGE_ID, text = Addon:T("FOREVER.TITLE"),
        icon = "Interface\\AddOns\\YiboMail\\Media\\YiboMailIcon", defaultChannels = { minimap = false, broker = false, builtinBar = false } })
end
