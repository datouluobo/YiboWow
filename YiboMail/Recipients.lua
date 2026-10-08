local Addon = _G.YiboMail
local R = { revision = 0, friendRevision = 0 }
Addon.Recipients = R
R.sources = Addon.RECIPIENT_SOURCES
local function Trim(value) return type(value) == "string" and value:match("^%s*(.-)%s*$") or "" end
function R:Current() return Addon.Core.Characters:GetCurrent() end
function R:Key(address) return Trim(address):gsub("%s+", ""):lower() end
function R:GetFaction(address)
    local normalized = self:Normalize(address)
    if not normalized then return end
    local key = self:Key(normalized)
    for _, character in ipairs(Addon.Core.Characters:GetAllCached()) do
        if self:Key(character.name .. "-" .. character.realm) == key then
            if character.faction == "Alliance" or character.faction == "Horde" then return character.faction, "core" end
            return nil, "core"
        end
    end
    local fact = (Addon.db.recipientFactions or {})[key]
    if fact and (fact.faction == "Alliance" or fact.faction == "Horde") then return fact.faction, fact.source end
end
function R:SetFaction(address, faction)
    local normalized, err = self:Normalize(address)
    if not normalized then return nil, err end
    if faction ~= "Alliance" and faction ~= "Horde" then return nil, "请选择联盟或部落。" end
    local _, source = self:GetFaction(normalized)
    if source == "core" then return nil, "账号角色阵营由 Core 登录采集。" end
    Addon.db.recipientFactions = Addon.db.recipientFactions or {}
    Addon.db.recipientFactions[self:Key(normalized)] = { faction = faction, source = "confirmed", updatedAt = Addon:Now() }
    self:Changed()
    if Addon.SendRules then Addon.SendRules:Changed(true) end
    return true
end
function R:CanRuleSend(address, current)
    current = current or self:Current()
    local normalized, _, _, realm = self:Normalize(address)
    if not normalized then return false, "收件人无效" end
    if not current or not current.realm then return nil, "当前角色服务器待采集" end
    if self:Key(realm) ~= self:Key(current.realm) then return false, "不同服务器，当前角色不适用" end
    local faction = current and current.faction
    local target = self:GetFaction(address)
    if faction ~= "Alliance" and faction ~= "Horde" then return nil, "当前角色阵营待采集" end
    if not target then return nil, "收件人阵营待确认" end
    if faction ~= target then return false, "对立阵营，当前角色不适用" end
    return true
end
function R:ObserveSuccessfulMail(address, senderFaction, ordinary)
    if not ordinary or (senderFaction ~= "Alliance" and senderFaction ~= "Horde") then return end
    local normalized = self:Normalize(address)
    if not normalized or self:GetFaction(normalized) then return end
    Addon.db.recipientFactions = Addon.db.recipientFactions or {}
    Addon.db.recipientFactions[self:Key(normalized)] = { faction = senderFaction, source = "mail-success", updatedAt = Addon:Now() }
    self:Changed()
    if Addon.SendRules then Addon.SendRules:Changed(true) end
end
function R:Normalize(value, realm)
    value = Trim(value)
    if value == "" or value:find("[|%c]") then return nil, "请填写有效的角色名或角色名-服务器。" end
    local name, server = value:match("^([^-]+)%-(.+)$")
    if not name then name, server = value, realm or (self:Current() or {}).realm end
    name, server = Trim(name), Trim(server)
    if name == "" or name:find("%s") or name:find("-", 1, true) or server == "" or server:find("[|%c]") then return nil, "请填写完整的角色名-服务器。" end
    -- Preserve a known realm's spelling; matching also ignores realm whitespace.
    if not self.realms then
        self.realms = {}
        for _, character in ipairs(Addon.Core.Characters:GetAllCached()) do
            if character.realm then self.realms[self:Key(character.realm)] = character.realm end
        end
    end
    server = self.realms[self:Key(server)] or server
    return name .. "-" .. server, nil, name, server
end
function R:Escape(value) return tostring(value or ""):gsub("|", "||") end
function R:Label(entry)
    if entry.label and entry.label ~= "" and self:Key(entry.label) ~= self:Key(entry.address) then return self:Escape(entry.label) end
    local _, _, name, realm = self:Normalize(entry.address)
    return self:Escape(name and (self:Key(realm) == self:Key((self:Current() or {}).realm) and name or name .. "-" .. realm) or entry.address)
end
function R:Changed(friends)
    self.revision = self.revision + 1
    if friends then self.friendRevision = self.friendRevision + 1; self.union = nil end
    self.queryCache = nil; self.candidateCache = nil
    if Addon.RecipientUI then Addon.RecipientUI:Refresh() end
    if Addon.NativeUI and Addon.NativeUI.readySend and Addon.NativeUI.send:IsShown() then Addon.NativeUI:RefreshFavoriteButtons() end
end
function R:Initialize()
    local db = Addon.db
    db.recipientFactions = type(db.recipientFactions) == "table" and db.recipientFactions or {}
    db.contacts = db.contacts or {}; db.recentRecipients = db.recentRecipients or {}; db.friendsByCharacter = db.friendsByCharacter or {}
    if db.quickRecipients == nil then
        db.quickRecipients = {}; local seen = {}; self.migrationSkipped = 0
        for _, entry in ipairs(db.contacts) do
            local address = type(entry) == "table" and self:Normalize(entry.address)
            if address and not seen[self:Key(address)] and #db.quickRecipients < 16 then
                seen[self:Key(address)] = true
                db.quickRecipients[#db.quickRecipients + 1] = { address = address, label = entry.label }
            elseif not address then self.migrationSkipped = self.migrationSkipped + 1 end
        end
    end
    db.recipientSchemaVersion = 1
    if Addon.Core.Events then
        Addon.Core.Events:Register("DATA_DOMAIN_UPDATED", self, function(owner, payload)
            if not payload or payload.domainID ~= "identity" or owner.factionRefreshPending then return end
            owner.factionRefreshPending = true
            local function Refresh()
                owner.factionRefreshPending = nil
                if Addon.SendRules then Addon.SendRules:Changed(true) end
                if Addon.SendRulesSettings then Addon.SendRulesSettings:Refresh() end
            end
            if C_Timer and C_Timer.After then C_Timer.After(0, Refresh) else Refresh() end
        end)
        Addon.Core.Events:Register("CHARACTER_ID_CHANGED", self, function(owner, oldID, newID)
            local snapshots = Addon.db.friendsByCharacter
            local old, new = snapshots[oldID], snapshots[newID]
            if old and (not new or (old.updatedAt or 0) > (new.updatedAt or 0)) then snapshots[newID] = old end
            snapshots[oldID] = nil; owner.realms = nil; owner.accountAddresses = nil; owner:Changed(true)
        end)
        for _, event in ipairs({ "CHARACTER_UPDATED", "CHARACTER_IMPORTED", "CHARACTER_DISPLAY_UPDATED", "CHARACTER_CACHE_DELETED" }) do
            Addon.Core.Events:Register(event, self, function(owner) owner.realms = nil; owner.accountAddresses = nil; owner:Changed() end)
        end
    end
end
function R:FindContact(value)
    local address = self:Normalize(value); if not address then return end
    for index, entry in ipairs(Addon.db.contacts) do
        local candidate = type(entry) == "table" and self:Normalize(entry.address)
        if candidate and self:Key(candidate) == self:Key(address) then return index, entry end
    end
end
function R:SaveContact(value, label, oldAddress)
    local address, err = self:Normalize(value); if not address then return nil, err end
    local index = self:FindContact(address)
    local oldIndex = oldAddress and self:FindContact(oldAddress)
    if index and index ~= oldIndex then return nil, "收件人已在常用名单中。" end
    Addon.db.contacts[oldIndex or #Addon.db.contacts + 1] = { address = address, label = Trim(label) }
    self:Changed(); return true
end
function R:RemoveContact(address)
    local index = self:FindContact(address); if not index then return nil, "收件人已不在常用名单中。" end
    table.remove(Addon.db.contacts, index); self:Changed(); return true
end
function R:SetShortcut(slot, value, label)
    if type(slot) ~= "number" or slot < 1 or slot > 72 or slot ~= math.floor(slot) then return nil, "快捷格不可用。" end
    local address, err = self:Normalize(value); if not address then return nil, err end
    local previous = Addon.db.quickRecipients[slot]
    Addon.db.quickRecipients[slot] = { address = address, label = Trim(label), icon = previous and previous.icon }; self:Changed(); return true
end
function R:SetShortcutIcon(slot, icon, expected)
    local saved = Addon.db.quickRecipients[slot]
    if not saved or (expected and saved ~= expected) then return nil, "快捷收件人已改变，请重新选择。" end
    if icon ~= nil and not Addon.Core:IsBuiltinIcon(icon) then return nil, "请选择游戏图标。" end
    saved.icon = icon; self:Changed(); return true
end
function R:ClearShortcut(slot, expected)
    if type(slot) ~= "number" or slot < 1 or slot > 72 or slot ~= math.floor(slot) then return nil end
    if expected and Addon.db.quickRecipients[slot] ~= expected then return nil, "快捷收件人已改变，请重新拖动。" end
    Addon.db.quickRecipients[slot] = nil; self:Changed(); return true
end
function R:MoveShortcut(source, target, expected)
    local function Valid(slot) return type(slot) == "number" and slot >= 1 and slot <= 72 and slot == math.floor(slot) end
    if not Valid(source) or not Valid(target) then return nil, "快捷格不可用。" end
    local slots = Addon.db.quickRecipients
    if not slots[source] or (expected and slots[source] ~= expected) then return nil, "快捷收件人已改变，请重新拖动。" end
    if source == target then return true end
    slots[source], slots[target] = slots[target], slots[source]
    self:Changed(); return true
end
function R:RecordRecent(value)
    local address = self:Normalize(value); if not address then return end
    local entries = Addon.db.recentRecipients
    for index = #entries, 1, -1 do if self:Key(entries[index].address) == self:Key(address) then table.remove(entries, index) end end
    table.insert(entries, 1, { address = address, sentAt = Addon:Now() })
    while #entries > 20 do table.remove(entries) end
    self:Changed()
end
local function SameSet(a, b)
    for key in pairs(a) do if not b[key] then return false end end
    for key in pairs(b) do if not a[key] then return false end end
    return true
end
function R:CommitFriends(character, entries, ready)
    if not character then return false end
    if not ready then self:SetFriendStatus("好友名单尚未就绪"); return false end
    local addresses = {}
    for _, value in ipairs(entries) do
        local address = self:Normalize(value, character.realm)
        if not address then self:SetFriendStatus("好友名单读取未完成"); return false end
        addresses[self:Key(address)] = address
    end
    local prior = Addon.db.friendsByCharacter[character.id]
    local changed = not prior or not SameSet(prior.addresses or {}, addresses)
    Addon.db.friendsByCharacter[character.id] = { addresses = addresses, updatedAt = Addon:Now(), realm = character.realm, status = "ready" }
    self.friendStatus = nil
    if changed then self:Changed(true) elseif Addon.RecipientUI then Addon.RecipientUI:Refresh() end
    return true
end
function R:SetFriendStatus(status)
    self.friendStatus = status
    local snapshot = Addon.db.friendsByCharacter[(self:Current() or {}).id]
    if snapshot then snapshot.readStatus = status end
    if Addon.RecipientUI then Addon.RecipientUI:Refresh() end
end
function R:ReadFriends(readyEvent)
    local api = _G.C_FriendList
    local countFn = api and api.GetNumFriends or _G.GetNumFriends
    local infoFn = api and api.GetFriendInfoByIndex or _G.GetFriendInfo
    if type(countFn) ~= "function" or type(infoFn) ~= "function" then self:SetFriendStatus("客户端好友接口不可用"); return end
    local ok, count = pcall(countFn)
    if not ok or type(count) ~= "number" or (count == 0 and not readyEvent) then self:SetFriendStatus("好友名单尚未就绪"); return end
    local entries = {}
    for index = 1, count do
        local success, info = pcall(infoFn, index)
        local name = type(info) == "table" and info.name or info
        if not success or type(name) ~= "string" or name == "" then self:SetFriendStatus("好友名单读取未完成"); return end
        entries[#entries + 1] = name
    end
    local success, afterCount = pcall(countFn)
    if not success or afterCount ~= count then self:SetFriendStatus("好友名单读取未完成"); return end
    self:CommitFriends(self:Current(), entries, true)
end
function R:RequestFriends(request)
    if request then
        local show = _G.C_FriendList and C_FriendList.ShowFriends or _G.ShowFriends
        if type(show) == "function" then show() end
    end
    if self.friendPending then return end
    self.friendPending = true
    local function Read()
        self.friendPending = nil; local ready = self.friendReady; self.friendReady = nil
        self:ReadFriends(ready)
    end
    if _G.C_Timer and C_Timer.After then C_Timer.After(0.15, Read) else Read() end
end
function R:OnEvent(event)
    if event == "FRIENDLIST_UPDATE" then self.friendReady = true; self:RequestFriends()
    elseif event == "PLAYER_ENTERING_WORLD" or event == "MAIL_SHOW" then self:RequestFriends(true)
        if event == "MAIL_SHOW" then self:RequestGuild() end
    elseif event == "GUILD_ROSTER_UPDATE" then self:ReadGuild(); self:Changed() end
end
function R:RequestGuild()
    if _G.C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster()
    elseif _G.GuildRoster then GuildRoster() end
    self:ReadGuild()
end
function R:ReadGuild()
    self.guild = {}; self.guildStatus = nil
    if not _G.IsInGuild or not IsInGuild() then return end
    if not _G.GetNumGuildMembers or not _G.GetGuildRosterInfo then self.guildStatus = "公会接口不可用"; return end
    local count = GetNumGuildMembers(true)
    if type(count) ~= "number" or count == 0 then self.guildStatus = "公会名单尚未就绪"; return end
    local seen = {}
    for index = 1, count do
        local name = GetGuildRosterInfo(index)
        local address = self:Normalize(name)
        if address and not seen[self:Key(address)] then seen[self:Key(address)] = true; self.guild[#self.guild + 1] = { address = address } end
    end
    table.sort(self.guild, function(a, b) return self:Key(a.address) < self:Key(b.address) end)
end
function R:AccountAddresses()
    local roster = Addon.Core.Characters:GetAllCached()
    local current = self:Current() or {}
    local currentAddress = current.name and current.realm and self:Normalize(current.name .. "-" .. current.realm)
    local cache = self.accountAddresses
    if cache and cache.roster == roster and cache.currentAddress == currentAddress then return cache.keys end
    local keys = {}
    for _, character in ipairs(roster) do
        local address = character.name and character.realm and self:Normalize(character.name .. "-" .. character.realm)
        if address then keys[self:Key(address)] = true end
    end
    if currentAddress then keys[self:Key(currentAddress)] = true end
    self.accountAddresses = { roster = roster, currentAddress = currentAddress, keys = keys }
    return keys
end
function R:AccountFriends()
    local currentID = (self:Current() or {}).id
    local accounts = self:AccountAddresses()
    local currentFriends = Addon.db.friendsByCharacter[currentID]
    local currentAddresses = currentFriends and currentFriends.addresses or {}
    if self.union and self.union.currentID == currentID and self.union.revision == self.friendRevision and self.union.accounts == accounts then return self.union.entries end
    local seen, entries = {}, {}
    for id, snapshot in pairs(Addon.db.friendsByCharacter) do
        if id ~= currentID then
            for key, address in pairs(snapshot.addresses or {}) do
                if not accounts[key] and not currentAddresses[key] and not seen[key] then seen[key] = true; entries[#entries + 1] = { address = address, key = key } end
            end
        end
    end
    table.sort(entries, function(a, b) return a.key < b.key end)
    self.union = { currentID = currentID, revision = self.friendRevision, accounts = accounts, entries = entries }; return entries
end
function R:FriendOwners(address)
    local owners = {}; local key = self:Key(address); local currentID = (self:Current() or {}).id
    for _, character in ipairs(Addon.Core.Characters:GetAllCached()) do
        local snapshot = Addon.db.friendsByCharacter[character.id]
        if character.id ~= currentID and snapshot and snapshot.addresses[key] then
            owners[#owners + 1] = character.name .. "-" .. character.realm .. " · " .. date("%m-%d %H:%M", snapshot.updatedAt or 0)
        end
    end
    return owners
end
function R:Candidates(source)
    if source == "accountFriends" then return self:AccountFriends() end
    local currentID = (self:Current() or {}).id
    local accounts = source == "friends" and self:AccountAddresses()
    self.candidateCache = self.candidateCache or {}
    local cached = self.candidateCache[source]
    if source ~= "characters" and cached and cached.currentID == currentID and cached.accounts == accounts then return cached.entries end
    local entries, seen = {}, {}
    local function Add(value, label, class)
        local address = self:Normalize(value)
        if address and not seen[self:Key(address)] then seen[self:Key(address)] = true; entries[#entries + 1] = { address = address, label = label, class = class, key = self:Key(address) } end
    end
    if source == "contacts" or source == "recent" then
        if source == "contacts" then self.invalidContacts = 0 end
        for _, entry in ipairs(source == "contacts" and Addon.db.contacts or Addon.db.recentRecipients) do
            if type(entry) == "table" then Add(entry.address, entry.label) end
            if source == "contacts" and (type(entry) ~= "table" or not self:Normalize(entry.address)) then self.invalidContacts = self.invalidContacts + 1 end
        end
    elseif source == "characters" then
        local view = Addon.Core.AccountView
        local characters = view and view.GetVisibleCharacters and view:GetVisibleCharacters() or Addon.Core.Characters:GetAllCached()
        if Addon.Core.CharacterSort and view and view.GetDefaultCharacterSort then
            characters = Addon.Core.CharacterSort:Sort(characters, view:GetDefaultCharacterSort(), currentID, view.GetCustomCharacterOrder and view:GetCustomCharacterOrder())
        end
        local current = self:Current()
        for _, character in ipairs(characters) do if not current or character.id ~= current.id then Add(character.name .. "-" .. character.realm, nil, character.class) end end
    elseif source == "friends" then
        local snapshot = Addon.db.friendsByCharacter[(self:Current() or {}).id]
        if snapshot then for key, address in pairs(snapshot.addresses) do if not accounts[key] then Add(address) end end end
        table.sort(entries, function(a, b) return self:Key(a.address) < self:Key(b.address) end)
    elseif source == "guild" then entries = self.guild or {} end
    self.candidateCache[source] = { currentID = currentID, accounts = accounts, entries = entries }
    return entries
end
function R:Query(source, query, realm)
    query = Trim(query):lower(); realm = realm and self:Key(realm)
    local cache = self.queryCache
    local accounts = (source == "friends" or source == "accountFriends") and self:AccountAddresses()
    if source ~= "characters" and cache and cache.revision == self.revision and cache.currentID == (self:Current() or {}).id and cache.accounts == accounts and cache.source == source and cache.query == query and cache.realm == realm then return cache.entries end
    local entries = {}
    for _, entry in ipairs(self:Candidates(source)) do
        local server = realm and entry.address:match("^[^-]+%-(.+)$")
        if (not realm or self:Key(server) == realm) and (query == "" or (entry.address .. " " .. (entry.label or "")):lower():find(query, 1, true)) then entries[#entries + 1] = entry end
    end
    self.queryCache = { source = source, query = query, realm = realm, accounts = accounts, entries = entries, currentID = (self:Current() or {}).id, revision = self.revision }; return entries
end
function R:HasCharacter(character, aliases)
    if Addon.db.friendsByCharacter[character.id] then return true end
    for id in pairs(aliases or {}) do if Addon.db.friendsByCharacter[id] then return true end end
    return false
end
function R:DeleteCharacter(character, aliases)
    Addon.db.friendsByCharacter[character.id] = nil
    for id in pairs(aliases or {}) do Addon.db.friendsByCharacter[id] = nil end
    self:Changed(true)
end
