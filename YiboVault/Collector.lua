local Addon = _G.YiboVault

local function ParseLink(link)
    if type(link) ~= "string" then return nil, nil end
    local linkType, payload = link:match("|H([^:|]+):([^|]+)|h")
    if not linkType then linkType, payload = link:match("^([^:|]+):([^|]+)$") end
    return linkType, payload
end

local function BuildRecord(source, character, container, slot, itemID, quantity, link)
    itemID = tonumber(itemID)
    quantity = tonumber(quantity)
    if not itemID or itemID <= 0 or not quantity or quantity <= 0 then return nil end
    local linkType, payload = ParseLink(link)
    local itemKey = "item:" .. itemID
    local variantKey = linkType and payload and ("link:" .. linkType .. ":" .. payload) or itemKey
    local observedAt, clockSource = Addon:Now()
    return {
        sourceID = source .. ":" .. character.id .. ":" .. tostring(container) .. ":" .. tostring(slot),
        source = source,
        sourceClass = "physical",
        itemID = itemID,
        itemLink = link,
        itemKey = itemKey,
        variantKey = variantKey,
        identityQuality = linkType and payload and "full-link" or "item-id-only",
        quantity = math.floor(quantity),
        characterID = character.id,
        realm = character.realm,
        location = { container = container, slot = slot },
        observedAt = observedAt,
        clockSource = clockSource,
        state = "observed",
    }
end

local function BagAPI()
    if type(C_Container) == "table" then
        return C_Container.GetContainerNumSlots, C_Container.GetContainerItemInfo,
            C_Container.GetContainerItemLink, C_Container.GetContainerNumFreeSlots
    end
    return GetContainerNumSlots, GetContainerItemInfo, GetContainerItemLink, GetContainerNumFreeSlots
end

local function ScanContainer(source, bagID)
    local getSlots, getInfo, getLink, getFreeSlots = BagAPI()
    if type(getSlots) ~= "function" or type(getInfo) ~= "function" then return nil, "container-api-unavailable" end
    local ok, slotCount = pcall(getSlots, bagID)
    if not ok or type(slotCount) ~= "number" or slotCount < 0 then return nil, "container-slot-read-failed" end
    local character = Addon.Core.Characters:GetCurrent()
    if not character then return nil, "current-character-unavailable" end
    local records = {}
    for slot = 1, slotCount do
        local itemResults = { pcall(getInfo, bagID, slot) }
        local itemOK, info, legacyCount, legacyLink = itemResults[1], itemResults[2], itemResults[3], itemResults[8]
        if not itemOK then return nil, "container-item-read-failed" end
        local itemID, count, link
        if type(info) == "table" then
            itemID, count, link = info.itemID, info.stackCount or info.count, info.hyperlink
        else
            count, link = legacyCount, legacyLink
        end
        if not link and type(getLink) == "function" then
            local linkOK, value = pcall(getLink, bagID, slot)
            if linkOK then link = value end
        end
        if itemID or (type(count) == "number" and count > 0) or link then
            if not itemID then
                local _, payload = ParseLink(link)
                itemID = payload and tonumber(payload:match("^(%-?%d+)"))
            end
            if not itemID then return nil, "occupied-slot-without-item-id" end
            local record = BuildRecord(source, character, bagID, slot, itemID, count or 1, link)
            if record then records[#records + 1] = record end
        end
    end
    local capacity = { totalSlots = slotCount }
    if slotCount > 0 and type(getFreeSlots) == "function" then
        local freeOK, freeSlots, bagType = pcall(getFreeSlots, bagID)
        if freeOK and type(freeSlots) == "number" and freeSlots >= 0 and freeSlots <= slotCount then
            capacity.freeSlots = freeSlots
        end
        if freeOK and type(bagType) == "number" then capacity.bagType = bagType end
    end
    if slotCount > 0 and type(GetBagName) == "function" then
        local nameOK, bagName = pcall(GetBagName, bagID)
        if nameOK and type(bagName) == "string" and bagName ~= "" then capacity.bagName = bagName end
    end
    return records, nil, character, capacity
end

function Addon:ScanBag(bagID)
    local records, errorMessage, character, capacity = ScanContainer("bags", bagID)
    if not records then self:MarkLocationError("bags", tostring(bagID), { bagID = bagID }, errorMessage); return nil, errorMessage end
    local key = tostring(bagID)
    local changed, coverage = self:ReplaceLocation(character.id, "bags", key, records, { bagID = bagID }, capacity)
    return true, changed, coverage
end

function Addon:ScanBankContainer(bagID)
    local records, errorMessage, character, capacity = ScanContainer("bank", bagID)
    local key = tostring(bagID)
    if not records then self:MarkLocationError("bank", key, { bagID = bagID }, errorMessage); return nil, errorMessage end
    local changed, coverage = self:ReplaceLocation(character.id, "bank", key, records, { bagID = bagID }, capacity)
    return true, changed, coverage
end

local function BankContainerIDs()
    local firstBag = (tonumber(NUM_BAG_SLOTS) or 4) + 1
    local lastBag = firstBag + (tonumber(NUM_BANKBAGSLOTS) or 7) - 1
    local result = { tonumber(BANK_CONTAINER) or -1 }
    for bagID = firstBag, lastBag do result[#result + 1] = bagID end
    return result
end

function Addon:ScanBank()
    if not self._bankOpen then return 0, 0 end
    local success, failed = 0, 0
    for _, bagID in ipairs(BankContainerIDs()) do
        local ok = self:ScanBankContainer(bagID)
        if ok then success = success + 1 else failed = failed + 1 end
    end
    wipe(self._dirtyBank)
    self:Print(string.format("个人银行扫描完成：成功 %d/%d 个容器，失败 %d。", success, #BankContainerIDs(), failed))
    return success, failed
end

function Addon:ScanBags()
    local maximum = tonumber(NUM_BAG_SLOTS) or 4
    local success, failed = 0, 0
    for bagID = 0, maximum do
        local ok = self:ScanBag(bagID)
        if ok then success = success + 1 else failed = failed + 1 end
    end
    return success, failed
end

local function ScanEquipment()
    if type(GetInventoryItemID) ~= "function" then return nil, "inventory-api-unavailable" end
    local character = Addon.Core.Characters:GetCurrent()
    if not character then return nil, "current-character-unavailable" end
    local firstSlot, lastSlot = tonumber(INVSLOT_FIRST_EQUIPPED) or 1, tonumber(INVSLOT_LAST_EQUIPPED) or 19
    local records = {}
    for slot = firstSlot, lastSlot do
        local ok, itemID = pcall(GetInventoryItemID, "player", slot)
        if not ok then return nil, "equipment-slot-read-failed" end
        local link
        if type(GetInventoryItemLink) == "function" then
            local linkOK, value = pcall(GetInventoryItemLink, "player", slot)
            if not linkOK then return nil, "equipment-link-read-failed" end
            link = value
        end
        if itemID then
            local record = BuildRecord("equipment", character, "equipment", slot, itemID, 1, link)
            if record then records[#records + 1] = record end
        end
    end
    return records, nil, character
end

function Addon:ScanEquipment()
    local records, errorMessage, character = ScanEquipment()
    if not records then self:MarkLocationError("equipment", "equipment", { firstSlot = tonumber(INVSLOT_FIRST_EQUIPPED) or 1, lastSlot = tonumber(INVSLOT_LAST_EQUIPPED) or 19 }, errorMessage); return nil, errorMessage end
    local changed, coverage = self:ReplaceLocation(character.id, "equipment", "equipment", records, { firstSlot = tonumber(INVSLOT_FIRST_EQUIPPED) or 1, lastSlot = tonumber(INVSLOT_LAST_EQUIPPED) or 19 })
    return true, changed, coverage
end

function Addon:ScanInitial()
    self:ScanBags()
    self:ScanEquipment()
end

function Addon:OnEvent(event, arg1, arg2)
    if event == "BAG_UPDATE" then
        if type(arg1) == "number" then
            if arg1 >= 0 and arg1 <= (tonumber(NUM_BAG_SLOTS) or 4) then self._dirtyBags[arg1] = true end
            if self._bankOpen then
                for _, bagID in ipairs(BankContainerIDs()) do
                    if bagID == arg1 then self._dirtyBank[bagID] = true; break end
                end
            end
        end
    elseif event == "BAG_UPDATE_DELAYED" then
        for bagID in pairs(self._dirtyBags) do self:ScanBag(bagID); self._dirtyBags[bagID] = nil end
        if self._bankOpen then
            for bagID in pairs(self._dirtyBank) do self:ScanBankContainer(bagID); self._dirtyBank[bagID] = nil end
        end
    elseif event == "BANKFRAME_OPENED" then
        self._bankOpen = true
        self._bankScanToken = (self._bankScanToken or 0) + 1
        local token = self._bankScanToken
        local scan = function() if self._bankOpen and self._bankScanToken == token then self:ScanBank() end end
        if C_Timer and C_Timer.After then C_Timer.After(0.1, scan) else scan() end
    elseif event == "BANKFRAME_CLOSED" then
        self._bankOpen = false
        for bagID in pairs(self._dirtyBank) do
            local character = self.Core.Characters:GetCurrent()
            if character then self:MarkLocationStale(character.id, "bank", tostring(bagID)) end
        end
        wipe(self._dirtyBank)
    elseif event == "PLAYERBANKSLOTS_CHANGED" then
        if self._bankOpen then self._dirtyBank[tonumber(BANK_CONTAINER) or -1] = true end
    elseif event == "UNIT_INVENTORY_CHANGED" then
        -- Client builds or UI replacements may wrap the unit token; the validated
        -- payload is not a dependable slot identifier, so rescan the whole set.
        self._equipmentDirty = true
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        self._equipmentDirty = true
    elseif event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_LOGIN" then
        self:ScanInitial()
    end
    if self._equipmentDirty and event ~= "UNIT_INVENTORY_CHANGED" then
        self._equipmentDirty = false
        self:ScanEquipment()
    elseif self._equipmentDirty and event == "UNIT_INVENTORY_CHANGED" then
        self._equipmentDirty = false
        self:ScanEquipment()
    end
end

function Addon:InitializeDatabase()
    local db = type(_G.YiboVaultDB) == "table" and _G.YiboVaultDB or {}
    if tonumber(db.schemaVersion) ~= self.SCHEMA_VERSION then
        db.byCharacter = type(db.byCharacter) == "table" and db.byCharacter or {}
        db.revision = tonumber(db.revision) or 0
        db.schemaVersion = self.SCHEMA_VERSION
    end
    db.byCharacter = type(db.byCharacter) == "table" and db.byCharacter or {}
    db.byGuild = type(db.byGuild) == "table" and db.byGuild or {}
    db.revision = tonumber(db.revision) or 0
    for _, character in pairs(db.byCharacter) do
        for _, source in ipairs({ "bags", "equipment", "bank", "auction", "mail" }) do
            for _, coverage in pairs(character.coverage and character.coverage[source] or {}) do
                if coverage.status == "known" or coverage.status == "known-empty" or coverage.status == "partial" then coverage.status = "stale" end
            end
        end
    end
    for _, guild in pairs(db.byGuild) do
        for _, coverage in pairs(guild.coverage or {}) do
            if coverage.status == "known" or coverage.status == "known-empty" or coverage.status == "partial" then coverage.status = "stale" end
        end
    end
    _G.YiboVaultDB = db
    self.db = db
    self._dirtyBags = {}
    self._dirtyBank = {}
    self._bankOpen = false
end

function Addon:MarkLocationError(source, key, location, errorMessage)
    local character = self.Core and self.Core.Characters:GetCurrent()
    if not character then return end
    local store = self:GetCharacterStore(character.id)
    local coverage = store.coverage[source][key] or {}
    local errorCode = tostring(errorMessage or "scan-failed")
    local changed = coverage.status ~= "error" or coverage.error ~= errorCode
    coverage.status = "error"
    coverage.error = errorCode
    coverage.location = location
    coverage.observedAt = select(1, self:Now())
    if changed then coverage.revision = (tonumber(self.db.revision) or 0) + 1 end
    store.coverage[source][key] = coverage
    if changed then self:NotifyLocationStatusChanged(source, character.id, coverage.observedAt) end
end

function Addon:RegisterWithCore()
    local core = _G.YiboCore
    if not core or not core:CheckAPIVersion(self.REQUIRED_CORE_API) then
        self:Print("需要 YiboCore API v" .. self.REQUIRED_CORE_API .. "。")
        return false
    end
    self.Core = core
    local registered, registerError = core:RegisterAddon(self.NAME, { version = self.VERSION, requiredAPI = self.REQUIRED_CORE_API })
    if not registered then self:Print(registerError or "Core 插件注册失败。"); return false end
    if core.CharacterCleanup then
        local cleanup, cleanupError = core.CharacterCleanup:RegisterOwner(self.NAME, {
            Inspect = function(character) return Addon:InspectCharacter(character) end,
            Delete = function(character) return Addon:DeleteCharacter(character) end,
        })
        if not cleanup then self:Print(cleanupError or "角色缓存清理注册失败。"); return false end
    end
    if type(core.RegisterSettingsPanel) == "function" then
        local settings, settingsError = core:RegisterSettingsPanel(self.NAME, {
            id = self.NAME,
            title = "物品仓库",
            description = "物品缓存状态；通用入口、页面字段和角色排序由 Core 管理。",
            CreateSettingsPanel = function(parent)
                local text = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                text:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
                text:SetJustifyH("LEFT")
                text:SetText("Vault 按角色和已访问位置缓存物品。个人银行、公会银行与 AH 上架数据在对应窗口打开后扫描。")
                return text
            end,
        })
        if not settings then self:Print(settingsError or "设置面板注册失败。"); return false end
    end
    local page, pageError = self.AccountPage:Register()
    if not page then self:Print(pageError or "账号页面注册失败。"); return false end
    return true
end
