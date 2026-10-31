local Addon = _G.YiboMail
local function SameValue(left, right)
    if left == right then return true end
    if type(left) ~= "table" or type(right) ~= "table" then return false end
    for key, value in pairs(left) do if not SameValue(value, right[key]) then return false end end
    for key in pairs(right) do if left[key] == nil then return false end end
    return true
end
-- SavedVariables writes shared tables by value. Restore equal immutable item
-- observations without dropping any event, field, mail or attachment occurrence.
function Addon:ShareStoredAttachments()
    local groups, arrays, reused, reusedArrays = {}, {}, 0, 0
    local function Item(item)
        if type(item) ~= "table" then return item end
        local key = item.variantKey or item.itemKey or item.itemID
        if type(key) ~= "string" and type(key) ~= "number" then return item end
        local quantity, slot = item.quantity or false, item.attachmentIndex or false
        if key ~= key or quantity ~= quantity or slot ~= slot then return item end
        local group = groups[key]; if not group then group = {}; groups[key] = group end
        local quantities = group[quantity]; if not quantities then quantities = {}; group[quantity] = quantities end
        local candidates = quantities[slot]; if not candidates then candidates = {}; quantities[slot] = candidates end
        for _, prior in ipairs(candidates) do
            if SameValue(prior, item) then
                if prior ~= item then reused = reused + 1 end
                return prior
            end
        end
        candidates[#candidates + 1] = item
        return item
    end
    local EMPTY = {}
    local function Attachments(items)
        if type(items) ~= "table" then return items end
        for index, item in ipairs(items) do items[index] = Item(item) end
        local first, size = items[1] or EMPTY, #items
        if first ~= first then return items end
        local group = arrays[first]; if not group then group = {}; arrays[first] = group end
        local candidates = group[size]; if not candidates then candidates = {}; group[size] = candidates end
        for _, prior in ipairs(candidates) do
            if SameValue(prior, items) then
                if prior ~= items then reusedArrays = reusedArrays + 1 end
                return prior
            end
        end
        candidates[#candidates + 1] = items
        return items
    end
    for _, snapshot in pairs(self.db.byCharacter or {}) do
        for _, mail in pairs(snapshot.records or {}) do
            if mail.attachments ~= nil then mail.attachments = Attachments(mail.attachments) end
        end
        for _, record in ipairs(snapshot.history or {}) do
            if record.mail and record.mail.attachments ~= nil then record.mail.attachments = Attachments(record.mail.attachments) end
            -- Assigning a missing key to nil can still grow Lua 5.1 hash parts.
            if record.attachments ~= nil then record.attachments = Attachments(record.attachments) end
            if record.item then record.item = Item(record.item) end
        end
    end
    -- The index is local to initialization, not another long-lived cache.
    return reused, reusedArrays
end
function Addon:InitializeDatabase()
    local name = self.Target and self.Target.savedVariable or "YiboMailDB"
    local saved = _G[name]
    if self.Target then
        if saved ~= nil and type(saved) ~= "table" then return nil, "store-mismatch" end
        if saved then
            if saved.schemaVersion ~= nil and saved.schemaVersion ~= 1 then return nil, "store-mismatch" end
            local scope = saved.clientScope
            if scope and (type(scope) ~= "table" or scope.target ~= "Forever" or scope.projectID ~= WOW_PROJECT_ID or scope.scope ~= "current-character") then return nil, "store-mismatch" end
            for _, key in ipairs({ "byCharacter", "settings", "contacts", "rules", "collectedMailMarkers", "mailArrivalSignals", "mailNoticeBatches" }) do
                if saved[key] ~= nil and type(saved[key]) ~= "table" then return nil, "store-mismatch" end
            end
            for _, snapshot in pairs(saved.byCharacter or {}) do
                if type(snapshot) ~= "table" or type(snapshot.records) ~= "table" or type(snapshot.visibleKeys) ~= "table" or type(snapshot.coverage) ~= "table" then return nil, "store-mismatch" end
            end
        end
    end
    _G[name] = type(saved) == "table" and saved or {}
    self.db = _G[name]
    if self.Target then self.db.clientScope = { target = "Forever", projectID = WOW_PROJECT_ID, scope = "current-character", rulesetState = "unknown" } end
    self.db.schemaVersion = 1
    self.db.revision = tonumber(self.db.revision) or 0
    self.db.nextMailKey = tonumber(self.db.nextMailKey) or 0
    self.db.nextHistoryID = tonumber(self.db.nextHistoryID) or 0
    self.db.byCharacter = self.db.byCharacter or {}
    self.db.collectedMailMarkers = self.db.collectedMailMarkers or {}
    self.db.mailArrivalSignals = self.db.mailArrivalSignals or {}
    self.db.mailNoticeBatches = self.db.mailNoticeBatches or {}
    self.db.nextMailNoticeID = tonumber(self.db.nextMailNoticeID) or 0
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
    -- Existing mailbox caches are storage, not a backlog of new work. This
    -- baseline is owned by Mail and does not change the inbox's read styling.
    if self.db.mailNoticeVersion ~= 1 then
        for _, snapshot in pairs(self.db.byCharacter) do
            for _, mail in pairs(snapshot.records or {}) do mail.noticeHandled = true end
        end
        self.db.mailNoticeBatches = {}
        self.db.mailNoticeVersion = 1
    end
    -- Give legacy events a permanent identity before pruning changes array indexes.
    for _, snapshot in pairs(self.db.byCharacter) do
        for _, record in ipairs(snapshot.history or {}) do
            self.db.nextHistoryID = math.max(self.db.nextHistoryID, tonumber((record.eventID or ""):match("^h(%d+)$")) or 0)
        end
    end
    for _, snapshot in pairs(self.db.byCharacter) do
        local originals = {}
        for _, record in ipairs(snapshot.history or {}) do
            -- Reloaded attachment operations may have separate equal originals.
            -- Intern only exact copies with the same source identity; differing
            -- historical observations remain independent evidence.
            local mail = record.state == "collected-archived" and record.mail
            local key = mail and (record.sourceMailKey or mail.mailKey)
            if key then
                local prior = originals[key]
                if prior and SameValue(prior, mail) then record.mail = prior
                elseif not prior then originals[key] = mail end
            end
            -- SavedVariables may deserialize equal attachment arrays separately.
            -- Reuse the mail's array only when every value agrees; no history is lost.
            if record.mail and record.attachments and record.mail.attachments
                and SameValue(record.attachments, record.mail.attachments) then
                record.attachments = record.mail.attachments
            end
            if not record.eventID then
                self.db.nextHistoryID = self.db.nextHistoryID + 1; record.eventID = "h" .. self.db.nextHistoryID
                record.sourceMailKey = record.sourceMailKey or (record.mail and record.mail.mailKey)
            end
        end
    end
    self:ShareStoredAttachments()
    return true
end
function Addon:UpdateMailNoticeBatch(characterID)
    local signal = self.db.mailArrivalSignals[characterID]
    local pending = signal and signal.awaitingScan
    local snapshot = self.db.byCharacter[characterID]
    for _, key in ipairs(snapshot and snapshot.visibleKeys or {}) do
        local mail = snapshot.records[key]
        if mail and mail.state == "observed" and not mail.openedByUser and not mail.noticeHandled then pending = true; break end
    end
    if pending and not self.db.mailNoticeBatches[characterID] then
        self.db.nextMailNoticeID = self.db.nextMailNoticeID + 1
        self.db.mailNoticeBatches[characterID] = "n" .. self.db.nextMailNoticeID
    elseif not pending then self.db.mailNoticeBatches[characterID] = nil end
end
function Addon:AppendHistory(snapshot, record, copies)
    self.db.nextHistoryID = self.db.nextHistoryID + 1
    -- A queue batch may supply its private copy map so attachment operations
    -- share one isolated original letter instead of copying it per attachment.
    local stored = self.Copy(record, copies)
    stored.eventID = "h" .. self.db.nextHistoryID
    stored.sourceMailKey = stored.sourceMailKey or (stored.mail and stored.mail.mailKey)
    stored.timeBasis = stored.timeBasis or (stored.recipient and "send-result" or "operation-result")
    snapshot.history = snapshot.history or {}
    snapshot.history[#snapshot.history + 1] = stored
end
function Addon:AddHistory(characterID, record, copies)
    local snapshot = self.db.byCharacter[characterID]
    if not snapshot then
        local character = self.Core.Characters:GetCurrent({ identityOnly = true })
        snapshot = { records = {}, visibleKeys = {}, coverage = { status = "not-yet-scanned" }, character = self.Copy(character or {}) }
        self.db.byCharacter[characterID] = snapshot
    end
    self:AppendHistory(snapshot, record, copies)
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
local function Groups(mails, records)
    local groups = {}
    for _, value in ipairs(mails) do
        local mail = value
        if records then mail = records[value] end
        if mail then
            local prior = groups[mail.signature]
            if not prior then groups[mail.signature] = mail
            elseif prior.signature then groups[mail.signature] = { prior, mail }
            else prior[#prior + 1] = mail end
        end
    end
    return groups
end
local function GroupCount(group)
    return not group and 0 or (group.signature and 1 or #group)
end
function Addon:Publish(characterID, keys, itemIDs, reason, transfersUnchanged)
    self.db.revision = self.db.revision + 1
    if self.Items.OnPublish then self.Items:OnPublish(self.db.revision, transfersUnchanged, characterID) end
    local snapshot = self.db.byCharacter[characterID]
    if snapshot then snapshot.coverage.revision = self.db.revision end
    table.sort(keys); table.sort(itemIDs)
    local payload = { apiVersion = 1, revision = self.db.revision, characterID = characterID,
        changedMailKeys = keys, changedItemIDs = itemIDs, reason = reason, observedAt = self:Now(),
        transfersUnchanged = transfersUnchanged == true }
    local batch = self.publicationBatch
    if not batch then self.Items.Events:Emit(payload); return end
    local change = batch.byCharacter[characterID]
    if not change then
        change = { payload = payload, keys = {}, items = {} }
        payload.changedMailKeys, payload.changedItemIDs = {}, {}
        batch.byCharacter[characterID] = change; batch.changes[#batch.changes + 1] = change
    end
    for _, key in ipairs(keys) do
        if not change.keys[key] then change.keys[key] = true; table.insert(change.payload.changedMailKeys, key) end
    end
    for _, id in ipairs(itemIDs) do
        if not change.items[id] then change.items[id] = true; table.insert(change.payload.changedItemIDs, id) end
    end
    change.payload.revision, change.payload.observedAt = payload.revision, payload.observedAt
    change.payload.transfersUnchanged = change.payload.transfersUnchanged and payload.transfersUnchanged
    if reason == "archive" then change.payload.reason = reason end
end
function Addon:WithPublicationBatch(callback)
    if self.publicationBatch then return callback() end
    local batch = { byCharacter = {}, changes = {} }; self.publicationBatch = batch
    local ok, result = pcall(callback)
    -- Release the batch before notifying consumers; reentrant changes start
    -- their own publication and cannot be swallowed by this completed scan.
    self.publicationBatch = nil
    for _, change in ipairs(batch.changes) do
        table.sort(change.payload.changedMailKeys); table.sort(change.payload.changedItemIDs)
        self.Items.Events:Emit(change.payload)
    end
    if batch.refreshPage and #batch.changes == 0 and self.Core.AccountView then
        self.Core.AccountView:NotifyPageChanged("mail-inbox")
    end
    if not ok then error(result, 0) end
    return result
end
function Addon:CommitScan(character, mails, coverage)
    local now = coverage.observedAt
    local old = self.db.byCharacter[character.id] or { records = {}, visibleKeys = {}, coverage = {} }
    local previous = old.visibleKeys
    local before, after = Groups(previous, old.records), Groups(mails)
    local knownSignatures
    local function Known(signature)
        if before[signature] then return true end
        -- Confirmed collection deltas already identify their changed letter.
        -- Materialize the historical signature set only for a genuinely new
        -- or ambiguous observed group, not once per collected attachment.
        if not knownSignatures then
            knownSignatures = {}
            for _, mail in pairs(old.records) do knownSignatures[mail.signature] = true end
        end
        return knownSignatures[signature] == true
    end
    local keys, changed, itemIDs, itemSet, keySet = {}, {}, {}, {}, {}
    local function Mark(mail)
        if not keySet[mail.mailKey] then changed[#changed + 1] = mail.mailKey; keySet[mail.mailKey] = true end
        for _, item in ipairs(mail.attachments) do if not itemSet[item.itemID] then itemSet[item.itemID] = true; itemIDs[#itemIDs + 1] = item.itemID end end
    end
    for signature, group in pairs(after) do
        local candidates = before[signature]
        local count, priorCount = GroupCount(group), GroupCount(candidates)
        -- Stable duplicate multiplicity keeps its keys. A changed duplicate
        -- group cannot identify which copy survived, so allocate fresh keys.
        local reusable = priorCount == count
        for index = 1, count do
            local mail = count == 1 and group or group[index]
            local candidate = reusable and (priorCount == 1 and candidates or candidates[index])
            if candidate then
                mail.mailKey = candidate.mailKey
                mail.openedByUser = candidate.openedByUser == true
                mail.noticeHandled = candidate.noticeHandled == true or mail.openedByUser
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
                    mail.noticeHandled = true
                elseif not Known(signature) then
                    mail.firstSeenAt = now
                    self:AppendHistory(old, { state = "discovered", mail = mail, attachments = mail.attachments,
                        money = mail.money, codAmount = mail.cod, observedAt = now, timeBasis = "first-seen" })
                else mail.discoveryUncertain = true; mail.noticeHandled = true end
                -- The initial client read flag is useful when importing a
                -- previously read letter. Later background flag changes do
                -- not count as an explicit user acknowledgement.
                mail.noticeHandled = mail.noticeHandled == true or mail.wasRead == true
            end
            mail.state, mail.stateEnteredAt = "observed", candidate and candidate.stateEnteredAt or now
            old.records[mail.mailKey] = mail; keys[#keys + 1] = mail.mailKey
        end
    end
    table.sort(keys, function(a, b) return old.records[a].inboxIndex < old.records[b].inboxIndex end)
    for _, key in ipairs(previous) do
        local mail = old.records[key]
        -- A completed scan is the current inbox snapshot. Mail that vanished
        -- while the add-on was offline is treated as gone; its disposition
        -- cannot be inferred reliably from the next scan.
        if mail and GroupCount(before[mail.signature]) ~= GroupCount(after[mail.signature]) then
            Mark(mail); old.records[key] = nil
        end
    end
    local visibleSet = {}; for _, key in ipairs(keys) do visibleSet[key] = true end
    for key, mail in pairs(old.records) do
        if not visibleSet[key] then Mark(mail); old.records[key] = nil end
    end
    local stateChanged = old.coverage.status ~= coverage.status or old.coverage.currentCount ~= coverage.currentCount or old.coverage.totalCount ~= coverage.totalCount
    if self.Scanner and self.Scanner.publishedStatus then
        stateChanged = stateChanged or self.Scanner.publishedStatus[character.id] ~= coverage.status
        self.Scanner.publishedStatus[character.id] = coverage.status
    end
    coverage.revision = old.coverage.revision or self.db.revision
    old.visibleKeys, old.coverage, old.character = keys, coverage, { id = character.id, name = character.name, realm = character.realm }
    self.db.byCharacter[character.id] = old
    local arrival = self.db.mailArrivalSignals[character.id]
    if arrival and arrival.awaitingScan then arrival.awaitingScan = false; stateChanged = true end
    self:UpdateMailNoticeBatch(character.id)
    local markers = self.db.collectedMailMarkers[character.id]
    if markers then
        for index = #markers, 1, -1 do
            if (tonumber(markers[index].expiresAtEstimate) or 0) + 86400 < now then table.remove(markers, index) end
        end
        if #markers == 0 then self.db.collectedMailMarkers[character.id] = nil end
    end
    if #changed > 0 or stateChanged then self:Publish(character.id, changed, itemIDs, "scan") end
    if self.FEATURES.account and self.Core.AccountView then
        if self.publicationBatch then self.publicationBatch.refreshPage = true
        else self.Core.AccountView:NotifyPageChanged("mail-inbox") end
    end
end
function Addon:MarkMailOpened(entry, batch)
    local snapshot = self.db.byCharacter[entry.character.id]
    local mail = snapshot and snapshot.records[entry.key]
    if not mail or mail.signature ~= entry.mail.signature then return nil end
    if not mail.openedByUser or not mail.noticeHandled then
        mail.openedByUser, mail.noticeHandled = true, true
        if batch then
            local keys = batch[entry.character.id] or {}; batch[entry.character.id] = keys
            keys[#keys + 1] = entry.key
        else
            self:UpdateMailNoticeBatch(entry.character.id)
            self:Publish(entry.character.id, { entry.key }, {}, "scan", true)
        end
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
    local hadArrival = self.db.mailArrivalSignals[character.id] ~= nil
    self.db.mailArrivalSignals[character.id] = nil
    self.db.mailNoticeBatches[character.id] = nil
    if snapshot then
        local keys, ids, seen = {}, {}, {}
        for key, mail in pairs(snapshot.records) do
            keys[#keys + 1] = key
            for _, item in ipairs(mail.attachments) do if not seen[item.itemID] then seen[item.itemID] = true; ids[#ids + 1] = item.itemID end end
        end
        self.db.byCharacter[character.id] = nil; self:Publish(character.id, keys, ids, "cleanup")
    elseif hadArrival then self:Publish(character.id, {}, {}, "cleanup")
    end
    return true
end
