local Addon = _G.YiboMail
local U = {}; Addon.RecipientUI = U
local R = Addon.Recipients
local ROW, GAP, FOOT = 28, 6, 36
local BACKDROP = { bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 }
local function IME(edit) return edit.IsInIMEComposition and edit:IsInIMEComposition() end
function U:Hide()
    self.hoveredSource = nil
    if self.popup then self.popup:Hide(); self.dismiss:Hide() end
    if self.home then self.home:Hide() end
    self.confirm = nil
end
function U:Create()
    if self.popup then return end
    local theme = Addon.Core.UITheme
    self.dismiss = CreateFrame("Button", nil, UIParent)
    self.dismiss:SetAllPoints(UIParent); self.dismiss:SetFrameStrata("DIALOG"); self.dismiss:SetFrameLevel(990)
    self.dismiss:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    self.dismiss:SetScript("OnClick", function() U:Hide() end)
    local p = CreateFrame("Frame", "YiboMailRecipientPopup", UIParent, "BackdropTemplate"); self.popup = p
    p:SetFrameStrata("DIALOG"); p:SetFrameLevel(995); p:SetClampedToScreen(true); p:EnableMouse(true)
    p:SetBackdrop(BACKDROP); p:SetBackdropColor(unpack(theme.Colors.bg)); p:SetBackdropBorderColor(unpack(theme.Colors.lineSoft))
    if _G.UISpecialFrames then table.insert(UISpecialFrames, "YiboMailRecipientPopup") end
    p:SetScript("OnHide", function() U.dismiss:Hide(); if U.home then U.home:Hide() end; U.confirm = nil; p.search:ClearFocus() end)
    local function Button(label, action)
        local b = theme:CreateButton(p, 100, label); b:SetHeight(ROW)
        b:SetScript("OnClick", action); return b
    end
    p.back = Button("‹ 返回", function()
        U.confirm = nil
        if U.realmMode then U.realmMode = nil elseif U.source then U.source, U.realm = nil, nil end
        U.page = 1; U:Refresh()
    end)
    p.back:SetPoint("TOPLEFT", GAP, -GAP); p.back:SetWidth(64)
    p.close = Button("×", function() U:Hide() end); p.close:SetWidth(ROW); p.close:SetPoint("TOPRIGHT", -GAP, -GAP)
    p.search = CreateFrame("EditBox", nil, p, "BackdropTemplate")
    p.search:SetPoint("TOPLEFT", 72, -GAP); p.search:SetPoint("TOPRIGHT", -40, -GAP); p.search:SetHeight(ROW)
    p.search:SetAutoFocus(false); p.search:SetMaxLetters(100); p.search:SetFont(STANDARD_TEXT_FONT, theme.Font.body, "OUTLINE")
    p.search:SetTextColor(unpack(theme.Colors.text)); p.search:SetTextInsets(8, 8, 0, 0)
    p.search.hint = theme:CreateText(p.search, theme.Font.assist, theme.Colors.muted, "LEFT")
    p.search.hint:SetPoint("LEFT", 8, 0); p.search.hint:SetText("全局搜索")
    p.search:SetBackdrop(BACKDROP); p.search:SetBackdropColor(unpack(theme.Colors.panel))
    p.search:SetScript("OnTextChanged", function() U.page = 1; U.confirm = nil; U.realmMode = nil; U:Refresh() end)
    p.search:SetScript("OnEscapePressed", function(edit)
        if IME(edit) then return end
        if edit:GetText() ~= "" then edit:SetText("") else U:Hide() end
    end)
    p.search:SetScript("OnEnterPressed", function(edit) if not IME(edit) then edit:ClearFocus() end end)
    p.filter = Button("服务器：全部", function() U.realmMode = not U.realmMode; U.page = 1; U:Refresh() end)
    p.filter:SetPoint("TOPLEFT", GAP, -40); p.filter:SetPoint("TOPRIGHT", -GAP, -40)
    p.rows = {}
    p.prev = Button("‹", function() U.page = U.page - 1; U:Refresh() end)
    p.prev:SetWidth(32); p.prev:SetPoint("BOTTOMLEFT", GAP, FOOT)
    p.next = Button("›", function() U.page = U.page + 1; U:Refresh() end)
    p.next:SetWidth(32); p.next:SetPoint("BOTTOMRIGHT", -GAP, FOOT)
    p.page = theme:CreateText(p, theme.Font.assist, theme.Colors.muted, "CENTER")
    p.page:SetPoint("LEFT", p.prev, "RIGHT", GAP, 0); p.page:SetPoint("RIGHT", p.next, "LEFT", -GAP, 0); p.page:SetHeight(ROW)
    p.action = Button("加入常用", function() U:Action() end)
    p.action:SetPoint("BOTTOMLEFT", GAP, GAP)
    p.action:SetScript("OnEnter", function(control)
        GameTooltip:SetOwner(control, "ANCHOR_RIGHT")
        local saved = U.slot and Addon.db.quickRecipients[U.slot]
        local address = saved and saved.address or SendMailNameEditBox and SendMailNameEditBox:GetText() or ""
        GameTooltip:SetText((R:Escape(address))); GameTooltip:Show()
    end)
    p.action:SetScript("OnLeave", function() GameTooltip:Hide() end)
    p.manage = Button("管理", function() end); p.manage:SetEnabled(false); p.manage:SetState("disabled")
    p.manage:SetPoint("BOTTOMRIGHT", -GAP, GAP); p.manage:SetWidth(76)
    p.action:SetPoint("RIGHT", p.manage, "LEFT", -GAP, 0)
    p.manage:SetScript("OnEnter", function(control)
        GameTooltip:SetOwner(control, "ANCHOR_RIGHT"); GameTooltip:SetText("后续在 Core 邮件设置页提供"); GameTooltip:Show()
    end)
    p.manage:SetScript("OnLeave", function() GameTooltip:Hide() end)
    self:Hide()
end
function U:SourceEntries()
    local entries = {}
    if self.slot then entries[#entries + 1] = { label = "自定义…", custom = true } end
    for _, source in ipairs(R.sources) do
        local count = #R:Candidates(source.id)
        local status = source.id == "friends" and R.friendStatus or source.id == "guild" and R.guildStatus
        entries[#entries + 1] = { label = source.label .. " · " .. count .. " 人" .. (status and " · " .. status or ""), source = source.id, disabled = count == 0 }
    end
    return entries
end
function U:ShowSources(x, y, width)
    local home = self.home
    if not home then
        local theme = Addon.Core.UITheme
        home = CreateFrame("Frame", nil, UIParent, "BackdropTemplate"); self.home = home
        home:SetFrameStrata("DIALOG"); home:SetFrameLevel(995); home:SetClampedToScreen(true); home:EnableMouse(true)
        home:SetBackdrop(BACKDROP); home:SetBackdropColor(unpack(theme.Colors.bg)); home:SetBackdropBorderColor(unpack(theme.Colors.lineSoft))
        home.title = theme:CreateButton(home, 180, "‹ 通讯录"); home.title:SetHeight(ROW)
        home.title:SetPoint("TOPLEFT", GAP, -GAP)
        home.title:SetScript("OnClick", function()
            U.source, U.realm, U.realmMode, U.page = nil, nil, nil, 1
            U.popup.search:SetText(""); U:Refresh()
        end)
        home.rows = {}
    end
    local entries = self:SourceEntries()
    home:SetSize(width, 40 + #entries * ROW + GAP); home:ClearAllPoints()
    home:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
    home.title:SetWidth(width - GAP * 2)
    for index, entry in ipairs(entries) do
        local row = home.rows[index]
        if not row then
            row = Addon.Core.UITheme:CreateButton(home, width - GAP * 2, ""); row:SetHeight(ROW)
            row:SetScript("OnClick", function(control)
                if control.entry.source ~= U.source then U:Select(control.entry) end
            end)
            row:SetScript("OnEnter", function(control) U:HoverSource(control) end)
            row:SetScript("OnLeave", function(control) if U.hoveredSource == control then U.hoveredSource = nil end end)
            home.rows[index] = row
        end
        row.entry = entry; row:SetWidth(width - GAP * 2)
        row:ClearAllPoints(); row:SetPoint("TOPLEFT", GAP, -(40 + (index - 1) * ROW))
        row:SetText(entry.label .. (entry.source and " ›" or "")); row:SetEnabled(not entry.disabled)
        local searching = self.popup.search:GetText():match("%S")
        row:SetState(entry.disabled and "disabled" or not searching and entry.source == self.source and "selected" or "default"); row:Show()
    end
    for index = #entries + 1, #home.rows do home.rows[index]:Hide() end
    home:Show()
end
function U:HoverSource(control)
    local entry = control.entry
    if not entry or not entry.source or entry.disabled or entry.source == self.source then return end
    self.hoveredSource = control
    local function Open()
        if U.hoveredSource == control and control:IsShown() and control.entry == entry then
            U.hoveredSource = nil
            U:Select(entry)
        end
    end
    if _G.C_Timer and C_Timer.After then C_Timer.After(0.15, Open) else Open() end
end
function U:Open(anchor, slot)
    self:Create(); self:Hide()
    self.anchor, self.slot, self.source, self.realm, self.realmMode, self.page = anchor, slot, nil, nil, nil, 1
    self.popup.search:SetText(""); self.dismiss:Show(); self.popup:Show(); self:Refresh()
end
function U:Entries()
    local query = self.popup.search:GetText()
    local searching = query:match("%S")
    if self.realmMode then
        local entries = { { label = "全部服务器", chooseRealm = true } }; local seen = {}
        for _, source in ipairs(R.sources) do
            if searching or source.id == self.source then
                for _, candidate in ipairs(R:Query(source.id, searching and query or "")) do
                    local _, _, _, realm = R:Normalize(candidate.address)
                    if realm and not seen[R:Key(realm)] then seen[R:Key(realm)] = true; entries[#entries + 1] = { label = realm, realm = realm, chooseRealm = true } end
                end
            end
        end
        table.sort(entries, function(a, b) if not a.realm then return b.realm ~= nil elseif not b.realm then return false end return a.realm < b.realm end)
        return entries
    end
    if searching then
        local entries, seen = {}, {}
        for _, source in ipairs(R.sources) do
            for _, candidate in ipairs(R:Query(source.id, query, self.realm)) do
                local key = R:Key(candidate.address)
                if not seen[key] then
                    local entry = { address = candidate.address, label = candidate.label, sources = {}, key = key }
                    seen[key] = entry; entries[#entries + 1] = entry
                end
                seen[key].sources[#seen[key].sources + 1] = source.label
            end
        end
        table.sort(entries, function(a, b) return a.key < b.key end)
        return entries
    end
    if self.source then return R:Query(self.source, "", self.realm) end
    return self:SourceEntries()
end
function U:Select(entry)
    if entry.disabled then return end
    self.confirm = nil
    if entry.custom then
        local slot = self.slot; self:Hide()
        local saved = Addon.db.quickRecipients[slot]
        Addon.NativeUI:PromptAddFavorite(saved and saved.address or "", slot)
    elseif entry.source then self.source, self.page, self.realm, self.realmMode = entry.source, 1, nil, nil; self:Refresh()
    elseif entry.chooseRealm then self.realm, self.realmMode, self.page = entry.realm, nil, 1; self:Refresh()
    elseif entry.address then
        -- Revalidate a visible result against its source after asynchronous updates.
        local entries = self:Entries(); local available = false
        for _, current in ipairs(entries) do if current.address and R:Key(current.address) == R:Key(entry.address) then available = true; break end end
        if not available then self:Refresh(); return end
        if self.slot then
            local ok = R:SetShortcut(self.slot, entry.address, entry.label)
            if not ok then return end
        else
            -- Close the picker only after the native recipient field accepts
            -- the selected address.
            if not SendMailNameEditBox or not Addon.NativeUI
                or not Addon.NativeUI:SetMailRecipient(entry.address) then return end
        end
        self:Hide()
    end
end
function U:Action()
    if self.slot then
        local saved = Addon.db.quickRecipients[self.slot]; if not saved then return end
        local token = self.slot .. ":" .. saved.address
        if self.confirm == token then R:ClearShortcut(self.slot); self:Hide()
        else self.confirm = token; self.popup.action:SetText("确认清空第 " .. self.slot .. " 格？") end
        return
    end
    local address = R:Normalize(SendMailNameEditBox and SendMailNameEditBox:GetText())
    if not address then return end
    if R:FindContact(address) then
        if self.confirm == address then R:RemoveContact(address); self.confirm = nil; self:Refresh()
        else self.confirm = address; self.popup.action:SetText("确认移出：" .. R:Label({ address = address }) .. "？") end
    else R:SaveContact(address); self:Refresh() end
end
function U:Refresh()
    local p = self.popup; if not p or not p:IsShown() or self.refreshing then return end
    self.refreshing = true
    self.confirm = nil
    p.search.hint:SetShown(p.search:GetText() == "")
    local entries = self:Entries()
    local screenWidth, screenHeight = UIParent:GetWidth(), UIParent:GetHeight()
    local maxHeight = math.min(360, screenHeight - 24)
    local width = math.min(200, screenWidth - 24)
    local anchor = self.anchor
    local left = anchor.GetLeft and anchor:GetLeft() or screenWidth / 2
    local right = anchor.GetRight and anchor:GetRight() or left + anchor:GetWidth()
    local top = anchor.GetTop and anchor:GetTop() or screenHeight / 2
    local bottom = anchor.GetBottom and anchor:GetBottom() or top - anchor:GetHeight()
    if anchor.GetEffectiveScale and UIParent.GetEffectiveScale then
        local factor = anchor:GetEffectiveScale() / UIParent:GetEffectiveScale()
        left, right, top, bottom = left * factor, right * factor, top * factor, bottom * factor
    end
    local header = self.source and 74 or 40
    local availableDown, availableUp = bottom - 12, screenHeight - top - 12
    local upward = not self.slot and availableDown < maxHeight and availableUp > availableDown
    if not self.slot then maxHeight = math.min(maxHeight, math.max(availableDown, availableUp)) end
    local capacity = math.max(1, math.floor((maxHeight - header - FOOT - GAP * 2) / ROW))
    if #entries > capacity then capacity = math.max(1, math.floor((maxHeight - header - FOOT - ROW - GAP * 2) / ROW)) end
    self.pageCount = math.max(1, math.ceil(#entries / capacity)); self.page = math.max(1, math.min(self.page or 1, self.pageCount))
    local first = (self.page - 1) * capacity + 1
    local visible = math.max(1, math.min(capacity, #entries - first + 1))
    local paging = self.pageCount > 1
    local height = header + visible * ROW + FOOT + (paging and ROW or 0) + GAP * 2
    p:SetSize(width, height); p:ClearAllPoints()
    if self.source then
        local homeWidth = math.min(200, screenWidth - 24)
        local homeHeight = 40 + #self:SourceEntries() * ROW + GAP
        local homeX = self.slot and right + 4 or right - homeWidth
        if self.slot and homeX + homeWidth > screenWidth - 12 then homeX = left - homeWidth - 4 end
        homeX = math.max(12, math.min(homeX, screenWidth - homeWidth - 12))
        local homeY = self.slot and top or upward and top + homeHeight + 2 or bottom - 2
        homeY = math.max(homeHeight + 12, math.min(homeY, screenHeight - 12))
        self:ShowSources(homeX, homeY, homeWidth)
        local x = homeX + homeWidth + 4
        if x + width > screenWidth - 12 then x = homeX - width - 4 end
        x = math.max(12, math.min(x, screenWidth - width - 12))
        p:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, math.max(height + 12, homeY))
    elseif self.slot then
        if self.home then self.home:Hide() end
        local x = right + 4
        if x + width > screenWidth - 12 then x = left - width - 4 end
        x = math.max(12, math.min(x, screenWidth - width - 12))
        local y = math.max(height + 12, math.min(top, screenHeight - 12))
        p:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
    else
        if self.home then self.home:Hide() end
        local x = math.max(12, math.min(right - width, screenWidth - width - 12))
        local y = upward and top + height + 2 or bottom - 2
        p:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, math.max(height + 12, math.min(y, screenHeight - 12)))
    end
    p.back:SetShown(self.source == nil)
    p.back:SetText(self.slot and "快捷格" or "通讯录")
    p.back:SetEnabled(false)
    p.search:ClearAllPoints()
    p.search:SetPoint("TOPLEFT", self.source and GAP or 72, -GAP)
    p.search:SetPoint("TOPRIGHT", p.close, "TOPLEFT", -GAP, 0)
    p.manage:SetWidth(math.min(64, math.floor(width * 0.34)))
    p.filter:SetShown(self.source ~= nil)
    p.filter:SetText(self.realmMode and "‹ 返回名单" or "服务器：" .. R:Escape(self.realm or "全部"))
    for index = 1, visible do
        local row = p.rows[index]
        if not row then
            row = Addon.Core.UITheme:CreateButton(p, width - 12, ""); row:SetHeight(ROW)
            row:SetScript("OnClick", function(control) U:Select(control.entry) end)
            row:SetScript("OnEnter", function(control)
                local entry = control.entry; if not entry then return end
                if entry.source then U:HoverSource(control) end
                if entry.source == "contacts" and (R.invalidContacts or 0) > 0 then
                    GameTooltip:SetOwner(control, "ANCHOR_RIGHT"); GameTooltip:SetText("常用收件人")
                    GameTooltip:AddLine("保留了 " .. R.invalidContacts .. " 条无法解析的旧记录，未加入候选。", 0.8, 0.85, 0.83, true); GameTooltip:Show(); return
                end
                if not entry.address then return end
                GameTooltip:SetOwner(control, "ANCHOR_RIGHT"); GameTooltip:SetText((R:Escape(entry.address)))
                if entry.sources then GameTooltip:AddLine(table.concat(entry.sources, "、"), 0.8, 0.85, 0.83, true) end
                if U.source == "accountFriends" then
                    for _, owner in ipairs(R:FriendOwners(entry.address)) do GameTooltip:AddLine(R:Escape(owner), 0.8, 0.85, 0.83, true) end
                    GameTooltip:AddLine("其它角色最近完整快照；登录后刷新。", 0.55, 0.78, 0.78, true)
                end
                GameTooltip:Show()
            end)
            row:SetScript("OnLeave", function(control) if U.hoveredSource == control then U.hoveredSource = nil end; GameTooltip:Hide() end); p.rows[index] = row
        end
        local entry = entries[first + index - 1] or { label = "暂无匹配的收件人", disabled = true }
        row.entry = entry; row:ClearAllPoints(); row:SetPoint("TOPLEFT", GAP, -(header + (index - 1) * ROW))
        row:SetWidth(width - GAP * 2); row:SetText(entry.address and R:Label(entry) or R:Escape(entry.label) .. (entry.source and " ›" or ""))
        row:SetEnabled(not entry.disabled); row:SetState(entry.disabled and "disabled" or "default"); row:Show()
    end
    for index = visible + 1, #p.rows do p.rows[index].entry = nil; p.rows[index]:Hide() end
    p.prev:SetShown(paging); p.next:SetShown(paging); p.page:SetShown(paging)
    p.prev:SetEnabled(self.page > 1); p.next:SetEnabled(self.page < self.pageCount)
    p.page:SetText(self.page .. " / " .. self.pageCount .. " · " .. #entries .. " 项")
    local saved = self.slot and Addon.db.quickRecipients[self.slot]
    local address = not self.slot and R:Normalize(SendMailNameEditBox and SendMailNameEditBox:GetText())
    p.action:SetText(self.slot and "清空此快捷格" or address and R:FindContact(address) and "移出常用" or "加入常用")
    local enabled = self.slot and saved ~= nil or not self.slot and address ~= nil
    p.action:SetEnabled(enabled); p.action:SetState(enabled and "default" or "disabled")
    self.refreshing = nil
end
