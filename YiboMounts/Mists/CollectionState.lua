local _, NS = ...
local State = {}
NS.CollectionState = State
NS.CLIENT_SUPPORTED = type(WOW_PROJECT_MISTS_CLASSIC) == "number" and WOW_PROJECT_ID == WOW_PROJECT_MISTS_CLASSIC

local function CurrentFaction()
    if type(UnitFactionGroup) ~= "function" then return nil end
    local faction = UnitFactionGroup("player")
    return type(faction) == "string" and faction:lower() or nil
end

local function ReadMountState(journal, mountJournalID, expectedSpellID)
    if type(mountJournalID) ~= "number" then return nil end
    local name, spellID, icon, active, usable, source, favorite, isFactionSpecific, faction, hide, isCollected = journal.GetMountInfoByID(mountJournalID)
    if type(expectedSpellID) == "number" and spellID ~= expectedSpellID then
        -- Journal IDs are client-owned and can point at a different entry on
        -- faction-specific/older clients. Never use that entry's state for
        -- the requested spell.
        return nil, spellID
    end
    -- Collection state is independent of whether the journal hides this mount
    -- for the current character. Only a confirmed opposite-faction restriction
    -- makes a negative result unsafe to label as uncollected.
    if isCollected == true then return true, spellID end
    if isFactionSpecific and type(faction) == "string" then
        local playerFaction = CurrentFaction()
        if playerFaction and faction:lower() ~= playerFaction then return nil, spellID end
    elseif isFactionSpecific and type(faction) == "number" then
        local playerFaction = CurrentFaction()
        local mountFaction = faction == 0 and "horde" or (faction == 1 and "alliance" or nil)
        if playerFaction and mountFaction and mountFaction ~= playerFaction then return nil, spellID end
    end
    if isCollected == false then return false, spellID end
    return nil, spellID
end

function State:Invalidate()
    self.index = nil
end

function State:Initialize()
    if self.frame then return end
    self.frame = CreateFrame("Frame")
    -- These events invalidate only an ephemeral ID index, never player data.
    for _, event in ipairs({ "NEW_MOUNT_ADDED", "COMPANION_UPDATE", "PLAYER_ENTERING_WORLD" }) do
        pcall(self.frame.RegisterEvent, self.frame, event)
    end
    self.frame:SetScript("OnEvent", function() self:Invalidate() end)
end

local function Index(self, journal)
    if self.journal ~= journal or self.infoAPI ~= journal.GetMountInfoByID or self.idsAPI ~= journal.GetMountIDs then
        self.index = nil
        self.journal, self.infoAPI, self.idsAPI = journal, journal.GetMountInfoByID, journal.GetMountIDs
    end
    if self.index then return self.index end
    local index, complete = {}, true
    for _, candidateID in ipairs(journal.GetMountIDs()) do
        local state, candidateSpell = ReadMountState(journal, candidateID)
        if type(candidateSpell) == "number" then
            local entries = index[candidateSpell] or {}
            index[candidateSpell] = entries
            entries[#entries + 1] = candidateID
        else complete = false end
    end
    -- A partially populated journal must be retried on the next tooltip.
    if complete and next(index) then self.index = index end
    return index
end

function State:Get(record, spellID)
    if not NS.CLIENT_SUPPORTED then return nil end
    if not (NS.CoreIntegration and NS.CoreIntegration:IsCollectionStatusAvailable()) then return nil end
    local mountJournalID = record and record.ids and record.ids.mountJournalID
    if type(record) ~= "table" then return nil end
    if not (C_MountJournal and type(C_MountJournal.GetMountInfoByID) == "function") then return nil end
    self:Initialize()
    local journal = C_MountJournal
    local collected = ReadMountState(journal, mountJournalID, spellID)
    if collected == true then return true end
    local foundUncollected = collected == false

    -- Do not trust a stale catalog journal ID. Re-resolve by spellID against
    -- the current character's journal, which is especially important when
    -- testing an account-owned mount from the opposing faction.
    if type(spellID) ~= "number" or type(journal.GetMountIDs) ~= "function" then
        if foundUncollected then return false end
        return nil
    end
    for _, candidateID in ipairs(Index(self, journal)[spellID] or {}) do
        local state = ReadMountState(journal, candidateID, spellID)
        if state == true then return true end
        if state == false then foundUncollected = true end
    end
    if foundUncollected then return false end
    return nil
end

