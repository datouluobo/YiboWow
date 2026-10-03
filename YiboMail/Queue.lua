local Addon = _G.YiboMail
local Queue = { state = "idle", actions = {}, completed = 0 }; Addon.Queue = Queue
local function Fingerprint(mails)
    local parts = {}; for _, mail in ipairs(mails) do parts[#parts + 1] = mail.signature end; table.sort(parts); return Addon.Encode(parts)
end
local function Find(mails, signature)
    local found
    for _, mail in ipairs(mails) do if mail.signature == signature then if found then return nil, "邮件身份存在歧义。" end; found = mail end end
    return found, found and nil or "邮件内容已变化，请重新选择。"
end
function Queue:Notify()
    if Addon.Core and Addon.FEATURES.account then Addon.Core.AccountView:NotifyPageChanged("mail-inbox") end
    if Addon.NativeUI then Addon.NativeUI:Refresh() end
end
function Queue:Discard()
    if self.pending then return nil, "请先核实当前操作结果。" end
    self.state, self.actions, self.completed, self.message = "idle", {}, 0, nil; return true
end
function Queue:Pause(reason)
    self.state, self.message = "paused", reason or "已暂停。"
    self:Notify()
end
function Queue:Prepare(selection, context)
    if self.pending then return nil, "上一步结果仍待核实，请等待邮箱更新或关闭后重新检查。" end
    local actions = {}
    for _, entry in ipairs(Addon.ViewModel:GetMails(context, {})) do
        local mail = entry.mail
        local function Selected(slot, item)
            local id = Addon.ViewModel:ActionID(entry.character.id, entry.key, slot)
            if not selection[id] then return true end
            if not entry.actionable then return nil, entry.restriction end
            actions[#actions + 1] = { id = id, characterID = entry.character.id, mailKey = entry.key,
                signature = mail.signature, original = Addon.Copy(mail), slot = slot, item = Addon.Copy(item), state = "pending" }
            return true
        end
        if mail.money > 0 then local ok, err = Selected("money"); if not ok then return nil, err end end
        for _, item in ipairs(mail.attachments) do local ok, err = Selected(item.attachmentIndex, item); if not ok then return nil, err end end
    end
    local selected = 0; for _ in pairs(selection) do selected = selected + 1 end
    if #actions ~= selected then return nil, "部分选择已失去可见性或超出当前范围，请清空后重新选择。" end
    if #actions == 0 then return nil, "请选择当前角色邮箱中的附件或金币。" end
    return actions
end
function Queue:RemainingSelection(context)
    if self.pending then return nil, "上一步结果仍待核实，请等待邮箱更新或重新打开后检查。" end
    local entries, selection = Addon.ViewModel:GetMails(context, {}), {}
    for _, action in ipairs(self.actions) do
        if action.state == "pending" then
            local found
            for _, entry in ipairs(entries) do
                if entry.character.id == action.characterID and entry.mail.signature == action.signature then
                    if found then return nil, "剩余项存在同签名歧义，请重新选择。" end
                    found = entry
                end
            end
            if not found or not found.actionable then return nil, "剩余项已变化，请清空后重新选择。" end
            selection[Addon.ViewModel:ActionID(found.character.id, found.key, action.slot)] = true
        end
    end
    return selection
end
function Queue:Start(actions)
    if self.state == "running" then return nil, "收取队列正在运行。" end
    if self.pending then return nil, "请等待上一步结果。" end
    if type(actions) ~= "table" or #actions == 0 then return nil, "请选择要收取的附件或金币。" end
    local mails, err = Addon.Scanner:ReadVisible(); if not mails then return nil, err end
    local current, selected = Addon.Core.Characters:GetCurrent(), {}
    for _, action in ipairs(actions) do
        if not current or current.id ~= action.characterID then return nil, "当前角色已变化，请重新选择。" end
        if selected[action.id] then return nil, "收取项目重复，请重新选择。" end
        selected[action.id] = true
        local mail, why = Find(mails, action.signature); if not mail then return nil, why end
        if mail.cod > 0 then return nil, "付款取信请使用原生邮箱。" end
        if action.slot == "money" then
            if mail.money <= 0 or mail.money ~= action.original.money then return nil, "金币数量已变化，请重新选择。" end
        else
            local found = false
            for _, item in ipairs(mail.attachments) do
                if item.attachmentIndex == action.slot and action.item and item.variantKey == action.item.variantKey and item.quantity == action.item.quantity then found = true; break end
            end
            if not found then return nil, "附件槽位或数量已变化，请重新选择。" end
        end
    end
    self.actions, self.completed, self.index, self.state, self.message = Addon.Copy(actions), 0, 1, "running", "正在逐项收取"
    self:Next(); return true
end
function Queue:Next()
    if self.state ~= "running" or self.pending then return end
    local action = self.actions[self.index]
    if not action then
        self.state, self.message = "complete", "本批收取完成。"
        if Addon:GetInboxPreferences().showSummary then Addon:Print("本批收取完成：" .. self.completed .. "/" .. #self.actions .. " 项。") end
        self:Notify(); return
    end
    local current = Addon.Core.Characters:GetCurrent()
    if not current or current.id ~= action.characterID then self:Pause("当前角色已变化。"); return end
    if InCombatLockdown and InCombatLockdown() then self:Pause("战斗中已暂停，请结束战斗后重新选择。"); return end
    local mails, err = Addon.Scanner:ReadVisible(); if not mails then self:Pause(err); return end
    local mail, reason = Find(mails, action.signature); if not mail then self:Pause(reason); return end
    if mail.cod > 0 then self:Pause("付款取信请使用原生邮箱。"); return end
    local expected = Addon.Copy(mail)
    if action.slot == "money" then
        if mail.money <= 0 or mail.money ~= action.original.money then self:Pause("金币数量已变化。"); return end
        expected.money = 0
    else
        local match
        for index, item in ipairs(expected.attachments) do
            if item.attachmentIndex == action.slot and item.variantKey == action.item.variantKey and item.quantity == action.item.quantity then match = index end
        end
        if not match then self:Pause("附件槽位或数量已变化。"); return end
        local free = 0; local slots = C_Container and C_Container.GetContainerNumFreeSlots or GetContainerNumFreeSlots
        if not slots then self:Pause("无法核对背包容量。"); return end
        for bag = 0, NUM_BAG_SLOTS or 4 do local count, family = slots(bag); if family == 0 then free = free + (count or 0) end end
        if free < 1 then self:Pause("普通背包空位不足，请整理后重新选择。"); return end
        table.remove(expected.attachments, match)
    end
    expected.signature = Addon.Scanner:Signature(expected)
    local after = {}; for _, entry in ipairs(mails) do after[#after + 1] = entry.inboxIndex == mail.inboxIndex and expected or entry end
    local removed = {}; for _, entry in ipairs(mails) do if entry.inboxIndex ~= mail.inboxIndex then removed[#removed + 1] = entry end end
    self.pending = { action = action, expected = expected, expectedFingerprint = Fingerprint(after),
        removedFingerprint = #expected.attachments == 0 and expected.money == 0 and Fingerprint(removed) or nil,
        startedAt = GetTime(), success = false, updated = false }
    self.invoking = true
    local fn = action.slot == "money" and TakeInboxMoney or TakeInboxItem
    local ok, errorMessage
    if type(fn) == "function" then
        if action.slot == "money" then ok, errorMessage = pcall(fn, mail.inboxIndex) else ok, errorMessage = pcall(fn, mail.inboxIndex, action.slot) end
    else ok, errorMessage = false, "客户端未提供收取接口。" end
    self.invoking = false
    if not ok then self.pending = nil; self:Pause(tostring(errorMessage)); return end
    self:Notify()
end
function Queue:OnScan(mails)
    local pending = self.pending
    if not pending or pending.interference or not pending.success or not pending.updated then return end
    local fingerprint = Fingerprint(mails)
    if fingerprint ~= pending.expectedFingerprint and fingerprint ~= pending.removedFingerprint then self:Pause("操作后邮箱内容不符，请等待更新并检查结果。"); return end
    local action = pending.action; action.state = "success"; self.completed = self.completed + 1
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
        if self.actions[index].mailKey == action.mailKey then self.actions[index].signature = pending.expected.signature end
    end
    self.pending, self.index = nil, self.index + 1
    if self.onSuccess then self.onSuccess(action.id) end
    if Addon.NativeUI then Addon.NativeUI:OnCollected(action.id) end
    self:Notify()
    if self.state == "running" then C_Timer.After(0.4, function() Queue:Next() end) end
end
function Queue:OnEvent(event, ...)
    if event == "MAIL_CLOSED" then
        if self.pending then
            local action = self.pending.action; action.state = "unverified"
            Addon:AddHistory(action.characterID, { state = "unverified", mail = action.original, item = action.item,
                money = action.slot == "money" and action.original.money or 0, observedAt = Addon:Now() })
            self.pending = nil
        end
        if self.state == "running" then self:Pause("邮箱已关闭，未执行项保留。") end
    elseif self.pending then
        if event == "MAIL_SUCCESS" then self.pending.success = true
        elseif event == "MAIL_INBOX_UPDATE" then self.pending.updated = true
        elseif event == "MAIL_FAILED" or event == "UI_ERROR_MESSAGE" or event == "ADDON_ACTION_BLOCKED" then self:Pause("收取未完成，请检查游戏提示后重新选择。") end
        if self.pending.success and self.pending.updated then Addon.Scanner:Schedule() end
    end
end
function Queue:Install()
    Addon.Frame:HookScript("OnUpdate", function()
        if Queue.pending and GetTime() - Queue.pending.startedAt > 12 and Queue.state == "running" then Queue:Pause("等待结果超时；关闭并重新打开邮箱核实后再收取。") end
    end)
    if hooksecurefunc then
        for _, name in ipairs({ "TakeInboxItem", "TakeInboxMoney", "AutoLootMailItem", "ReturnInboxItem", "DeleteInboxItem" }) do
            if type(_G[name]) == "function" then hooksecurefunc(name, function()
                if Queue.state == "running" and not Queue.invoking then
                    if Queue.pending then Queue.pending.interference = true end
                    Queue:Pause("检测到其它邮箱操作，请重新打开邮箱核实后选择。")
                end
            end) end
        end
    end
end
