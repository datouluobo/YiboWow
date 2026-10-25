local Addon = _G.YiboVault

local function Read(fn, ...)
    if type(fn) ~= "function" then error("api-unavailable") end
    local ok, value = pcall(fn, ...)
    if not ok then error("api-read-failed") end
    if type(issecretvalue) == "function" and issecretvalue(value) then error("restricted-value") end
    return value
end
local function Number(value, minimum, maximum)
    if type(issecretvalue) == "function" and issecretvalue(value) then error("restricted-value") end
    if type(value) ~= "number" or value ~= math.floor(value) or value < minimum or value > maximum then
        error("invalid-numeric-value")
    end
    return value
end
function Addon:GetBagIDs()
    local ids = { 0, 1, 2, 3, 4 }
    local reagent = Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag
    if type(reagent) == "number" and reagent == 5 then ids[#ids + 1] = reagent end
    return ids
end

function Addon:InitializeDatabase()
    local name = self.Target.savedVariable
    local db = _G[name]
    if db ~= nil and type(db) ~= "table" then return nil, self:T("FOREVER.STORE_MISMATCH") end
    db = db or {}
    if db.schemaVersion ~= nil and db.schemaVersion ~= self.SCHEMA_VERSION then return nil, self:T("FOREVER.STORE_MISMATCH") end
    if db.clientScope and (type(db.clientScope) ~= "table" or db.clientScope.target ~= "Forever"
        or db.clientScope.projectID ~= WOW_PROJECT_ID or db.clientScope.scope ~= "current-character") then
        return nil, self:T("FOREVER.STORE_MISMATCH")
    end
    for _, field in ipairs({ "byCharacter", "byGuild", "settings" }) do
        if db[field] ~= nil and type(db[field]) ~= "table" then return nil, self:T("FOREVER.STORE_MISMATCH") end
    end
    db.schemaVersion, db.revision = self.SCHEMA_VERSION, tonumber(db.revision) or 0
    db.byCharacter, db.byGuild, db.settings = db.byCharacter or {}, db.byGuild or {}, db.settings or {}
    db.clientScope = { target = "Forever", projectID = WOW_PROJECT_ID, scope = "current-character", rulesetState = "unknown" }
    db.settings.previewColumns = db.settings.previewColumns or { item = true, location = true, quantity = true }
    if db.settings.foreverSource ~= "equipment" and db.settings.foreverSource ~= "bank" and db.settings.foreverSource ~= "mail" and db.settings.foreverSource ~= "auction" and db.settings.foreverSource ~= "guild-bank" then db.settings.foreverSource = "bags" end
    for _, character in pairs(db.byCharacter) do
        for _, source in ipairs({ "bags", "equipment", "bank", "mail", "auction" }) do
            for _, state in pairs(character.coverage and character.coverage[source] or {}) do
                if state.completedScan then state.status = "stale" end
            end
        end
    end
    for _, guild in pairs(db.byGuild) do
        for _, state in pairs(guild.coverage or {}) do if state.completedScan then state.status = "stale" end end
    end
    _G[name], self.db = db, db
    self._dirtyBags, self._dirtyBank, self._ready = {}, {}, {}
    return true
end

local function Current()
    local character = Addon.Core.Characters:GetCurrent({ identityOnly = true })
    if not character then error("current-character-unavailable") end
    return character
end
local function StageContainers(source, ids)
    local character, staged, total = Current(), {}, 0
    for _, bag in ipairs(ids) do
        local count = Number(Read(C_Container and C_Container.GetContainerNumSlots, bag), (source == "bank" and #staged == 0 or bag == 0) and 1 or 0, 200)
        local records = {}
        for slot = 1, count do
            local info = Read(C_Container and C_Container.GetContainerItemInfo, bag, slot)
            if info ~= nil then
                if type(info) ~= "table" then error("invalid-container-info") end
                local id = Number(info.itemID, 1, 2147483647)
                local quantity = Number(info.stackCount, 1, 2147483647)
                local link = info.hyperlink
                if type(issecretvalue) == "function" and issecretvalue(link) then error("restricted-link") end
                if link ~= nil and type(link) ~= "string" then error("invalid-link") end
                records[#records + 1] = Addon.BuildItemRecord(source, character, bag, slot, id, quantity, link)
            end
        end
        local capacity = { totalSlots = count }
        if C_Container and type(C_Container.GetContainerNumFreeSlots) == "function" and count > 0 then
            capacity.freeSlots = Number(Read(C_Container.GetContainerNumFreeSlots, bag), 0, count)
            if capacity.freeSlots + #records ~= count then error("container-data-incomplete") end
        end
        total = total + #records
        staged[#staged + 1] = { key = tostring(bag), records = records, location = { bagID = bag }, capacity = capacity }
    end
    if source == "bags" and total == 0 and not Addon._ready.bags then return nil, "awaiting-bag-data" end
    if source == "bank" and total == 0 and not Addon._ready.bank then return nil, "awaiting-bank-data" end
    return staged, nil, character
end
local function StageBags() return StageContainers("bags", Addon:GetBagIDs()) end
local function StageBank()
    local bankType = Enum and Enum.BankType and Enum.BankType.Character
    if type(bankType) ~= "number" then error("bank-api-unavailable") end
    if Read(C_Bank and C_Bank.CanViewBank, bankType) ~= true then return nil, "bank-not-viewable" end
    local tabs = Read(C_Bank and C_Bank.FetchPurchasedBankTabData, bankType)
    local count = Number(Read(C_Bank and C_Bank.FetchNumPurchasedBankTabs, bankType), 0, 100)
    if type(tabs) ~= "table" or #tabs ~= count then error("incomplete-bank-tabs") end
    -- A first free tab can still be initializing; no tabs is not an empty bank.
    if count == 0 then return nil, "awaiting-bank-tabs" end
    local allowed, ids, seen = {}, {}, {}
    for key, id in pairs(Enum.BagIndex or {}) do
        if type(key) == "string" and key:match("^CharacterBankTab_%d+$") then allowed[Number(id, 1, 1000)] = true end
    end
    for _, tab in ipairs(tabs) do
        if type(tab) ~= "table" then error("invalid-bank-tab") end
        local id = Number(tab.ID, 1, 1000)
        if tab.bankType ~= bankType or not allowed[id] or seen[id] then error("invalid-character-bank-tab") end
        seen[id], ids[#ids + 1] = true, id
    end
    table.sort(ids)
    local staged, reason, character = StageContainers("bank", ids)
    -- Recheck access and tab identity before replacing any saved location.
    if not Addon._bankOpen or Read(C_Bank.CanViewBank, bankType) ~= true then return nil, "bank-closed" end
    local after = Read(C_Bank.FetchPurchasedBankTabData, bankType)
    if type(after) ~= "table" or #after ~= #tabs then error("bank-tabs-changed") end
    for _, tab in ipairs(after) do
        if type(tab) ~= "table" or tab.bankType ~= bankType or not seen[tab.ID] then error("bank-tabs-changed") end
        seen[tab.ID] = nil
    end
    return staged, reason, character
end
local function StageEquipment()
    local character, records = Current(), {}
    for slot = 1, 19 do
        local id = Read(GetInventoryItemID, "player", slot)
        if id ~= nil then
            Number(id, 1, 2147483647)
            local link
            if type(GetInventoryItemLink) == "function" then link = Read(GetInventoryItemLink, "player", slot) end
            if link ~= nil and type(link) ~= "string" then error("invalid-link") end
            records[#records + 1] = Addon.BuildItemRecord("equipment", character, "equipment", slot, id, 1, link)
        end
    end
    if #records == 0 and not Addon._ready.equipment then return nil, "awaiting-equipment-data" end
    return { { key = "equipment", records = records, location = { firstSlot = 1, lastSlot = 19 } } }, nil, character
end
local function Scan(source, stage)
    if not Addon._inWorld then return nil, "not-in-world" end
    local ok, staged, reason, character = pcall(stage)
    if not ok then
        local current = Addon.Core.Characters:GetCurrent()
        if current then
            for key in pairs(Addon:GetCharacterCoverage(current.id, source)) do Addon:MarkLocationStale(current.id, source, key) end
        end
        Addon:MarkLocationError(source, source == "equipment" and "equipment" or "scan", {}, tostring(staged))
        return nil, "read-failed"
    end
    if not staged then return nil, reason end
    if source == "bank" then
        local active = {}
        for _, item in ipairs(staged) do active[item.key] = true end
        for key in pairs(Addon:GetCharacterCoverage(character.id, "bank")) do
            if key ~= "scan" and not active[key] then Addon:MarkLocationStale(character.id, "bank", key) end
        end
    end
    for _, item in ipairs(staged) do
        Addon:ReplaceLocation(character.id, source, item.key, item.records, item.location, item.capacity)
    end
    -- The source-level failure marker is removed only after a complete recovery.
    if source ~= "equipment" then
        local coverage = Addon:GetCharacterStore(character.id).coverage[source]
        if coverage.scan then coverage.scan = nil; Addon:NotifyLocationStatusChanged(source, character.id, select(1, Addon:Now())) end
    end
    return true
end
function Addon:ScanBags() local ok, reason = Scan("bags", StageBags); return ok and 1 or 0, ok and 0 or 1, reason end
function Addon:ScanBank()
    if not self._bankOpen then return nil, "bank-closed" end
    local ok, reason = Scan("bank", StageBank)
    if not ok and reason ~= "read-failed" then
        local current = self.Core.Characters:GetCurrentID()
        if current then
            for key in pairs(self:GetCharacterCoverage(current, "bank")) do self:MarkLocationStale(current, "bank", key) end
        end
    end
    return ok, reason
end
function Addon:ScanEquipment() return Scan("equipment", StageEquipment) end
function Addon:ScanInitial(reason)
    if not self.initialized or not self._inWorld then return nil, "not-ready" end
    if type(GetTime) == "function" and GetTime() < (self._notBefore or 0) then return nil, "awaiting-world-data" end
    if reason == "manual" then
        self._ready.bags, self._ready.equipment = true, true
        if self._bankOpen then self._ready.bank = true end
        if self:IsMailboxReadable() then self._ready.mail = true end
        if self:IsAuctionReadable() then self:RequestOwnedAuctions() end
        if self:IsGuildBankReadable() then self:RequestCurrentGuildTab(true) end
    end
    local _, failed = self:ScanBags()
    local equipment = self:ScanEquipment()
    local bank = not self._bankOpen or self:ScanBank()
    local mail = not self._mailOpen or self:ScanMail()
    local auction = not self._auctionOpen or self:ScanAuctions()
    local guild = not self._guildBankOpen or self:ScanGuildBank()
    return failed == 0 and equipment == true and bank == true and mail == true and auction == true and guild == true
end
function Addon:QueueScan(delay)
    if self._scanQueued then return end
    self._scanQueued = true
    local token = self._scanToken
    local function Run()
        if self._scanToken ~= token then return end
        self._scanQueued = nil
        if self._inWorld and self._scanToken == token then self:ScanInitial("event") end
    end
    if C_Timer and type(C_Timer.After) == "function" then C_Timer.After(delay or 0.1, Run) else Run() end
end
function Addon:CloseBank()
    self._bankOpen = false
    if self._ready then self._ready.bank = nil end
    local current = self.Core.Characters:GetCurrentID()
    if current then
        for key in pairs(self:GetCharacterCoverage(current, "bank")) do self:MarkLocationStale(current, "bank", key) end
    end
    self.Core.AccountView:NotifyPageChanged("vault-items")
end
function Addon:OnEvent(event, unit)
    if event == "PLAYER_ENTERING_WORLD" then
        self:CloseBank(); self:CloseMail(); self:CloseAuctions(); self:CloseGuildBank()
        self._inWorld, self._ready = true, {}
        self._notBefore = (type(GetTime) == "function" and GetTime() or 0) + 3
        self._scanToken, self._scanQueued = (self._scanToken or 0) + 1, nil
        local character = self.Core.Characters:GetCurrent()
        if character then
            for _, source in ipairs({ "bags", "equipment", "bank", "mail", "auction" }) do
                for key in pairs(self:GetCharacterCoverage(character.id, source)) do self:MarkLocationStale(character.id, source, key) end
            end
        end
        self:QueueScan(3)
    elseif event == "PLAYER_LEAVING_WORLD" or event == "PLAYER_LOGOUT" then
        self:CloseBank(); self:CloseMail(); self:CloseAuctions(); self:CloseGuildBank()
        self._inWorld = false; self._scanToken = (self._scanToken or 0) + 1; self._scanQueued = nil
    elseif event == "GUILDBANKFRAME_OPENED" and self._inWorld then
        self._guildBankOpen = true
        self._guildBankToken = (self._guildBankToken or 0) + 1
        local token = self._guildBankToken
        local function Request() if self._guildBankOpen and self._guildBankToken == token then self:RequestCurrentGuildTab(false) end end
        if C_Timer and C_Timer.After then C_Timer.After(0.2, Request) else Request() end
        self.Core.AccountView:NotifyPageChanged("vault-items")
    elseif event == "GUILDBANKFRAME_CLOSED" or (event == "PLAYER_GUILD_UPDATE" and (unit == nil or unit == "player")) then
        self:CloseGuildBank()
    elseif event == "GUILDBANKBAGSLOTS_CHANGED" then
        self:GuildBankSlotsChanged()
    elseif (event == "GUILDBANK_UPDATE_TABS" or event == "GUILD_ROSTER_UPDATE") and self._guildBankOpen then
        self:GuildBankPermissionsChanged()
    elseif event == "AUCTION_HOUSE_SHOW" and self._inWorld then
        self:OpenAuctions()
    elseif event == "AUCTION_HOUSE_CLOSED" then
        self:CloseAuctions()
    elseif event == "OWNED_AUCTIONS_UPDATED" and self._auctionOpen then
        self._ready.auction = true
        self._auctionResultsRevision = (self._auctionResultsRevision or 0) + 1
        self:QueueScan(0.2)
    elseif event == "AUCTION_HOUSE_THROTTLED_SYSTEM_READY" and self._auctionOpen
        and self._auctionQueryWaiting and self._auctionPendingReason == "auction-throttled" then
        self:RequestOwnedAuctions()
    elseif event == "MAIL_SHOW" and self._inWorld then
        self._mailOpen, self._mailPendingReason, self._ready.mail = true, nil, nil
        self:QueueScan(0.3)
        self.Core.AccountView:NotifyPageChanged("vault-items")
    elseif event == "MAIL_CLOSED" then
        self:CloseMail()
    elseif event == "MAIL_INBOX_UPDATE" and self._mailOpen then
        self._ready.mail = true; self:QueueScan(0.2)
    elseif event == "BANKFRAME_OPENED" and self._inWorld then
        self._ready.bank = nil
        self._bankOpen = true; self:QueueScan(0.3)
        self.Core.AccountView:NotifyPageChanged("vault-items")
    elseif event == "BANKFRAME_CLOSED" then
        self:CloseBank()
    elseif (event == "PLAYERBANKSLOTS_CHANGED" or event == "BAG_CONTAINER_UPDATE"
        or (event == "BANK_TABS_CHANGED" and unit == (Enum and Enum.BankType and Enum.BankType.Character))) and self._bankOpen then
        if event ~= "BANK_TABS_CHANGED" then self._ready.bank = true end
        self:QueueScan()
    elseif event == "BAG_UPDATE_DELAYED" and self._inWorld then
        if self._bankOpen then self._ready.bank = true end
        self._ready.bags = true; self:QueueScan()
    elseif (event == "UNIT_INVENTORY_CHANGED" and unit == "player") or event == "PLAYER_EQUIPMENT_CHANGED" then
        if self._inWorld then self._ready.equipment = true; self:QueueScan() end
    end
end

-- The shared service advertises only implemented capabilities on this target.
function Addon.Items:GetPersonalCounts() return nil, "unsupported-capability" end
