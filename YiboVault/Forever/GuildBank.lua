local Addon = _G.YiboVault
local function Pack(...) return { n = select("#", ...), ... } end
local function Read(fn, ...)
    if type(fn) ~= "function" then error("guild-bank-api-unavailable") end
    local result = Pack(pcall(fn, ...))
    if not result[1] then error("guild-bank-api-read-failed") end
    for index = 2, result.n do
        if type(issecretvalue) == "function" and issecretvalue(result[index]) then error("restricted-guild-bank-value") end
    end
    return unpack(result, 2, result.n)
end
local function Integer(value, minimum, maximum)
    if type(value) ~= "number" or value ~= math.floor(value) or value < minimum or value > maximum then error("invalid-guild-bank-number") end
    return value
end
local function Identity()
    local character = Addon.Core.Characters:GetCurrent({ identityOnly = true })
    if not character then return nil, "guild-identity-unavailable" end
    if Read(IsInGuild) ~= true then return nil, "guild-none" end
    local clubID = Read(C_Club and C_Club.GetGuildClubId)
    if type(clubID) == "number" then clubID = string.format("%.0f", Integer(clubID, 1, 9007199254740991)) end
    if type(clubID) ~= "string" or not clubID:match("^%d+$") or clubID == "0" then return nil, "guild-identity-unavailable" end
    local name = Read(GetGuildInfo, "player")
    if type(name) ~= "string" or name == "" then return nil, "guild-identity-unavailable" end
    return { key = "Forever:club:" .. clubID .. ":viewer:" .. character.id, name = name, realm = character.realm, viewer = character.id }
end
function Addon:CurrentGuildBankIdentity()
    local ok, identity, reason = pcall(Identity)
    return ok and identity or nil, ok and reason or "guild-identity-unavailable"
end
function Addon:ResolveCurrentGuildBankKeys(characters, options)
    local identity = self:CurrentGuildBankIdentity()
    if not identity then return {} end
    if options.guildKey and options.guildKey ~= identity.key then return {} end
    if self:IsGuildHidden(identity.key) and not options.includeHiddenGuilds then return {} end
    for _, character in ipairs(characters) do
        if character.id == identity.viewer then return { identity.key } end
    end
    return {}
end
function Addon:ValidateCurrentGuildBankOptions(options)
    if options.guildKey then
        local identity = self:CurrentGuildBankIdentity()
        if not identity or options.guildKey ~= identity.key then return nil, "scope-not-supported" end
    end
    return true
end
function Addon:IsGuildBankReadable()
    return self._inWorld and self._guildBankOpen and (not GuildBankFrame or type(GuildBankFrame.IsShown) ~= "function" or GuildBankFrame:IsShown())
end
function Addon:StaleGuildBank(key)
    local guild, changed = self.db.byGuild[key], false
    for _, state in pairs(guild and guild.coverage or {}) do
        if state.status ~= "stale" then
            state.status, state.revision, changed = "stale", (tonumber(self.db.revision) or 0) + 1, true
        end
    end
    if changed then self:NotifyLocationStatusChanged("guild-bank", guild.viewerCharacterID, select(1, self:Now())) end
    return changed
end
function Addon:StaleGuildBankTab(key, tab)
    local guild = self.db.byGuild[key]
    local state = guild and guild.coverage and guild.coverage[tostring(tab)]
    if state and state.status ~= "stale" then
        state.status, state.revision = "stale", (tonumber(self.db.revision) or 0) + 1
        self:NotifyLocationStatusChanged("guild-bank", guild.viewerCharacterID, select(1, self:Now()))
    end
end
local function Permissions(identity)
    local count = Integer(Read(GetNumGuildBankTabs), 0, 100)
    if count == 0 then return nil, "guild-tabs-pending" end
    local tabs, allowed = {}, 0
    for tab = 1, count do
        local name, _, viewable = Read(GetGuildBankTabInfo, tab)
        if type(viewable) ~= "boolean" then error("guild-permission-unavailable") end
        if viewable then
            if type(name) ~= "string" then error("guild-tab-unavailable") end
            tabs[tab], allowed = name, allowed + 1
        end
    end
    local guild = Addon.db.byGuild[identity.key]
    if guild then
        local changed = guild.viewableCount ~= allowed
        for tab, name in pairs(guild.viewableTabs or {}) do if tabs[tab] ~= name then changed = true end end
        for tab, name in pairs(tabs) do if not guild.viewableTabs or guild.viewableTabs[tab] ~= name then changed = true end end
        guild.viewableTabs, guild.viewableCount = tabs, allowed
        if changed and not Addon:StaleGuildBank(identity.key) then
            Addon:NotifyLocationStatusChanged("guild-bank", identity.viewer, select(1, Addon:Now()))
        end
    end
    return tabs, allowed
end
function Addon:RequestCurrentGuildTab(manual)
    if not self:IsGuildBankReadable() then return nil, "guild-bank-closed" end
    self._guildTabReady, self._guildTabDirty, self._guildManualEmpty = false, false, manual == true
    self._guildRequested = nil
    local ok, identity, tab, tabs, allowed = pcall(function()
        local guild, reason = Identity()
        if not guild then return nil, reason end
        local viewable, count = Permissions(guild)
        if not viewable then return nil, count end
        local selected = Integer(Read(GetCurrentGuildBankTab), 1, 100)
        if not viewable[selected] then return nil, "guild-no-view" end
        self._guildRequested = { key = guild.key, tab = selected }
        self:StaleGuildBankTab(guild.key, selected)
        Read(QueryGuildBankTab, selected)
        return guild, selected, viewable, count
    end)
    if not ok then
        self._guildPendingReason, self._guildRequested, self._guildManualEmpty = "guild-read-error", nil, false
        self.Core.AccountView:NotifyPageChanged("vault-items")
        return nil, "read-failed"
    end
    if not identity then
        self._guildPendingReason, self._guildManualEmpty = tab, false
        self.Core.AccountView:NotifyPageChanged("vault-items")
        return nil, tab
    end
    self._guildIdentity, self._guildViewableTabs, self._guildViewableCount = identity, tabs, allowed
    self._guildPendingReason = "guild-awaiting-tab"
    self.Core.AccountView:NotifyPageChanged("vault-items")
    return true
end
local function Capture(identity, tab, name)
    local records = {}
    for slot = 1, Addon.Target.guildBankSlots do
        local texture, quantity = Read(GetGuildBankItemInfo, tab, slot)
        local link = Read(GetGuildBankItemLink, tab, slot)
        if texture or (quantity ~= nil and quantity ~= 0) or link then
            if type(link) ~= "string" then error("guild-item-link-unavailable") end
            local id = tonumber(link:match("|Hitem:(%d+)") or link:match("^item:(%d+)"))
            Integer(id, 1, 2147483647); Integer(quantity, 1, 2147483647)
            local character = { id = identity.viewer, realm = identity.realm }
            local record = Addon.BuildItemRecord("guild-bank", character, tab, slot, id, quantity, link)
            record.sourceID = "guild-bank:" .. identity.key .. ":" .. tab .. ":" .. slot
            record.characterID, record.visitorCharacterID = nil, identity.viewer
            record.guildKey, record.guildName = identity.key, identity.name
            record.location.tabID, record.location.tabName = tab, name
            records[#records + 1] = record
        end
    end
    return records
end
function Addon:ScanGuildBank()
    if not self:IsGuildBankReadable() then return nil, "guild-bank-closed" end
    if not self._guildTabDirty then return not self._guildPendingReason end
    self._guildTabDirty = false
    local ok, result, reason = pcall(function()
        local identity, unavailable = Identity()
        if not identity then return nil, unavailable end
        local tabs, allowed = Permissions(identity)
        if not tabs then return nil, allowed end
        local tab = Integer(Read(GetCurrentGuildBankTab), 1, 100)
        if not tabs[tab] then return nil, "guild-no-view" end
        local requested = self._guildRequested
        if not self._guildTabReady or not requested or requested.key ~= identity.key or requested.tab ~= tab then return nil, "guild-awaiting-tab" end
        local records, after = Capture(identity, tab, tabs[tab]), Capture(identity, tab, tabs[tab])
        if #records ~= #after then error("guild-tab-changed") end
        for index, record in ipairs(records) do
            local other = after[index]
            if record.sourceID ~= other.sourceID or record.quantity ~= other.quantity or record.itemLink ~= other.itemLink then error("guild-tab-changed") end
        end
        local current = Identity()
        local _, _, canView = Read(GetGuildBankTabInfo, tab)
        if not self:IsGuildBankReadable() or not current or current.key ~= identity.key or Read(GetCurrentGuildBankTab) ~= tab or canView ~= true then return nil, "guild-context-changed" end
        if #records == 0 and not self._guildManualEmpty then return nil, "guild-empty-pending" end
        return { identity = identity, tab = tab, name = tabs[tab], tabs = tabs, allowed = allowed, records = records }
    end)
    if not ok then
        self._guildPendingReason = "guild-read-error"
        local requested, identity = self._guildRequested, self._guildIdentity
        if requested and identity and requested.key == identity.key then self:MarkGuildTabError(identity.key, identity.name, identity.realm, requested.tab, tostring(result)) end
        self.Core.AccountView:NotifyPageChanged("vault-items")
        return nil, "read-failed"
    end
    if not result then
        self._guildPendingReason = reason
        if self._guildIdentity then self:StaleGuildBank(self._guildIdentity.key) end
        self.Core.AccountView:NotifyPageChanged("vault-items")
        return nil, reason
    end
    local identity = result.identity
    self._guildIdentity, self._guildPendingReason, self._guildManualEmpty = identity, nil, false
    -- Persist observer scope and permissions before Store emits its change event.
    local guild = self.db.byGuild[identity.key] or { tabs = {}, coverage = {} }
    self.db.byGuild[identity.key] = guild
    guild.viewerCharacterID, guild.viewableTabs, guild.viewableCount = identity.viewer, result.tabs, result.allowed
    self:ReplaceGuildTab(identity.key, identity.name, identity.realm, result.tab, identity.viewer, result.records, result.name,
        { totalSlots = self.Target.guildBankSlots, freeSlots = self.Target.guildBankSlots - #result.records })
    return true
end
function Addon:GuildBankSlotsChanged()
    if not self:IsGuildBankReadable() then return end
    local identity = self:CurrentGuildBankIdentity()
    local ok, tab = pcall(Read, GetCurrentGuildBankTab)
    if not identity or not ok then return end
    if not self._guildRequested or self._guildRequested.key ~= identity.key or self._guildRequested.tab ~= tab then self:RequestCurrentGuildTab(false); return end
    self._guildTabReady, self._guildTabDirty = true, true
    self:QueueScan(0.1)
end
function Addon:GuildBankPermissionsChanged()
    if not self:IsGuildBankReadable() then return end
    local ok, identity, tabs, current = pcall(function()
        local guild = Identity()
        if not guild then return end
        local viewable = Permissions(guild)
        return guild, viewable, Read(GetCurrentGuildBankTab)
    end)
    if not ok then self._guildPendingReason = "guild-read-error"
    elseif not identity or not tabs then self._guildPendingReason = "guild-tabs-pending"
    elseif not tabs[current] then
        self._guildRequested, self._guildTabReady, self._guildPendingReason = nil, false, "guild-no-view"
    elseif not self._guildRequested or self._guildRequested.key ~= identity.key or self._guildRequested.tab ~= current then
        self:RequestCurrentGuildTab(false)
    end
    self.Core.AccountView:NotifyPageChanged("vault-items")
end
function Addon:CloseGuildBank()
    self._guildBankOpen, self._guildTabReady, self._guildTabDirty, self._guildManualEmpty = false, false, false, false
    self._guildBankToken = (self._guildBankToken or 0) + 1
    if self._guildIdentity then self:StaleGuildBank(self._guildIdentity.key) end
    self._guildRequested, self._guildPendingReason = nil, nil
    self.Core.AccountView:NotifyPageChanged("vault-items")
end
local getRecords, getCoverage = Addon.GetGuildRecords, Addon.GetGuildCoverage
function Addon:GetGuildCoverage(key)
    local identity = self:CurrentGuildBankIdentity()
    local guild = self.db.byGuild[key]
    if not identity or identity.key ~= key or not guild or guild.viewerCharacterID ~= identity.viewer then return {} end
    local result = getCoverage(self, key)
    for tab in pairs(result) do if not (guild.viewableTabs and guild.viewableTabs[tonumber(tab)]) then result[tab] = nil end end
    return result
end
function Addon:GetGuildRecords(key, itemID)
    local coverage, result = self:GetGuildCoverage(key), {}
    for _, record in ipairs(getRecords(self, key, itemID)) do
        if coverage[tostring(record.location.tabID)] then result[#result + 1] = record end
    end
    return result
end
function Addon:GuildBankViewStatus()
    local identity, reason = self:CurrentGuildBankIdentity()
    if not identity then return reason == "guild-none" and "guild_none" or "guild_identity" end
    if self._guildBankOpen and self._guildPendingReason then
        if self._guildPendingReason == "guild-read-error" then return "error" end
        if self._guildPendingReason == "guild-no-view" then return "guild_no_view" end
        return "guild_waiting"
    end
    local guild = self.db.byGuild[identity.key]
    local states = self:GetGuildCoverage(identity.key)
    local sampled, empty, stale = 0, true, false
    for _, state in pairs(states) do
        if state.status == "error" then return "error" end
        if state.completedScan then sampled = sampled + 1 end
        if (state.recordCount or 0) > 0 then empty = false end
        if state.status == "stale" then stale = true end
    end
    if sampled == 0 then return "guild_pending" end
    if not self._guildBankOpen then return "stale" end
    if sampled < (guild.viewableCount or 0) then return "guild_partial" end
    return stale and "stale" or (empty and "empty" or "known")
end
local inspect, delete = Addon.InspectCharacter, Addon.DeleteCharacter
function Addon:InspectCharacter(character)
    local result = inspect(self, character)
    for _, guild in pairs(self.db.byGuild) do
        if guild.viewerCharacterID == character.id then result.hasData = true; result.detail = self:T("FOREVER.GUILD_CACHE") end
    end
    return result
end
function Addon:DeleteCharacter(character)
    local ok, existed = delete(self, character)
    if not ok then return ok, existed end
    local keys = {}
    for key, guild in pairs(self.db.byGuild) do if guild.viewerCharacterID == character.id then keys[#keys + 1] = key end end
    for _, key in ipairs(keys) do self:DeleteGuild(key); existed = true end
    return true, existed
end
