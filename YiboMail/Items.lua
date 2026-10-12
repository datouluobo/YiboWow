local Addon = _G.YiboMail
local Items = { API_VERSION = 1, Events = { listeners = {} }, transfersCache = {} }; Addon.Items = Items
function Items:GetAPIVersion() return 1 end
function Items:GetCapabilities() return Addon.Copy(Addon.CAPABILITIES) end
function Items:HasCapability(name, minimumVersion)
    local version = Addon.CAPABILITIES[name]; return version ~= nil and version >= (tonumber(minimumVersion) or 1), version
end
function Items:GetRevision() return Addon.db and Addon.db.revision or 0 end
local function CharacterByAddress(address, defaultRealm)
    local normalized, _, name, realm = Addon.Recipients:Normalize(address, defaultRealm)
    if not normalized then return nil end
    local key = Addon.Recipients:Key(name .. "-" .. realm)
    for _, character in ipairs(Addon.Core.Characters:GetAllCached()) do
        if character.name and character.realm
            and Addon.Recipients:Key(character.name .. "-" .. character.realm) == key then return character end
    end
end
local function ItemVariantKey(item)
    if type(item) ~= "table" then return nil end
    if type(item.variantKey) == "string" and item.variantKey ~= "" then return item.variantKey end
    if type(item.itemLink) == "string" then
        local payload = item.itemLink:match("|H([^|]+)|h")
        if payload then return "link:" .. payload end
    end
    return type(item.itemID) == "number" and ("item:" .. item.itemID) or nil
end
local function AttachmentSignature(items)
    if type(items) ~= "table" or #items == 0 then return nil end
    local identities = {}
    for _, item in ipairs(items) do
        if type(item) ~= "table" or type(item.itemID) ~= "number" or type(item.quantity) ~= "number" then return nil end
        identities[#identities + 1] = Addon.Encode({ ItemVariantKey(item) or ("item:" .. item.itemID), item.quantity })
    end
    table.sort(identities)
    return Addon.Encode(identities)
end
local function SenderMatches(sender, senderCharacter, recipientRealm)
    if type(sender) ~= "string" or sender == "" then return false end
    local normalized, _, name, realm = Addon.Recipients:Normalize(sender, recipientRealm)
    if normalized then
        return Addon.Recipients:Key(name) == Addon.Recipients:Key(senderCharacter.name)
            and Addon.Recipients:Key(realm) == Addon.Recipients:Key(senderCharacter.realm)
    end
    return false
end
function Items:GetTransfers(characterID)
    if type(characterID) ~= "string" or characterID == "" then return nil, "invalid-character-id" end
    local revision = self:GetRevision()
    local characters = Addon.Core and Addon.Core.Characters:GetAllCached() or {}
    local directory = {}
    for _, character in ipairs(characters) do
        directory[#directory + 1] = Addon.Encode({ character.id, character.name or "", character.realm or "" })
    end
    table.sort(directory)
    local cacheKey = Addon.Encode({ revision, table.concat(directory) })
    local cached = self.transfersCache[characterID]
    if cached and cached.cacheKey == cacheKey then return Addon.Copy(cached.result) end
    local target
    for _, character in ipairs(characters) do
        if character.id == characterID then target = character end
    end
    if not target then
        local empty = { apiVersion = 1, revision = revision, characterID = characterID, records = {} }
        self.transfersCache[characterID] = { cacheKey = cacheKey, result = empty }
        return Addon.Copy(empty)
    end

    -- A scanned receipt confirms a send only when its sender and complete
    -- attachment multiset match. Identical messages are counted by occurrence.
    local received = {}
    local targetSnapshot = Addon.db.byCharacter[characterID]
    local function AddReceived(mail, observedAt, identity)
        if not mail or mail.wasReturned or type(observedAt) ~= "number" then return end
        local senderCharacter
        for _, candidate in ipairs(characters) do
            if SenderMatches(mail.sender, candidate, target.realm) then senderCharacter = candidate; break end
        end
        local attachmentKey = AttachmentSignature(mail.attachments)
        if not senderCharacter or not attachmentKey then return end
        local signature = Addon.Encode({ senderCharacter.id, mail.subject or "", attachmentKey })
        received[signature] = received[signature] or {}
        if not received[signature][identity] then received[signature][identity] = observedAt end
    end
    if targetSnapshot then
        for key, mail in pairs(targetSnapshot.records or {}) do
            if mail.state == "observed" then AddReceived(mail, mail.observedAt, "inbox:" .. key) end
        end
        for _, history in ipairs(targetSnapshot.history or {}) do
            if history.state == "discovered" or history.state == "collected-archived" then
                local mail = history.mail or history
                AddReceived(mail, history.observedAt or mail.observedAt, "history:" .. tostring(history.eventID or history.sourceMailKey or ""))
            end
        end
    end

    local consumed, consumedReturns = {}, {}
    local records = {}
    for _, senderCharacter in ipairs(characters) do
        local snapshot = Addon.db.byCharacter[senderCharacter.id]
        for _, history in ipairs(snapshot and snapshot.history or {}) do
            if history.state == "in-transit" and type(history.recipient) == "string" then
                local recipient = CharacterByAddress(history.recipient, senderCharacter.realm)
                local attachmentKey = AttachmentSignature(history.attachments)
                if recipient and recipient.id == characterID and attachmentKey then
                    local sentAt = tonumber(history.observedAt or history.attemptedAt) or 0
                    local signature = Addon.Encode({ senderCharacter.id, history.subject or "", attachmentKey })
                    local returned = false
                    local function CheckReturn(mail, observedAt, identity)
                        if returned or consumedReturns[identity] or not mail or not mail.wasReturned
                            or (tonumber(observedAt) or 0) < sentAt or (mail.subject or "") ~= (history.subject or "")
                            or AttachmentSignature(mail.attachments) ~= attachmentKey
                            or not SenderMatches(mail.sender, recipient, senderCharacter.realm) then return end
                        returned, consumedReturns[identity] = true, true
                    end
                    for key, mail in pairs(snapshot and snapshot.records or {}) do
                        CheckReturn(mail, mail.observedAt, "return-inbox:" .. senderCharacter.id .. ":" .. key)
                    end
                    for _, mailHistory in ipairs(snapshot and snapshot.history or {}) do
                        if mailHistory.state == "collected-archived" then
                            local returnedMail = mailHistory.mail or mailHistory
                            CheckReturn(returnedMail, mailHistory.observedAt or returnedMail.observedAt,
                                "return-history:" .. senderCharacter.id .. ":" .. tostring(mailHistory.eventID or mailHistory.sourceMailKey or ""))
                        end
                    end
                    local matchedReceipt
                    if not returned then
                        for receiptID, receivedAt in pairs(received[signature] or {}) do
                            if not consumed[receiptID] and receivedAt >= sentAt then matchedReceipt = receiptID; break end
                        end
                    end
                    if returned then
                        -- A returned attachment is back with its sender; do not
                        -- continue showing it as addressed to the recipient.
                    elseif matchedReceipt then
                        consumed[matchedReceipt] = true
                    else
                        for attachmentIndex, item in ipairs(history.attachments) do
                            local variantKey = ItemVariantKey(item)
                            records[#records + 1] = {
                                sourceID = "mail-transit:" .. senderCharacter.id .. ":" .. tostring(history.eventID or sentAt) .. ":" .. attachmentIndex,
                                source = "mail", sourceClass = "external", mailStatus = "in-transit",
                                itemID = item.itemID, itemLink = item.itemLink,
                                itemKey = item.itemKey or ("item:" .. item.itemID), variantKey = variantKey,
                                identityQuality = variantKey and variantKey ~= ("item:" .. item.itemID) and "full-link" or "item-id-only",
                                quantity = item.quantity,
                                characterID = characterID, realm = target.realm, senderCharacterID = senderCharacter.id,
                                senderName = senderCharacter.name, recipientCharacterID = characterID,
                                location = { container = "in-transit", attachmentIndex = attachmentIndex },
                                observedAt = sentAt, state = "in-transit", subject = history.subject,
                            }
                        end
                    end
                end
            end
        end
    end
    table.sort(records, function(a, b) return a.sourceID < b.sourceID end)
    local result = { apiVersion = 1, revision = revision, characterID = characterID, records = records }
    self.transfersCache[characterID] = { cacheKey = cacheKey, result = result }
    return Addon.Copy(result)
end
function Items:RegisterService()
    local contracts = Addon.Core.Contracts
    self.serviceDefinition = self.serviceDefinition or {
        name = "mail.items", kind = "service", providerID = Addon.NAME .. ":inbox", version = { major = 1, minor = 1 },
        methods = {
            GetState = function(request) return Items:GetState(request and request.characterID) end,
            GetByCharacter = function(request) return Items:GetByCharacter(request and request.characterID, request and request.options) end,
            GetTransfers = function(request) return Items:GetTransfers(request and request.characterID) end,
            GetRevision = function() return Items:GetRevision() end,
        },
    }
    local ref, err = contracts:Register(Addon.NAME, self.serviceDefinition)
    if not ref then return nil, err end
    self.serviceRef = ref
    return true
end
function Items.Events:Register(owner, callback)
    if owner == nil or type(callback) ~= "function" then return nil, "invalid-listener" end
    for _, listener in ipairs(self.listeners) do if listener.owner == owner and listener.callback == callback then return true end end
    self.listeners[#self.listeners + 1] = { owner = owner, callback = callback }; return true
end
function Items.Events:Unregister(owner, callback)
    for index = #self.listeners, 1, -1 do
        local listener = self.listeners[index]
        if listener.owner == owner and (callback == nil or callback == listener.callback) then table.remove(self.listeners, index) end
    end
end
function Items.Events:Emit(payload)
    if Items.serviceRef then Addon.Core.Contracts:NotifyChanged(Addon.NAME, Items.serviceRef, payload) end
    local listeners = {}; for index, listener in ipairs(self.listeners) do listeners[index] = listener end
    for _, listener in ipairs(listeners) do
        local ok, err = pcall(listener.callback, "MAIL_ITEMS_CHANGED", Addon.Copy(payload))
        if not ok and geterrorhandler then geterrorhandler()(err) end
    end
end
function Items:GetState(characterID)
    if type(characterID) ~= "string" or characterID == "" then return nil, "invalid-character-id" end
    local snapshot = Addon.db and Addon.db.byCharacter[characterID]
    local result = snapshot and Addon.Copy(snapshot.coverage) or { status = "not-yet-scanned", revision = self:GetRevision() }
    -- Closed mailbox state is stale without consulting a full Core snapshot.
    -- When live/error identity is needed, read it once for this query.
    local mailboxOpen = Addon.Scanner:IsOpen()
    local current = (mailboxOpen or Addon.Scanner.lastError) and Addon.Core and Addon.Core.Characters:GetCurrent()
    if snapshot then
        local live = current and current.id == characterID and mailboxOpen and Addon.Scanner.updated
            and Addon.Scanner.validAt == snapshot.coverage.observedAt and not Addon.Scanner.lastError
        if not live then
            result.lastScanStatus = result.status
            result.status = current and current.id == characterID and Addon.Scanner.lastError and "error" or "stale"
        end
    end
    if current and current.id == characterID and Addon.Scanner.lastError then
        result.lastScanStatus, result.status = snapshot and snapshot.coverage.status or "not-yet-scanned", "error"
    end
    return result
end
local function Resolve(scope)
    local core = Addon.Core
    if not core then return {} end
    if scope == nil then local current = core.Characters:GetCurrent(); return current and { current } or {} end
    if type(scope) ~= "table" then return nil, "invalid-scope" end
    if scope.mode == "characters" then
        if type(scope.characterIDs) ~= "table" then return nil, "invalid-scope" end
        local count = 0
        for key, id in pairs(scope.characterIDs) do
            if type(key) ~= "number" or key < 1 or key % 1 ~= 0 or type(id) ~= "string" or id == "" then return nil, "invalid-scope" end
            count = count + 1
        end
        for index = 1, count do if scope.characterIDs[index] == nil then return nil, "invalid-scope" end end
        local byID, result, seen = {}, {}, {}
        for _, character in ipairs(core.Characters:GetAllCached()) do byID[character.id] = character end
        for _, id in ipairs(scope.characterIDs) do if byID[id] and not seen[id] then result[#result + 1] = byID[id]; seen[id] = true end end
        return result
    end
    if scope.mode ~= "account" and scope.mode ~= "realm" then return nil, "invalid-scope" end
    if scope.mode == "realm" and (type(scope.realm) ~= "string" or scope.realm == "") then return nil, "invalid-scope" end
    local result = {}
    for _, character in ipairs(core.AccountView:GetVisibleCharacters()) do
        if scope.mode == "account" or character.realm == scope.realm then result[#result + 1] = character end
    end
    return result
end
function Items:Query(options)
    if options ~= nil and type(options) ~= "table" then return nil, "invalid-options" end
    options = options or {}
    if options.itemID ~= nil and (type(options.itemID) ~= "number" or options.itemID <= 0 or options.itemID % 1 ~= 0) then return nil, "invalid-item-id" end
    local mode = options.identityMode
    if mode == nil then mode = "item-id" end
    if mode ~= "item-id" and mode ~= "strict" then return nil, "invalid-identity-mode" end
    if options.variantKey ~= nil and (mode ~= "strict" or type(options.variantKey) ~= "string" or options.variantKey == "") then return nil, "invalid-variant-key" end
    if options.includeStale ~= nil and type(options.includeStale) ~= "boolean" then return nil, "invalid-include-stale" end
    local characters, err = Resolve(options.scope); if not characters then return nil, err end
    local now = Addon:Now()
    local result = { apiVersion = 1, revision = self:GetRevision(), generatedAt = now, records = {}, quantity = 0, coverage = {} }
    local current = Addon.Core and Addon.Core.Characters:GetCurrent()
    for _, character in ipairs(characters) do
        result.coverage[character.id] = self:GetState(character.id)
        local snapshot = Addon.db and Addon.db.byCharacter[character.id]
        local live = current and current.id == character.id and Addon.Scanner:IsOpen() and Addon.Scanner.updated and not Addon.Scanner.lastError
            and Addon.Scanner.validAt == (snapshot and snapshot.coverage.observedAt)
        if snapshot and (live or options.includeStale ~= false) then
            for _, key in ipairs(snapshot.visibleKeys) do
                local mail = snapshot.records[key]
                for _, item in ipairs(mail and mail.attachments or {}) do
                    if (options.itemID == nil or options.itemID == item.itemID) and (options.variantKey == nil or options.variantKey == item.variantKey) then
                        local record = Addon.Copy(item)
                        record.sourceID = "mail:" .. character.id .. ":" .. key .. ":" .. item.attachmentIndex
                        record.source, record.sourceClass = "mail", "external"
                        record.characterID, record.realm, record.mailKey = character.id, character.realm, key
                        record.location = { container = "inbox", slot = mail.inboxIndex, attachmentIndex = item.attachmentIndex }
                        for _, field in ipairs({ "sender", "subject", "mailType", "expiresAtEstimate", "daysLeftAtScan", "observedAt", "clockSource" }) do record[field] = mail[field] end
                        record.state = live and "observed" or "stale"
                        result.records[#result.records + 1] = record; result.quantity = result.quantity + record.quantity
                    end
                end
            end
        end
    end
    table.sort(result.records, function(a, b) return a.sourceID < b.sourceID end)
    return result
end
function Items:GetByCharacter(characterID, options)
    if type(characterID) ~= "string" or characterID == "" then return nil, "invalid-character-id" end
    if options ~= nil and type(options) ~= "table" then return nil, "invalid-options" end
    options = Addon.Copy(options or {}); options.scope = { mode = "characters", characterIDs = { characterID } }
    return self:Query(options)
end
