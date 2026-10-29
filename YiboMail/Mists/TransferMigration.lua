local Addon = _G.YiboMail
-- Vault 1.2.1 / Mail 1.2.7 introduced receipt correlation at this release.
-- Older successful-send history has no guaranteed receipt tracking baseline.
local TRACKING_STARTED_AT = 1791784788 -- 2026-10-12 13:59:48 Asia/Shanghai

function Addon.Items:MigrateLegacyTransfers()
    if Addon.db.transferTrackingMigrationVersion == 1 then return true end
    local reviewNeeded = false
    for _, snapshot in pairs(Addon.db.byCharacter) do
        for _, history in ipairs(snapshot.history or {}) do
            local sentAt = tonumber(history.observedAt or history.attemptedAt)
            if history.state == "in-transit" and (not sentAt or sentAt < TRACKING_STARTED_AT) then reviewNeeded = true; break end
        end
        if reviewNeeded then break end
    end
    if not reviewNeeded then Addon.db.transferTrackingMigrationVersion = 1; return true end
    local pending = {}
    for _, character in ipairs(Addon.Core.Characters:GetAllCached({ identityOnly = true })) do
        local result, err = self:GetTransfers(character.id)
        if not result then return nil, err end
        for _, record in ipairs(result.records) do pending[record.sourceID] = true end
    end
    local changes = {}
    local now = Addon:Now()
    for characterID, snapshot in pairs(Addon.db.byCharacter) do
        local ids = {}
        for _, history in ipairs(snapshot.history or {}) do
            local sentAt = tonumber(history.observedAt or history.attemptedAt)
            if history.state == "in-transit" and (not sentAt or sentAt < TRACKING_STARTED_AT) then
                local unresolved = false
                for index in ipairs(history.attachments or {}) do
                    local sourceID = "mail-transit:" .. characterID .. ":" .. tostring(history.eventID or sentAt or 0) .. ":" .. index
                    if pending[sourceID] then unresolved = true; break end
                end
                if unresolved then
                    history.transferReview = "legacy-unverified"
                    history.transferReviewedAt = now
                    for _, item in ipairs(history.attachments) do ids[item.itemID] = true end
                end
            end
        end
        if next(ids) then
            local itemIDs = {}; for id in pairs(ids) do itemIDs[#itemIDs + 1] = id end
            changes[#changes + 1] = { characterID = characterID, itemIDs = itemIDs }
        end
    end
    Addon.db.transferTrackingMigrationVersion = 1
    for _, change in ipairs(changes) do Addon:Publish(change.characterID, {}, change.itemIDs, "cleanup") end
    return true
end
