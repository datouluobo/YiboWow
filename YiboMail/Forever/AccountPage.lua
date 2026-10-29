local Addon, Core = _G.YiboMail, _G.YiboCore
local Page, Theme = {}, Core.UITheme; Addon.AccountPage = Page
local function Fields()
    return { { id = "sender", title = Addon:T("FOREVER.SENDER"), defaultVisible = true },
        { id = "subject", title = Addon:T("FOREVER.SUBJECT"), defaultVisible = true },
        { id = "attachments", title = Addon:T("FOREVER.ATTACHMENTS"), defaultVisible = true },
        { id = "money", title = Addon:T("FOREVER.MONEY"), defaultVisible = true },
        { id = "cod", title = Addon:T("FOREVER.COD"), defaultVisible = true } }
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
local function ItemSummary(mail)
    local parts = {}
    for _, item in ipairs(mail.attachments) do
        local info = Core.ItemResolver:GetInfo(item.itemID)
        if info and info.state == "unloaded" and not Page.pendingItems[item.itemID] then
            Page.pendingItems[item.itemID] = true
            Core.ItemResolver:Request(item.itemID, function(result)
                Page.pendingItems[item.itemID] = nil
                if result and result.state == "ready" then Core.AccountView:NotifyPageChanged("mail-inbox") end
            end)
        end
        parts[#parts + 1] = Addon:T("FOREVER.ITEM_COUNT", info and info.name or Addon:T("FOREVER.ITEM_ID", item.itemID), item.quantity)
    end
    return #parts > 0 and table.concat(parts, ", ") or Addon:T("FOREVER.NO_ITEMS")
end
Page.pendingItems = {}
function Page:Refresh(parent, context)
    local character = context.characters and context.characters[1]
    local snapshot = character and Addon.db.byCharacter[character.id]
    local mails = {}
    for _, key in ipairs(snapshot and snapshot.visibleKeys or {}) do if snapshot.records[key] then mails[#mails + 1] = snapshot.records[key] end end
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
    local page, err = Core.AccountView:RegisterPage(Addon.NAME, { id = "mail-inbox", title = Addon:T("FOREVER.TITLE"),
        fields = Fields(), defaultEnabled = true, previewEnabled = true,
        GetPreviewFields = function() return Addon.db.settings.previewColumns end,
        GetEligibleCharacters = function(characters)
            local current, result = Core.Characters:GetCurrentID(), {}
            for _, character in ipairs(characters) do
                local snapshot = Addon.db.byCharacter[character.id]
                if character.id == current and snapshot and snapshot.coverage.observedAt then result[#result + 1] = character end
            end
            return result
        end,
        GetSurfaceMetrics = function() return { minContentWidth = 700, naturalContentWidth = 1040, minContentHeight = 200, naturalContentHeight = 440 } end,
        Create = function(parent) Page:Create(parent) end, Refresh = function(parent, context) Page:Refresh(parent, context) end })
    if not page then return nil, err end
    return Core.Entry:RegisterBusinessEntry(Addon.NAME, { id = "yma", brokerName = "YiboMail", pageID = "mail-inbox", text = Addon:T("FOREVER.TITLE"),
        icon = "Interface\\AddOns\\YiboMail\\Media\\YiboMailIcon", defaultChannels = { minimap = false, broker = false, builtinBar = false } })
end
