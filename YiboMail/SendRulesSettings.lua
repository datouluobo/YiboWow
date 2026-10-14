local Addon = _G.YiboMail
local S = {}; Addon.SendRulesSettings = S
local function Theme() return Addon.Core.UITheme end
local function RuleLabel(rule)
    local label = Addon.SendRules:Label(rule)
    local excluded = 0; for _ in pairs(rule.excluded or {}) do excluded = excluded + 1 end
    if rule.kind == "category" and excluded > 0 then label = label .. Addon:T("UI.TEXT_0021") .. excluded .. Addon:T("UI.TEXT_0043") end
    return label
end
local function Place(control, x, y, width, height)
    control:ClearAllPoints(); control:SetPoint("TOPLEFT", x, -y)
    if width then control:SetWidth(width) end
    if height then control:SetHeight(height) end
end
function S:Refresh()
    if self.rendering then return end
    if self.host and self.host.refreshPanel then self.host.refreshPanel() end
end
function S:ConfirmLeave(action)
    if not self.dirty then action(); return end
    Addon.Core.ItemConfirmation:Show({ text = Addon:T("UI.TEXT_0274"),
        OnAccept = function() S.dirty = nil; action() end })
end
function S:Edit(id, recipient)
    self:ConfirmLeave(function()
        S.editID, S.editing = id, true
        S.draft = id and Addon.Copy(Addon.db.sendRules[id]) or { kind = "item", enabled = true, excluded = {}, characters = {}, recipient = "" }
        if not id then S.draft.recipient = recipient or "" end
        if S.panel then S.panel.item:Invalidate(); S.panel.exclude:Invalidate() end
        S.inlineRecipient = id and S.draft.recipient or recipient
        S.focusRecipient = S.inlineRecipient and Addon.Recipients:Key(S.inlineRecipient) or nil
        if S.focusRecipient then S.collapsed[S.focusRecipient] = false end
        S.dirty, S.notice, S.more, S.factionEdit, S.deleteNotice = nil, nil, false, nil, nil; S.syncDraft = true; S:Refresh()
    end)
end
function S:OpenTab(tab)
    self:ConfirmLeave(function() S.tab = tab; S:Refresh() end)
end
function S:DeleteSelectedRule()
    local id = self.editID
    local rule = id and Addon.db.sendRules[id]
    if not rule then return end
    local revision = Addon.db.sendRuleRevision
    local function IsCurrent()
        return S.editID == id and Addon.db.sendRuleRevision == revision and Addon.db.sendRules[id] == rule
    end
    Addon.Core.ItemConfirmation:Show({
        text = Addon:T("RULE.DELETE_CONFIRM", Addon.SendRules:Label(rule), rule.recipient),
        IsCurrent = IsCurrent,
        OnAccept = function()
            if not IsCurrent() then return end
            local ok, err = Addon.SendRules:Delete(id)
            if ok then
                S.editID, S.draft, S.dirty, S.notice, S.inlineRecipient, S.focusRecipient = nil, nil, nil, nil, nil, nil
                S.syncDraft = true
            end
            S.deleteNotice = ok and Addon:T("RULE.DELETED") or err; S:Refresh()
        end,
    })
end
function S:RenderRuleDelete(cache, width)
    local t = Theme()
    if not cache.ruleDelete then
        cache.ruleDeleteTitle = t:CreateText(cache, t.Font.body, t.Colors.text, "LEFT")
        cache.ruleDeleteTarget = t:CreateText(cache, t.Font.assist, t.Colors.muted, "LEFT")
        cache.ruleDeleteRisk = t:CreateText(cache, t.Font.assist, t.Colors.warning, "LEFT")
        cache.ruleDelete = t:CreateButton(cache, 180, Addon:T("RULE.DELETE"), "danger")
        cache.ruleDelete:SetScript("OnClick", function() S:DeleteSelectedRule() end)
    end
    local rule = self.editID and Addon.db.sendRules[self.editID]
    local y, contentWidth = 152, math.max(1, width - 24)
    Place(cache.ruleDeleteTitle, 12, y, contentWidth, 24); cache.ruleDeleteTitle:SetText(Addon:T("RULE.DELETE")); y = y + 28
    cache.ruleDeleteTarget:SetText(rule and Addon:T("RULE.DELETE_TARGET", Addon.SendRules:Label(rule), rule.recipient)
        or self.deleteNotice or Addon:T("RULE.DELETE_EMPTY"))
    cache.ruleDeleteRisk:SetText(Addon:T("RULE.DELETE_RISK"))
    for _, text in ipairs({ cache.ruleDeleteTarget, cache.ruleDeleteRisk }) do
        Place(text, 12, y, contentWidth, 0); text:SetWordWrap(true)
        local height = math.max(24, text:GetStringHeight()); text:SetHeight(height); y = y + height + 6
    end
    local buttonWidth = math.max(112, t:MeasureText(t.Font.body, cache.ruleDelete.label:GetText()) + 20)
    Place(cache.ruleDelete, 12, y, buttonWidth, t.Size.standard); cache.ruleDelete:SetEnabled(rule ~= nil)
    cache:SetHeight(y + t.Size.standard + 12)
end
function S:Host(parent, host, business, cache, width, businessHeight)
    self.host, self.parent = host, parent
    local t = Theme()
    if not parent.mailSettingsTabs then
        parent.mailSettingsTabs = t:CreateBusinessTabs(parent, {
            { id = "business", title = Addon:T("UI.TEXT_0093"), width = 112 },
            { id = "rules", title = Addon:T("UI.TEXT_0503"), width = 112 },
            { id = "cache", title = Addon:T("UI.TEXT_0353"), width = 132 },
        }, function(id) S:OpenTab(id) end)
    end
    parent.mailSettingsTabs:Show()
    local left = 0
    for _, id in ipairs({ "business", "rules", "cache" }) do
        local button = parent.mailSettingsTabs.buttons[id]
        local tabWidth = math.min((width - 4) / 3, math.max(112, t:MeasureText(t.Font.body, button.label:GetText()) + 24))
        button:ClearAllPoints(); button:SetPoint("TOPLEFT", left, 0); button:SetWidth(tabWidth)
        left = left + tabWidth + 2
    end
    if self.requestedTab then
        local tab, id = self.requestedTab, self.requestedRule
        self.requestedTab, self.requestedRule = nil, nil
        if self.dirty then
            self:ConfirmLeave(function() S.tab = tab; if id then S:Edit(id) else S:Refresh() end end)
        else
            self.tab = tab
            if id and Addon.db.sendRules[id] then
                self.editID, self.draft, self.editing, self.syncDraft = id, Addon.Copy(Addon.db.sendRules[id]), true, true
                self.inlineRecipient = self.draft.recipient; self.focusRecipient = Addon.Recipients:Key(self.inlineRecipient)
            end
        end
    end
    self.tab = self.tab or "business"
    parent.mailSettingsTabs:SetActive(self.tab)
    business:SetShown(self.tab == "business"); cache:SetShown(self.tab == "cache")
    Place(business, 0, 44); Place(cache, 0, 44)
    if self.tab == "cache" then
        self:RenderRuleDelete(cache, width)
    end
    if self.panel then self.panel:SetShown(self.tab == "rules") end
    if self.tab == "rules" then return 44 + self:Render(parent, width, host) end
    return 44 + (self.tab == "business" and businessHeight or cache:GetHeight())
end
local function Count(values)
    local count = 0; for _ in pairs(values or {}) do count = count + 1 end; return count
end
function S:ReturnToList() self:Edit() end
-- Keep Core's complete input/add/drop operation group and shared sizing.
local function RulePicker(parent, label, callback, validate, retain)
    local picker = Addon.Core:CreateItemPicker(parent, { enterAction = "add", dropMode = "add", rightInset = 0,
        multiple = retain == true, retainInput = retain == true,
        resolve = { allowName = true, includeBags = true },
        placeholder = retain and Addon:T("UI.TEXT_0210") or Addon:T("UI.TEXT_0454"), OnLayoutChanged = function() S:Refresh() end,
        OnSelected = function(info) callback(info) end,
        add = { label = label, Validate = validate, Execute = function(info)
            if not S.editing then return nil, Addon:T("UI.TEXT_0536") end
            callback(info)
            local names = {}
            for _, item in ipairs(retain and info or { info }) do names[#names + 1] = (item.icon and ("|T" .. item.icon .. ":20:20|t ") or "") .. item.name end
            return true, Addon:T("UI.TEXT_0257") .. table.concat(names, Addon:T("UI.TEXT_0078"))
        end }, OnSuccess = function() S:Refresh() end })
    picker.drop:SetText(Addon:T("UI.TEXT_0320"))
    function picker:Layout(width)
        local h, gap, actionWidth, dropWidth = Theme().Size.standard, 6, retain and 72 or 96, 80
        actionWidth = math.max(actionWidth, Theme():MeasureText(Theme().Font.body, label) + 20)
        dropWidth = math.max(dropWidth, Theme():MeasureText(Theme().Font.body, self.drop.label:GetText()) + 20)
        self.layoutWidth = width; self:SetWidth(width)
        local inputWidth = math.max(1, width - actionWidth - dropWidth - gap * 2)
        Place(self.input, 0, 0, inputWidth, h)
        for _, group in ipairs(self.controls) do
            local control = group.control
            if control ~= self.input and control ~= self.dropdown and control ~= self.retry and control ~= self.drop then
                Place(control, inputWidth + gap, 0, actionWidth, h)
            end
        end
        Place(self.drop, width - dropWidth, 0, dropWidth, h)
        local y = h + gap
        self.dropdown:SetShown(#self.candidates > 1); self.retry:SetShown(self.canRetry == true)
        if #self.candidates > 1 or self.canRetry then
            Place(self.dropdown, 0, y, width - (self.canRetry and 86 or 0), h)
            Place(self.retry, width - 80, y, 80, h); y = y + h + gap
        end
        local feedback = self.preview:GetText()
        self.preview:SetShown(feedback ~= nil and feedback ~= "")
        if feedback and feedback ~= "" then
            Place(self.preview, 0, y, width, 0)
            local height = math.max(24, self.preview:GetStringHeight() or 0)
            self.preview:SetHeight(height); y = y + height + gap
        end
        local previous = self.layoutHeight; self.layoutHeight = y; self:SetHeight(y)
        if previous and previous ~= y and self.config.OnLayoutChanged then self.config.OnLayoutChanged(y) end
        return y
    end
    return picker
end
function S:Create(parent)
    local t, p = Theme(), CreateFrame("Frame", nil, parent); self.panel = p
    self.filterState, self.filterKind = "all", "all"
    Addon.db.settings = Addon.db.settings or {}
    Addon.db.settings.sendRuleCollapsed = Addon.db.settings.sendRuleCollapsed or {}
    self.collapsed = Addon.db.settings.sendRuleCollapsed
    p.list, p.editor = CreateFrame("Frame", nil, p), CreateFrame("Frame", nil, p)
    p.rows, p.excludes = {}, {}
    local function Button(owner, text, callback)
        local b = t:CreateButton(owner, 180, text); b:SetScript("OnClick", callback); return b
    end
    p.search = t:CreateInput(p.list, { placeholder = Addon:T("UI.TEXT_0327"), clearable = true,
        OnChanged = function(value)
            p.listScroll:SetVerticalScroll(0); S:Refresh()
        end })
    p.listScroll = t:CreateScrollFrame(p.list)
    p.listScroll:SetPoint("TOPLEFT", 0, -42); p.listScroll:SetPoint("BOTTOMRIGHT", 0, 28)
    p.listContent = CreateFrame("Frame", nil, p.listScroll); p.listContent:SetSize(1, 1)
    p.listScroll:SetScrollChild(p.listContent)
    p.listScroll:HookScript("OnSizeChanged", function() S:Refresh() end)
    p.range = t:CreateText(p.list, t.Font.assist, t.Colors.muted, "LEFT")
    p.empty = t:CreateText(p.listContent, t.Font.body, t.Colors.muted, "LEFT")
    p.listNotice = t:CreateText(p.listContent, t.Font.assist, t.Colors.muted, "LEFT"); p.listNotice:SetWordWrap(true)
    p.heading = t:CreateText(p.editor, t.Font.section, t.Colors.text, "LEFT")
    p.kind = CreateFrame("Frame", nil, p.editor)
    p.kind.buttons = {}
    function p.kind:SetValue(value)
        for id, button in pairs(self.buttons) do button:SetChecked(id == value) end
    end
    p.kind.onValueChanged = function(v) p.item:Invalidate(); p.exclude:Invalidate(); S.draft.kind = v; S.dirty = true; S:Refresh() end
    for index, definition in ipairs({ { "item", Addon:T("UI.TEXT_0455") }, { "category", Addon:T("UI.TEXT_0149") } }) do
        local value = definition[1]
        local button = t:CreateCheckbox(p.kind, definition[2]); p.kind.buttons[value] = button
        button:SetScript("OnClick", function() p.kind.onValueChanged(value) end)
    end
    p.item = RulePicker(p.editor, Addon:T("UI.TEXT_0463"), function(items)
        local ids = {}; for _, item in ipairs(items) do ids[#ids + 1] = item.itemID end
        S.draft.itemIDs, S.draft.itemID = ids, ids[1]; S.dirty = true
    end, nil, true)
    local itemChanged = p.item.input:GetScript("OnTextChanged")
    p.item.input:SetScript("OnTextChanged", function(control, userInput)
        itemChanged(control, userInput)
        if S.editing and not control.silent and (userInput or control.notifyProgrammatic) then
            -- Editing the query must not silently save the previously selected item.
            S.draft.itemID, S.draft.itemIDs, S.dirty = nil, nil, true
        end
    end)
    p.class = t:CreateDropdown(p.editor, 240, {})
    p.class:SetOnValueChanged(function(v) S.draft.classID, S.draft.subclassID = v, nil; S.dirty = true; S:Refresh() end)
    p.subclass = t:CreateDropdown(p.editor, 240, {})
    p.subclass:SetOnValueChanged(function(v) S.draft.subclassID = v ~= -1 and v or nil; S.dirty = true; S:Refresh() end)
    p.class:SetMenuPageSize(8); p.subclass:SetMenuPageSize(8)
    p.classLabel = t:CreateText(p.editor, t.Font.body, t.Colors.text, "LEFT"); p.classLabel:SetText(Addon:T("UI.TEXT_0211"))
    p.subclassLabel = t:CreateText(p.editor, t.Font.body, t.Colors.text, "LEFT"); p.subclassLabel:SetText(Addon:T("UI.TEXT_0217"))
    p.categoryStatus = t:CreateText(p.editor, t.Font.assist, t.Colors.muted, "LEFT"); p.categoryStatus:SetWordWrap(true)
    p.target = t:CreateInput(p.editor, { placeholder = Addon:T("UI.TEXT_0341"), OnChanged = function(v) S.draft.recipient = v; S.dirty = true; S:Refresh() end })
    p.contacts = Button(p.editor, Addon:T("RULE.CONTACTS"), function(_, button)
        if button == "RightButton" then S.factionEdit = true; S:Refresh(); return end
        Addon.RecipientUI:Open(p.contacts, nil, function(address) S.draft.recipient = address; S.dirty, S.syncDraft = true, true; S:Refresh() end)
    end)
    p.contacts:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    t:BindTooltip(p.contacts, Addon:T("UI.TEXT_0581"), { Addon:T("UI.TEXT_0200") })
    p.factionNotice = t:CreateText(p.editor, t.Font.assist, t.Colors.muted, "LEFT")
    p.factionAlliance = Button(p.editor, Addon:T("UI.TEXT_0467"), function() local ok, err = Addon.Recipients:SetFaction(S.draft.recipient, "Alliance"); S.factionEdit = nil; S.notice = not ok and err or nil; S:Refresh() end)
    p.factionHorde = Button(p.editor, Addon:T("UI.TEXT_0469"), function() local ok, err = Addon.Recipients:SetFaction(S.draft.recipient, "Horde"); S.factionEdit = nil; S.notice = not ok and err or nil; S:Refresh() end)
    p.excludeTitle = t:CreateText(p.editor, t.Font.body, t.Colors.text, "LEFT")
    p.excludeTitle:SetText(Addon:T("UI.TEXT_0150"))
    p.excludeHelp = t:CreateText(p.editor, t.Font.assist, t.Colors.muted, "LEFT"); p.excludeHelp:SetWordWrap(true)
    p.excludeHelp:SetText(Addon:T("UI.TEXT_0108"))
    p.excludeEmpty = t:CreateText(p.editor, t.Font.assist, t.Colors.muted, "LEFT")
    p.excludeEmpty:SetText(Addon:T("UI.TEXT_0644"))
    p.exclude = RulePicker(p.editor, Addon:T("UI.TEXT_0164"), function(info) S.draft.excluded[info.itemID] = true; S.dirty = true; S:Refresh(); return true end,
        function() return S.draft.kind == "category", Addon:T("UI.TEXT_0106") end)
    p.cancel = Button(p.editor, Addon:T("UI.TEXT_0441"), function() S:ReturnToList() end)
    p.deleteShortcut = Button(p.editor, Addon:T("RULE.DELETE_LINK"), function() S:OpenTab("cache") end)
    t:BindTooltip(p.deleteShortcut, Addon:T("RULE.DELETE"), { Addon:T("RULE.DELETE_HELP") })
    p.save = Button(p.editor, Addon:T("UI.TEXT_0121"), function()
        if S.draft.kind == "item" and (p.item.busy or p.item.input:GetText() ~= table.concat(Addon.SendRules:ItemIDs(S.draft), ";")) then
            S.notice = Addon:T("UI.TEXT_0531"); S:Refresh(); return
        end
        local ok, id = Addon.SendRules:Save(S.draft, S.editID)
        S.notice = ok and Addon:T("UI.TEXT_0500") or id
        if ok then
            S.editID, S.dirty, S.editing = id, nil, true
            local rule = Addon.db.sendRules[id]
            S.focusRecipient = Addon.Recipients:Key(rule.recipient)
            S.collapsed[S.focusRecipient] = false
            S.draft = Addon.Copy(rule); S.syncDraft = true
        end
        S:Refresh()
    end)
    p.targetLabel = t:CreateText(p.editor, t.Font.assist, t.Colors.muted, "LEFT"); p.targetLabel:SetText(Addon:T("UI.TEXT_0332"))
    p.kindLabel = t:CreateText(p.editor, t.Font.assist, t.Colors.muted, "LEFT"); p.kindLabel:SetText(Addon:T("UI.TEXT_0167"))
    p.matchLabel = t:CreateText(p.editor, t.Font.assist, t.Colors.muted, "LEFT")
    p.editor.line = p.editor:CreateTexture(nil, "BACKGROUND"); p.editor.line:SetColorTexture(unpack(t.Colors.lineSoft))
    p.notice = t:CreateText(p.editor, t.Font.assist, t.Colors.muted, "LEFT"); p.notice:SetWordWrap(true)
    p.blacklistTitle = t:CreateText(p.editor, t.Font.body, t.Colors.text, "LEFT"); p.blacklistTitle:SetText(Addon:T("UI.TEXT_0130"))
    p.blacklistHelp = t:CreateText(p.editor, t.Font.assist, t.Colors.muted, "LEFT")
    p.blacklistHelp:SetText(Addon:T("UI.TEXT_0579"))
    p.blockItem = RulePicker(p.editor, Addon:T("UI.TEXT_0323"), function(info)
        Addon.SendRules:SetBlockedItem(info.itemID, true); S.blacklistNotice = nil; S:Refresh()
    end)
    p.blockSenderInput = t:CreateInput(p.editor, { placeholder = Addon:T("UI.TEXT_0181"), clearable = true })
    p.blockSender = Button(p.editor, Addon:T("RULE.BLOCK_SENDER"), function()
        local address, err = Addon.Recipients:Normalize(p.blockSenderInput:GetText())
        local found
        if address then
            local current = Addon.Core.Characters:GetCurrent()
            if current and Addon.Recipients:Key(current.name .. "-" .. current.realm) == Addon.Recipients:Key(address) then found = current end
            for _, character in ipairs(Addon.Core.Characters:GetAllCached()) do
                if Addon.Recipients:Key(character.name .. "-" .. character.realm) == Addon.Recipients:Key(address) then found = character; break end
            end
        end
        if found then
            Addon.SendRules:SetBlockedSender(found.id, true); p.blockSenderInput:SetValue(""); S.blacklistNotice = nil
        else S.blacklistNotice = err or Addon:T("UI.TEXT_0542") end
        S:Refresh()
    end)
    p.blockCurrent = Button(p.editor, Addon:T("RULE.BLOCK_CURRENT"), function()
        local current = Addon.Core.Characters:GetCurrent()
        if current then Addon.SendRules:SetBlockedSender(current.id, true); S.blacklistNotice = nil; S:Refresh() end
    end)
    p.blacklistRows = {}
    p.blacklistStatus = t:CreateText(p.editor, t.Font.assist, t.Colors.muted, "LEFT"); p.blacklistStatus:SetWordWrap(true)
    p.blacklistPrevious = Button(p.editor, Addon:T("UI.TEXT_0087"), function() S.blacklistPage = (S.blacklistPage or 1) - 1; S:Refresh() end)
    p.blacklistNext = Button(p.editor, Addon:T("UI.TEXT_0090"), function() S.blacklistPage = (S.blacklistPage or 1) + 1; S:Refresh() end)
    p:SetScript("OnHide", function()
        for _, dropdown in ipairs({ p.class, p.subclass }) do dropdown.menu:Hide() end
        p.item:Invalidate(); p.exclude:Invalidate(); p.item.dropdown.menu:Hide(); p.exclude.dropdown.menu:Hide()
        p.blockItem:Invalidate(); p.blockItem.dropdown.menu:Hide()
        Addon.RecipientUI:Hide()
    end)
    return p
end
function S:RenderBlacklist(width, y)
    local p, t, data = self.panel, Theme(), Addon.db.sendBlacklist
    Place(p.blacklistTitle, 0, y + 8, width, 24); y = y + 36
    Place(p.blacklistHelp, 0, y, width, 0); p.blacklistHelp:SetWordWrap(true)
    local helpHeight = math.max(24, p.blacklistHelp:GetStringHeight()); p.blacklistHelp:SetHeight(helpHeight); y = y + helpHeight + 4
    Place(p.blockItem, 0, y); y = y + p.blockItem:Layout(width) + 4
    local blockWidth = math.max(80, t:MeasureText(t.Font.body, p.blockSender.label:GetText()) + 20)
    local currentWidth = math.max(90, t:MeasureText(t.Font.body, p.blockCurrent.label:GetText()) + 20)
    local inputWidth = width - blockWidth - currentWidth - 12
    if inputWidth < 150 then
        Place(p.blockSenderInput, 0, y, width, t.Size.standard); y = y + t.Size.standard + 6
        inputWidth = 0
    else Place(p.blockSenderInput, 0, y, inputWidth, t.Size.standard) end
    Place(p.blockSender, width - blockWidth - currentWidth - 6, y, blockWidth, t.Size.standard)
    Place(p.blockCurrent, width - currentWidth, y, currentWidth, t.Size.standard); y = y + t.Size.standard + 8
    local entries = {}
    for itemID in pairs(data.items) do
        local item = Addon.SendRules:GetItem(itemID) or {}
        entries[#entries + 1] = { kind = "item", id = itemID, label = Addon:T("UI.TEXT_0452") .. (item.name or tostring(itemID)), icon = item.icon }
    end
    for id, address in pairs(data.senders) do
        entries[#entries + 1] = { kind = "sender", id = id, label = Addon:T("UI.TEXT_0180") .. Addon.Recipients:Label({ address = address }) }
    end
    table.sort(entries, function(a, b) if a.kind ~= b.kind then return a.kind < b.kind end return tostring(a.id) < tostring(b.id) end)
    local pages = math.max(1, math.ceil(#entries / 6))
    self.blacklistPage = math.max(1, math.min(self.blacklistPage or 1, pages))
    for _, row in ipairs(p.blacklistRows) do row:Hide() end
    for index = 1, math.min(6, #entries - (self.blacklistPage - 1) * 6) do
        local entry = entries[(self.blacklistPage - 1) * 6 + index]
        local row = p.blacklistRows[index]
        if not row then
            row = CreateFrame("Frame", nil, p.editor); p.blacklistRows[index] = row
            row.label = t:CreateText(row, t.Font.body, t.Colors.text, "LEFT"); row.label:SetWordWrap(false)
            row.remove = t:CreateButton(row, 60, Addon:T("UI.TEXT_0472"))
        end
        row:Show(); row.entry = entry; Place(row, 0, y, width, t.Size.standard)
        Place(row.label, 0, 3, width - 68, 24); Place(row.remove, width - 60, 0, 60, t.Size.standard)
        row.label:SetText((entry.icon and ("|T" .. entry.icon .. ":20:20|t ") or "") .. entry.label)
        row.remove:SetScript("OnClick", function()
            if entry.kind == "item" then Addon.SendRules:SetBlockedItem(entry.id, false)
            else Addon.SendRules:SetBlockedSender(entry.id, false) end
            S.blacklistNotice = nil; S:Refresh()
        end)
        y = y + t.Size.standard + 4
    end
    p.blacklistPrevious:SetShown(pages > 1); p.blacklistNext:SetShown(pages > 1)
    if pages > 1 then
        Place(p.blacklistPrevious, 0, y, 72, t.Size.standard); Place(p.blacklistNext, 78, y, 72, t.Size.standard)
        p.blacklistPrevious:SetEnabled(self.blacklistPage > 1); p.blacklistNext:SetEnabled(self.blacklistPage < pages); y = y + t.Size.standard + 4
    end
    Place(p.blacklistStatus, 0, y, width, 24)
    p.blacklistStatus:SetText(self.blacklistNotice or (#entries == 0 and Addon:T("UI.TEXT_0644") or Addon:T("UI.TEXT_0142") .. #entries .. Addon:T("UI.TEXT_0052") .. (pages > 1 and " · " .. self.blacklistPage .. "/" .. pages .. Addon:T("UI.TEXT_0051") or "")))
    return y + 28
end
function S:Groups(search)
    local groups, byKey, count = {}, {}, 0
    for _, rule in ipairs(Addon.SendRules:List()) do
        local label = Addon.SendRules:Label(rule) .. " " .. rule.recipient
        if string.lower(label):find(search, 1, true)
            and (self.filterState == "all" or self.filterState == "enabled" and rule.enabled ~= false or self.filterState == "disabled" and rule.enabled == false)
            and (self.filterKind == "all" or rule.kind == self.filterKind) then
            local key = Addon.Recipients:Key(rule.recipient)
            local group = byKey[key]
            if not group then group = { key = key, recipient = rule.recipient, rules = {} }; byKey[key] = group; groups[#groups + 1] = group end
            group.rules[#group.rules + 1] = rule; count = count + 1
        end
    end
    for _, group in ipairs(groups) do
        table.sort(group.rules, function(a, b)
            if a.kind ~= b.kind then return a.kind == "category" end
            return a.id < b.id
        end)
    end
    table.sort(groups, function(a, b) return a.key < b.key end)
    return groups, count
end
function S:Row(index)
    local p, t = self.panel, Theme()
    local row = p.rows[index]
    if not row then
        row = CreateFrame("Frame", nil, p.listContent, "BackdropTemplate"); p.rows[index] = row
        row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
        row.fold = t:CreateButton(row, 24, "-"); row.fold:SetHeight(24)
        row.header = t:CreateText(row, t.Font.body, t.Colors.text, "LEFT"); row.header:SetWordWrap(false)
        row.icon = row:CreateTexture(nil, "ARTWORK"); row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        row.label = t:CreateText(row, t.Font.body, t.Colors.text, "LEFT"); row.label:SetWordWrap(false)
        row.toggle = t:CreateCheckbox(row, Addon:T("UI.TEXT_0206"))
        row:EnableMouse(true)
    end
    row:Show(); return row
end
function S:RenderList(width, host)
    local p, t = self.panel, Theme()
    Place(p.search, 0, 0, width, t.Size.standard)
    local listHeight = math.max(190, (host.availableHeight or 540) - 44)
    local viewportHeight = listHeight - 70
    p.list:SetHeight(listHeight); p.listScroll:SetHeight(viewportHeight)
    local y, step = 0, 30
    local toggleWidth = math.max(84, t:MeasureText(t.Font.body, Addon:T("UI.TEXT_0206")) + 32)
    local search = string.lower(p.search:GetText())
    local groups, count = self:Groups(search)
    if not p.ruleMeasure then
        p.ruleMeasure = t:CreateText(p.list, t.Font.body, t.Colors.text, "LEFT")
        p.ruleMeasure:SetWordWrap(true); p.ruleMeasure:Hide()
    end
    local labels, heights = {}, {}
    local conflicts = Addon.SendRules:Match(Addon.Compose:BagItems()).conflicts
    local function Measure(contentWidth)
        p.ruleMeasure:SetWidth(math.max(1, contentWidth - toggleWidth - 72))
        local total = count == 0 and 34 or 0
        for _, group in ipairs(groups) do
            total = total + step + 12
            if search ~= "" or not self.collapsed[group.key] then
                for _, rule in ipairs(group.rules) do
                    local label = RuleLabel(rule)
                    p.ruleMeasure:SetText(label); p.ruleMeasure:SetHeight(0)
                    local height = math.max(step, math.max(24, p.ruleMeasure:GetStringHeight()) + 6)
                    labels[rule.id], heights[rule.id] = label, height
                    total = total + height
                end
            end
        end
        return total + (#conflicts > 0 and 40 or 0)
    end
    if Measure(width) > viewportHeight + 1 then
        width = width - t.Geometry.scrollbarGutter; Measure(width)
    end
    p.listContent:SetWidth(width)
    local focusTop
    local index = 0
    local function Row(kind)
        index = index + 1; local row = S:Row(index)
        row.kind, row.rule, row.group = kind, nil, nil
        row:SetScript("OnMouseUp", nil); row:SetScript("OnEnter", nil); row:SetScript("OnLeave", nil)
        Place(row, 0, y, width, step); y = y + step
        row.fold:SetShown(kind == "group"); row.header:SetShown(kind == "group")
        row.icon:SetShown(kind == "rule"); row.label:SetShown(kind == "rule")
        Place(row.toggle, width - toggleWidth, 0, toggleWidth, step); row.toggle.label:SetWordWrap(false)
        row:SetBackdropColor(0, 0, 0, 0)
        return row
    end
    for _, group in ipairs(groups) do
        if group.key == self.focusRecipient then focusTop = y end
        local expanded = search ~= "" or not self.collapsed[group.key]
        local header = Row("group"); header.group = group
        Place(header.fold, 0, 3, 24, 24); Place(header.header, 32, 3, width - toggleWidth - 44, 24)
        header.fold:SetText(expanded and "-" or "+")
        local allowed, factionReason = Addon.Recipients:CanRuleSend(group.recipient)
        header.header:SetText(Addon.Recipients:Label({ address = group.recipient }) .. " · " .. #group.rules .. Addon:T("UI.TEXT_0038") .. (allowed == false and Addon:T("UI.TEXT_0009") or allowed == nil and Addon:T("UI.TEXT_0018") or ""))
        header.fold:SetScript("OnClick", function()
            if search ~= "" then return end
            S.collapsed[group.key] = expanded; S.focusRecipient = group.key; S:Refresh()
        end)
        header.toggle:SetChecked(Addon.SendRules:IsRecipientEnabled(group.recipient))
        header.toggle:SetScript("OnClick", function() Addon.SendRules:SetRecipientEnabled(group.recipient, not Addon.SendRules:IsRecipientEnabled(group.recipient)); S:Refresh() end)
        t:BindTooltip(header, group.recipient, { factionReason or Addon:T("UI.TEXT_0276"), Addon:T("UI.TEXT_0336") })
        if expanded then
            for _, rule in ipairs(group.rules) do
                local row = Row("rule"); row.rule = rule
                Place(row.icon, 32, 5, 20, 20); row.icon:SetTexture(Addon.SendRules:Icon(rule))
                Place(row.label, 60, 3, width - toggleWidth - 72, 24)
                row.label:SetText(labels[rule.id])
                local rowHeight = heights[rule.id]
                row.label:SetWordWrap(true); row.label:SetHeight(rowHeight - 6)
                row:SetHeight(rowHeight); y = y + rowHeight - step
                row.label:SetTextColor(unpack(Addon.SendRules:IsRecipientEnabled(group.recipient) and t.Colors.text or t.Colors.muted))
                if self.editID == rule.id then row:SetBackdropColor(unpack(t.Colors.selected)) end
                row:SetScript("OnMouseUp", function(_, button) if button == "LeftButton" then S:Edit(rule.id) end end)
                row.toggle:SetChecked(rule.enabled ~= false)
                row.toggle:SetScript("OnClick", function()
                    Addon.SendRules:SetEnabled(rule.id, rule.enabled == false)
                    if S.editID == rule.id then S.draft.enabled = rule.enabled end
                    S:Refresh()
                end)
                local lines = { Addon:T("UI.TEXT_0340") .. rule.recipient, Addon:T("UI.TEXT_0450") }
                local excludes = {}; for id in pairs(rule.excluded or {}) do excludes[#excludes + 1] = (Addon.SendRules:GetItem(id) or {}).name or tostring(id) end
                table.sort(excludes); if #excludes > 0 then lines[#lines + 1] = Addon:T("UI.TEXT_0645") .. table.concat(excludes, Addon:T("UI.TEXT_0078")) end
                t:BindTooltip(row, Addon.SendRules:Label(rule), lines)
            end
        end
        y = y + 12
    end
    for rest = index + 1, #p.rows do p.rows[rest]:Hide() end
    p.empty:SetShown(count == 0)
    if count == 0 then Place(p.empty, 0, y, width, 30); p.empty:SetText(search ~= "" and Addon:T("UI.TEXT_0435") or Addon:T("UI.TEXT_0384")); y = y + 34 end
    p.range:ClearAllPoints(); p.range:SetPoint("BOTTOMLEFT", p.list, "BOTTOMLEFT", 0, 0)
    p.range:SetPoint("BOTTOMRIGHT", p.list, "BOTTOMRIGHT", 0, 0); p.range:SetHeight(24)
    p.range:SetText(Addon:T("UI.TEXT_0142") .. #groups .. Addon:T("UI.TEXT_0028") .. count .. Addon:T("UI.TEXT_0040"))
    p.listNotice:SetShown(#conflicts > 0)
    if #conflicts > 0 then Place(p.listNotice, 0, y, width, 32); p.listNotice:SetText(Addon:T("UI.TEXT_0273") .. #conflicts .. Addon:T("UI.TEXT_0054")); y = y + 40 end
    p.listContent:SetHeight(math.max(1, y)); p.listScroll:SetContentHeight(y)
    local maximum = math.max(0, y - viewportHeight)
    local offset = math.min(p.listScroll:GetVerticalScroll() or 0, maximum)
    if focusTop and (focusTop < offset or focusTop + step > offset + viewportHeight) then offset = math.min(focusTop, maximum) end
    self.focusRecipient = nil; p.listScroll:SetVerticalScroll(offset)
    return listHeight
end
function S:RenderEditor(width)
    local p, t = self.panel, Theme()
    local draft = self.draft; draft.excluded, draft.characters = draft.excluded or {}, draft.characters or {}
    local editorWidth, h, step, bw = width, t.Size.standard, t.Size.standard + t.Space.xs, 112
    local sync = self.syncDraft; self.syncDraft = nil
    p.editor.line:Hide()
    Place(p.heading, 0, 0, width, 24); p.heading:SetText(self.editID and Addon:T("UI.TEXT_0489") or Addon:T("UI.TEXT_0440"))
    p.save:SetText(self.editID and Addon:T("UI.TEXT_0119") or Addon:T("UI.TEXT_0440"))
    local y, labelWidth = 34, t:MeasureText(t.Font.assist, p.targetLabel:GetText()) + 8
    local contactsWidth = math.max(96, t:MeasureText(t.Font.body, p.contacts.label:GetText()) + 20)
    Place(p.targetLabel, 0, y + 4, labelWidth, 24)
    Place(p.target, labelWidth, y, width - labelWidth - contactsWidth - 6, h); Place(p.contacts, width - contactsWidth, y, contactsWidth, h); y = y + step
    if sync then p.target:SetValue(draft.recipient ~= "" and Addon.Recipients:Label({ address = draft.recipient }) or "") end
    local normalized = Addon.Recipients:Normalize(draft.recipient)
    local faction, factionSource = Addon.Recipients:GetFaction(normalized or "")
    local needsFaction = normalized and (not faction or self.factionEdit and factionSource ~= "core")
    p.factionNotice:SetShown(needsFaction ~= nil and needsFaction ~= false)
    p.factionAlliance:SetShown(needsFaction and factionSource ~= "core" or false)
    p.factionHorde:SetShown(needsFaction and factionSource ~= "core" or false)
    if needsFaction then
        p.factionNotice:SetText(factionSource == "core" and Addon:T("UI.TEXT_0547") or Addon:T("UI.TEXT_0339"))
        Place(p.factionNotice, 0, y, width, 0); p.factionNotice:SetWordWrap(true)
        local noticeHeight = math.max(24, p.factionNotice:GetStringHeight())
        p.factionNotice:SetHeight(noticeHeight); y = y + noticeHeight + 6
        if factionSource ~= "core" then
            local allianceWidth = math.max(92, t:MeasureText(t.Font.body, p.factionAlliance.label:GetText()) + 20)
            local hordeWidth = math.max(92, t:MeasureText(t.Font.body, p.factionHorde.label:GetText()) + 20)
            Place(p.factionAlliance, 0, y, allianceWidth, h); Place(p.factionHorde, allianceWidth + 8, y, hordeWidth, h)
            y = y + step
        end
    end
    p.kindLabel:Hide(); p.matchLabel:Hide()
    Place(p.kind, 0, y, width, h); p.kind:SetValue(draft.kind)
    local kindLeft = 0
    for _, id in ipairs({ "item", "category" }) do
        local button = p.kind.buttons[id]
        local buttonWidth = t:MeasureText(t.Font.body, button.label:GetText()) + 32
        Place(button, kindLeft, 0, buttonWidth, h); kindLeft = kindLeft + buttonWidth + 12
    end
    y = y + step
    local category = draft.kind == "category"
    p.item:SetShown(not category); p.class:SetShown(category); p.subclass:SetShown(category)
    p.classLabel:SetShown(category); p.subclassLabel:SetShown(category); p.categoryStatus:Hide()
    if not category then
        Place(p.item, 0, y); if sync then p.item:SetValue(table.concat(Addon.SendRules:ItemIDs(draft), ";")) end
        if sync and draft.itemID then
            p.item:Feedback(Addon:T("UI.TEXT_0257") .. Addon.SendRules:Label(draft))
        end
        y = y + p.item:Layout(editorWidth) + 8
    else
        p.item:Invalidate()
        local categoryLabelWidth = t:MeasureText(t.Font.body, p.classLabel:GetText()) + 8
        local subclassLabelWidth = t:MeasureText(t.Font.body, p.subclassLabel:GetText()) + 8
        local stacked = (editorWidth - 12) / 2 - math.max(categoryLabelWidth, subclassLabelWidth) < 130
        local groupWidth = stacked and editorWidth or (editorWidth - 12) / 2
        local subclassX = stacked and 0 or groupWidth + 12
        Place(p.classLabel, 0, y + 4, categoryLabelWidth, 24)
        Place(p.class, categoryLabelWidth, y, groupWidth - categoryLabelWidth, h)
        p.class:SetOptions(Addon.SendRules:Categories()); p.class:SetValue(draft.classID)
        if draft.classID == nil then p.class:SetText(Addon:T("UI.TEXT_0553")) end
        local subclasses = draft.classID ~= nil and Addon.SendRules:Categories(draft.classID) or {}
        -- The first entry is the synthetic “all” choice, not a subclass.
        local subclassCount = math.max(0, #subclasses - 1)
        if subclassCount <= 1 then
            local automatic = subclassCount == 1 and subclasses[2].value or nil
            if draft.subclassID ~= automatic then draft.subclassID = automatic; self.dirty = true end
        end
        if stacked then y = y + step end
        Place(p.subclassLabel, subclassX, y + 4, subclassLabelWidth, 24)
        Place(p.subclass, subclassX + subclassLabelWidth, y, groupWidth - subclassLabelWidth, h)
        p.subclass:SetOptions(subclasses); p.subclass:SetValue(draft.subclassID or -1)
        p.subclass:SetEnabled(subclassCount > 1)
        p.subclass:SetState(subclassCount > 1 and "default" or "disabled")
        if subclassCount <= 1 then p.subclass.menu:Hide() end
        if subclassCount == 0 then
            p.subclass:SetText(draft.classID == nil and Addon:T("UI.TEXT_0535") or Addon:T("UI.TEXT_0364"))
        end
        y = y + step
        if draft.classID == 5 or draft.classID ~= nil and subclassCount == 0 then
            p.categoryStatus:SetText(draft.classID == 5 and Addon:T("UI.TEXT_0494") or Addon:T("UI.TEXT_0227"))
            Place(p.categoryStatus, labelWidth, y, editorWidth - labelWidth, 0)
            local statusHeight = math.max(24, p.categoryStatus:GetStringHeight())
            p.categoryStatus:SetHeight(statusHeight); p.categoryStatus:Show(); y = y + statusHeight + 8
        end
    end
    p.excludeTitle:SetShown(category); p.excludeHelp:SetShown(category); p.exclude:SetShown(category)
    p.excludeHelp:SetText(category and Addon:T("UI.TEXT_0194") or Addon:T("UI.TEXT_0107"))
    p.excludeEmpty:SetShown(category and not next(draft.excluded))
    for _, row in ipairs(p.excludes) do row:Hide() end
    if category then
        Place(p.excludeTitle, 0, y + 8, editorWidth, 24); y = y + 36
        Place(p.excludeHelp, 0, y, editorWidth, 0); local helpHeight = math.max(24, p.excludeHelp:GetStringHeight()); p.excludeHelp:SetHeight(helpHeight); y = y + helpHeight + 8
        Place(p.exclude, 0, y); y = y + p.exclude:Layout(editorWidth) + 6
        for _, group in ipairs(p.exclude.controls) do group.control:SetEnabled(category and (group.control ~= p.exclude.retry or p.exclude.canRetry == true)) end
        if not category then p.exclude:Invalidate(); p.exclude.dropdown.menu:Hide() end
        local ids = {}; if category then for id in pairs(draft.excluded) do ids[#ids + 1] = id end end; table.sort(ids)
        if category and #ids == 0 then Place(p.excludeEmpty, 0, y, editorWidth, 24); y = y + 28 end
        for index, id in ipairs(ids) do
            local row = p.excludes[index]
            if not row then
                row = CreateFrame("Frame", nil, p.editor); p.excludes[index] = row
                row.label = Theme():CreateText(row, Theme().Font.body, Theme().Colors.text, "LEFT"); row.label:SetWordWrap(false)
                row.remove = Theme():CreateButton(row, 180, Addon:T("UI.TEXT_0472"))
            end
            row:Show(); row.itemID = id; Place(row, 0, y, editorWidth, 36)
            Place(row.label, 8, 3, editorWidth - bw - 16, 24); Place(row.remove, editorWidth - bw, 0, bw, h)
            local item = Addon.SendRules:GetItem(id) or {}
            row.label:SetText((item.icon and ("|T" .. item.icon .. ":20:20|t ") or "") .. (item.name or tostring(id)))
            row.remove:SetScript("OnClick", function() S.draft.excluded[id] = nil; S.dirty = true; S:Refresh() end)
            y = y + 36
        end
        y = y + 6
    end
    local deleteWidth = math.max(96, t:MeasureText(t.Font.body, p.deleteShortcut.label:GetText()) + 20)
    local cancelWidth = math.max(80, t:MeasureText(t.Font.body, p.cancel.label:GetText()) + 20)
    local saveWidth = math.max(112, t:MeasureText(t.Font.body, p.save.label:GetText()) + 20)
    p.deleteShortcut:SetEnabled(self.editID ~= nil and Addon.db.sendRules[self.editID] ~= nil)
    Place(p.deleteShortcut, 0, y, deleteWidth, h)
    if deleteWidth + cancelWidth + saveWidth + 16 > editorWidth then y = y + step end
    Place(p.cancel, editorWidth - cancelWidth - saveWidth - 8, y, cancelWidth, h)
    Place(p.save, editorWidth - saveWidth, y, saveWidth, h); y = y + 40
    p.notice:SetShown(self.notice ~= nil)
    if self.notice then Place(p.notice, 0, y, editorWidth, 0); p.notice:SetText(self.notice); local h = math.max(24, p.notice:GetStringHeight()); p.notice:SetHeight(h); y = y + h + 8 end
    return self:RenderBlacklist(editorWidth, y)
end
function S:Render(parent, width, host)
    local p = self.panel or self:Create(parent)
    if p:GetParent() ~= parent then p:SetParent(parent) end
    if not self.draft then self.draft = { kind = "item", enabled = true, recipient = "", excluded = {}, characters = {} }; self.syncDraft = true end
    self.editing, self.rendering = true, true
    Place(p, 0, 44, width); p:Show(); p.editor:Show(); p.list:Show()
    local twoColumns = width >= 780
    local editorWidth = twoColumns and math.floor((width - 24) * 0.58) or width
    local listWidth = twoColumns and width - editorWidth - 24 or width
    Place(p.editor, 0, 0, editorWidth)
    local ok, height = pcall(function()
        local editorHeight = self:RenderEditor(editorWidth); p.editor:SetHeight(editorHeight)
        Place(p.list, twoColumns and editorWidth + 24 or 0, twoColumns and 0 or editorHeight + 20, listWidth)
        local listHeight = self:RenderList(listWidth, host); p.list:SetHeight(listHeight)
        return twoColumns and math.max(editorHeight, listHeight) or editorHeight + 20 + listHeight
    end)
    self.rendering = nil
    if not ok then error(height) end
    p:SetHeight(height); return height
end
