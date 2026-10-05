local Addon = _G.YiboMail
function Addon:InitializeDatabase()
    YiboMailDB = type(YiboMailDB) == "table" and YiboMailDB or {}
    self.db = YiboMailDB
    self.db.schemaVersion = 1
    self.db.revision = tonumber(self.db.revision) or 0
    self.db.nextMailKey = tonumber(self.db.nextMailKey) or 0
    self.db.nextHistoryID = tonumber(self.db.nextHistoryID) or 0
    self.db.byCharacter = self.db.byCharacter or {}
    self.db.collectedMailMarkers = self.db.collectedMailMarkers or {}
    self.db.settings = self.db.settings or {}
    self.db.contacts = self.db.contacts or {}
    self.db.rules = self.db.rules or {}
    self.db.settings.historyDays = math.max(1, math.min(3650, math.floor(tonumber(self.db.settings.historyDays) or 90)))
    self.db.settings.unverifiedDays = math.max(1, math.min(3650, math.floor(tonumber(self.db.settings.unverifiedDays) or 30)))
    self.db.settings.previewColumns = self.db.settings.previewColumns or {}
    local previewDefaults = {
        character = true, count = true, attachments = true,
        money = true, expires = true, status = true,
        alert = false, cod = false, backlog = false,
    }
    for fieldID, visible in pairs(previewDefaults) do
        if self.db.settings.previewColumns[fieldID] == nil then
            self.db.settings.previewColumns[fieldID] = visible
        end
    end
    if self.db.settings.loginReminderEnabled == nil then
        self.db.settings.loginReminderEnabled = true
    end
    -- Give legacy events a permanent identity before pruning changes array indexes.
    for _, snapshot in pairs(self.db.byCharacter) do
        for _, record in ipairs(snapshot.history or {}) do
            self.db.nextHistoryID = math.max(self.db.nextHistoryID, tonumber((record.eventID or ""):match("^h(%d+)$")) or 0)
        end
    end
    for _, snapshot in pairs(self.db.byCharacter) do
        for _, record in ipairs(snapshot.history or {}) do
            if not record.eventID then
                self.db.nextHistoryID = self.db.nextHistoryID + 1; record.eventID = "h" .. self.db.nextHistoryID
                record.sourceMailKey = record.sourceMailKey or (record.mail and record.mail.mailKey)
            end
        end
    end
end
function Addon:AppendHistory(snapshot, record)
    self.db.nextHistoryID = self.db.nextHistoryID + 1
    local stored = self.Copy(record)
    stored.eventID = "h" .. self.db.nextHistoryID
    stored.sourceMailKey = stored.sourceMailKey or (stored.mail and stored.mail.mailKey)
    stored.timeBasis = stored.timeBasis or (stored.recipient and "send-result" or "operation-result")
    snapshot.history = snapshot.history or {}
    snapshot.history[#snapshot.history + 1] = stored
end
function Addon:AddHistory(characterID, record)
    local snapshot = self.db.byCharacter[characterID]
    if not snapshot then
        local character = self.Core.Characters:GetCurrent()
        snapshot = { records = {}, visibleKeys = {}, coverage = { status = "not-yet-scanned" }, character = self.Copy(character or {}) }
        self.db.byCharacter[characterID] = snapshot
    end
    self:AppendHistory(snapshot, record)
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
    local knownSignatures = {}
    for _, mail in pairs(old.records) do knownSignatures[mail.signature] = true end
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
                mail.firstSeenAt, mail.discoveryUncertain = candidate.firstSeenAt, candidate.discoveryUncertain
                local moved = candidate.inboxIndex ~= mail.inboxIndex or candidate.wasRead ~= mail.wasRead
                for slot, item in ipairs(mail.attachments) do
                    local prior = candidate.attachments[slot]
                    if not prior or prior.attachmentIndex ~= item.attachmentIndex or prior.variantKey ~= item.variantKey or prior.quantity ~= item.quantity then moved = true end
                end
                if moved then Mark(mail) end
            else
                self.db.nextMailKey = self.db.nextMailKey + 1
                mail.mailKey = "m" .. self.db.nextMailKey; Mark(mail)
                local pending = self.Queue and self.Queue.pending
                local collecting = pending and pending.action.characterID == character.id and pending.targetIndex == mail.inboxIndex
                    and pending.expected and pending.expected.signature == mail.signature
                if collecting then
                    mail.firstSeenAt = pending.action.original.firstSeenAt
                    mail.discoveryUncertain = pending.action.original.discoveryUncertain
                elseif not knownSignatures[signature] then
                    mail.firstSeenAt = now
                    self:AppendHistory(old, { state = "discovered", mail = mail, attachments = mail.attachments,
                        money = mail.money, codAmount = mail.cod, observedAt = now, timeBasis = "first-seen" })
                else mail.discoveryUncertain = true end
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
    local markers = self.db.collectedMailMarkers[character.id]
    if markers then
        for index = #markers, 1, -1 do
            if (tonumber(markers[index].expiresAtEstimate) or 0) + 86400 < now then table.remove(markers, index) end
        end
        if #markers == 0 then self.db.collectedMailMarkers[character.id] = nil end
    end
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
