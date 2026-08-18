local Core = _G.YiboCore

-- 角色档案只保存跨业务可复用的事实快照；任务、收藏、Boss 等业务状态仍归各插件。
local Profile = {}
Core.Profile = Profile
Profile._collectors = Profile._collectors or {}

local function Timestamp()
    return (GetServerTime and GetServerTime()) or time()
end

local function SetAvailability(record, key, state)
    record.availability = record.availability or {}
    record.availability[key] = state
end

local function GetCurrentRecord()
    local character = Core.Characters:GetCurrent()
    local db = Core.Database:GetDB()
    local store = db and db.characters
    return character, store and store.byID[character and character.id]
end

local function Snapshot(value)
    return Core.Defaults:Copy(value)
end

local PRIMARY_PROFESSION_ICONS = {
    ["炼金"] = "Interface\\Icons\\Trade_Alchemy", ["炼金术"] = "Interface\\Icons\\Trade_Alchemy",
    ["锻造"] = "Interface\\Icons\\Trade_BlackSmithing",
    ["附魔"] = "Interface\\Icons\\Trade_Engraving",
    ["工程"] = "Interface\\Icons\\Trade_Engineering",
    ["草药"] = "Interface\\Icons\\Trade_Herbalism",
    ["铭文"] = "Interface\\Icons\\INV_Inscription_Tradeskill01",
    ["珠宝加工"] = "Interface\\Icons\\INV_Misc_Gem_01", ["珠宝"] = "Interface\\Icons\\INV_Misc_Gem_01",
    ["制皮"] = "Interface\\Icons\\Trade_LeatherWorking",
    ["裁缝"] = "Interface\\Icons\\Trade_Tailoring",
    ["采矿"] = "Interface\\Icons\\Trade_Mining",
    ["剥皮"] = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01",
}

local function CollectPrimaryProfessionFallback()
    local collected = {}
    if not GetNumSkillLines or not GetSkillLineInfo then return collected end
    for index = 1, GetNumSkillLines() do
        local name, isHeader, _, skillLevel, _, _, maxSkillLevel = GetSkillLineInfo(index)
        if not isHeader and PRIMARY_PROFESSION_ICONS[name] then
            collected[#collected + 1] = {
                name = name, icon = PRIMARY_PROFESSION_ICONS[name], skillLevel = skillLevel, maxSkillLevel = maxSkillLevel,
            }
        end
    end
    return collected
end

function Profile:RegisterCollector(name, callback, events)
    if type(name) ~= "string" or name == "" or type(callback) ~= "function" then
        return nil, "角色档案采集器必须提供名称和回调。"
    end
    if self._collectors[name] then return nil, "角色档案采集器已存在: " .. name end
    self._collectors[name] = { callback = callback, events = events }
    return true
end

local function RunCollectors(record, reason, now)
    for name, collector in pairs(Profile._collectors) do
        if not collector.events or collector.events[reason] then
            local ok, errorMessage = xpcall(function() collector.callback(record, reason, now) end, function(message) return tostring(message) end)
            if ok then
                record.observedAt.collectors = record.observedAt.collectors or {}
                record.observedAt.collectors[name] = now
            else
                SetAvailability(record, "collector:" .. name, "error")
                Core:Print("角色档案采集器 “" .. name .. "” 失败：" .. errorMessage)
            end
        end
    end
end

function Profile:RefreshCurrent(reason)
    local character, record = GetCurrentRecord()
    if not character or not record then
        return nil
    end

    local now = Timestamp()
    record.profile = record.profile or {}
    record.observedAt = record.observedAt or {}
    record.availability = record.availability or {}

    local raceName, raceFile = UnitRace and UnitRace("player")
    local factionName, factionFile = UnitFactionGroup and UnitFactionGroup("player")
    record.race = raceFile or raceName or record.race
    record.faction = factionFile or factionName or record.faction
    record.sex = UnitSex and UnitSex("player") or record.sex
    record.profile.money = GetMoney and GetMoney() or record.profile.money
    record.profile.guild = GetGuildInfo and select(1, GetGuildInfo("player")) or record.profile.guild
    record.profile.zone = GetZoneText and GetZoneText() or record.profile.zone
    record.profile.subZone = GetSubZoneText and GetSubZoneText() or record.profile.subZone
    record.profile.mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player") or record.profile.mapID
    record.observedAt.identity = now
    record.observedAt.profile = now
    SetAvailability(record, "profile", "known")

    local refreshEquipment = reason == "PLAYER_LOGIN" or reason == "PLAYER_ENTERING_WORLD" or reason == "PLAYER_EQUIPMENT_CHANGED"
    if refreshEquipment then
        local itemLevel
        if C_PaperDollInfo and C_PaperDollInfo.GetAverageItemLevel then
            local average, equipped = C_PaperDollInfo.GetAverageItemLevel()
            itemLevel = equipped or average
        end
        if not itemLevel and GetAverageItemLevel then
            local average, equipped = GetAverageItemLevel()
            itemLevel = equipped or average
        end
        if itemLevel then
            record.profile.itemLevel = itemLevel
            record.observedAt.itemLevel = now
            SetAvailability(record, "itemLevel", "known")
        elseif not record.availability.itemLevel then
            SetAvailability(record, "itemLevel", "unavailable")
        end
    elseif not record.availability.itemLevel then
        SetAvailability(record, "itemLevel", "unavailable")
    end

    local specIndex = GetSpecialization and GetSpecialization()
    local refreshSpecialization = reason == "PLAYER_LOGIN" or reason == "PLAYER_ENTERING_WORLD" or reason == "PLAYER_SPECIALIZATION_CHANGED"
    if refreshSpecialization and specIndex and GetSpecializationInfo then
        local specID, specName, _, specIcon = GetSpecializationInfo(specIndex)
        record.profile.specialization = { id = specID, name = specName, icon = specIcon }
        record.observedAt.specialization = now
        SetAvailability(record, "specialization", "known")
    elseif not record.availability.specialization then
        SetAvailability(record, "specialization", "not-yet-scanned")
    end

    local refreshProfessions = reason == "PLAYER_LOGIN" or reason == "PLAYER_ENTERING_WORLD" or reason == "SKILL_LINES_CHANGED"
    if refreshProfessions then
        record.profile.professions = {}
        record.profile.primaryProfessions = {}
        if GetProfessions and GetProfessionInfo then
            -- GetProfessions returns the two primary slots first, followed by
            -- archaeology, fishing, cooking and first aid.  Keep the slot
            -- explicitly because some client versions do not reliably expose
            -- the skill-line ID from GetProfessionInfo.
            local primaryOne, primaryTwo, archaeology, fishing, cooking, firstAid = GetProfessions()
            local professionSlots = { primaryOne, primaryTwo, archaeology, fishing, cooking, firstAid }
            for slot = 1, 6 do
                local professionIndex = professionSlots[slot]
                if professionIndex then
                    local name, icon, skillLevel, maxSkillLevel, _, _, skillLine = GetProfessionInfo(professionIndex)
                    local snapshot = {
                        id = skillLine, slot = slot, name = name, icon = icon, skillLevel = skillLevel, maxSkillLevel = maxSkillLevel,
                    }
                    record.profile.professions[#record.profile.professions + 1] = snapshot
                    if slot <= 2 then record.profile.primaryProfessions[slot] = Snapshot(snapshot) end
                end
            end
            -- Some Classic clients expose secondary professions here but omit
            -- primary slots until the skill book is initialized.  Read the
            -- skill-line list as a fallback so the account view remains useful
            -- on those clients too.
            if not record.profile.primaryProfessions[1] or not record.profile.primaryProfessions[2] then
                local fallbackSlot = 1
                for _, profession in ipairs(CollectPrimaryProfessionFallback()) do
                    while fallbackSlot <= 2 and record.profile.primaryProfessions[fallbackSlot] do fallbackSlot = fallbackSlot + 1 end
                    if fallbackSlot > 2 then break end
                    record.profile.primaryProfessions[fallbackSlot] = profession
                    fallbackSlot = fallbackSlot + 1
                end
            end
            record.observedAt.professions = now
            SetAvailability(record, "professions", "known")
        else
            SetAvailability(record, "professions", "unavailable")
        end
    end

    local refreshCurrencies = reason == "PLAYER_LOGIN" or reason == "PLAYER_ENTERING_WORLD" or reason == "CURRENCY_DISPLAY_UPDATE"
    if refreshCurrencies then
        local currencyInfo = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyListInfo
        local currencySize = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyListSize and C_CurrencyInfo.GetCurrencyListSize()
        if currencyInfo and currencySize then
            record.profile.currencies = {}
            for index = 1, currencySize do
                local info = currencyInfo(index)
                if info and info.currencyID and not info.isHeader then
                    record.profile.currencies[info.currencyID] = {
                        id = info.currencyID,
                        name = info.name,
                        quantity = info.quantity,
                        iconFileID = info.iconFileID,
                        maxQuantity = info.maxQuantity,
                        weeklyQuantity = info.weeklyQuantity,
                        maxWeeklyQuantity = info.maxWeeklyQuantity,
                    }
                end
            end
            record.observedAt.currencies = now
            SetAvailability(record, "currencies", "known")
        elseif not record.availability.currencies then
            SetAvailability(record, "currencies", "unavailable")
        end
    end

    RunCollectors(record, reason, now)

    record.lastSeenAt = now
    Core.Events:Fire("CHARACTER_PROFILE_UPDATED", character.id, Snapshot(record), reason)
    return Snapshot(record)
end

function Profile:Get(characterID)
    local record = Core.Characters:Get(characterID)
    return record and Snapshot(record) or nil
end

Core.Capabilities:Register("character-profile", 1)
