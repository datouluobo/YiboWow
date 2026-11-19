local Addon = _G.YiboMail
local Scanner = Addon.Scanner
function Scanner:PublishStatus(characterID)
    if not characterID or not Addon.db then return end
    local status = Addon.Items:GetState(characterID).status
    local previous = self.publishedStatus[characterID] or (Addon.db.byCharacter[characterID] and "stale" or "not-yet-scanned")
    if previous ~= status then
        self.publishedStatus[characterID] = status
        Addon:Publish(characterID, {}, {}, "scan", true)
    end
end
function Scanner:BeginCollection()
    self:CancelRead()
    self.refreshPending = self.validAt ~= nil or self.refreshPending
    self.validAt, self.stable, self.scheduledScan = nil, nil, nil
    self.generation = (self.generation or 0) + 1
    local current = Addon.Core.Characters:GetCurrent({ identityOnly = true })
    self:PublishStatus(current and current.id)
end
function Scanner:CommitCollection(mails, visible, total, fullRead)
    local current = Addon.Core.Characters:GetCurrent({ identityOnly = true })
    local snapshot = current and Addon.db.byCharacter[current.id]
    if not snapshot then return end
    self.validAt, self.refreshPending = nil, true
    -- This is an observed action delta, not a fresh full-inbox sample. Keep
    -- the last full scan time and public stale status until final reconciliation.
    local coverage = Addon.Copy(snapshot.coverage)
    if fullRead then coverage.observedAt, coverage.clockSource = Addon:Now() end
    coverage.currentCount, coverage.totalCount, coverage.unscannedCount = visible, total, total - visible
    coverage.status = visible < total and "partial" or (total == 0 and "known-empty" or "known")
    Addon:CommitScan(current, mails, coverage)
    self.publishedStatus[current.id] = "stale"
end
