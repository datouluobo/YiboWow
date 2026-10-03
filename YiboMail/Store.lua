local Addon = _G.YiboMail
function Addon:InitializeDatabase()
    YiboMailDB = type(YiboMailDB) == "table" and YiboMailDB or {}
    self.db = YiboMailDB
    self.db.schemaVersion = 1
    self.db.revision = tonumber(self.db.revision) or 0
    self.db.nextMailKey = tonumber(self.db.nextMailKey) or 0
    self.db.byCharacter = self.db.byCharacter or {}
    self.db.settings = self.db.settings or {}
    self.db.contacts = self.db.contacts or {}
    self.db.rules = self.db.rules or {}
    self.db.settings.historyDays = tonumber(self.db.settings.historyDays) or 90
    self.db.settings.unverifiedDays = tonumber(self.db.settings.unverifiedDays) or 30
    self.db.settings.previewColumns = self.db.settings.previewColumns or { character = true, count = true, attachments = true, expires = true, status = true }
end
function Addon:AddHistory(characterID, record)
    local snapshot = self.db.byCharacter[characterID]
    if not snapshot then
        local character = self.Core.Characters:GetCurrent()
        snapshot = { records = {}, visibleKeys = {}, coverage = { status = "not-yet-scanned" }, character = self.Copy(character or {}) }
        self.db.byCharacter[characterID] = snapshot
    end
    snapshot.history = snapshot.history or {}; snapshot.history[#snapshot.history + 1] = self.Copy(record)
    local keys, ids = {}, {}
    if record.mail and record.mail.mailKey then keys[1] = record.mail.mailKey end
    if record.item then ids[1] = record.item.itemID end
    self:Publish(characterID, keys, ids, "archive")
end
function Addon:PruneHistory()
    local now = self:Now()
    for characterID, snapshot in pairs(self.db.byCharacter) do
        local keys, ids, seen, changed = {}, {}, {}, false
        for key, mail in pairs(snapshot.records) do
            if mail.state == "unverified" and now - (mail.stateEnteredAt or now) >= self.db.settings.unverifiedDays * 86400 then
                snapshot.records[key] = nil; keys[#keys + 1] = key; changed = true
                for _, item in ipairs(mail.attachments) do if not seen[item.itemID] then seen[item.itemID] = true; ids[#ids + 1] = item.itemID end end
            end
        end
        for index = #(snapshot.history or {}), 1, -1 do
            local record = snapshot.history[index]
            local days = record.state == "unverified" and self.db.settings.unverifiedDays or self.db.settings.historyDays
            if now - (record.observedAt or now) >= days * 86400 then table.remove(snapshot.history, index); changed = true end
        end
        if changed then self:Publish(characterID, keys, ids, "cleanup") end
    end
end
local function Groups(mails)
    local groups = {}
    for _, mail in ipairs(mails) do
        groups[mail.signature] = groups[mail.signature] or {}; table.insert(groups[mail.signature], mail)
    end
    return groups
end
function Addon:Publish(characterID, keys, itemIDs, reason)
    self.db.revision = self.db.revision + 1
    local snapshot = self.db.byCharacter[characterID]
    if snapshot then snapshot.coverage.revision = self.db.revision end
    table.sort(keys); table.sort(itemIDs)
    self.Items.Events:Emit({ apiVersion = 1, revision = self.db.revision, characterID = characterID,
        changedMailKeys = keys, changedItemIDs = itemIDs, reason = reason, observedAt = self:Now() })
end
function Addon:CommitScan(character, mails, coverage)
    local now = coverage.observedAt
    local old = self.db.byCharacter[character.id] or { records = {}, visibleKeys = {}, coverage = {} }
    local previous = {}; for _, key in ipairs(old.visibleKeys) do if old.records[key] then previous[#previous + 1] = old.records[key] end end
    local before, after = Groups(previous), Groups(mails)
    local keys, changed, itemIDs, itemSet, keySet = {}, {}, {}, {}, {}
    local function Mark(mail)
        if not keySet[mail.mailKey] then changed[#changed + 1] = mail.mailKey; keySet[mail.mailKey] = true end
        for _, item in ipairs(mail.attachments) do if not itemSet[item.itemID] then itemSet[item.itemID] = true; itemIDs[#itemIDs + 1] = item.itemID end end
    end
    for signature, group in pairs(after) do
        local candidates = before[signature] or {}
        -- Stable duplicate multiplicity keeps its keys. A changed duplicate
        -- group cannot identify which copy survived, so allocate fresh keys.
        local reusable = #candidates == #group
        for index, mail in ipairs(group) do
            local candidate = reusable and candidates[index]
            if candidate then
                mail.mailKey = candidate.mailKey
                mail.openedByUser = candidate.openedByUser == true
                local moved = candidate.inboxIndex ~= mail.inboxIndex or candidate.wasRead ~= mail.wasRead
                for slot, item in ipairs(mail.attachments) do
                    local prior = candidate.attachments[slot]
                    if not prior or prior.attachmentIndex ~= item.attachmentIndex or prior.variantKey ~= item.variantKey or prior.quantity ~= item.quantity then moved = true end
                end
                if moved then Mark(mail) end
            else
                self.db.nextMailKey = self.db.nextMailKey + 1
                mail.mailKey = "m" .. self.db.nextMailKey; Mark(mail)
            end
            mail.state, mail.stateEnteredAt = "observed", candidate and candidate.stateEnteredAt or now
            old.records[mail.mailKey] = mail; keys[#keys + 1] = mail.mailKey
        end
    end
    table.sort(keys, function(a, b) return old.records[a].inboxIndex < old.records[b].inboxIndex end)
    local current = {}; for _, key in ipairs(keys) do current[key] = true end
    for _, mail in ipairs(previous) do
        if not current[mail.mailKey] then mail.state, mail.stateEnteredAt = "unverified", now; Mark(mail) end
    end
    local stateChanged = old.coverage.status ~= coverage.status or old.coverage.currentCount ~= coverage.currentCount or old.coverage.totalCount ~= coverage.totalCount
    if self.Scanner and self.Scanner.publishedStatus then
        stateChanged = stateChanged or self.Scanner.publishedStatus[character.id] ~= coverage.status
        self.Scanner.publishedStatus[character.id] = coverage.status
    end
    coverage.revision = old.coverage.revision or self.db.revision
    old.visibleKeys, old.coverage, old.character = keys, coverage, { id = character.id, name = character.name, realm = character.realm }
    self.db.byCharacter[character.id] = old
    if #changed > 0 or stateChanged then self:Publish(character.id, changed, itemIDs, "scan") end
    if self.FEATURES.account and self.Core.AccountView then self.Core.AccountView:NotifyPageChanged("mail-inbox") end
end
function Addon:MarkMailOpened(entry)
    local snapshot = self.db.byCharacter[entry.character.id]
    local mail = snapshot and snapshot.records[entry.key]
    if not mail or mail.signature ~= entry.mail.signature then return nil end
    if not mail.openedByUser then
        mail.openedByUser = true
        self:Publish(entry.character.id, { entry.key }, {}, "scan")
    end
    entry.mail.openedByUser = true
    return true
end
function Addon:CleanupBacklog(characterID)
    local snapshot = self.db.byCharacter[characterID]; if not snapshot then return end
    local keys, ids, seen = {}, {}, {}
    for key, mail in pairs(snapshot.records) do
        if mail.state == "unverified" then
            keys[#keys + 1] = key
            for _, item in ipairs(mail.attachments) do if not seen[item.itemID] then seen[item.itemID] = true; ids[#ids + 1] = item.itemID end end
        end
    end
    for _, key in ipairs(keys) do snapshot.records[key] = nil end
    if #keys > 0 then self:Publish(characterID, keys, ids, "cleanup") end
end
function Addon:DeleteCharacter(character)
    local snapshot = self.db.byCharacter[character.id]
    if snapshot then
        local keys, ids, seen = {}, {}, {}
        for key, mail in pairs(snapshot.records) do
            keys[#keys + 1] = key
            for _, item in ipairs(mail.attachments) do if not seen[item.itemID] then seen[item.itemID] = true; ids[#ids + 1] = item.itemID end end
        end
        self.db.byCharacter[character.id] = nil; self:Publish(character.id, keys, ids, "cleanup")
    end
    return true
end
