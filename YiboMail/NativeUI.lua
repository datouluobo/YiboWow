local Addon = _G.YiboMail
local Native = {}; Addon.NativeUI = Native
local View = Addon.ViewModel
local BACKDROP = { bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 }
local function StripNativeArt(control, hideText)
    if not control then return end
    if control.GetRegions then
        for _, region in ipairs({ control:GetRegions() }) do
            local kind = region.GetObjectType and region:GetObjectType()
            if kind == "Texture" or hideText and kind == "FontString" then region:SetAlpha(0) end
        end
    end
    for _, method in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture", "GetCheckedTexture" }) do
        local texture = control[method] and control[method](control)
        if texture then texture:SetAlpha(0) end
    end
    for _, key in ipairs({ "NineSlice", "backdrop", "Backdrop", "BorderFrame", "Background", "Bg", "shadow", "Shadow" }) do
        local decoration = control[key]
        if decoration then decoration:SetAlpha(0) end
    end
end
local function Text(parent, font, justify)
    local text = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
    text:SetJustifyH(justify or "LEFT"); text:SetWordWrap(false); return text
end
local function Button(parent, width, label, callback)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 24); button:SetText(label); button:SetScript("OnClick", callback); return button
end
local function InboxButton(parent, width, label, callback)
    local button = Addon.Core.UITheme:CreateButton(parent, width, label, "secondary")
    button:SetScript("OnClick", callback); return button
end
local function Surface(parent)
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetBackdrop(BACKDROP); frame:SetBackdropColor(0.025, 0.055, 0.055, 1); frame:SetBackdropBorderColor(0.18, 0.29, 0.27, 1)
    frame:EnableMouse(true); return frame
end
local function Tooltip(control, title, detail, link)
    control:SetScript("OnEnter", function()
        GameTooltip:SetOwner(control, "ANCHOR_RIGHT")
        if link then GameTooltip:SetHyperlink(link) else GameTooltip:SetText(title or ""); if detail then GameTooltip:AddLine(detail, 1, 1, 1, true) end end
        GameTooltip:Show()
    end)
    control:SetScript("OnLeave", function() GameTooltip:Hide() end)
end
-- Shared widgets are reused by the Mists mailbox surface.
Native.inboxWidgets = { Text, InboxButton, Surface, Tooltip, BACKDROP }
function Native:InstallMailboxTabs()
    if self.mailboxTabs or not MailFrameTab1 or not MailFrameTab2 then return end
    self.mailboxTabs = {}
    -- Own the navigation controls; leave Blizzard's two-page registry untouched.
    for _, entry in ipairs({ { "mail", Addon:T("UI.TEXT_0344") }, { "items", Addon:T("UI.TEXT_0635") }, { "send", Addon:T("UI.TEXT_0179") }, { "rules", Addon:T("MAILBOX.RULES") } }) do
        local key = entry[1]
        local tab = Addon.Core.UITheme:CreateButton(MailFrame, 1, entry[2], "secondary")
        local theme = Addon.Core.UITheme
        tab.indicator = tab:CreateTexture(nil, "OVERLAY")
        tab.indicator:SetColorTexture(unpack(theme.Colors.accent)); tab.indicator:SetHeight(2)
        tab.indicator:SetPoint("TOPLEFT"); tab.indicator:SetPoint("TOPRIGHT")
        tab.SetState = function(control, state)
            control.state = state or "default"
            control:SetBackdropColor(unpack(theme.Colors.nav))
            control:SetBackdropBorderColor(0, 0, 0, 0)
            control.label:SetTextColor(unpack(control.state == "selected" and theme.Colors.accent or theme.Colors.muted))
            control.indicator:SetShown(control.state == "selected")
        end
        tab:SetScript("OnEnter", function(control) control.label:SetTextColor(unpack(theme.Colors.text)) end)
        tab:SetScript("OnLeave", function(control) control:SetState(control.state) end)
        tab:SetFrameLevel(MailFrame:GetFrameLevel() + 20)
        tab:SetScript("OnClick", function() Native:SelectMailboxTab(key) end)
        self.mailboxTabs[key] = tab
    end
    MailFrameTab1:Hide(); MailFrameTab2:Hide()
    MailFrame:HookScript("OnSizeChanged", function() Native:LayoutMailboxTabs() end)
    self:RefreshMailboxTabs()
end
function Native:LayoutMailboxTabs()
    if not self.mailboxTabs then return end
    local gap = 2
    local width = math.max(1, (MailFrame:GetWidth() - gap * 3) / 4)
    local height = Addon.Core.UITheme.Size.compact
    for index, key in ipairs({ "mail", "items", "send", "rules" }) do
        local tab = self.mailboxTabs[key]
        tab:ClearAllPoints()
        tab:SetSize(width, height)
        tab:SetPoint("TOPLEFT", MailFrame, "BOTTOMLEFT", (index - 1) * (width + gap), 0)
    end
end
function Native:RefreshMailboxTabs()
    if not self.mailboxTabs then return end
    self:LayoutMailboxTabs()
    local key = Addon.RuleSendUI and Addon.RuleSendUI.active and "rules"
        or (self.activePage == 2 and "send" or (self.inbox and self.inbox.mode == "items" and "items" or "mail"))
    for name, tab in pairs(self.mailboxTabs) do tab:SetState(name == key and "selected" or "default") end
end
function Native:SelectMailboxTab(key)
    if key ~= "mail" and key ~= "items" and key ~= "send" and key ~= "rules" then return end
    if key ~= "mail" then self:CancelReturnConfirmation() end
    if key == "rules" and (not Addon.RuleSendUI or not Addon.RuleSendUI.root) then return end
    -- Rules and compose share native page 2. Always leave rule mode explicitly,
    -- even when Blizzard skips its page handler because page 2 is selected.
    if Addon.RuleSendUI then Addon.RuleSendUI:SetActive(false) end
    if self.inbox and (key == "mail" or key == "items") then
        local changed = self.inbox.mode ~= key
        self.inbox.mode, self.inbox.notice = key, nil
        if changed then
            self.inbox.keepTilesDuringQueue = nil
            self.inbox.scroll:SetVerticalScroll(0)
        end
        self.inbox.filter.menu:Hide(); self.inbox.menu.menu:Hide()
    end
    local page = (key == "send" or key == "rules") and 2 or 1
    if type(MailFrameTab_OnClick) == "function" then
        if securecallfunction then securecallfunction(MailFrameTab_OnClick, nil, page)
        else MailFrameTab_OnClick(nil, page) end
    end
    self:RememberBrowsePage(page, key)
    if key == "rules" then
        Addon.RuleSendUI:SetActive(true)
        Addon.RuleSendController:Scan(); Addon.RuleSendUI:Refresh()
    elseif page == 1 then self:RefreshInbox() end
    self:RefreshMailboxTabs()
end
function Native:SetMailRecipient(address)
    if not SendMailNameEditBox or type(address) ~= "string" or address == "" then return false end
    SendMailNameEditBox:SetText(address)
    if type(_G.SendMailFrame_Update) == "function" then _G.SendMailFrame_Update() end
    SendMailNameEditBox:ClearFocus()
    return SendMailNameEditBox:GetText() == address
end
function Native:CaptureMoneySendDraft()
    local compose = Addon.Compose
    local draft = { recipient = SendMailNameEditBox and SendMailNameEditBox:GetText() or "",
        subject = SendMailSubjectEditBox and SendMailSubjectEditBox:GetText() or "",
        body = compose and compose:GetBodyEditBox() and compose:GetBodyEditBox():GetText() or "",
        copper = MoneyInputFrame_GetCopper and SendMailMoney and MoneyInputFrame_GetCopper(SendMailMoney) or 0,
        cod = SendMailCODButton and SendMailCODButton:GetChecked() and true or false, attachments = {} }
    for _, item in ipairs(compose and compose:GetAttachments() or {}) do
        draft.attachments[#draft.attachments + 1] = { item.slot, item.itemLink or item.itemID, item.quantity }
    end
    return draft
end
function Native:MoneySendDraftMatches(expected)
    if not expected or not Addon.Scanner:IsOpen() then return false end
    local current = self:CaptureMoneySendDraft()
    for _, key in ipairs({ "recipient", "subject", "body", "copper", "cod" }) do
        if current[key] ~= expected[key] then return false end
    end
    if #current.attachments ~= #expected.attachments then return false end
    for index, item in ipairs(expected.attachments) do
        local actual = current.attachments[index]
        if not actual or actual[1] ~= item[1] or actual[2] ~= item[2] or actual[3] ~= item[3] then return false end
    end
    return current.copper > 0
end
function Native:ConfirmMoneySend(button, original, clickArgs)
    if Addon.db and Addon.db.settings and Addon.db.settings.confirmGoldSend == false then
        original(button, unpack(clickArgs)); return
    end
    if not StaticPopupDialogs or not StaticPopup_Show then
        Addon:Print(Addon:T("UI.TEXT_0671")); return
    end
    StaticPopupDialogs.YIBOMAIL_CONFIRM_GOLD_SEND = StaticPopupDialogs.YIBOMAIL_CONFIRM_GOLD_SEND or {
        text = "%s", button1 = Addon:T("UI.TEXT_0463"), button2 = Addon:T("UI.TEXT_0192"), timeout = 0,
        whileDead = true, hideOnEscape = 1, preferredIndex = 3,
        OnAccept = function(_, data)
            if Native.moneyConfirmPending ~= data then return end
            Native.moneyConfirmPending = nil
            if not Native:MoneySendDraftMatches(data.draft) or not data.button:IsEnabled() then
                Addon:Print(Addon:T("UI.TEXT_0672")); return
            end
            data.original(data.button, unpack(data.clickArgs))
        end,
        OnCancel = function(_, data)
            if Native.moneyConfirmPending == data then Native.moneyConfirmPending = nil end
        end,
    }
    if self.moneyConfirmPending then return end
    local draft = self:CaptureMoneySendDraft()
    if draft.copper <= 0 then original(button, unpack(clickArgs)); return end
    local data = { draft = draft, button = button, original = original, clickArgs = clickArgs }
    self.moneyConfirmPending = data
    local popup = StaticPopup_Show("YIBOMAIL_CONFIRM_GOLD_SEND",
        Addon:T("UI.TEXT_0670", draft.recipient, View:Money(draft.copper)), nil, data)
    if not popup then self.moneyConfirmPending = nil; Addon:Print(Addon:T("UI.TEXT_0671")) end
end
function Native:InstallMoneySendConfirmation()
    local button = _G.SendMailMailButton or _G.SendMailSendButton
    if self.moneyConfirmationInstalled or not button then return end
    local original = button:GetScript("OnClick")
    if type(original) ~= "function" then return end
    self.moneyConfirmationInstalled, self.nativeSendButton = true, button
    button:SetScript("OnClick", function(control, ...)
        if Native.moneyConfirmPending then return end
        if Addon.Compose and Addon.Compose:HasSendMoney() then
            local args = { ... }
            Native:ConfirmMoneySend(control, original, args)
            return
        end
        return original(control, ...)
    end)
end
local function ContactAddressKey(value)
    return string.lower((tostring(value or "")):gsub("%s", ""))
end
function Native:RememberInboxFilters()
    if not self.inbox or self.applyingPreferences or not Addon:GetInboxPreferences().rememberFilters then return end
    Addon.db.settings.inboxFilters = Addon.Copy(self.inbox.options)
end
function Native:RememberInboxSort()
    if not self.inbox or self.applyingPreferences or not Addon.db or not Addon.db.settings then return end
    local settings = Addon.db.settings.inbox or {}
    Addon.db.settings.inbox = settings
    settings.sort = self.inbox.options.sort == "inbox" and "inbox" or "expiry"
end
function Native:RememberBrowsePage(page, tab)
    if not Addon.db or not Addon.db.settings then return end
    if page == 1 or page == 2 then self.activePage = page end
    if self.restorePagePending or self.restoringPage then return end
    local settings = Addon.db.settings.inbox or {}
    Addon.db.settings.inbox = settings
    settings.page = self.activePage or 1
    if tab == "mail" or tab == "items" or tab == "send" or tab == "rules" then settings.tab = tab end
    if self.inbox and (self.inbox.mode == "mail" or self.inbox.mode == "items") then settings.mode = self.inbox.mode end
end
function Native:RestoreBrowsePage()
    local settings = Addon.db.settings.inbox or {}
    local tab = settings.tab
    if tab ~= "mail" and tab ~= "items" and tab ~= "send" and tab ~= "rules" then
        tab = settings.page == 2 and "send" or (self.inbox and self.inbox.mode == "items" and "items" or "mail")
    end
    if tab == "rules" and (not Addon.RuleSendUI or not Addon.RuleSendUI.root) then tab = "send" end
    local page = (tab == "send" or tab == "rules") and 2 or 1
    self.activePage = page
    self.restoringPage = true
    self:SelectMailboxTab(tab)
    self.restoringPage = nil
    self.restorePagePending = nil
    self:RememberBrowsePage(page, tab)
end
function Native:RestoreBrowsePageWhenShown()
    self.restorePagePending = true
    self:ApplyInboxPreferences()
    self:Refresh()
    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            if MailFrame:IsShown() then Native:RestoreBrowsePage()
            else Native.restorePagePending = nil end
        end)
    else self:RestoreBrowsePage() end
end
function Native:ApplyInboxPreferences(deferWhileOpen)
    if not self.readyInbox then return end
    if deferWhileOpen and Addon.Scanner:IsOpen() then return end
    local prefs = Addon:GetInboxPreferences()
    local options = prefs.rememberFilters and Addon.db.settings.inboxFilters or nil
    self.applyingPreferences = true
    self.inbox.mode = prefs.mode
    local savedSort = Addon.db.settings.inbox and Addon.db.settings.inbox.sort
    if savedSort ~= "expiry" and savedSort ~= "inbox" then savedSort = nil end
    self.inbox.options = { search = options and options.search or "", kind = options and options.kind or prefs.kind,
        sort = savedSort or options and options.sort or prefs.sort }
    self.inbox.search:SetText(self.inbox.options.search); self.inbox.filter:SetValue(self.inbox.options.kind)
    self.applyingPreferences = nil
    self:RefreshInbox()
end
function Native:Context()
    local character = Addon.Core.Characters:GetCurrent({ identityOnly = true })
    return { characters = character and { character } or {} }
end
function Native:Dropdown(parent, width, label)
    local dropdown = Addon.Core.UITheme:CreateDropdown(parent, width, {})
    dropdown.menu:SetParent(parent)
    local open = dropdown:GetScript("OnClick")
    dropdown:SetScript("OnClick", function(control)
        open(control)
        Native:RaiseDropdown(control)
    end)
    dropdown:SetText(label); return dropdown
end
function Native:RaiseDropdown(control)
    local parent = control:GetParent()
    control.menu:SetFrameStrata(parent:GetFrameStrata())
    control.menu:SetFrameLevel(parent:GetFrameLevel() + 30)
    for _, button in ipairs(control.menu.buttons) do button:SetFrameLevel(control.menu:GetFrameLevel() + 1) end
end
function Native:CreateBasicSend()
    local panel = CreateFrame("Frame", nil, SendMailFrame); self.send = panel
    panel:SetAllPoints(SendMailFrame); panel:SetFrameLevel(SendMailFrame:GetFrameLevel() + 1)
    local theme = Addon.Core.UITheme
    panel.shell = CreateFrame("Frame", nil, MailFrame, "BackdropTemplate")
    panel.shell:SetAllPoints(MailFrame); panel.shell:SetFrameLevel(MailFrame:GetFrameLevel() + 1)
    panel.shell:SetBackdrop(BACKDROP); panel.shell:SetBackdropColor(unpack(theme.Colors.bg)); panel.shell:SetBackdropBorderColor(unpack(theme.Colors.lineSoft))
    local function CreateSendField(label)
        local field = Surface(panel)
        field.label = theme:CreateText(field, theme.Font.body, theme.Colors.muted, "LEFT")
        field.label:SetPoint("LEFT", 8, 0); field.label:SetWidth(58); field.label:SetHeight(theme.Size.standard)
        field.label:SetText(label)
        return field
    end
    panel.recipientField = CreateSendField(Addon:T("UI.TEXT_0332"))
    panel.subjectField = CreateSendField(Addon:T("UI.TEXT_0100"))
    panel.close = InboxButton(panel, 22, "x", function() if HideUIPanel then HideUIPanel(MailFrame) else MailFrame:Hide() end end)
    panel.close:SetSize(theme.Size.standard, theme.Size.standard); panel.close:SetPoint("TOPRIGHT", MailFrame, "TOPRIGHT", -8, -6)
    panel.contactPage, panel.serverPage = 1, 1
    panel.contacts = self:Dropdown(panel, theme.Size.standard, "")
    panel.contacts:SetSize(theme.Size.standard, theme.Size.standard)
    panel.contacts:SetPoint("TOPRIGHT", panel.close, "TOPLEFT", -6, 0)
    panel.favoritesExpanded = true
    panel.favoritesPanel = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    panel.favoritesPanel:SetFrameLevel(panel:GetFrameLevel() + 2)
    panel.favoritesPanel:SetBackdrop(BACKDROP)
    panel.favoritesPanel:SetBackdropColor(unpack(theme.Colors.bg))
    panel.favoritesPanel:SetBackdropBorderColor(unpack(theme.Colors.lineSoft))
    panel.favoritesPanel:EnableMouse(true)
    panel.favoriteButtons = {}
    for index = 1, 72 do
        local button = CreateFrame("Button", nil, panel.favoritesPanel, "BackdropTemplate")
        button:SetBackdrop(BACKDROP)
        button:SetBackdropColor(unpack(theme.Colors.panel))
        button:SetBackdropBorderColor(unpack(theme.Colors.lineSoft))
        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetPoint("TOPLEFT", 1, -1); button.icon:SetPoint("BOTTOMRIGHT", -1, 1)
        button.emptyMark = theme:CreateText(button, theme.Font.title, theme.Colors.muted, "CENTER")
        button.emptyMark:SetAllPoints(); button.emptyMark:SetText("+")
        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        button:RegisterForDrag("LeftButton")
        button.slot = index
        button:SetScript("OnDragStart", function(control) Native:StartShortcutDrag(control) end)
        button:SetScript("OnDragStop", function() Native:FinishShortcutDrag() end)
        button:SetScript("OnClick", function(control, mouseButton)
            if control.suppressShortcutClick or Native.shortcutDrag then
                control.suppressShortcutClick = nil; return
            end
            if mouseButton == "RightButton" then Addon.RecipientUI:Open(control, control.slot); return end
            -- A picked-up item uses the same route as a drag release. Always
            -- stop here, including failed drops, so this click cannot also send
            -- an existing draft or execute a rule contact action.
            if mouseButton == "LeftButton" and GetCursorInfo and GetCursorInfo() == "item" then
                if Addon.RuleSendUI then Addon.RuleSendUI:Drop(control.contact) end
                return
            end
            local contact = control.contact
            if not contact then return end
            if Addon.RuleSendUI and Addon.RuleSendUI.active then
                local ok, err = Addon.RuleSendController:Contact(contact.address)
                if not ok then Addon.RuleSendController.notice = err end
                Addon.RuleSendUI:Refresh(); return
            end
            if not SendMailNameEditBox then return end
            Native:SetMailRecipient(contact.address)
            local hasAttachments = Addon.Compose and #Addon.Compose:GetAttachments() > 0
            local hasMoney = Addon.Compose and Addon.Compose.HasSendMoney and Addon.Compose:HasSendMoney()
            if hasAttachments or hasMoney then
                if Addon.Compose.EnsureSubject then Addon.Compose:EnsureSubject() end
                local sendButton = _G.SendMailMailButton or _G.SendMailSendButton
                if not sendButton then Addon:Print(Addon:T("UI.TEXT_0174")); return end
                -- Recompute the native button state after changing the recipient, then
                -- run its Blizzard click handler directly. Button:Click() ignores a
                -- disabled button, which made the first favorite click only fill the
                -- recipient and required a second click to send.
                if type(_G.SendMailFrame_Update) == "function" then _G.SendMailFrame_Update() end
                local onClick = sendButton:GetScript("OnClick")
                if type(onClick) == "function" then
                    onClick(sendButton, "LeftButton")
                else
                    sendButton:Click("LeftButton")
                end
            end
        end)
        button:SetScript("OnReceiveDrag", function(control)
            if Addon.RuleSendUI then Addon.RuleSendUI:Drop(control.contact) end
        end)
        button:SetScript("OnEnter", function(control)
            control:SetBackdropBorderColor(unpack(theme.Colors.accent))
            local contact = control.contact
            if not contact then return end
            GameTooltip:SetOwner(control, "ANCHOR_RIGHT")
            -- Escape uses string.gsub internally, which also returns the
            -- replacement count. Parenthesize it so the tooltip receives only
            -- the escaped string as its first argument.
            GameTooltip:SetText((Addon.Recipients:Escape(contact.address)))
            if Addon.RuleSendUI and Addon.RuleSendUI.active then
                local c = Addon.RuleSendController
                local ready = c.state == "ready" and c.packet and Addon.Recipients:Key(c.packet[1].recipient) == Addon.Recipients:Key(contact.address)
                GameTooltip:AddLine(ready and Addon:T("UI.TEXT_0146") or Addon:T("UI.TEXT_0451"), 0.55, 0.78, 0.78, true)
                GameTooltip:AddLine(Addon:T("UI.TEXT_0318"), 0.55, 0.78, 0.78, true)
            else GameTooltip:AddLine(Addon:T("UI.TEXT_0319"), 0.55, 0.78, 0.78, true) end
            GameTooltip:AddLine(Addon:T("UI.TEXT_0244"), 0.55, 0.78, 0.78, true)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function(control)
            local contact, c = control.contact, Addon.RuleSendController
            local hit = Addon.RuleSendUI and Addon.RuleSendUI.active and contact and c and c.match and c.match.groups[Addon.Recipients:Key(contact.address)]
            control:SetBackdropBorderColor(unpack(hit and theme.Colors.accent or theme.Colors.lineSoft)); GameTooltip:Hide()
        end)
        panel.favoriteButtons[index] = button
    end
    panel.favoriteToggle = InboxButton(panel, theme.Size.standard, "<", function()
        panel.favoritesExpanded = not panel.favoritesExpanded
        panel.favoritesPanel:SetShown(panel.favoritesExpanded)
        panel.favoriteToggle:SetText(panel.favoritesExpanded and "<" or ">")
        Tooltip(panel.favoriteToggle, panel.favoritesExpanded and Addon:T("UI.TEXT_0352") or Addon:T("UI.TEXT_0243"))
    end)
    panel.favoriteToggle:SetSize(theme.Size.standard, theme.Size.standard)
    panel.favoriteToggle:SetPoint("LEFT", panel.contacts, "RIGHT", 6, 0)
    Tooltip(panel.favoriteToggle, Addon:T("UI.TEXT_0352"))
    panel.favoriteEntries = {}
    panel.contacts:SetScript("OnClick", function(control)
        local picker = Addon.RecipientUI
        if picker.popup and picker.popup:IsShown() and picker.anchor == control then picker:Hide()
        else picker:Open(control) end
    end)
    Tooltip(panel.contacts, Addon:T("UI.TEXT_0338"), Addon:T("UI.TEXT_0325"))
    if SendMailNameEditBox then SendMailNameEditBox:HookScript("OnTextChanged", function() Addon.RecipientUI.confirm = nil; Addon.RecipientUI:Refresh() end) end
    panel.balance = theme:CreateText(panel, theme.Font.body, theme.Colors.text, "LEFT")
    panel.balance:SetPoint("BOTTOMLEFT", MailFrame, "BOTTOMLEFT", 14, 8)
    panel.balance:SetSize(148, theme.Size.standard)
    panel.moneyEvents = CreateFrame("Frame", nil, panel)
    panel.moneyEvents:RegisterEvent("PLAYER_MONEY")
    panel.moneyEvents:SetScript("OnEvent", function() Native:RefreshSendBalance() end)
    panel:SetScript("OnShow", function() Native:LayoutBasicSend(); Native:RefreshSend() end)
    panel:SetScript("OnHide", function() panel.contacts.menu:Hide(); Addon.RecipientUI:Hide(); if Native.favoriteEditor then Native.favoriteEditor:Hide() end; Native:HideShortcutIconPicker(); panel.shell:Hide(); panel.favoritesPanel:Hide() end)
    panel.favoritesPanel:SetScript("OnSizeChanged", function() Native:LayoutFavoriteButtons() end)
    panel.favoritesPanel:HookScript("OnHide", function() Native:CancelShortcutDrag() end)
    MailFrame:HookScript("OnSizeChanged", function() Native:LayoutBasicSend(); Addon.RecipientUI:Refresh() end)
    MailFrame:HookScript("OnDragStop", function() Addon.RecipientUI:Refresh() end)
    self.readySend = true
end
function Native:CancelShortcutDrag()
    local drag = self.shortcutDrag
    self.shortcutDrag = nil
    if drag then
        drag.button:SetAlpha(1)
        if C_Timer and C_Timer.After then
            C_Timer.After(0, function() drag.button.suppressShortcutClick = nil end)
        end
    end
    if self.shortcutGhost then self.shortcutGhost:Hide(); self.shortcutGhost:SetScript("OnUpdate", nil) end
end
function Native:StartShortcutDrag(button)
    self:CancelShortcutDrag()
    local saved = Addon.db.quickRecipients[button.slot]
    if not saved or not button.contact or not button:IsShown() then return end
    self:HideShortcutIconPicker()
    Addon.RecipientUI:Hide(); GameTooltip:Hide()
    self.shortcutDrag = { button = button, saved = saved }
    button.suppressShortcutClick = true; button:SetAlpha(0.45)
    local ghost = self.shortcutGhost
    if not ghost then
        ghost = CreateFrame("Frame", nil, UIParent); self.shortcutGhost = ghost
        ghost:SetFrameStrata("TOOLTIP"); ghost:EnableMouse(false)
        ghost.icon = ghost:CreateTexture(nil, "ARTWORK"); ghost.icon:SetAllPoints()
    end
    ghost:SetSize(button:GetWidth(), button:GetHeight())
    local coords = not button.contact.icon and button.contact.class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[button.contact.class]
    ghost.icon:SetTexture(button.contact.icon or (coords and "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES" or "Interface\\Icons\\INV_Misc_GroupLooking"))
    if coords then ghost.icon:SetTexCoord(unpack(coords)) else ghost.icon:SetTexCoord(0.06, 0.94, 0.06, 0.94) end
    local function FollowCursor()
        local x, y = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        ghost:ClearAllPoints(); ghost:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
    end
    ghost:SetScript("OnUpdate", FollowCursor); FollowCursor(); ghost:Show()
end
function Native:FinishShortcutDrag()
    local drag = self.shortcutDrag
    if not drag then return end
    local target
    for _, button in ipairs(self.send.favoriteButtons) do
        if button:IsShown() and button:IsMouseOver() then target = button; break end
    end
    local insideBar = self.send.favoritesPanel:IsMouseOver()
    self:CancelShortcutDrag()
    -- A drag release must never fall through to the normal click-to-send path.
    drag.button.suppressShortcutClick = true
    if target then
        target.suppressShortcutClick = true
        local ok, err = Addon.Recipients:MoveShortcut(drag.button.slot, target.slot, drag.saved)
        if not ok then Addon:Print(err) end
    elseif not insideBar then
        local ok, err = Addon.Recipients:ClearShortcut(drag.button.slot, drag.saved)
        if not ok then Addon:Print(err) end
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            drag.button.suppressShortcutClick = nil
            if target then target.suppressShortcutClick = nil end
        end)
    end
end
function Native:HideShortcutIconPicker()
    if self.shortcutIconConfig and Addon.Core.iconPicker and Addon.Core.iconPicker.config == self.shortcutIconConfig then
        Addon.Core:HideIconPicker()
    end
    self.shortcutIconConfig = nil
end
function Native:EditShortcutIcon(slot)
    local saved = Addon.db.quickRecipients[slot]
    if not saved then return end
    if type(Addon.Core.ShowIconPicker) ~= "function" then Addon:Print(Addon:T("UI.TEXT_0537")); return end
    self:CancelShortcutDrag()
    local contact = self.send.favoriteEntries[slot]
    local coords = contact and contact.class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[contact.class]
    local config = {
        icon = saved.icon,
        autoTexture = coords and "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES" or "Interface\\Icons\\INV_Misc_GroupLooking",
        autoCoords = coords,
        onConfirm = function(icon)
            local ok, err = Addon.Recipients:SetShortcutIcon(slot, icon, saved)
            if not ok then Addon:Print(err) end
        end,
    }
    self.shortcutIconConfig = config
    Addon.Core:ShowIconPicker(config)
end
function Native:LayoutFavoriteButtons()
    self:CancelShortcutDrag()
    local panel = self.send
    local favorites = panel and panel.favoritesPanel
    if not favorites then return end
    local width, height = favorites:GetWidth(), favorites:GetHeight()
    if width <= 0 or height <= 0 then return end
    local gapX, gapY, paddingX, paddingY = 6, 4, 6, 6
    local rows, columns = Addon:GetShortcutLayout()
    local size = math.max(1, math.min(math.floor((width - paddingX * 2 - gapX * (columns - 1)) / columns), math.floor((height - paddingY * 2 - gapY * (rows - 1)) / rows)))
    local totalWidth, totalHeight = size * columns + gapX * (columns - 1), size * rows + gapY * (rows - 1)
    local left, top = math.floor((width - totalWidth) / 2), math.floor((height - totalHeight) / 2)
    for index, button in ipairs(panel.favoriteButtons) do
        local row, column = math.floor((index - 1) / columns), (index - 1) % columns
        button:ClearAllPoints(); button:SetSize(size, size)
        button:SetPoint("TOPLEFT", favorites, "TOPLEFT", left + column * (size + gapX), -(top + row * (size + gapY)))
        button:SetShown(panel.favoritesExpanded and index <= rows * columns)
    end
end
function Native:PromptAddFavorite(prefill, slot)
    local editor = self.favoriteEditor
    if not editor then
        local theme = Addon.Core.UITheme
        editor = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        editor:SetSize(344, 156); editor:SetPoint("CENTER")
        editor:SetFrameStrata("DIALOG"); editor:SetFrameLevel(1000)
        editor:SetClampedToScreen(true); editor:EnableMouse(true); editor:SetToplevel(true)
        editor:SetBackdrop(BACKDROP); editor:SetBackdropColor(unpack(theme.Colors.bg)); editor:SetBackdropBorderColor(unpack(theme.Colors.lineSoft))
        editor.title = theme:CreateText(editor, theme.Font.section, theme.Colors.text, "LEFT")
        editor.title:SetPoint("TOPLEFT", 14, -12); editor.title:SetText(Addon:T("UI.TEXT_0613"))
        editor.address = CreateFrame("EditBox", nil, editor, "BackdropTemplate")
        editor.address:SetPoint("TOPLEFT", 14, -42); editor.address:SetSize(316, theme.Size.standard)
        editor.address:SetAutoFocus(false); editor.address:SetMaxLetters(160)
        editor.address:SetFont(STANDARD_TEXT_FONT, theme.Font.body, "OUTLINE"); editor.address:SetTextColor(unpack(theme.Colors.text))
        editor.address:SetTextInsets(8, 8, 0, 0); editor.address:SetBackdrop(BACKDROP)
        editor.address:SetBackdropColor(unpack(theme.Colors.panel)); editor.address:SetBackdropBorderColor(unpack(theme.Colors.lineSoft))
        editor.status = theme:CreateText(editor, theme.Font.assist, theme.Colors.muted, "LEFT")
        editor.status:SetPoint("TOPLEFT", editor.address, "BOTTOMLEFT", 0, -5); editor.status:SetPoint("RIGHT", editor, "RIGHT", -14, 0); editor.status:SetHeight(20)
        editor.cancel = InboxButton(editor, 76, Addon:T("UI.TEXT_0192"), function() editor:Hide() end)
        editor.cancel:SetPoint("BOTTOMRIGHT", -14, 10)
        editor.save = InboxButton(editor, 76, Addon:T("UI.TEXT_0118"), function() Native:SaveFavoriteFromEditor() end)
        editor.save:SetPoint("RIGHT", editor.cancel, "LEFT", -6, 0)
        editor.address:SetScript("OnEnterPressed", function() Native:SaveFavoriteFromEditor() end)
        editor.address:SetScript("OnEscapePressed", function()
            if editor.address.IsInIMEComposition and editor.address:IsInIMEComposition() then return end
            editor.address:ClearFocus(); editor:Hide()
        end)
        editor:SetScript("OnShow", function()
            editor.address:SetFocus(); editor.address:HighlightText()
        end)
        editor:SetScript("OnHide", function() editor.address:ClearFocus() end)
        self.favoriteEditor = editor
    end
    editor.slot = slot
    editor.title:SetText(Addon:T("UI.TEXT_0612") .. tostring(slot) .. Addon:T("UI.TEXT_0041"))
    editor.address:SetText(prefill or ""); editor.status:SetText(""); editor:Show()
end
function Native:SaveFavoriteFromEditor()
    local editor = self.favoriteEditor
    if not editor then return end
    local address = editor.address:GetText()
    if editor.address.IsInIMEComposition and editor.address:IsInIMEComposition() then return end
    local ok, err = Addon.Recipients:SetShortcut(editor.slot, address)
    if not ok then editor.status:SetText(err or Addon:T("UI.TEXT_0120")); editor.address:SetFocus(); editor.address:HighlightText(); return end
    Addon:Print(Addon:T("UI.TEXT_0300"))
    editor:Hide()
    self:RefreshBasicSend()
end
function Native:RefreshFavoriteButtons()
    local panel = self.send
    if not panel or not panel.favoriteButtons then return end
    local roster, byAddress = Addon.Core.Characters:GetAllCached(), {}
    for _, character in ipairs(roster) do
        local address = character.name .. "-" .. character.realm
        byAddress[ContactAddressKey(address)] = character
    end
    panel.favoriteEntries = {}
    for index = 1, 72 do
        local saved = Addon.db.quickRecipients and Addon.db.quickRecipients[index]
        local address = saved and Addon.Recipients:Normalize(saved.address)
        if address then
            local character = byAddress[ContactAddressKey(address)]
            panel.favoriteEntries[index] = { address = address, label = saved.label, icon = saved.icon, class = character and character.class }
        end
    end
    for index, button in ipairs(panel.favoriteButtons) do
        local contact = panel.favoriteEntries[index]
        button.contact = contact
        local match = Addon.RuleSendController and Addon.RuleSendController.match
        local hit = Addon.RuleSendUI and Addon.RuleSendUI.active and contact and match and match.groups[Addon.Recipients:Key(contact.address)]
        local c = Addon.RuleSendController
        local selected = Addon.RuleSendUI and Addon.RuleSendUI.active and contact and c and c.packet and c.owned
            and Addon.Recipients:Key(c.packet[1].recipient) == Addon.Recipients:Key(contact.address)
        button:SetBackdropBorderColor(unpack(selected and Addon.Core.UITheme.Colors.text or hit and Addon.Core.UITheme.Colors.accent or Addon.Core.UITheme.Colors.lineSoft))
        if button.hitLabel == nil then
            button.hitLabel = Addon.Core.UITheme:CreateText(button, Addon.Core.UITheme.Font.assist, Addon.Core.UITheme.Colors.text, "RIGHT")
            button.hitLabel:SetPoint("BOTTOMRIGHT", -2, 2)
        end
        button.hitLabel:SetText(selected and Addon:T("UI.TEXT_0182") or hit and tostring(hit.quantity) or "")
        local rows, columns = Addon:GetShortcutLayout()
        button:SetShown(panel.favoritesExpanded and index <= rows * columns)
        button.emptyMark:SetShown(contact == nil)
        if contact then
            local coords = contact.class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[contact.class]
            if contact.icon then
                button.icon:SetTexture(contact.icon); button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            elseif coords then
                button.icon:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
                button.icon:SetTexCoord(unpack(coords))
            else
                button.icon:SetTexture("Interface\\Icons\\INV_Misc_GroupLooking")
                button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            end
        else
            button.icon:SetTexture(nil)
        end
    end
    self:LayoutFavoriteButtons()
end
function Native:LayoutBasicSend()
    local panel = self.send
    if not panel or Addon.FEATURES.sendAssist or not MailFrame or not SendMailNameEditBox then return end
    local theme = Addon.Core.UITheme
    local frameWidth = MailFrame:GetWidth()
    local fieldWidth = math.max(170, frameWidth - 124)
    local labelWidth = math.max(theme:MeasureText(theme.Font.body, Addon:T("UI.TEXT_0332")), theme:MeasureText(theme.Font.body, Addon:T("UI.TEXT_0100")))
    panel.inputInset = labelWidth + 20
    panel.recipientField.label:SetWidth(labelWidth); panel.subjectField.label:SetWidth(labelWidth)
    panel.recipientField:ClearAllPoints(); panel.recipientField:SetPoint("TOPLEFT", MailFrame, "TOPLEFT", 8, -6); panel.recipientField:SetSize(fieldWidth, theme.Size.standard)
    panel.subjectField:ClearAllPoints(); panel.subjectField:SetPoint("TOPLEFT", panel.recipientField, "BOTTOMLEFT", 0, -4); panel.subjectField:SetSize(fieldWidth, theme.Size.standard)
    local function StyleInput(editBox, field)
        if not editBox then return end
        StripNativeArt(editBox)
        -- The field's opaque backdrop is above the original native EditBox.
        -- Keep the native input above it for both text rendering and mouse input.
        if editBox:GetParent() ~= field then editBox:SetParent(field) end
        editBox:SetFrameLevel(field:GetFrameLevel() + 1)
        editBox:ClearAllPoints(); editBox:SetPoint("LEFT", field, "LEFT", panel.inputInset, 0); editBox:SetWidth(math.max(1, fieldWidth - panel.inputInset - 6))
        editBox:SetFont(STANDARD_TEXT_FONT, theme.Font.body, "OUTLINE"); editBox:SetTextColor(unpack(theme.Colors.text))
        for _, region in ipairs({ editBox:GetRegions() }) do
            if type(region.GetObjectType) == "function" then
                local objectType = region:GetObjectType()
                local name = type(region.GetName) == "function" and region:GetName() or nil
                local nativeBackground = name == "SendMailNameEditBoxLeft" or name == "SendMailNameEditBoxMiddle" or name == "SendMailNameEditBoxRight"
                    or name == "SendMailSubjectEditBoxLeft" or name == "SendMailSubjectEditBoxMiddle" or name == "SendMailSubjectEditBoxRight"
                if objectType == "Texture" and nativeBackground then region:SetAlpha(0)
                elseif objectType == "FontString" then
                    local text = region:GetText()
                    if text and ((type(MAIL_TO_LABEL) == "string" and text == MAIL_TO_LABEL)
                        or (type(MAIL_SUBJECT_LABEL) == "string" and text == MAIL_SUBJECT_LABEL)
                        or text == Addon:T("UI.TEXT_0340") or text == Addon:T("UI.TEXT_0333") or text == Addon:T("UI.TEXT_0102") or text == Addon:T("UI.TEXT_0101")) then region:Hide() end
                end
            end
        end
    end
    StyleInput(SendMailNameEditBox, panel.recipientField)
    StyleInput(SendMailSubjectEditBox, panel.subjectField)
    local body = Addon.Compose:GetBodyEditBox()
    if body and SendMailScrollChildFrame then
        body:ClearAllPoints()
        body:SetPoint("TOPLEFT", SendMailScrollChildFrame, "TOPLEFT", 6, -10)
        body:SetWidth(math.max(140, SendMailScrollChildFrame:GetWidth() - 16))
    end
    panel.contacts:ClearAllPoints(); panel.contacts:SetSize(theme.Size.standard, theme.Size.standard)
    panel.contacts:SetPoint("TOPRIGHT", panel.close, "TOPLEFT", -theme.Size.standard - 6, 0)
    panel.favoriteToggle:ClearAllPoints(); panel.favoriteToggle:SetSize(theme.Size.standard, theme.Size.standard)
    panel.favoriteToggle:SetPoint("LEFT", panel.contacts, "RIGHT", 6, 0)
    panel.favoritesPanel:ClearAllPoints(); panel.favoritesPanel:SetPoint("TOPLEFT", MailFrame, "TOPRIGHT", 0, 0)
    local gridGapX, gridGapY, gridPaddingX, gridPaddingY = 6, 4, 6, 6
    local rows, columns = Addon:GetShortcutLayout()
    -- Keep the existing tile size when fewer rows are displayed.
    local sizingRows = math.max(8, rows)
    local tileSize = math.max(1, math.floor((MailFrame:GetHeight() - gridPaddingY * 2 - gridGapY * (sizingRows - 1)) / sizingRows))
    panel.favoritesPanel:SetWidth(tileSize * columns + gridGapX * (columns - 1) + gridPaddingX * 2)
    panel.favoritesPanel:SetHeight(MailFrame:GetHeight())
    panel.favoritesPanel:SetShown(panel.favoritesExpanded)
    panel.favoriteToggle:SetText(panel.favoritesExpanded and "<" or ">")
    self:LayoutFavoriteButtons()
    local postage = _G.SendMailCostMoneyFrame
    if postage then postage:ClearAllPoints(); postage:SetPoint("TOPRIGHT", MailFrame, "TOPRIGHT", -12, -48) end
    if _G.SendMailMoneyFrame then _G.SendMailMoneyFrame:Hide() end
    local sendButton = _G.SendMailMailButton or _G.SendMailSendButton
    local cancelButton = SendMailCancelButton
    if sendButton and cancelButton then
        local width, height = 80, theme.Size.compact
        cancelButton:ClearAllPoints(); cancelButton:SetSize(width, height)
        cancelButton:SetPoint("BOTTOMRIGHT", MailFrame, "BOTTOMRIGHT", -8, 8)
        sendButton:ClearAllPoints(); sendButton:SetSize(width, height)
        sendButton:SetPoint("RIGHT", cancelButton, "LEFT", -6, 0)
    end
    panel.balance:ClearAllPoints(); panel.balance:SetPoint("BOTTOMLEFT", MailFrame, "BOTTOMLEFT", 8, 8)
    panel.balance:SetSize(math.max(60, frameWidth - (Addon.RuleSendUI and Addon.RuleSendUI.active and 276 or 194)), theme.Size.compact)
    panel.balance:SetFont(STANDARD_TEXT_FONT, theme.Font.assist, "")
    self:LayoutSendMoney()
    self:LayoutSendAttachments()
    self:StyleComposeAppearance()
    self:InstallBodyScrollHooks()
    self:RefreshBodyScrollBar()
    if Addon.RuleSendUI and Addon.RuleSendUI.root then Addon.RuleSendUI:Layout() end
    self:RefreshSendBalance()
end
function Native:StyleComposeAppearance()
    local panel, theme = self.send, Addon.Core.UITheme
    if not panel then return end
    StripNativeArt(SendMailFrame)
    for _, name in ipairs({ "SendStationeryBackgroundLeft", "SendStationeryBackgroundRight", "SendMailMoneyInset", "SendMailMoneyBg", "SendMailMoneyFrame" }) do
        local decoration = _G[name]
        if decoration then
            decoration:Hide()
            if decoration.HookScript and not decoration.yiboMailHidden then
                decoration.yiboMailHidden = true
                decoration:HookScript("OnShow", function(control) control:Hide() end)
            end
        end
    end
    local wrapper = _G.MailEditBox or _G.SendMailScrollFrame
    local body = Addon.Compose:GetBodyEditBox()
    StripNativeArt(wrapper); StripNativeArt(_G.SendMailScrollChildFrame)
    if wrapper then StripNativeArt(wrapper.ScrollBox) end
    if wrapper then
        wrapper:SetFrameLevel(panel:GetFrameLevel() + 2)
        if not wrapper.yiboMailBodySurface then
            local surface = CreateFrame("Frame", nil, wrapper, "BackdropTemplate")
            surface:SetAllPoints(wrapper); surface:SetFrameLevel(wrapper:GetFrameLevel()); surface:EnableMouse(false)
            surface:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
            surface:SetBackdropColor(unpack(theme.Colors.bg)); wrapper.yiboMailBodySurface = surface
        end
    end
    if body then body:SetFont(STANDARD_TEXT_FONT, theme.Font.body, ""); body:SetTextColor(unpack(theme.Colors.text)) end
    if _G.SendMailCostMoneyFrame then
        for _, region in ipairs({ SendMailCostMoneyFrame:GetRegions() }) do
            if region.GetObjectType and region:GetObjectType() == "FontString" then
                region:SetFont(STANDARD_TEXT_FONT, theme.Font.assist, ""); region:SetTextColor(unpack(theme.Colors.muted))
            end
        end
    end
    local bar = _G.MailEditBoxScrollBar or _G.SendMailScrollFrameScrollBar
    if bar then
        if wrapper then
            bar:ClearAllPoints(); bar:SetPoint("TOPLEFT", wrapper, "TOPRIGHT", 4, -2); bar:SetPoint("BOTTOMLEFT", wrapper, "BOTTOMRIGHT", 4, 2)
            bar:SetWidth(14); bar:SetFrameLevel(wrapper:GetFrameLevel() + 2)
        end
        StripNativeArt(bar)
        StripNativeArt(bar.Track)
        local thumb = bar.ThumbTexture or (bar.GetThumbTexture and bar:GetThumbTexture())
        if thumb then thumb:SetColorTexture(unpack(theme.Colors.accent)); thumb:SetAlpha(1) end
        if bar.Thumb then
            StripNativeArt(bar.Thumb)
            if not bar.Thumb.yiboMailFill then
                bar.Thumb.yiboMailFill = bar.Thumb:CreateTexture(nil, "ARTWORK")
                bar.Thumb.yiboMailFill:SetAllPoints(); bar.Thumb.yiboMailFill:SetColorTexture(unpack(theme.Colors.accent))
            end
            bar.Thumb.yiboMailFill:SetAlpha(1)
        end
        for _, key in ipairs({ "ScrollUpButton", "ScrollDownButton", "Back", "Forward" }) do
            local button = bar[key]
            if button then
                StripNativeArt(button)
                if not button.yiboMailArrow then
                    button.yiboMailArrow = theme:CreateText(button, theme.Font.body, theme.Colors.muted, "CENTER")
                    button.yiboMailArrow:SetAllPoints(); button.yiboMailArrow:SetText((key == "ScrollUpButton" or key == "Back") and "↑" or "↓")
                end
            end
        end
    end
    if _G.SendMailFrameLockSendMail then SendMailFrameLockSendMail:SetFrameLevel(panel:GetFrameLevel() + 10) end
end
function Native:RefreshBodyScrollBar()
    local scroll = _G.MailEditBox and MailEditBox.ScrollBox or _G.SendMailScrollFrame
    local bar = _G.MailEditBoxScrollBar or _G.SendMailScrollFrameScrollBar or (scroll and scroll.ScrollBar)
    if not bar then return end
    local range = scroll and (scroll.GetDerivedScrollRange and scroll:GetDerivedScrollRange()
        or scroll.GetVerticalScrollRange and scroll:GetVerticalScrollRange()) or 0
    bar:SetShown(range > 0 and SendMailFrame:IsShown() and not (Addon.RuleSendUI and Addon.RuleSendUI.active))
end
function Native:InstallBodyScrollHooks()
    if not self.send or self.send.bodyScrollHooks then return end
    local scroll = _G.MailEditBox and MailEditBox.ScrollBox or _G.SendMailScrollFrame
    local bar = _G.MailEditBoxScrollBar or _G.SendMailScrollFrameScrollBar or (scroll and scroll.ScrollBar)
    local body = Addon.Compose:GetBodyEditBox()
    if not scroll or not bar or not body then return end
    self.send.bodyScrollHooks = true
    local function Refresh()
        Native:RefreshBodyScrollBar()
        if C_Timer and C_Timer.After then C_Timer.After(0, function() Native:RefreshBodyScrollBar() end) end
    end
    bar:HookScript("OnShow", function() Native:RefreshBodyScrollBar() end)
    scroll:HookScript("OnSizeChanged", Refresh)
    body:HookScript("OnTextChanged", Refresh)
    if _G.MailEditBox then
        if MailEditBox.SetBackdropBorderColor then MailEditBox:SetBackdropBorderColor(0, 0, 0, 0) end
        for _, key in ipairs({ "backdrop", "Backdrop", "BorderFrame" }) do
            local decoration = MailEditBox[key]
            if decoration and decoration.SetBackdropBorderColor then decoration:SetBackdropBorderColor(0, 0, 0, 0) end
        end
    end
end
function Native:SendRegionLayout()
    local columns, gap = 8, 4
    local count = ATTACHMENTS_MAX_SEND or 12
    local rows = math.ceil(count / columns)
    local size = math.min(36, (MailFrame:GetWidth() - 16 - gap * (columns - 1)) / columns)
    local bottom = 42
    return { columns = columns, gap = gap, count = count, rows = rows, size = size,
        attachmentBottom = bottom, controlsBottom = bottom + rows * size + (rows - 1) * gap + 8,
        moneyHeight = Addon.Core.UITheme.Size.compact * 2 + 4 }
end
function Native:LayoutSendAttachments()
    local layout = self:SendRegionLayout()
    local columns, gap, count, rows, size, bottom = layout.columns, layout.gap, layout.count, layout.rows, layout.size, layout.attachmentBottom
    for index = 1, count do
        local button = _G["SendMailAttachment" .. index] or (SendMailFrame.SendMailAttachments and SendMailFrame.SendMailAttachments[index])
        if button then
            local row, column = math.floor((index - 1) / columns), (index - 1) % columns
            button:ClearAllPoints(); button:SetSize(size, size)
            button:SetPoint("BOTTOMLEFT", MailFrame, "BOTTOMLEFT", 8 + column * (size + gap), bottom + (rows - row - 1) * (size + gap))
            self:StyleSendAttachment(button, index)
            button:Show()
        end
    end
    for index = count + 1, math.max(count, ATTACHMENTS_MAX or 16, #(SendMailFrame.SendMailAttachments or {})) do
        local button = _G["SendMailAttachment" .. index] or (SendMailFrame.SendMailAttachments and SendMailFrame.SendMailAttachments[index])
        if button then button:Hide() end
    end
    if SendMailScrollFrame and SendMailAttachment1 then
        SendMailScrollFrame:ClearAllPoints(); SendMailScrollFrame:SetPoint("TOPLEFT", MailFrame, "TOPLEFT", 8, -82)
        SendMailScrollFrame:SetPoint("BOTTOMRIGHT", MailFrame, "BOTTOMRIGHT", -8, layout.controlsBottom + layout.moneyHeight + 10)
    end
    if _G.MailEditBox and SendMailAttachment1 then
        MailEditBox:ClearAllPoints(); MailEditBox:SetPoint("TOPLEFT", MailFrame, "TOPLEFT", 8, -82)
        MailEditBox:SetPoint("BOTTOMRIGHT", MailFrame, "BOTTOMRIGHT", -8, layout.controlsBottom + layout.moneyHeight + 10)
    end
end
function Native:StyleSendAttachment(button, index)
    local theme = Addon.Core.UITheme
    button:SetFrameLevel(self.send:GetFrameLevel() + 2)
    StripNativeArt(button, true)
    local skin = button.yiboMailAttachment
    if not skin then
        skin = CreateFrame("Frame", nil, button, "BackdropTemplate")
        skin:SetAllPoints(button); skin:SetFrameLevel(button:GetFrameLevel() + 1); skin:EnableMouse(false)
        skin:SetBackdrop(BACKDROP); skin:SetBackdropColor(unpack(theme.Colors.panel))
        skin.icon = skin:CreateTexture(nil, "ARTWORK")
        skin.icon:SetPoint("TOPLEFT", 1, -1); skin.icon:SetPoint("BOTTOMRIGHT", -1, 1); skin.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        skin.count = theme:CreateText(skin, theme.Font.assist, theme.Colors.text, "RIGHT")
        skin.count:SetPoint("BOTTOMRIGHT", -2, 2)
        button.yiboMailAttachment = skin
        button:HookScript("OnEnter", function() skin:SetBackdropBorderColor(unpack(theme.Colors.accent)) end)
        button:HookScript("OnLeave", function() skin:SetBackdropBorderColor(unpack(theme.Colors.lineSoft)) end)
    end
    local name, id, texture, quantity
    if GetSendMailItem then name, id, texture, quantity = GetSendMailItem(index) end
    skin.icon:SetTexture(name and texture or nil); skin.icon:SetShown(name ~= nil)
    skin.count:SetText(name and (quantity or 0) > 1 and tostring(quantity) or "")
    skin:SetBackdropBorderColor(unpack(theme.Colors.lineSoft))
end
function Native:LayoutSendMoney()
    local theme = Addon.Core.UITheme
    local bottom = self:SendRegionLayout().controlsBottom
    local money = _G.SendMailMoney
    if money then
        if money:GetParent() ~= self.send then money:SetParent(self.send) end
        money:SetFrameLevel(self.send:GetFrameLevel() + 2)
        money:ClearAllPoints(); money:SetPoint("BOTTOMLEFT", MailFrame, "BOTTOMLEFT", 8, bottom + theme.Size.compact + 4); money:SetHeight(theme.Size.compact)
        for _, unit in ipairs({ "Gold", "Silver", "Copper" }) do
            local input = _G["SendMailMoney" .. unit] or money[unit:lower()] or money[unit]
            if input then
                StripNativeArt(input)
                local offset = unit == "Gold" and 0 or unit == "Silver" and 78 or 122
                input:ClearAllPoints(); input:SetPoint("LEFT", money, "LEFT", offset, 0)
                input:SetSize(unit == "Gold" and 58 or 24, theme.Size.compact)
                input:SetFont(STANDARD_TEXT_FONT, theme.Font.assist, ""); input:SetTextColor(unpack(theme.Colors.text)); input:SetTextInsets(4, 4, 0, 0)
                if input.texture then
                    input.texture:SetAlpha(1); input.texture:ClearAllPoints(); input.texture:SetPoint("LEFT", input, "RIGHT", 2, 0); input.texture:SetSize(13, 13)
                end
                if input.label then input.label:ClearAllPoints(); input.label:SetPoint("LEFT", input, "RIGHT", 2, 0) end
                if not input.yiboMailInput then
                    local surface = CreateFrame("Frame", nil, input:GetParent(), "BackdropTemplate")
                    surface:SetAllPoints(input); surface:SetFrameLevel(math.max(0, input:GetFrameLevel() - 1)); surface:EnableMouse(false)
                    surface:SetBackdrop(BACKDROP); surface:SetBackdropColor(unpack(theme.Colors.panel)); surface:SetBackdropBorderColor(unpack(theme.Colors.lineSoft))
                    input.yiboMailInput = surface
                end
            end
        end
    end
    if _G.SendMailMoneyText then _G.SendMailMoneyText:Hide() end
    local controls = { { "SendMailSendMoneyButton", Addon:T("UI.TEXT_0231") }, { "SendMailCODButton", Addon:T("UI.TEXT_0157") } }
    local left = 8
    for _, entry in ipairs(controls) do
        local control = _G[entry[1]]
        if control then
            if control:GetParent() ~= self.send then control:SetParent(self.send) end
            control:SetFrameLevel(self.send:GetFrameLevel() + 2)
            StripNativeArt(control)
            if not control.yiboMailRadio then
                local skin = CreateFrame("Frame", nil, control, "BackdropTemplate")
                skin:SetAllPoints(control); skin:EnableMouse(false); skin:SetBackdrop(BACKDROP)
                skin:SetBackdropColor(unpack(theme.Colors.panel)); skin:SetBackdropBorderColor(unpack(theme.Colors.lineSoft))
                skin.mark = skin:CreateTexture(nil, "ARTWORK"); skin.mark:SetPoint("TOPLEFT", 4, -4); skin.mark:SetPoint("BOTTOMRIGHT", -4, 4)
                skin.mark:SetColorTexture(unpack(theme.Colors.accent)); control.yiboMailRadio = skin
                control:HookScript("OnClick", function() Native:LayoutSendMoney() end)
            end
            control.yiboMailRadio.mark:SetShown(control.GetChecked and control:GetChecked() or false)
            control:ClearAllPoints(); control:SetSize(18, 18)
            control:SetPoint("BOTTOMLEFT", MailFrame, "BOTTOMLEFT", left, bottom + 4)
            local label = _G[entry[1] .. "Text"] or control.Text
            if label then
                if label:GetParent() ~= control then label:SetParent(control) end
                label:SetText(entry[2]); label:SetFont(STANDARD_TEXT_FONT, theme.Font.assist, "")
                label:ClearAllPoints(); label:SetPoint("LEFT", control, "RIGHT", 4, 0)
                label:SetWidth(theme:MeasureText(theme.Font.assist, entry[2]) + 2); label:SetHeight(theme.Size.compact); label:SetWordWrap(false)
            end
            left = left + 18 + 4 + theme:MeasureText(theme.Font.assist, entry[2]) + 16
        end
    end
end
function Native:RefreshSendBalance()
    local balance = self.send and self.send.balance
    if not balance or type(GetMoney) ~= "function" then return end
    local gold = math.floor((tonumber(GetMoney()) or 0) / 10000)
    local digits = tostring(gold)
    local formatted = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    balance:SetText(formatted .. " |TInterface\\MoneyFrame\\UI-GoldIcon:14:14:2:0|t")
end
function Native:RefreshBasicSend()
    local panel = self.send
    if not panel or not panel:IsShown() or self.refreshingSend then return end
    self.refreshingSend = true
    self:LayoutBasicSend()
    panel.contacts:SetText("")
    self:RefreshFavoriteButtons()
    Addon.RecipientUI:Refresh()
    self.refreshingSend = nil
end
function Native:RefreshSend()
    self:RefreshBasicSend()
    if Addon.RuleSendUI then Addon.RuleSendUI:Refresh() end
end
local function StyleNativeActionButton(button, primary, labelKey)
    if not button then return end
    local theme = Addon.Core.UITheme
    local skin = CreateFrame("Frame", nil, button, "BackdropTemplate")
    skin:SetAllPoints(button); skin:SetFrameLevel(button:GetFrameLevel() + 1); skin:EnableMouse(false)
    skin:SetBackdrop(BACKDROP)
    skin.label = theme:CreateText(skin, theme.Font.body, theme.Colors.text, "CENTER")
    skin.label:SetAllPoints()
    button.yiboMailSkin = skin
    local function Apply(hovered)
        local enabled = button:IsEnabled()
        local fill = enabled and (primary and theme.Colors.chrome or theme.Colors.panel) or theme.Colors.bg
        local border = enabled and (hovered and theme.Colors.accent or (primary and theme.Colors.line or theme.Colors.lineSoft)) or theme.Colors.lineSoft
        skin:SetBackdropColor(unpack(fill))
        skin:SetBackdropBorderColor(unpack(border))
        skin.label:SetText(Addon:T(labelKey))
        skin.label:SetTextColor(unpack(enabled and theme.Colors.text or theme.Colors.muted))
        for _, region in ipairs({ button:GetRegions() }) do
            if type(region.GetObjectType) == "function" then
                local objectType = region:GetObjectType()
                if objectType == "Texture" then region:SetAlpha(0)
                elseif objectType == "FontString" then region:SetAlpha(0) end
            end
        end
    end
    Apply(false)
    button:HookScript("OnEnter", function() Apply(true) end)
    button:HookScript("OnLeave", function() Apply(false) end)
    button:HookScript("OnEnable", function() Apply(false) end)
    button:HookScript("OnDisable", function() Apply(false) end)
end
function Native:Install()
    if self.installed or not MailFrame or not InboxFrame then return end
    if Addon.FEATURES.send and (not SendMailFrame or not SendMailNameEditBox or not SendMailCancelButton) then return end
    if InCombatLockdown and InCombatLockdown() then return end
    -- Do not initialize or restyle Blizzard panels during login. In particular,
    -- leave hidden mailbox state untouched before GameMenu's logout callback.
    if not MailFrame:IsShown() then
        if not self.waitingForMailbox then
            self.waitingForMailbox = true
            MailFrame:HookScript("OnShow", function() Native:Install() end)
        end
        return
    end
    self.installed = true
    if Addon.FEATURES.send and hooksecurefunc and type(ContainerFrameItemButton_OnModifiedClick) == "function" then
        hooksecurefunc("ContainerFrameItemButton_OnModifiedClick", function(button)
            if not button or not IsControlKeyDown or not IsControlKeyDown()
                or not SendMailFrame or not SendMailFrame:IsShown() or (CursorHasItem and CursorHasItem()) then return end
            local parent = button:GetParent()
            local bag = button.bagID or (parent and (parent:GetID() or parent.bagID))
            local slot = button:GetID()
            if bag == nil or not slot then return end
            local ok, message = Addon.Compose:AddMatchingBagItems(bag, slot)
            if self.send then self.send.notice = message; self:RefreshSend() end
        end)
    end
    if Addon.FEATURES.send and not Addon.FEATURES.sendAssist then
        StyleNativeActionButton(_G.SendMailMailButton or _G.SendMailSendButton, true, "UI.TEXT_0182")
        StyleNativeActionButton(SendMailCancelButton, false, "UI.TEXT_0192")
    end
    if Addon.FEATURES.send then self:InstallMoneySendConfirmation() end
    self:CreateInbox()
    if Addon.FEATURES.send then self:CreateBasicSend(); if Addon.RuleSendUI then Addon.RuleSendUI:Install() end end
    if Addon.FEATURES.send and hooksecurefunc and type(SendMailFrame_Update) == "function" then
        hooksecurefunc("SendMailFrame_Update", function() Native:LayoutBasicSend() end)
    end
    self:InstallMailboxTabs()
    if OpenMailFrame then OpenMailFrame:HookScript("OnHide", function() Native.openMailKey = nil end) end
    InboxFrame:HookScript("OnShow", function()
        Native:RememberBrowsePage(1)
        Native:SuppressInboxContent(); Native:RefreshInbox()
    end)
    if hooksecurefunc and type(InboxFrame_Update) == "function" then hooksecurefunc("InboxFrame_Update", function() Native:SuppressInboxContent() end) end
    if SendMailFrame then SendMailFrame:HookScript("OnShow", function()
        Native:RememberBrowsePage(2)
        local close = MailFrame.CloseButton or _G.MailFrameCloseButton
        if close and close:GetParent() ~= Native.nativeInboxContent then
            if Addon.FEATURES.send and not Addon.FEATURES.sendAssist then close:Hide() else close:Show() end
        end
        if Addon.FEATURES.send and not Addon.FEATURES.sendAssist then Native:SetInboxShell(true) end
        if Addon.FEATURES.send and not Addon.FEATURES.sendAssist then
            if MailFrame.TitleText then MailFrame.TitleText:SetAlpha(0) end
            for _, name in ipairs({ "MailFrameTitleText", "SendMailFrameTitleText", "SendMailTitleText" }) do
                if _G[name] then _G[name]:SetAlpha(0) end
            end
        end
        if Native.send and Native.send.shell then Native.send.shell:Show() end
        if Addon.FEATURES.send then
            Native:LayoutBasicSend()
            if C_Timer and C_Timer.After and not Addon.FEATURES.sendAssist then C_Timer.After(0, function() Native:LayoutBasicSend() end) end
            Native:RefreshSend()
        end
    end) end
    if hooksecurefunc and type(MailFrameTab_OnClick) == "function" then
        hooksecurefunc("MailFrameTab_OnClick", function(_, page)
            if page == 1 or page == 2 then Native:RememberBrowsePage(page); Native:RefreshMailboxTabs() end
        end)
    end
    MailFrame:HookScript("OnShow", function()
        Native:RestoreBrowsePageWhenShown()
    end)
    MailFrame:HookScript("OnHide", function()
        if Native.moneyConfirmPending then
            StaticPopup_Hide("YIBOMAIL_CONFIRM_GOLD_SEND")
            Native.moneyConfirmPending = nil
        end
        Native:SetInboxShell(false)
        if Addon.RuleSendUI then Addon.RuleSendUI:SetActive(false) end
        Native.deleting = nil
        Native.restorePagePending = nil
        Native:RememberBrowsePage()
        Native:RememberInboxFilters()
        Native.inbox.selection = {}
        Native.inbox.search:ClearFocus(); Native.inbox.filter.menu:Hide(); Native.inbox.menu.menu:Hide()
        if Native.send then
            Native.send.notice = nil; Native.send.contacts.menu:Hide()
        end
    end)
    Addon.Items.Events:Register(self, function() Native.deleting = nil; Native:Refresh(true) end)
    Addon.Frame:HookScript("OnUpdate", function()
        if Addon.RuleSendController then Addon.RuleSendController:Tick() end
        if Native.deleting and GetTime() - Native.deleteStartedAt > 12 then
            Native.deleting = nil; Native.inbox.notice = Addon:T("UI.TEXT_0154"); Native:RefreshInbox()
        end
    end)
    self:RestoreBrowsePageWhenShown()
end
function Native:Refresh(observation)
    self:RefreshInbox(observation); if Addon.FEATURES.send then self:RefreshSend() end
end
function Native:OnEvent(event, itemID, success)
    if event == "MAIL_CLOSED" then self:CancelReturnConfirmation() end
    if event == "MAIL_FAILED" and self.deleting then
        self.deleting = nil; self.inbox.notice = Addon:T("UI.TEXT_0153")
    end
    if event == "GET_ITEM_INFO_RECEIVED" then
        if self.pendingItemInfo and self.pendingItemInfo[itemID] then
            self.pendingItemInfo[itemID] = nil
            if success then self:RefreshInbox() end
        end
        return
    end
    if event == "ADDON_LOADED" or event == "MAIL_SHOW" or event == "PLAYER_REGEN_ENABLED" then self:Install() end
    if event == "MAIL_SEND_SUCCESS" then
        if self.send then
            self.send.notice = Addon:T("UI.TEXT_0184")
            if self.send.status then self.send.status:SetText(Addon:T("UI.TEXT_0183")) end
        end
    elseif event == "MAIL_FAILED" and self.send and self.send.status then
        self.send.status:SetText(Addon:T("UI.TEXT_0188"))
    end
    if not self.installed then return end
    if event == "MAIL_INBOX_UPDATE" or event == "MAIL_SUCCESS" or event == "MAIL_SHOW" or event == "MAIL_FAILED" then
        self:Refresh(true)
    elseif Addon.FEATURES.send and (event == "MAIL_SEND_INFO_UPDATE" or event == "MAIL_SEND_SUCCESS" or event == "BAG_UPDATE_DELAYED") then
        self:RefreshSend()
    end
end
