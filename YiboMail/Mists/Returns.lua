local Addon = _G.YiboMail
local Returns, Queue = {}, Addon.Queue
Addon.Returns = Returns

function Returns:MailID(entry)
    return Addon.ViewModel:ActionID(entry.character.id, entry.key, "mail")
end
function Returns:IsSelected(entry, selection)
    if selection[self:MailID(entry)] then return true end
    for _, action in ipairs(Addon:GetInboxActions(entry)) do
        if selection[action.id] then return true end
    end
    return false
end
function Returns:IsLive(entry)
    local current = Addon.Core.Characters:GetCurrent({ identityOnly = true })
    local state = Addon.Items:GetState(entry.character.id)
    return current and current.id == entry.character.id and entry.mail.state == "observed"
        and (state.status == "known" or state.status == "partial") and Addon.Scanner:IsOpen()
end
function Returns:CanReturn(mail)
    if mail.auctionMail then return nil, Addon:T("RETURN.AUCTION_EXCLUDED") end
    if mail.canReply ~= true or mail.isGM == true then return nil, Addon:T("RETURN.SENDER_UNVERIFIED") end
    if type(ReturnInboxItem) ~= "function" then return nil, Addon:T("RETURN.API_UNAVAILABLE") end
    if mail.canReturn == true then return true end
    return nil, Addon:T(mail.canReturn == false and "RETURN.NOT_RETURNABLE" or "RETURN.PERMISSION_UNKNOWN")
end
function Returns:Selection(entries, selection)
    local selected, eligible, reasons = {}, 0, {}
    for _, entry in ipairs(entries) do
        if self:IsSelected(entry, selection) then
            selected[#selected + 1] = entry
            local ok, reason = self:CanReturn(entry.mail)
            if ok and not self:IsLive(entry) then ok, reason = nil, Addon:T("RETURN.CHANGED") end
            if ok then eligible = eligible + 1 else reasons[reason] = (reasons[reason] or 0) + 1 end
        end
    end
    return selected, eligible, reasons
end
local function SameInbox(mails, baseline, visible, total, count, all)
    if visible ~= count or total ~= all or #mails ~= #baseline then return false end
    for index, mail in ipairs(baseline) do
        if not mails[index] or mails[index].signature ~= mail.signature then return false end
    end
    return true
end
function Returns:Prepare(selection, context)
    if Queue.state == "running" or Queue.pending then return nil, Addon:T("UI.TEXT_0552") end
    local entries = Addon.ViewModel:GetMails(context, {})
    local mails, visible, total = Addon.Scanner:ReadVisible()
    if not mails then return nil, visible end
    local plan = { actions = {}, skipped = 0, reasons = {}, selected = 0, selectedMails = {},
        mails = Addon.Copy(mails), visible = visible, total = total, selection = Addon.Copy(selection),
        generation = Addon.Scanner.generation }
    local recognized = {}
    for _, entry in ipairs(entries) do
        if self:IsSelected(entry, selection) then
            if not self:IsLive(entry) then return nil, Addon:T("RETURN.CHANGED") end
            recognized[self:MailID(entry)] = true
            for _, action in ipairs(Addon:GetInboxActions(entry)) do recognized[action.id] = true end
            local mail = mails[entry.mail.inboxIndex]
            if not mail or mail.signature ~= entry.mail.signature then return nil, Addon:T("RETURN.CHANGED") end
            plan.selected = plan.selected + 1
            plan.selectedMails[#plan.selectedMails + 1] = { characterID = entry.character.id, mailKey = entry.key,
                index = mail.inboxIndex, signature = mail.signature }
            local ok, reason = self:CanReturn(mail)
            if ok then
                plan.actions[#plan.actions + 1] = { id = self:MailID(entry), characterID = entry.character.id,
                    mailKey = entry.key, signature = mail.signature, original = Addon.Copy(mail),
                    slot = "return", state = "pending" }
            else
                plan.skipped = plan.skipped + 1
                plan.reasons[reason] = (plan.reasons[reason] or 0) + 1
            end
        end
    end
    for id in pairs(selection) do if not recognized[id] then return nil, Addon:T("RETURN.CHANGED") end end
    if #plan.actions == 0 then
        local details, reasons = { Addon:T("RETURN.NONE") }, {}
        for reason in pairs(plan.reasons) do reasons[#reasons + 1] = reason end
        table.sort(reasons)
        for _, reason in ipairs(reasons) do
            details[#details + 1] = Addon:T("RETURN.SKIP_REASON", plan.reasons[reason], reason)
        end
        return nil, table.concat(details, "\n")
    end
    -- Descending positions keep every earlier selected envelope at its index.
    table.sort(plan.actions, function(a, b) return a.original.inboxIndex > b.original.inboxIndex end)
    return plan
end
function Returns:Matches(plan, selection)
    if Addon.Scanner.generation ~= plan.generation or not Addon.Scanner:IsOpen() then return false end
    for id in pairs(selection) do if not plan.selection[id] then return false end end
    for id in pairs(plan.selection) do if not selection[id] then return false end end
    return true
end
function Queue:StartReturn(plan)
    if self.state == "running" or self.pending then return nil, Addon:T("UI.TEXT_0552") end
    local current = Addon.Core.Characters:GetCurrent({ identityOnly = true })
    if not current or not plan.actions[1] or current.id ~= plan.actions[1].characterID
        or Addon.Scanner.generation ~= plan.generation then return nil, Addon:T("RETURN.CHANGED") end
    local mails, visible, total = Addon.Scanner:ReadVisible()
    if not mails or not SameInbox(mails, plan.mails, visible, total, plan.visible, plan.total) then
        return nil, Addon:T("RETURN.CHANGED")
    end
    for _, action in ipairs(plan.actions) do
        local mail = mails[action.original.inboxIndex]
        if action.characterID ~= current.id or not mail or mail.signature ~= action.signature
            or not Returns:CanReturn(mail) then return nil, Addon:T("RETURN.CHANGED") end
    end
    self.actions, self.completed, self.index = Addon.Copy(plan.actions), 0, 1
    self.operation, self.returnPlan = "return", { mails = mails, visible = visible, total = total, skipped = plan.skipped,
        selectedMails = Addon.Copy(plan.selectedMails) }
    self.state, self.pauseCode, self.message = "running", nil, Addon:T("RETURN.RUNNING")
    self.nextScheduled, self.lastRequestAt, self.cooldownUntil, self.preflight = nil, nil, nil, nil
    Addon.Scanner:BeginCollection()
    self:Next(); return true
end
function Queue:NextReturn()
    local action, plan = self.actions[self.index], self.returnPlan
    if not action then
        self.state, self.message = "complete", Addon:T("RETURN.SUMMARY", self.completed, plan.skipped)
        Addon.Scanner:Schedule(true)
        if Addon:GetInboxPreferences().showSummary then Addon:Print(self.message) end
        self:Notify(); return
    end
    local batch = self.actions
    local wait = self.lastRequestAt and self.lastRequestAt + math.max(0.25, self.requestInterval) - GetTime() or 0
    if wait > 0 then
        if not self.nextScheduled then
            self.nextScheduled = true
            C_Timer.After(wait, function()
                if Queue.actions ~= batch then return end
                Queue.nextScheduled = nil
                if Queue.state == "running" then Queue:Next() end
            end)
        end
        return
    end
    if InCombatLockdown and InCombatLockdown() then self:Pause(Addon:T("UI.TEXT_0306")); return end
    local current = Addon.Core.Characters:GetCurrent({ identityOnly = true })
    if not current or current.id ~= action.characterID then self:Pause(Addon:T("RETURN.CHANGED")); return end
    local mails, visible, total = Addon.Scanner:ReadVisible()
    if not mails or not SameInbox(mails, plan.mails, visible, total, plan.visible, plan.total) then
        self:Pause(Addon:T("RETURN.CHANGED")); return
    end
    local mail = mails[action.original.inboxIndex]
    if not mail or mail.signature ~= action.signature or not Returns:CanReturn(mail) then
        self:Pause(Addon:T("RETURN.CHANGED")); return
    end
    -- No loot path is used: returning a COD letter never pays its amount.
    self.pending = { action = action, before = mail, beforeMails = mails, beforeCount = visible, beforeTotal = total,
        targetIndex = mail.inboxIndex, originalIndex = action.original.inboxIndex, startedAt = GetTime(),
        success = false, updated = false }
    self.lastRequestAt, self.invoking = GetTime(), true
    local ok, err = pcall(ReturnInboxItem, mail.inboxIndex)
    self.invoking = false
    if not ok then
        -- A wrapped API can raise after submitting its request. Keep the
        -- uncertain request isolated until mailbox close; never offer a retry.
        self.pending.interference = true
        self:Pause(tostring(err)); return
    end
    self:ScheduleCheck(); self:Notify()
end
function Queue:CheckReturnPending()
    local pending = self.pending
    local current = Addon.Core.Characters:GetCurrent({ identityOnly = true })
    if not current or current.id ~= pending.action.characterID or not Addon.Scanner:IsOpen() then
        pending.interference = true; self:Pause(Addon:T("RETURN.CHANGED")); return
    end
    local age = GetTime() - pending.startedAt
    if age >= 30 then self:Pause(Addon:T("RETURN.UNVERIFIED"), "result-timeout"); return end
    if age >= 0.75 then self:Backoff(pending) end
    if pending.success and pending.updated then
        local mails, visible, total = Addon.Scanner:ReadVisible()
        if mails and self:OnReturnScan(mails, visible, total, false) then return end
    end
    self:ScheduleCheck(math.min(0.5, math.max(0.1, age / 4)))
end
function Queue:OnReturnScan(mails, visible, total, committed)
    local pending = self.pending
    if not pending or pending.interference or not pending.success or not pending.updated
        or self.pauseCode == "result-timeout" then return false end
    local current = Addon.Core.Characters:GetCurrent({ identityOnly = true })
    if not current or current.id ~= pending.action.characterID then return false end
    if total ~= pending.beforeTotal - 1 then return false end
    local expected = {}
    for index, mail in ipairs(pending.beforeMails) do
        if index ~= pending.targetIndex then expected[#expected + 1] = mail end
    end
    if visible ~= math.min(100, total) or #mails ~= visible or #mails < #expected then return false end
    for index, mail in ipairs(expected) do
        if mails[index].signature ~= mail.signature then return false end
    end
    -- Only the newly exposed tail may enter the visible window. A changed
    -- prefix, new arrival or ambiguous removal stops further requests.
    local action = pending.action
    Addon:WithPublicationBatch(function()
        if not committed then Addon.Scanner:CommitCollection(mails, visible, total, true) end
        local snapshot = Addon.db.byCharacter[action.characterID]
        local source = snapshot and snapshot.records[action.mailKey]
        if source and source.state == "unverified" and source.signature == action.signature then
            source.state = "returned-archived"
        end
        Addon:AddHistory(action.characterID, { state = "returned-archived", mail = action.original,
            sourceMailKey = action.mailKey, attachments = action.original.attachments,
            money = action.original.money, codAmount = action.original.cod, observedAt = Addon:Now() })
        action.state, self.completed = "success", self.completed + 1
        -- Store deliberately replaces keys when duplicate multiplicity changes.
        -- Rebind only from the now-proven positions, never a first-signature hit.
        local keysAt = {}
        for _, key in ipairs(snapshot and snapshot.visibleKeys or {}) do
            local mail = snapshot.records[key]
            keysAt[mail.inboxIndex] = key
        end
        for _, selected in ipairs(self.returnPlan.selectedMails) do
            if not selected.returned then
                if selected.index == pending.targetIndex then selected.returned = true
                elseif selected.index > pending.targetIndex then selected.index = selected.index - 1 end
                if not selected.returned then selected.mailKey = keysAt[selected.index] or selected.mailKey end
            end
        end
        for index = self.index + 1, #self.actions do
            local nextAction = self.actions[index]
            local key = keysAt[nextAction.original.inboxIndex]
            if key then
                nextAction.mailKey = key
                nextAction.id = Addon.ViewModel:ActionID(nextAction.characterID, key, "mail")
            end
        end
        self.returnPlan.mails, self.returnPlan.visible, self.returnPlan.total = Addon.Copy(mails), visible, total
        self.layoutDirty, self.pending, self.index = nil, nil, self.index + 1
        if Addon.NativeUI and Addon.NativeUI.OnReturned then Addon.NativeUI:OnReturned(action) end
        self:Notify()
    end)
    if self.notifyPending then self:Notify() end
    if self.state == "running" then
        local batch = self.actions
        C_Timer.After(0, function() if Queue.actions == batch then Queue:Next() end end)
    else Addon.Scanner:Schedule(true) end
    return true
end
