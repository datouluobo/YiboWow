local Addon = _G.YiboMail
local Queue = { state = "idle", actions = {}, completed = 0 }; Addon.Queue = Queue
local REQUEST_INTERVAL, ACTION_TIMEOUT = 1, 30
local function SignatureSequence(mails)
    local result = {}; for _, mail in ipairs(mails) do result[#result + 1] = mail.signature end
    return result
end
local function MatchesSequence(mails, signatures, allowAdditional)
    if not signatures or #mails < #signatures or (not allowAdditional and #mails ~= #signatures) then return false end
    for index, signature in ipairs(signatures) do
        if mails[index].signature ~= signature then return false end
    end
    return true
end
function Queue:Notify()
    if Addon.publicationBatch then self.notifyPending = true; return end
    self.notifyPending = nil
    -- Mail mutations already notify the account view. Intermediate queue
    -- progress only needs the mounted inbox footer; terminal states rebuild.
    local native = Addon.NativeUI
    if self.state == "running" and native and native.RefreshInboxProgress
        and native.inbox and native.inbox.keepTilesDuringQueue then
        native:RefreshInboxProgress(); return
    end
    if Addon.Core and Addon.FEATURES.account then Addon.Core.AccountView:NotifyPageChanged("mail-inbox") end
    if Addon.NativeUI then Addon.NativeUI:Refresh() end
end
function Queue:Discard()
    if self.pending then return nil, Addon:T("UI.TEXT_0530") end
    self.state, self.actions, self.completed, self.message, self.pauseCode = "idle", {}, 0, nil, nil
    self.index, self.lastRequestAt, self.nextScheduled = nil, nil, nil
    self.verifiedMails, self.removedIndexes = nil, nil
    return true
end
function Queue:Pause(reason, code)
    self.state, self.message = "paused", reason or Addon:T("UI.TEXT_0252")
    self.pauseCode = code
    self:Notify()
end
local function HasRegularBagSpace()
    local slots = C_Container and C_Container.GetContainerNumFreeSlots or GetContainerNumFreeSlots
    if not slots then return nil end
    local free = 0
    for bag = 0, NUM_BAG_SLOTS or 4 do local count, family = slots(bag); if family == 0 then free = free + (count or 0) end end
    return free > 0
end
local function CurrentInboxIndex(queue, originalIndex)
    local removedBefore = 0
    for index in pairs(queue.removedIndexes or {}) do if index < originalIndex then removedBefore = removedBefore + 1 end end
    return originalIndex - removedBefore
end
local function CopyActions(actions)
    local result, originals = {}, {}
    for _, action in ipairs(actions) do
        local copy = {}
        for key, value in pairs(action) do
            if key == "original" and type(value) == "table" then
                if not originals[value] then originals[value] = Addon.Copy(value) end
                copy[key] = originals[value]
            else copy[key] = Addon.Copy(value) end
        end
        result[#result + 1] = copy
    end
    return result
end
function Queue:Prepare(selection, context)
    if self.pending then return nil, Addon:T("UI.TEXT_0085") end
    local actions = {}
    for _, entry in ipairs(Addon.ViewModel:GetMails(context, {})) do
        local mail, original = entry.mail, nil
        local function Selected(slot, item)
            local id = Addon.ViewModel:ActionID(entry.character.id, entry.key, slot)
            if not selection[id] then return true end
            if not entry.actionable then return nil, entry.restriction end
            if not original then original = Addon.Copy(mail) end
            actions[#actions + 1] = { id = id, characterID = entry.character.id, mailKey = entry.key,
                signature = mail.signature, original = original, slot = slot, item = Addon.Copy(item), state = "pending" }
            return true
        end
        if mail.money > 0 then local ok, err = Selected("money"); if not ok then return nil, err end end
        for _, item in ipairs(mail.attachments) do local ok, err = Selected(item.attachmentIndex, item); if not ok then return nil, err end end
    end
    local selected = 0; for _ in pairs(selection) do selected = selected + 1 end
    if #actions ~= selected then return nil, Addon:T("UI.TEXT_0610") end
    if #actions == 0 then return nil, Addon:T("UI.TEXT_0555") end
    -- Process the earliest estimated expiry first; use inbox position for ties.
    table.sort(actions, function(a, b)
        local aExpiry, bExpiry = tonumber(a.original.expiresAtEstimate) or math.huge, tonumber(b.original.expiresAtEstimate) or math.huge
        if aExpiry ~= bExpiry then return aExpiry < bExpiry end
        local aIndex, bIndex = tonumber(a.original.inboxIndex) or math.huge, tonumber(b.original.inboxIndex) or math.huge
        if aIndex ~= bIndex then return aIndex < bIndex end
        if a.characterID ~= b.characterID then return tostring(a.characterID) < tostring(b.characterID) end
        local aSlot = a.slot == "money" and 0 or tonumber(a.slot) or math.huge
        local bSlot = b.slot == "money" and 0 or tonumber(b.slot) or math.huge
        return aSlot < bSlot
    end)
    return actions
end
function Queue:RemainingSelection(context)
    if self.pending then return nil, Addon:T("UI.TEXT_0086") end
    local entries, selection = Addon.ViewModel:GetMails(context, {}), {}
    for _, action in ipairs(self.actions) do
        if action.state == "pending" then
            local index = CurrentInboxIndex(self, tonumber(action.original and action.original.inboxIndex) or 0)
            local found
            for _, entry in ipairs(entries) do
                if entry.character.id == action.characterID and entry.mail.inboxIndex == index and entry.mail.signature == action.signature then found = entry; break end
            end
            if not found or not found.actionable then return nil, Addon:T("UI.TEXT_0162") end
            selection[Addon.ViewModel:ActionID(found.character.id, found.key, action.slot)] = true
        end
    end
    return selection
end
function Queue:Start(actions)
    if self.state == "running" then return nil, Addon:T("UI.TEXT_0349") end
    if self.pending then return nil, Addon:T("UI.TEXT_0550") end
    if type(actions) ~= "table" or #actions == 0 then return nil, Addon:T("UI.TEXT_0559") end
    local mails, err = Addon.Scanner:ReadVisible(); if not mails then return nil, err end
    local current, selected = Addon.Core.Characters:GetCurrent({ identityOnly = true }), {}
    for _, action in ipairs(actions) do
        if not current or current.id ~= action.characterID then return nil, Addon:T("UI.TEXT_0279") end
        if selected[action.id] then return nil, Addon:T("UI.TEXT_0351") end
        selected[action.id] = true
        local index = tonumber(action.original and action.original.inboxIndex)
        local mail = index and mails[index]
        if not mail or mail.signature ~= action.signature then return nil, Addon:T("UI.TEXT_0312") end
        if mail.cod > 0 then return nil, Addon:T("UI.TEXT_0112") end
        if action.slot == "money" then
            if mail.money <= 0 or mail.money ~= action.original.money then return nil, Addon:T("UI.TEXT_0620") end
        else
            local found = false
            for _, item in ipairs(mail.attachments) do
                if item.attachmentIndex == action.slot and action.item and item.variantKey == action.item.variantKey and item.quantity == action.item.quantity then found = true; break end
            end
            if not found then return nil, Addon:T("UI.TEXT_0633") end
        end
    end
    self.actions, self.completed, self.index, self.state, self.message, self.pauseCode = CopyActions(actions), 0, 1, "running", Addon:T("UI.TEXT_0426"), nil
    self.lastRequestAt, self.nextScheduled = nil, nil
    self.verifiedMails, self.removedIndexes = mails, {}
    self:Next(); return true
end
function Queue:Next()
    if self.state ~= "running" or self.pending then return end
    local action = self.actions[self.index]
    if not action then
        self.state, self.message = "complete", Addon:T("UI.TEXT_0404")
        if Addon:GetInboxPreferences().showSummary then Addon:Print(Addon:T("UI.TEXT_0405") .. self.completed .. "/" .. #self.actions .. Addon:T("UI.TEXT_0053")) end
        self:Notify(); return
    end
    local elapsed = self.lastRequestAt and (GetTime() - self.lastRequestAt) or REQUEST_INTERVAL
    if elapsed < REQUEST_INTERVAL then
        if not self.nextScheduled then
            self.nextScheduled = true
            C_Timer.After(REQUEST_INTERVAL - elapsed, function()
                Queue.nextScheduled = nil
                if Queue.state == "running" then Queue:Next() end
            end)
        end
        return
    end
    local current = Addon.Core.Characters:GetCurrent({ identityOnly = true })
    if not current or current.id ~= action.characterID then self:Pause(Addon:T("UI.TEXT_0278")); return end
    if InCombatLockdown and InCombatLockdown() then self:Pause(Addon:T("UI.TEXT_0306")); return end
    local mails = self.verifiedMails
    self.verifiedMails = nil
    if not mails then
        local err
        mails, err = Addon.Scanner:ReadVisible()
        if not mails then self:Pause(err); return end
    end
    local originalIndex = tonumber(action.original and action.original.inboxIndex)
    local index = originalIndex and CurrentInboxIndex(self, originalIndex)
    local mail = index and mails[index]
    if not mail or mail.signature ~= action.signature then self:Pause(Addon:T("UI.TEXT_0312")); return end
    if mail.cod > 0 then self:Pause(Addon:T("UI.TEXT_0112")); return end
    local expected = Addon.Copy(mail)
    if action.slot == "money" then
        if mail.money <= 0 or mail.money ~= action.original.money then self:Pause(Addon:T("UI.TEXT_0619")); return end
        expected.money = 0
    else
        local match
        for index, item in ipairs(expected.attachments) do
            if item.attachmentIndex == action.slot and item.variantKey == action.item.variantKey and item.quantity == action.item.quantity then match = index end
        end
        if not match then self:Pause(Addon:T("UI.TEXT_0632")); return end
        local hasSpace = HasRegularBagSpace()
        if hasSpace == nil then self:Pause(Addon:T("UI.TEXT_0367"), "bag-space-unknown"); return end
        if not hasSpace then self:Pause(Addon:T("UI.TEXT_0377"), "bag-full"); return end
        table.remove(expected.attachments, match)
    end
    expected.signature = Addon.Scanner:Signature(expected)
    local after = {}; for _, entry in ipairs(mails) do after[#after + 1] = entry.inboxIndex == mail.inboxIndex and expected or entry end
    local removed = {}; for _, entry in ipairs(mails) do if entry.inboxIndex ~= mail.inboxIndex then removed[#removed + 1] = entry end end
    self.pending = { action = action, expected = expected, mailCollected = #expected.attachments == 0 and expected.money == 0,
        expectedSignatures = SignatureSequence(after),
        removedSignatures = #expected.attachments == 0 and expected.money == 0 and SignatureSequence(removed) or nil,
        originalIndex = originalIndex, targetIndex = index,
        startedAt = GetTime(), success = false, updated = false }
    self.lastRequestAt = self.pending.startedAt
    self.invoking = true
    local fn = action.slot == "money" and TakeInboxMoney or TakeInboxItem
    local ok, errorMessage
    if type(fn) == "function" then
        if action.slot == "money" then ok, errorMessage = pcall(fn, mail.inboxIndex) else ok, errorMessage = pcall(fn, mail.inboxIndex, action.slot) end
    else ok, errorMessage = false, Addon:T("UI.TEXT_0223") end
    self.invoking = false
    if not ok then self.pending = nil; self:Pause(tostring(errorMessage)); return end
    self:Notify()
end
function Queue:OnScan(mails)
    local pending = self.pending
    if not pending or pending.interference or not pending.success or not pending.updated then return false end
    local expectedMatches = MatchesSequence(mails, pending.expectedSignatures, false)
    -- GetInboxNumItems exposes at most the first 100 messages. When a complete
    -- message is collected, the next unseen message can enter that visible
    -- window immediately, so the old remaining messages must match its prefix.
    local removedMatches = MatchesSequence(mails, pending.removedSignatures, true)
    if not expectedMatches and not removedMatches then
        pending.mismatchScans = (pending.mismatchScans or 0) + 1
        if pending.mismatchScans == 1 and C_Timer and C_Timer.After then
            -- The client can emit MAIL_INBOX_UPDATE before the mailbox APIs
            -- expose the final post-loot contents, especially for large inboxes.
            C_Timer.After(0.3, function()
                if Queue.pending == pending and Queue.state == "running" then Addon.Scanner:Schedule() end
            end)
            return false
        end
        self:Pause(Addon:T("UI.TEXT_0331")); return true
    end
    self.verifiedMails = mails
    local targetRemoved = removedMatches
    if targetRemoved and pending.originalIndex then self.removedIndexes[pending.originalIndex] = true end
    local action = pending.action; action.state = "success"; self.completed = self.completed + 1
    action.mailCollected = pending.mailCollected
    action.resultMail, action.resultMailKey, action.resultInboxIndex = nil, nil, pending.targetIndex
    if not targetRemoved then
        local snapshot = Addon.db.byCharacter[action.characterID]
        for _, key in ipairs(snapshot and snapshot.visibleKeys or {}) do
            local mail = snapshot.records[key]
            if mail and mail.inboxIndex == pending.targetIndex then action.resultMail, action.resultMailKey = mail, key; break end
        end
    end
    if action.mailCollected and not targetRemoved then
        local markers = Addon.db.collectedMailMarkers[action.characterID] or {}
        Addon.db.collectedMailMarkers[action.characterID] = markers
        markers[#markers + 1] = { signature = pending.expected.signature,
            expiresAtEstimate = tonumber(pending.expected.expiresAtEstimate) or Addon:Now() }
    end
    if action.original.openedByUser and Addon.MarkMailOpened then
        local snapshot = Addon.db.byCharacter[action.characterID]
        local found
        for _, key in ipairs(snapshot and snapshot.visibleKeys or {}) do
            local mail = snapshot.records[key]
            if mail.signature == pending.expected.signature then
                if found then found = nil; break end
                found = { character = { id = action.characterID }, key = key, mail = mail }
            end
        end
        if found then Addon:MarkMailOpened(found) end
    end
    Addon:AddHistory(action.characterID, { state = "collected-archived", mail = action.original,
        item = action.item, money = action.slot == "money" and action.original.money or 0, observedAt = Addon:Now() })
    for index = self.index + 1, #self.actions do
        local nextAction = self.actions[index]
        if nextAction.characterID == action.characterID
            and nextAction.original and nextAction.original.inboxIndex == action.original.inboxIndex then
            nextAction.signature = pending.expected.signature
        end
    end
    self.pending, self.index = nil, self.index + 1
    if self.onSuccess then self.onSuccess(action.id) end
    if Addon.NativeUI then Addon.NativeUI:OnCollected(action.id, action) end
    self:Notify()
    if self.state == "running" then C_Timer.After(0, function() Queue:Next() end) end
    return true
end
function Queue:OnEvent(event, ...)
    if event == "MAIL_CLOSED" then
        if self.pending then
            local action = self.pending.action; action.state = "unverified"
            Addon:AddHistory(action.characterID, { state = "unverified", mail = action.original, item = action.item,
                money = action.slot == "money" and action.original.money or 0, observedAt = Addon:Now() })
            self.pending = nil
        end
        self.verifiedMails, self.nextScheduled = nil, nil
        if self.state == "running" then self:Pause(Addon:T("UI.TEXT_0603"), "mailbox-closed")
        elseif self.state == "paused" then
            -- A timeout may have paused the queue before the mailbox closes.
            -- Preserve the unknown result until close, then release the stale
            -- queue on the next open without asking the player to clear it.
            self.pauseCode = "mailbox-closed"
        end
    elseif event == "MAIL_SHOW" then
        if self.state == "paused" and self.pauseCode == "mailbox-closed" and not self.pending then
            self:Discard()
            if Addon.NativeUI and Addon.NativeUI.inbox then
                Addon.NativeUI.inbox.notice, Addon.NativeUI.inbox.selection = nil, {}
                Addon.NativeUI.inbox.keepTilesDuringQueue = nil
            end
            self:Notify()
        end
    elseif event == "BAG_UPDATE_DELAYED" then
        if self.state == "paused" and self.pauseCode == "bag-full" and HasRegularBagSpace() then
            self:Discard()
            self:Notify()
        end
    elseif self.pending then
        if event == "MAIL_SUCCESS" then self.pending.success = true
        elseif event == "MAIL_INBOX_UPDATE" then self.pending.updated = true
        elseif event == "MAIL_FAILED" or event == "UI_ERROR_MESSAGE" or event == "ADDON_ACTION_BLOCKED" then self:Pause(Addon:T("UI.TEXT_0348")) end
        if self.pending.success and self.pending.updated then Addon.Scanner:Schedule() end
    elseif event == "MAIL_INBOX_UPDATE" then
        self.verifiedMails = nil
    end
end
function Queue:Install()
    Addon.Frame:HookScript("OnUpdate", function()
        if Queue.pending and GetTime() - Queue.pending.startedAt > ACTION_TIMEOUT and Queue.state == "running" then Queue:Pause(Addon:T("UI.TEXT_0477")) end
    end)
    if hooksecurefunc then
        for _, name in ipairs({ "TakeInboxItem", "TakeInboxMoney", "AutoLootMailItem", "ReturnInboxItem", "DeleteInboxItem" }) do
            if type(_G[name]) == "function" then hooksecurefunc(name, function()
                if Queue.state == "running" and not Queue.invoking then
                    if Queue.pending then Queue.pending.interference = true end
                    Queue:Pause(Addon:T("UI.TEXT_0419"))
                end
            end) end
        end
    end
end
