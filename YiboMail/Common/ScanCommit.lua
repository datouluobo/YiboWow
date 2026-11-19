local Addon = _G.YiboMail
local Scanner = Addon.Scanner
function Scanner:CommitObservation(character, mails, visible, total, now, clock)
    -- Header days are fractional while observation time is whole seconds.
    -- Reconstructing the same expiry can jitter around adjacent letters and
    -- reorder an untouched list. Retain only a matching envelope's estimate
    -- within the clock rounding tolerance; larger corrections still apply.
    local snapshot = Addon.db.byCharacter[character.id]
    local previous = {}
    for _, key in ipairs(snapshot and snapshot.visibleKeys or {}) do
        local mail = snapshot.records[key]
        if mail then previous[mail.inboxIndex] = mail end
    end
    for _, mail in ipairs(mails) do
        local prior = previous[mail.inboxIndex]
        if prior and prior.signature == mail.signature and type(prior.expiresAtEstimate) == "number"
            and math.abs(prior.expiresAtEstimate - mail.expiresAtEstimate) <= 2 then
            mail.expiresAtEstimate = prior.expiresAtEstimate
        end
    end
    local queueRefreshed
    -- Publication callbacks invalidate consumers, while this scan owns the
    -- native presentation refresh immediately after its complete commit.
    local previousCommit = Scanner.committingObservation
    Scanner.committingObservation = true
    local committed, commitError = pcall(Addon.WithPublicationBatch, Addon, function()
        local signatures = {}; for _, mail in ipairs(mails) do signatures[#signatures + 1] = mail.signature end; table.sort(signatures)
        local fingerprint = Addon.Encode(signatures)
        Scanner.lastError, Scanner.validAt, Scanner.refreshPending = nil, now, nil
        Addon:CommitScan(character, mails, { status = visible < total and "partial" or (total == 0 and "known-empty" or "known"),
            currentCount = visible, totalCount = total, unscannedCount = total - visible, observedAt = now, clockSource = clock })
        if Addon.STABLE_INBOX_LIMIT and visible == total and total <= Addon.STABLE_INBOX_LIMIT then
            local stable = Scanner.stable
            if stable and stable.characterID == character.id and stable.fingerprint == fingerprint and stable.count == total then
                if now - stable.at >= 60 then Addon:CleanupBacklog(character.id) end
            else Scanner.stable = { characterID = character.id, fingerprint = fingerprint, count = total, at = now } end
        else Scanner.stable = nil end
        queueRefreshed = Addon.Queue and Addon.Queue:OnScan(mails, visible, total)
    end)
    Scanner.committingObservation = previousCommit
    if not committed then error(commitError, 0) end
    if Addon.Queue and Addon.Queue.notifyPending then Addon.Queue:Notify() end
    if Addon.NativeUI then
        Addon.NativeUI.deleting = nil
        if not queueRefreshed then Addon.NativeUI:Refresh(true) end
    end
end
