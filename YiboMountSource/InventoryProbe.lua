local _, NS = ...

NS.InventoryProbe = {}

local function GetMountJournal()
    return C_MountJournal and C_MountJournal.GetMountIDs and C_MountJournal.GetMountInfoByID and C_MountJournal
end

function NS.InventoryProbe:Capture()
    local journal = GetMountJournal()
    if not journal then
        return nil, "Mount Journal API is unavailable on this client."
    end

    local records = {}
    local seenSpellIDs = {}
    for _, mountJournalID in ipairs(journal.GetMountIDs()) do
        local name, spellID, icon, isActive, isUsable, sourceType, isFavorite,
            isFactionSpecific, faction, shouldHideOnChar, isCollected, mountType = journal.GetMountInfoByID(mountJournalID)
        local description, sourceText
        if journal.GetMountInfoExtraByID then
            -- The game client owns these localized fields.  They are captured
            -- only for the offline catalog builder, never queried at tooltip time.
            local ignored
            ignored, description, sourceText = journal.GetMountInfoExtraByID(mountJournalID)
        end
        if type(spellID) == "number" and not seenSpellIDs[spellID] then
            seenSpellIDs[spellID] = true
            records[#records + 1] = {
                mountJournalID = mountJournalID,
                spellID = spellID,
                icon = icon,
                name = name,
                isActive = isActive,
                isUsable = isUsable,
                sourceType = sourceType,
                isFavorite = isFavorite,
                isFactionSpecific = isFactionSpecific,
                faction = faction,
                shouldHideOnChar = shouldHideOnChar,
                isCollected = isCollected,
                mountType = mountType,
                description = type(description) == "string" and description or nil,
                sourceText = type(sourceText) == "string" and sourceText or nil,
            }
        end
    end
    table.sort(records, function(left, right) return left.spellID < right.spellID end)

    local covered, visibleTotal, visibleCovered = 0, 0, 0
    for _, record in ipairs(records) do
        local isCovered = NS.Catalog:GetBySpellID(record.spellID) ~= nil
        if isCovered then covered = covered + 1 end
        if not record.shouldHideOnChar then
            visibleTotal = visibleTotal + 1
            if isCovered then visibleCovered = visibleCovered + 1 end
        end
    end

    YiboMountSourceDiagnostics = YiboMountSourceDiagnostics or {}
    YiboMountSourceDiagnostics.mountInventory = {
        capturedAt = date("!%Y-%m-%dT%H:%M:%SZ"),
        build = select(4, GetBuildInfo()),
        rawTotal = #records,
        rawCovered = covered,
        visibleTotal = visibleTotal,
        visibleCovered = visibleCovered,
        mounts = records,
    }
    return YiboMountSourceDiagnostics.mountInventory
end

function NS.InventoryProbe:PrintCapture()
    local snapshot, errorMessage = self:Capture()
    if not snapshot then
        NS.Probe.Print(errorMessage)
        return
    end
    NS.Probe.Print("inventory saved: raw " .. snapshot.rawCovered .. "/" .. snapshot.rawTotal .. " (catalog baseline); visible " .. snapshot.visibleCovered .. "/" .. snapshot.visibleTotal .. " (character diagnostic)")
    NS.Probe.Print("exit the game once, then share the YiboMountSourceDiagnostics SavedVariables file for catalog import")
end
