local Addon = _G.YiboMail
local Native, Returns = Addon.NativeUI, Addon.Returns
local Tooltip = Native.inboxWidgets[4]

function Native:GetSelectableMailActions(entry)
    local actions = Addon:GetInboxActions(entry)
    -- Collection keeps attachment selection; return-only letters get one
    -- envelope selection rather than pretending they contain lootable slots.
    if not entry.actionable and entry.mail.canReturn == true and Returns:IsLive(entry) then
        return { { id = Returns:MailID(entry), slot = "mail", actionable = true, entry = entry } }
    end
    if #actions == 0 and entry.mail.canReturn == true and Returns:IsLive(entry) then
        actions[1] = { id = Returns:MailID(entry), slot = "mail", actionable = true, entry = entry }
    end
    return actions
end
function Native:GetCollectSelection(entries)
    local selection, count, recognized = {}, 0, {}
    for _, entry in ipairs(entries) do
        recognized[Returns:MailID(entry)] = true
        for _, action in ipairs(Addon:GetInboxActions(entry)) do
            recognized[action.id] = true
            if action.actionable and self.inbox.selection[action.id] then
                selection[action.id], count = true, count + 1
            end
        end
    end
    for id in pairs(self.inbox.selection) do
        if not recognized[id] then return nil, 0, Addon:T("UI.TEXT_0610") end
    end
    return selection, count
end
function Native:UpdateReturnButton(entries)
    local panel, queue = self.inbox, Addon.Queue
    local selected, eligible, reasons = Returns:Selection(entries or {}, panel.selection)
    panel.returnMail:SetText(Addon:T("RETURN.BUTTON", #selected))
    panel.returnMail:SetWidth(math.max(72, panel.returnMail.label:GetStringWidth() + 20))
    panel.returnMail:SetShown(panel.mode == "mail" and #selected > 0)
    panel.returnMail:SetEnabled(eligible > 0 and queue.state ~= "running" and not queue.pending
        and not self.deleting and not self.returnConfirmation)
    panel.returnMail:SetState(panel.returnMail:IsEnabled() and "default" or "disabled")
    local detail = { Addon:T("RETURN.WHOLE_MAIL") }
    local sorted = {}; for reason in pairs(reasons) do sorted[#sorted + 1] = reason end; table.sort(sorted)
    for _, reason in ipairs(sorted) do detail[#detail + 1] = Addon:T("RETURN.SKIP_REASON", reasons[reason], reason) end
    Tooltip(panel.returnMail, Addon:T("RETURN.TITLE"), table.concat(detail, "\n"))
    return #selected
end
function Native:CancelReturnConfirmation()
    local request = self.returnConfirmation
    self.returnConfirmation = nil
    if request then request:Cancel() end
end
function Native:ReturnSelectedMail()
    local panel, queue = self.inbox, Addon.Queue
    if self.returnConfirmation or self.deleting or queue.state == "running" or queue.pending then return end
    local plan, err = Returns:Prepare(panel.selection, self:Context())
    if not plan then panel.notice = err; self:RefreshInbox(); return end
    if not (Addon.Core.ItemConfirmation and type(Addon.Core.ItemConfirmation.Show) == "function") then
        panel.notice = Addon:T("RETURN.CONFIRM_UNAVAILABLE"); self:RefreshInbox(); return
    end
    local detail = { Addon:T("RETURN.CONFIRM", #plan.actions, plan.skipped), Addon:T("RETURN.WHOLE_MAIL") }
    local sorted = {}; for reason in pairs(plan.reasons) do sorted[#sorted + 1] = reason end; table.sort(sorted)
    for _, reason in ipairs(sorted) do detail[#detail + 1] = Addon:T("RETURN.SKIP_REASON", plan.reasons[reason], reason) end
    local request
    request = Addon.Core.ItemConfirmation:Show({ text = table.concat(detail, "\n\n"),
        OnAccept = function()
            if Native.returnConfirmation ~= request then return end
            Native.returnConfirmation = nil
            if Native.deleting or queue.state == "running" or queue.pending then
                panel.notice = Addon:T("UI.TEXT_0552"); Native:RefreshInbox(); return
            end
            if not panel:IsShown() or panel.mode ~= "mail" or not Returns:Matches(plan, panel.selection) then
                panel.notice = Addon:T("RETURN.CHANGED"); Native:RefreshInbox(); return
            end
            -- Close an open letter without its native on-close deletion path.
            if OpenMailFrame and OpenMailFrame:IsShown() then
                InboxFrame.openMailID = nil
                if HideUIPanel then HideUIPanel(OpenMailFrame) else OpenMailFrame:Hide() end
            end
            panel.keepTilesDuringQueue, panel.notice = nil, nil
            local ok, why = queue:StartReturn(plan)
            if not ok then panel.notice = why end
            Native:RefreshInbox()
        end,
        OnCancel = function()
            if Native.returnConfirmation == request then Native.returnConfirmation = nil; Native:RefreshInbox() end
        end,
    })
    self.returnConfirmation = request
    if not request then panel.notice = Addon:T("RETURN.CONFIRM_UNAVAILABLE") end
    self:RefreshInbox()
end
function Native:OnReturned(action)
    local panel = self.inbox
    if not panel then return end
    panel.selection[action.id] = nil
    panel.selection[Addon.ViewModel:ActionID(action.characterID, action.mailKey, "money")] = nil
    for _, item in ipairs(action.original.attachments) do
        panel.selection[Addon.ViewModel:ActionID(action.characterID, action.mailKey, item.attachmentIndex)] = nil
    end
    local selections = Addon.Queue.returnPlan and Addon.Queue.returnPlan.selectedMails
    if selections then
        panel.selection = {}
        for _, selected in ipairs(selections) do
            if not selected.returned then
                local snapshot = Addon.db.byCharacter[selected.characterID]
                local mail = snapshot and snapshot.records[selected.mailKey]
                if mail and mail.signature == selected.signature then
                    local entry = { character = snapshot.character, key = selected.mailKey, mail = mail }
                    local actions = Addon:GetInboxActions(entry)
                    if #actions == 0 or mail.cod > 0 then panel.selection[Returns:MailID(entry)] = true
                    else for _, item in ipairs(actions) do panel.selection[item.id] = true end end
                end
            end
        end
    end
end
