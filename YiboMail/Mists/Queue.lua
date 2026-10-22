local Addon = _G.YiboMail
local Queue = { state = "idle", actions = {}, completed = 0 }; Addon.Queue = Queue
local MIN_INTERVAL, INITIAL_INTERVAL, MAX_INTERVAL, ACTION_TIMEOUT = 0.15, 0.25, 2, 30
Queue.requestInterval = INITIAL_INTERVAL
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
local function SameEnvelope(a, b)
    return a and b and a.sender == b.sender and a.subject == b.subject
        and a.cod == b.cod and a.wasReturned == b.wasReturned
end
local function CountSignature(mails, signature)
    local count = 0
    for _, mail in ipairs(mails) do if mail.signature == signature then count = count + 1 end end
    return count
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
    self.index, self.lastRequestAt, self.nextScheduled, self.cooldownUntil = nil, nil, nil, nil
    self.verifiedMails, self.removedIndexes, self.preflight = nil, nil, nil
    self.positions, self.expectedMails, self.layoutDirty = nil, nil, nil
    self.mailOrder, self.nextExtra = nil, nil
    self.operation, self.returnPlan = nil, nil
    return true
end
function Queue:Pause(reason, code)
    self.state, self.message = "paused", reason or Addon:T("UI.TEXT_0252")
    self.pauseCode = code
    Addon.Scanner:Schedule(true)
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
    if queue.positions then return queue.positions[originalIndex] end
    local removedBefore = 0
    for index in pairs(queue.removedIndexes or {}) do if index < originalIndex then removedBefore = removedBefore + 1 end end
    return originalIndex - removedBefore
end
-- Align the original letters in order, allowing newly delivered letters and
-- already-empty rows to disappear. Every still-selected letter must have one
-- possible position across ALL valid alignments; never pick an arbitrary copy.
function Queue:FindLayout(mails, visible, total, pending, unchanged)
    local known, protected = {}, {}
    for index = self.index, #self.actions do
        local action = self.actions[index]
        if action.state == "pending" then protected[action.original.inboxIndex] = true end
    end
    if pending and pending.mailCollected and not unchanged then protected[pending.originalIndex] = nil end
    for _, original in ipairs(self.mailOrder) do
        local mail = self.expectedMails[original]
        if pending and pending.originalIndex == original and not unchanged then mail = pending.expected end
        if mail then
            known[#known + 1] = { original = original, mail = mail,
                empty = #mail.attachments == 0 and mail.money == 0 and mail.cod == 0 }
        elseif protected[original] then return nil, false end
    end
    local n, m, memo = #known, #mails, {}
    local partial = visible == 100 and total > visible
    local arrivals = self.layoutDirty or total > self.totalCount
    local suffixNonempty, suffixVisible = { [n + 1] = 0 }, { [n + 1] = 0 }
    for i = n, 1, -1 do
        suffixNonempty[i] = suffixNonempty[i + 1] + (known[i].empty and 0 or 1)
        suffixVisible[i] = suffixVisible[i + 1] + (not known[i].empty and self.positions[known[i].original] and 1 or 0)
    end
    local function CanHide(i)
        return partial and suffixNonempty[i] <= total - visible and (arrivals or suffixVisible[i] == 0)
    end
    local function Match(i, j)
        local entry, mail = known[i], mails[j]
        if not entry or not mail then return false end
        if entry.mail.signature == mail.signature then return true end
        if pending and SameEnvelope(entry.mail, pending.before) then return false end
        return not protected[entry.original] and SameEnvelope(entry.mail, mail)
            and (not entry.empty or (#mail.attachments == 0 and mail.money == 0))
    end
    local function NewEntry(j)
        if not arrivals then return false end
        local mail = mails[j]
        -- An unexpected nonempty version of the in-flight target may be an
        -- intermediate cache read, not a newly delivered replacement letter.
        return not (pending and not unchanged and SameEnvelope(mail, pending.before)
            and (#mail.attachments > 0 or mail.money > 0))
    end
    local tailSafe = { [m + 1] = true }
    for j = m, 1, -1 do
        local mail = mails[j]
        tailSafe[j] = tailSafe[j + 1] and not (pending and not unchanged
            and SameEnvelope(mail, pending.before) and (#mail.attachments > 0 or mail.money > 0))
    end
    local Possible
    Possible = function(i, j)
        if i > n then return tailSafe[j] end
        if j > m and CanHide(i) then return true end
        local key = i * (m + 2) + j
        if memo[key] ~= nil then return memo[key] end
        local value = (j <= m and Match(i, j) and Possible(i + 1, j + 1))
            or (known[i].empty and Possible(i + 1, j))
            or (j <= m and NewEntry(j) and Possible(i, j + 1)) or false
        memo[key] = value
        return value
    end
    if not Possible(1, 1) then return nil, false end
    if unchanged then return nil, true end
    local visited, candidates = {}, {}
    local function Candidate(original, position)
        if not protected[original] then return end
        local values = candidates[original] or {}; candidates[original] = values; values[position] = true
    end
    local Walk
    Walk = function(i, j)
        if i > n then return end
        local key = i * (m + 2) + j
        if visited[key] then return end
        visited[key] = true
        if j > m and CanHide(i) then
            for k = i, n do Candidate(known[k].original, -1) end
        end
        if j <= m and Match(i, j) and Possible(i + 1, j + 1) then
            Candidate(known[i].original, j); Walk(i + 1, j + 1)
        end
        if known[i].empty and Possible(i + 1, j) then
            Candidate(known[i].original, 0); Walk(i + 1, j)
        end
        if j <= m and NewEntry(j) and Possible(i, j + 1) then Walk(i, j + 1) end
    end
    Walk(1, 1)
    for original in pairs(protected) do
        local count = 0
        for _ in pairs(candidates[original] or {}) do count = count + 1 end
        if count ~= 1 then return nil, true end
    end
    local layout, i, j = { positions = {}, removed = {} }, 1, 1
    while i <= n do
        local entry = known[i]
        if j <= m and Match(i, j) and Possible(i + 1, j + 1) then
            layout.positions[entry.original] = j; i, j = i + 1, j + 1
        elseif entry.empty and Possible(i + 1, j) then
            layout.removed[entry.original] = true; i = i + 1
        elseif j > m and CanHide(i) then break
        else j = j + 1 end
    end
    return layout, true
end
function Queue:ApplyLayout(mails, visible, total, layout)
    local previousOrder, atPosition, order = self.mailOrder, {}, {}
    self.positions, self.verifiedMails = layout.positions, mails
    self.visibleCount, self.totalCount, self.layoutDirty = visible, total, nil
    for original in pairs(layout.removed) do
        self.expectedMails[original], self.removedIndexes[original] = nil, true
    end
    for original, position in pairs(layout.positions) do self.expectedMails[original] = mails[position] end
    for original, position in pairs(layout.positions) do atPosition[position] = original end
    for position, mail in ipairs(mails) do
        local original = atPosition[position]
        if not original then
            self.nextExtra = self.nextExtra - 1; original = self.nextExtra
            self.positions[original], self.expectedMails[original] = position, mail
        end
        order[#order + 1] = original
    end
    -- Keep known letters evicted beyond the visible window so they can be
    -- identified when earlier collections make room. Extra IDs stay private.
    for _, original in ipairs(previousOrder) do
        if self.expectedMails[original] and not self.positions[original] then order[#order + 1] = original end
    end
    self.mailOrder = order
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
    local mails, visible, total = Addon.Scanner:ReadVisible(); if not mails then return nil, visible end
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
    self.operation, self.returnPlan = nil, nil
    self.actions, self.completed, self.index, self.state, self.message, self.pauseCode = CopyActions(actions), 0, 1, "running", Addon:T("UI.TEXT_0426"), nil
    self.lastRequestAt, self.nextScheduled = nil, nil
    self.verifiedMails, self.removedIndexes = mails, {}
    self.positions, self.expectedMails, self.layoutDirty = {}, {}, nil
    self.mailOrder, self.nextExtra = {}, 0
    for index, mail in ipairs(mails) do self.positions[index], self.expectedMails[index], self.mailOrder[index] = index, mail, index end
    self.visibleCount, self.totalCount, self.preflight = visible, total, nil
    Addon.Scanner:BeginCollection()
    self:Next(); return true
end
function Queue:OwnsRefresh()
    return self.state == "running" or (self.pending ~= nil and not self.pending.interference and self.pauseCode ~= "result-timeout")
end
function Queue:Backoff(pending)
    if pending and pending.backedOff then return end
    if pending then pending.backedOff = true end
    self.requestInterval = math.min(MAX_INTERVAL, math.max(INITIAL_INTERVAL, self.requestInterval * 1.6))
end
function Queue:ScheduleCheck(delay)
    local pending = self.pending
    if not pending or pending.checkScheduled or pending.interference or self.pauseCode == "result-timeout" then return end
    pending.checkScheduled = true
    C_Timer.After(delay or 0.05, function()
        pending.checkScheduled = nil
        if Queue.pending == pending and not pending.interference and Queue.pauseCode ~= "result-timeout" then Queue:CheckPending() end
    end)
end
function Queue:Next()
    if self.state ~= "running" or self.pending then return end
    if self.operation == "return" then self:NextReturn(); return end
    local action = self.actions[self.index]
    if not action then
        self.state, self.message = "complete", Addon:T("UI.TEXT_0404")
        Addon.Scanner:Schedule(true)
        if Addon:GetInboxPreferences().showSummary then Addon:Print(Addon:T("UI.TEXT_0405") .. self.completed .. "/" .. #self.actions .. Addon:T("UI.TEXT_0053")) end
        self:Notify(); return
    end
    local elapsed = self.lastRequestAt and (GetTime() - self.lastRequestAt) or self.requestInterval
    local waitFor = math.max(self.requestInterval - elapsed, (self.cooldownUntil or 0) - GetTime())
    if waitFor > 0.000001 then
        if not self.nextScheduled then
            local batch = self.actions
            self.nextScheduled = true
            C_Timer.After(waitFor, function()
                if Queue.actions ~= batch then return end
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
    local originalIndex = tonumber(action.original and action.original.inboxIndex)
    local index = originalIndex and CurrentInboxIndex(self, originalIndex)
    local mail, visible, total, readError
    if index then mail, visible, total, readError = Addon.Scanner:ReadTarget(index)
    else readError = "target-not-visible" end
    if readError or not mail or mail.signature ~= action.signature
        or visible ~= self.visibleCount or total ~= self.totalCount or self.layoutDirty then
        -- Recover positions only from an unambiguous ordered alignment. A
        -- delayed empty-row removal or new AH return can move several letters.
        local fresh, count, all = Addon.Scanner:ReadVisible()
        local layout = fresh and self:FindLayout(fresh, count, all)
        if layout then
            self:ApplyLayout(fresh, count, all, layout)
            mails, index = fresh, CurrentInboxIndex(self, originalIndex)
            mail, visible, total = index and fresh[index], count, all
            readError = not index and "target-not-visible" or nil
            Addon.Scanner:CommitCollection(fresh, count, all, true)
            if not index then
                -- A newly delivered prefix may hide the earliest-expiring
                -- selection. Advance the earliest visible selected action to
                -- make room, then reconsider that hidden letter on the next step.
                for nextIndex = self.index + 1, #self.actions do
                    local nextAction = self.actions[nextIndex]
                    if self.positions[nextAction.original.inboxIndex] then
                        table.remove(self.actions, nextIndex); table.insert(self.actions, self.index, nextAction)
                        self.preflight = nil; self:Next(); return
                    end
                end
            end
        end
        if not layout or not mail or mail.signature ~= action.signature or readError then
            local wait = self.preflight
            if not wait or wait.action ~= action then wait = { action = action, at = GetTime() }; self.preflight = wait end
            local age = GetTime() - wait.at
            local limit = layout and not index and ACTION_TIMEOUT or 3
            if age >= limit then self:Pause(Addon:T("UI.TEXT_0312")); return end
            if not wait.scheduled then
                wait.scheduled = true
                C_Timer.After(math.min(1, math.max(0.25, age / 4)), function()
                    wait.scheduled = nil
                    if Queue.preflight == wait and Queue.state == "running" then Queue:Next() end
                end)
            end
            return
        end
    end
    self.preflight = nil
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
    self.pending = { action = action, expected = expected, before = mail, beforeMails = mails,
        beforeCount = visible, beforeTotal = total,
        mailCollected = #expected.attachments == 0 and expected.money == 0,
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
    self:ScheduleCheck()
    self:Notify()
end
local function Project(pending, target, removed)
    local mails = {}
    for index, mail in ipairs(pending.beforeMails) do
        if index ~= pending.targetIndex then
            if removed and index > pending.targetIndex then
                mail = Addon.Copy(mail); mail.inboxIndex = index - 1
            end
            mails[#mails + 1] = mail
        elseif not removed then mails[#mails + 1] = target end
    end
    return mails
end
function Queue:CheckPending()
    local pending = self.pending
    if not pending or pending.interference then return end
    if self.operation == "return" then self:CheckReturnPending(); return end
    local current = Addon.Core.Characters:GetCurrent({ identityOnly = true })
    if not current or current.id ~= pending.action.characterID then
        pending.interference = true; self:Pause(Addon:T("UI.TEXT_0278")); return
    end
    local age = GetTime() - pending.startedAt
    if age >= ACTION_TIMEOUT then
        if self.pauseCode ~= "result-timeout" then self:Pause(Addon:T("UI.TEXT_0477"), "result-timeout") end
        return
    end
    if age >= 0.75 then self:Backoff(pending) end
    -- Success is necessary, but a second event is only a wake-up hint. Some
    -- clients deliver the cache change without another MAIL_INBOX_UPDATE.
    if pending.success then
        local mail, visible, total, err = Addon.Scanner:ReadTarget(pending.targetIndex)
        if not err then
            if not self.layoutDirty and mail and mail.signature == pending.expected.signature
                and visible == pending.beforeCount and total == pending.beforeTotal then
                if pending.mailCollected then
                    -- AH empty rows often disappear just after the attachment
                    -- update. One target-only grace read avoids rebasing the
                    -- entire inbox for that routine two-step transition.
                    pending.emptyObservedAt = pending.emptyObservedAt or GetTime()
                    if GetTime() - pending.emptyObservedAt < 0.099 then
                        self:ScheduleCheck(0.1); return
                    end
                end
                self:Confirm(Project(pending, mail, false), false, visible, total); return
            end
            local nextMail = pending.beforeMails[pending.targetIndex + 1]
            local shifted = (nextMail and mail and mail.signature == nextMail.signature) or (not nextMail and not mail)
            local removed = pending.mailCollected and shifted and visible == pending.beforeCount - 1 and total == pending.beforeTotal - 1
            if removed and not self.layoutDirty then
                self:Confirm(Project(pending, nil, true), true, visible, total); return
            end
            -- A full visible window can refill immediately. Reconcile this
            -- structural boundary, new arrivals or other unexpected changes;
            -- unchanged old target contents only need another target read.
            local unchanged = mail and mail.signature == pending.before.signature
                and visible == pending.beforeCount and total == pending.beforeTotal
            if (self.layoutDirty or not unchanged) and (not pending.lastFullCheck or GetTime() - pending.lastFullCheck >= 1) then
                pending.lastFullCheck = GetTime()
                local mails, count, all = Addon.Scanner:ReadVisible()
                if mails and self:OnScan(mails, count, all, false) then return end
            end
        end
    end
    self:ScheduleCheck(math.min(0.5, math.max(0.1, age / 4)))
end
function Queue:OnScan(mails, visible, total, committed)
    local pending = self.pending
    if not pending or pending.interference or not pending.success then return false end
    if self.operation == "return" then return self:OnReturnScan(mails, visible, total, committed) end
    local current = Addon.Core.Characters:GetCurrent({ identityOnly = true })
    if not current or current.id ~= pending.action.characterID then
        pending.interference = true; self:Pause(Addon:T("UI.TEXT_0278")); return false
    end
    local removed = pending.mailCollected and Project(pending, nil, true)
    local target = mails[pending.targetIndex]
    local expectedMatches = target and target.signature == pending.expected.signature
    local removedMatches = removed and (#removed > 0 or visible == pending.beforeCount - 1)
        and MatchesSequence(mails, SignatureSequence(removed), true)
    if removed and not removedMatches and total == pending.beforeTotal - 1
        and SameEnvelope(target, pending.beforeMails[pending.targetIndex + 1])
        and CountSignature(mails, pending.before.signature) == CountSignature(pending.beforeMails, pending.before.signature) - 1 then
        -- A different unselected attachment/amount need not invalidate this
        -- action. Anchor the removal to its successor and recheck every still
        -- selected letter at the shifted index, without guessing identities.
        removedMatches = true
        for index = self.index + 1, #self.actions do
            local action = self.actions[index]
            local original = action.original.inboxIndex
            local shifted = CurrentInboxIndex(self, original) - (original > pending.originalIndex and 1 or 0)
            if not mails[shifted] or mails[shifted].signature ~= action.signature then removedMatches = false; break end
        end
    end
    -- A different row alone cannot prove removal (in particular when the old
    -- prefix is empty). Require the server count to confirm that one vanished.
    removedMatches = removedMatches and total == pending.beforeTotal - 1
    local layout, alignmentPossible = self:FindLayout(mails, visible, total, pending)
    if alignmentPossible and not layout then return false end
    if self.layoutDirty then
        if not layout then return false end
        local _, unchangedPossible = self:FindLayout(mails, visible, total, pending, true)
        if unchangedPossible then return false end
    end
    if not expectedMatches and not removedMatches then
        if not layout then return false end
        -- If the same readings can still represent the unchanged request,
        -- its result is unproven (e.g. an original row was pushed off-screen).
        local _, unchangedPossible = self:FindLayout(mails, visible, total, pending, true)
        if unchangedPossible then return false end
        local targetPosition = layout.positions[pending.originalIndex]
        removedMatches = layout.removed[pending.originalIndex] == true
        expectedMatches = targetPosition and mails[targetPosition].signature == pending.expected.signature
        if not expectedMatches and not removedMatches then return false end
    end
    if layout then
        removedMatches = layout.removed[pending.originalIndex] == true
        local targetPosition = layout.positions[pending.originalIndex]
        if not removedMatches and not targetPosition then return false end
        if targetPosition then pending.targetIndex = targetPosition end
    end
    -- Prefer count-proven removal when the successor is an identical empty
    -- letter: its signature also looks like a retained, just-emptied target.
    self:Confirm(mails, removedMatches == true, visible, total, committed ~= false, true, layout)
    return true
end
function Queue:Confirm(mails, targetRemoved, visible, total, committed, fullRead, layout)
    local pending = self.pending
    local latency = GetTime() - pending.startedAt
    self.responseLatency = self.responseLatency and (self.responseLatency * 0.75 + latency * 0.25) or latency
    if not pending.backedOff then
        self.requestInterval = math.max(MIN_INTERVAL, math.min(MAX_INTERVAL, math.max(self.requestInterval * 0.9, self.responseLatency * 0.5)))
    else self.cooldownUntil = GetTime() + self.requestInterval end
    Addon:WithPublicationBatch(function()
        if not committed then Addon.Scanner:CommitCollection(mails, visible, total, fullRead) end
        self:Accept(mails, targetRemoved, visible, total, layout)
    end)
    if self.state ~= "running" then Addon.Scanner:Schedule(true) end
    if self.notifyPending then self:Notify() end
end
function Queue:Accept(mails, targetRemoved, visible, total, layout)
    local pending = self.pending
    if layout then self:ApplyLayout(mails, visible, total, layout)
    else
        self.verifiedMails, self.visibleCount, self.totalCount = mails, visible, total
        if targetRemoved then
            for original, position in pairs(self.positions) do
                if position > pending.targetIndex then self.positions[original] = position - 1 end
            end
            self.positions[pending.originalIndex] = nil
        end
    end
    if targetRemoved and pending.originalIndex then
        self.removedIndexes[pending.originalIndex], self.expectedMails[pending.originalIndex] = true, nil
    else self.expectedMails[pending.originalIndex] = mails[pending.targetIndex] end
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
    if self.state == "running" then
        local batch = self.actions
        C_Timer.After(0, function() if Queue.actions == batch then Queue:Next() end end)
    end
end
function Queue:OnEvent(event, ...)
    if event == "UPDATE_PENDING_MAIL" and self.state == "running" then
        self.layoutDirty = true; self:ScheduleCheck(); return
    end
    if event == "MAIL_CLOSED" then
        if self.pending then
            local action = self.pending.action; action.state = "unverified"
            Addon:AddHistory(action.characterID, { state = "unverified", mail = action.original, item = action.item,
                attachments = action.slot == "return" and action.original.attachments or nil,
                money = (action.slot == "money" or action.slot == "return") and action.original.money or 0,
                codAmount = action.slot == "return" and action.original.cod or nil, observedAt = Addon:Now() })
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
        elseif event == "MAIL_FAILED" then
            self:Backoff(self.pending); self:Pause(Addon:T("UI.TEXT_0348"))
        elseif event == "ADDON_ACTION_BLOCKED" then
            self.pending.interference = true; self:Pause(Addon:T("UI.TEXT_0348"))
        elseif event == "UI_ERROR_MESSAGE" then
            -- Unrelated UI errors are not evidence that a mail action failed.
            -- Keep waiting for its observed result, slowing subsequent requests.
            self:Backoff(self.pending)
        end
        self:ScheduleCheck()
    elseif event == "MAIL_INBOX_UPDATE" then
        if self.state ~= "running" then self.verifiedMails = nil end
    end
end
function Queue:Install()
    Addon.Frame:HookScript("OnUpdate", function()
        if Queue.pending and GetTime() - Queue.pending.startedAt > ACTION_TIMEOUT and Queue.state == "running" then Queue:Pause(Addon:T(Queue.operation == "return" and "RETURN.UNVERIFIED" or "UI.TEXT_0477"), "result-timeout") end
    end)
    if hooksecurefunc then
        for _, name in ipairs({ "TakeInboxItem", "TakeInboxMoney", "AutoLootMailItem", "ReturnInboxItem", "DeleteInboxItem" }) do
            if type(_G[name]) == "function" then hooksecurefunc(name, function()
                if (Queue.state == "running" or Queue.pending) and not Queue.invoking then
                    if Queue.pending then Queue.pending.interference = true end
                    Queue:Pause(Addon:T("UI.TEXT_0419"))
                end
            end) end
        end
    end
end
