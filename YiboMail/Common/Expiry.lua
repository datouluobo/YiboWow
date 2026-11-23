local Addon = _G.YiboMail
local Expiry = {}; Addon.Expiry = Expiry
local DAY, DELIVERY_WINDOW = 86400, 3600
local MAIL_LIFETIME, COD_LIFETIME = 30 * DAY, 3 * DAY
local AUCTION_RECEIPT_RETENTION = 90 * DAY

local function Entries(snapshot)
    snapshot.expiryEntries = snapshot.expiryEntries or {}
    return snapshot.expiryEntries
end

local function AddressKey(value, realm)
    local address = Addon.Recipients:Normalize(value, realm)
    return address and Addon.Recipients:Key(address)
end

local function FindRecipient(value, realm)
    local key = AddressKey(value, realm)
    if not key then return end
    for _, character in ipairs(Addon.Core.Characters:GetAllCached({ identityOnly = true })) do
        if AddressKey(character.name, character.realm) == key then return character end
    end
end

local function AttachmentsKey(attachments)
    local keys = {}
    for _, item in ipairs(attachments) do
        if not item.itemID and not item.currencyID then return end
        keys[#keys + 1] = Addon.Encode({ item.currencyID and "currency" or "item", item.currencyID or item.itemID, item.quantity })
    end
    table.sort(keys)
    return Addon.Encode(keys)
end

local function EnvelopeKey(subject, money, cod, attachments)
    local items = AttachmentsKey(attachments)
    return items and Addon.Encode({ subject or "", money, cod, items })
end

function Expiry:TrackSend(sender, send, now, backfill)
    if not sender or not sender.name or not sender.realm or send.transferReview == "legacy-unverified"
        or type(send.eventID) ~= "string" or type(send.observedAt) ~= "number" or send.observedAt <= 0 or send.observedAt > now
        or (send.clockSource ~= "server" and not (backfill and send.clockSource == nil)) then return end
    local copper = tonumber(send.copper) or 0
    local cod = send.cod == true or send.cod == 1
    local money, charge = cod and 0 or copper, cod and copper or 0
    local deadline = send.observedAt + (charge > 0 and COD_LIFETIME or MAIL_LIFETIME)
    if now >= deadline + Addon.db.settings.unverifiedDays * DAY then return end
    local envelope = EnvelopeKey(send.subject, money, charge, send.attachments or {})
    if not envelope then return end
    local recipient = FindRecipient(send.recipient, sender.realm)
    if not recipient then return end
    local snapshot = Addon.db.byCharacter[recipient.id]
    -- Existing history can seed the clock when neither participant has a later
    -- scan. This avoids recreating letters already received before the upgrade.
    if backfill then
        local senderSnapshot = Addon.db.byCharacter[sender.id]
        if (snapshot and (snapshot.coverage.observedAt or 0) >= send.observedAt)
            or (senderSnapshot.coverage.observedAt or 0) > send.observedAt then return end
    end
    snapshot = snapshot or Addon:GetOrCreateMailSnapshot(recipient.id, recipient)
    Entries(snapshot)["send:" .. send.eventID] = {
        expirySource = "send", senderID = sender.id, senderKey = AddressKey(sender.name, sender.realm),
        sender = sender.name .. "-" .. sender.realm, subject = send.subject or "", observedAt = send.observedAt,
        arrivesAt = send.observedAt, expiresAtEstimate = deadline, envelope = envelope,
        money = money, cod = charge, attachments = send.attachments or {},
        returnEnvelope = charge > 0 and EnvelopeKey(send.subject, 0, 0, send.attachments or {}) or envelope,
    }
end

function Expiry:Seed()
    if Addon.db.expiryForecastsSeeded then return end
    local now, clock = Addon:Now()
    if clock ~= "server" then return end
    for _, character in ipairs(Addon.Core.Characters:GetAllCached({ identityOnly = true })) do
        local snapshot = Addon.db.byCharacter[character.id]
        for _, send in ipairs(snapshot and snapshot.history or {}) do
            if send.state == "in-transit" then self:TrackSend(character, send, now, true) end
        end
    end
    Addon.db.expiryForecastsSeeded = true
end

function Expiry:OnHistory(snapshot, record)
    if record.state == "in-transit" then
        self:TrackSend(Addon.Core.Characters:Get(record.characterID, { identityOnly = true }), record, record.observedAt)
    elseif record.state == "collected-archived" or record.state == "returned-archived" then
        self:ConfirmRemoval(snapshot, record.sourceMailKey)
    end
end

function Expiry:ConfirmRemoval(snapshot, mailKey)
    if snapshot.expiryEntries and mailKey then snapshot.expiryEntries["missing:" .. mailKey] = nil end
end

function Expiry:Prune(snapshot, now)
    local days = Addon.db.settings.unverifiedDays * DAY
    for key, entry in pairs(snapshot.expiryEntries or {}) do
        if entry.expirySource == "auction" or now >= entry.expiresAtEstimate + days then snapshot.expiryEntries[key] = nil end
    end
    local receiptsByItem = snapshot.auctionExpiryReceipts or {}
    for item, receipts in pairs(receiptsByItem) do
        for index = #receipts, 1, -1 do
            if now >= receipts[index].observedAt + AUCTION_RECEIPT_RETENTION then table.remove(receipts, index) end
        end
        if #receipts == 0 then receiptsByItem[item] = nil end
    end
end

local function RemoveMatch(entries, predicate)
    local bestKey, best
    for key, entry in pairs(entries or {}) do
        if predicate(entry) and (not best or entry.observedAt < best.observedAt
            or (entry.observedAt == best.observedAt and key < bestKey)) then
            best, bestKey = entry, key
        end
    end
    if bestKey then entries[bestKey] = nil end
    return best
end

local function ReconcileForecasts(snapshot, character, mail, now)
    if mail.auctionMail then return end
    local sender = AddressKey(mail.sender, character.realm)
    if not sender then return end
    local envelope = EnvelopeKey(mail.subject, mail.money or 0, mail.cod or 0, mail.attachments or {})
    if not envelope then return end
    if mail.wasReturned then
        local recipient = FindRecipient(mail.sender, character.realm)
        local remote = recipient and Addon.db.byCharacter[recipient.id]
        return RemoveMatch(remote and remote.expiryEntries, function(entry)
            return entry.expirySource == "send" and entry.senderID == character.id and entry.returnEnvelope == envelope and entry.arrivesAt <= now
        end)
    else
        return RemoveMatch(snapshot.expiryEntries, function(entry)
            return entry.expirySource == "send" and entry.senderKey == sender and entry.envelope == envelope and entry.arrivesAt <= now
        end)
    end
end

local function RememberAuctionReceipts(snapshot, mails, now)
    local seen = {}
    for _, mail in ipairs(mails) do
        local item = mail.auctionMail and #mail.attachments == 1 and mail.attachments[1]
        if item and item.itemID and Addon:MatchesMailSubject(mail.subject, _G.AUCTION_EXPIRED_MAIL_SUBJECT) then
            local byItem = snapshot.auctionExpiryReceipts or {}
            snapshot.auctionExpiryReceipts = byItem
            local itemKey = Addon.Encode({ item.itemID, item.quantity })
            local receipts = byItem[itemKey] or {}; byItem[itemKey] = receipts
            local match
            for _, receipt in ipairs(receipts) do
                if math.abs(receipt.expiresAt - mail.expiresAtEstimate) <= 2 then match = receipt; break end
            end
            if not match then
                match = { expiresAt = mail.expiresAtEstimate, observedAt = now, count = 0 }
                receipts[#receipts + 1] = match
            end
            seen[match] = (seen[match] or 0) + 1
            match.count = math.max(match.count, seen[match])
        end
    end
end

function Expiry:OnScan(snapshot, character, mails, coverage)
    local now, complete = coverage.observedAt, coverage.status ~= "partial"
    local moneyChanged = false
    self:Prune(snapshot, now)
    if coverage.clockSource == "server" then RememberAuctionReceipts(snapshot, mails, now) end
    local previousBySignature = {}
    for _, key in ipairs(snapshot.visibleKeys) do
        local prior = snapshot.records[key]
        previousBySignature[prior.signature] = (previousBySignature[prior.signature] or 0) + 1
    end
    local remaining = {}
    for _, mail in ipairs(mails) do
        remaining[mail.signature] = (remaining[mail.signature] or 0) + 1
        if remaining[mail.signature] > (previousBySignature[mail.signature] or 0) then
            RemoveMatch(snapshot.expiryEntries, function(entry)
                return entry.expirySource == "missing" and entry.signature == mail.signature
                    and math.abs(entry.expiresAtEstimate - mail.expiresAtEstimate) <= 2
            end)
            if snapshot.expiryEntries or mail.wasReturned then
                local matched = ReconcileForecasts(snapshot, character, mail, now)
                if matched and matched.money > 0 then moneyChanged = true end
            end
        end
    end
    for _, key in ipairs(snapshot.visibleKeys) do
        local prior = snapshot.records[key]
        local count = remaining[prior.signature] or 0
        local deadline = tonumber(prior.expiresAtEstimate)
        if count > 0 then
            remaining[prior.signature] = count - 1
        elseif deadline and deadline > 0 and (not complete or deadline <= now)
            and (not prior.clockSource or prior.clockSource == coverage.clockSource) then
            local entry = Addon.Copy(prior)
            entry.expirySource = "missing"
            Entries(snapshot)["missing:" .. key] = entry
        end
    end
    if complete then
        for key, entry in pairs(snapshot.expiryEntries or {}) do
            if entry.expiresAtEstimate and now < entry.expiresAtEstimate
                and (entry.expirySource == "missing" or now >= entry.arrivesAt + DELIVERY_WINDOW) then
                snapshot.expiryEntries[key] = nil
                if entry.expirySource == "send" and entry.money > 0 then moneyChanged = true end
            end
        end
    end
    return moneyChanged
end

function Expiry:ReadAuctionTimings(characters)
    if #characters == 0 then return end
    local contracts = Addon.Core.Contracts
    if type(contracts.Resolve) ~= "function" or type(contracts.Call) ~= "function" then return end
    local descriptor = contracts:Resolve("vault.items", { major = 1, minMinor = 2 })
    if not descriptor then return end
    local ids = {}
    for index, character in ipairs(characters) do ids[index] = character.id end
    local result = contracts:Call(Addon.NAME, descriptor, "GetAuctionTimings", { scope = { mode = "characters", characterIDs = ids } })
    return result and result.byCharacter
end

function Expiry:WatchAuctionTimings()
    local core = Addon.Core
    if not core.Events then return end
    local function Changed(descriptor, change)
        if descriptor.name == "vault.items"
            and (type(change) ~= "table" or change.reason == "auction-timing" or (change.source == "auction" and change.reason == "cleanup")) then
            core.AccountView:NotifyPageChanged("mail-inbox")
        end
    end
    for _, event in ipairs({ "BUSINESS_CONTRACT_REGISTERED", "BUSINESS_CONTRACT_UNREGISTERED", "BUSINESS_CONTRACT_CHANGED" }) do
        core.Events:Register(event, self, Changed)
    end
end

local function MatchAuctionReceipt(receipts, used, auction)
    local best, distance
    for _, receipt in ipairs(receipts or {}) do
        if (used[receipt] or 0) < receipt.count then
            local delta = math.abs(receipt.expiresAt - (auction.endedAt + MAIL_LIFETIME))
            local seenAfter = receipt.observedAt - auction.endedAt
            if seenAfter >= -60 and (delta <= DELIVERY_WINDOW or (seenAfter >= 0 and seenAfter <= DELIVERY_WINDOW))
                and (not distance or delta < distance) then
                best, distance = receipt, delta
            end
        end
    end
    if best then used[best] = (used[best] or 0) + 1 end
    return best
end

function Expiry:GetPreview(characterID, auctions, now)
    local snapshot = Addon.db.byCharacter[characterID]
    local times = {}
    local preview = { times = times, transitCopper = 0 }
    local grace = Addon.db.settings.unverifiedDays * DAY
    local function Include(kind, deadline)
        local remaining = deadline - now
        if remaining > -grace and (not times[kind] or remaining < times[kind]) then times[kind] = remaining end
    end
    for _, entry in pairs(snapshot and snapshot.expiryEntries or {}) do
        local kind, deadline = entry.expirySource, entry.expiresAtEstimate
        if kind == "send" or kind == "missing" then Include(kind, deadline) end
        if kind == "send" and deadline > now then
            preview.transitCopper = preview.transitCopper + (entry.money or 0)
        end
    end
    if not auctions or #auctions.records == 0 then return preview end
    local receipts, used = snapshot and snapshot.auctionExpiryReceipts or {}, {}
    -- Sort the private contract result's projection, so identical lots consume receipts once.
    local records = {}
    for index, record in ipairs(auctions.records) do records[index] = record end
    table.sort(records, function(a, b)
        local at, bt = a.endedAt or a.endsAt, b.endedAt or b.endsAt
        if at ~= bt then return at < bt end
        return a.auctionID < b.auctionID
    end)
    for _, auction in ipairs(records) do
        if auction.status == "expired" then
            local itemKey = Addon.Encode({ auction.itemID, auction.quantity })
            if not MatchAuctionReceipt(receipts[itemKey], used, auction) then Include("auction", auction.endedAt + MAIL_LIFETIME) end
        elseif auction.status == "active" and auction.endsAt > now then
            Include("listing", auction.endsAt + MAIL_LIFETIME)
        end
    end
    return preview
end

function Expiry:FormatDuration(seconds)
    if seconds > 0 then
        return Addon:T(seconds < DAY and "UI.TEXT_0485" or "UI.TEXT_0484", seconds / (seconds < DAY and 3600 or DAY))
    end
    if seconds == 0 then return Addon:T("UI.TEXT_0057", 0) end
    if seconds > -3600 then return Addon:T("EXPIRY.OVERDUE_MINUTES", math.max(1, math.floor(-seconds / 60))) end
    return Addon:T(seconds > -DAY and "EXPIRY.OVERDUE_HOURS" or "EXPIRY.OVERDUE_DAYS", seconds > -DAY and -seconds / 3600 or -seconds / DAY)
end
