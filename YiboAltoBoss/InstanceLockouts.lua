if _G.YAB and _G.YAB.CoreReady == false then return end
local YAB = _G.YAB
if not YAB.LockoutLocaleReady then return end
local Core = _G.YiboCore
local throttleRuntime = {}
local instanceCatalog

local EXPANSION_ORDER = {
    ["熊猫人之谜"] = 1, ["Mists of Pandaria"] = 1,
    ["大地的裂变"] = 2, ["Cataclysm"] = 2,
    ["巫妖王之怒"] = 3, ["Wrath of the Lich King"] = 3,
    ["燃烧的远征"] = 4, ["The Burning Crusade"] = 4,
    ["经典旧世"] = 5, ["Classic"] = 5,
}

local INSTANCE_ABBREVIATIONS = {
    -- Mists of Pandaria
    ["魔古山宝库"] = "MSV", ["恐惧之心"] = "HoF", ["永春台"] = "ToES",
    ["雷电王座"] = "ToT", ["决战奥格瑞玛"] = "SoO", ["围攻奥格瑞玛"] = "SoO",
    ["青龙寺"] = "TJS", ["风暴烈酒酿造厂"] = "SSB", ["影踪禅院"] = "SPM",
    ["魔古山宫殿"] = "MSP", ["残阳关"] = "GSS", ["围攻砮皂寺"] = "SNT",
    ["围攻怒皂寺"] = "SNT", ["血色大厅"] = "SH", ["血色修道院"] = "SM",
    ["通灵学院"] = "Scholo", ["潘达利亚"] = "Pandaria",
    -- Cataclysm
    ["巨龙之魂"] = "DS", ["巴拉丁监狱"] = "BH", ["暮光堡垒"] = "BoT",
    ["火焰之地"] = "FL", ["风神王座"] = "T4W", ["黑翼血环"] = "BWD",
    ["巨石之核"] = "SC", ["托维尔失落之城"] = "LCoT", ["托维尔失"] = "LCoT",
    ["旋云之巅"] = "VP", ["格瑞姆巴托"] = "GB", ["起源大厅"] = "HoO",
    ["潮汐王座"] = "ToT", ["黑石岩窟"] = "BRC", ["死亡矿井"] = "DM",
    ["影牙城堡"] = "SFK", ["祖阿曼"] = "ZA", ["祖尔格拉布"] = "ZG",
    ["时光之末"] = "ET", ["永恒之井"] = "WoE", ["暮光审判"] = "HoT",
    -- Wrath of the Lich King
    ["红玉圣殿"] = "RS", ["冰冠堡垒"] = "ICC", ["十字军的试炼"] = "ToC", ["十字军试炼"] = "ToC",
    ["奥妮克希亚的巢穴"] = "Ony", ["奥杜尔"] = "ULD", ["阿尔卡冯的宝库"] = "VoA",
    ["永恒之眼"] = "EoE", ["黑曜石圣殿"] = "OS", ["纳克萨玛斯"] = "NAXX",
    ["乌特加德城堡"] = "UK", ["乌特加德之巅"] = "UP", ["魔枢"] = "Nexus",
    ["魔环"] = "Occ", ["艾卓-尼鲁布"] = "AN", ["安卡赫特：古代王国"] = "OK",
    ["达克萨隆要塞"] = "DTK", ["古达克"] = "Gun", ["紫罗兰监狱"] = "VH",
    ["岩石大厅"] = "HoS", ["闪电大厅"] = "HoL", ["净化斯坦索姆"] = "CoS",
    ["冠军的试炼"] = "ToC", ["灵魂洪炉"] = "FoS", ["萨隆矿坑"] = "PoS",
    ["映像大厅"] = "HoR",
    -- The Burning Crusade
    ["太阳之井高地"] = "SWP", ["太阳井高地"] = "SWP", ["黑暗神殿"] = "BT",
    ["海加尔峰"] = "MH", ["海加尔山"] = "MH", ["海加尔山之战"] = "MH",
    ["风暴要塞"] = "TK", ["毒蛇神殿"] = "SSC", ["玛瑟里顿的巢穴"] = "Mag",
    ["格鲁尔的巢穴"] = "Gruul", ["卡拉赞"] = "Kara",
    ["地狱火城墙"] = "Ramps", ["地狱火壁垒"] = "Ramps", ["鲜血熔炉"] = "BF", ["破碎大厅"] = "SHH",
    ["奴隶围栏"] = "SP", ["幽暗沼泽"] = "UB", ["蒸汽地窟"] = "SV",
    ["法力陵墓"] = "MT", ["奥金尼地穴"] = "AC", ["塞泰克大厅"] = "Sethekk",
    ["暗影迷宫"] = "SL", ["旧希尔斯布莱德丘陵"] = "OHB", ["逃离敦霍尔德"] = "OHB",
    ["敦霍尔德城堡"] = "OHB", ["黑色沼泽"] = "BM", ["开启黑暗之门"] = "BM",
    ["能源舰"] = "Mech", ["生态船"] = "Bot", ["禁魔监狱"] = "Arc",
    ["魔导师平台"] = "MgT",
    -- Classic
    ["安其拉神殿"] = "AQ40", ["安其拉废墟"] = "AQ20", ["黑翼之巢"] = "BWL",
    ["熔火之心"] = "MC", ["剃刀沼泽"] = "RFK", ["剃刀高地"] = "RFD",
    ["厄运之槌"] = "DM", ["哀嚎洞穴"] = "WC", ["怒焰裂谷"] = "RFC",
    ["斯坦索姆"] = "Strat", ["暴风城监狱"] = "Stocks", ["监狱"] = "Stocks",
    ["玛拉顿"] = "Mara", ["祖尔法拉克"] = "ZF", ["阿塔哈卡神庙"] = "ST",
    ["沉没的神庙"] = "ST", ["黑暗深渊"] = "BFD", ["诺莫瑞根"] = "Gnomer",
    ["黑石深渊"] = "BRD", ["黑石塔"] = "BRS", ["黑石塔下层"] = "LBRS", ["黑石塔上层"] = "UBRS",
    ["奥达曼"] = "Ulda",
}

local function EnglishAcronym(name)
    if type(name) ~= "string" or name == "" then return nil end
    for index = 1, #name do if name:byte(index) > 127 then return nil end end
    local result = {}
    for word in name:gmatch("[%w']+") do
        local lower = word:lower()
        if lower ~= "the" and lower ~= "of" and lower ~= "and" then result[#result + 1] = word:sub(1, 1):upper() end
    end
    return #result > 0 and table.concat(result) or nil
end

local function Abbreviation(name, fallback)
    return INSTANCE_ABBREVIATIONS[name] or EnglishAcronym(name) or fallback or "INST"
end

-- Mists Classic's Encounter Journal does not expose every legacy raid.
-- Map IDs keep these entries compatible with GetSavedInstanceInfo lockouts.
local LEGACY_RAIDS = {
    { expansion = _G.YiboCore.Locale:Get("YiboAltoBoss", "EXPANSION.WRATH"), mapID = 724, name = _G.YiboCore.Locale:Get("YiboAltoBoss", "INSTANCE.724"), abbr = "RS" },
    { expansion = _G.YiboCore.Locale:Get("YiboAltoBoss", "EXPANSION.WRATH"), mapID = 631, name = _G.YiboCore.Locale:Get("YiboAltoBoss", "INSTANCE.631"), abbr = "ICC" },
    { expansion = _G.YiboCore.Locale:Get("YiboAltoBoss", "EXPANSION.WRATH"), mapID = 649, name = _G.YiboCore.Locale:Get("YiboAltoBoss", "INSTANCE.649"), abbr = "ToC" },
    { expansion = _G.YiboCore.Locale:Get("YiboAltoBoss", "EXPANSION.WRATH"), mapID = 249, name = _G.YiboCore.Locale:Get("YiboAltoBoss", "INSTANCE.249"), abbr = "Ony" },
    { expansion = _G.YiboCore.Locale:Get("YiboAltoBoss", "EXPANSION.WRATH"), mapID = 603, name = _G.YiboCore.Locale:Get("YiboAltoBoss", "INSTANCE.603"), abbr = "ULD" },
    { expansion = _G.YiboCore.Locale:Get("YiboAltoBoss", "EXPANSION.WRATH"), mapID = 624, name = _G.YiboCore.Locale:Get("YiboAltoBoss", "INSTANCE.624"), abbr = "VoA" },
    { expansion = _G.YiboCore.Locale:Get("YiboAltoBoss", "EXPANSION.WRATH"), mapID = 616, name = _G.YiboCore.Locale:Get("YiboAltoBoss", "INSTANCE.616"), abbr = "EoE" },
    { expansion = _G.YiboCore.Locale:Get("YiboAltoBoss", "EXPANSION.WRATH"), mapID = 615, name = _G.YiboCore.Locale:Get("YiboAltoBoss", "INSTANCE.615"), abbr = "OS" },
    { expansion = _G.YiboCore.Locale:Get("YiboAltoBoss", "EXPANSION.WRATH"), mapID = 533, name = _G.YiboCore.Locale:Get("YiboAltoBoss", "INSTANCE.533"), abbr = "NAXX" },
    { expansion = _G.YiboCore.Locale:Get("YiboAltoBoss", "EXPANSION.TBC"), mapID = 580, name = _G.YiboCore.Locale:Get("YiboAltoBoss", "INSTANCE.580"), abbr = "SWP" },
    { expansion = _G.YiboCore.Locale:Get("YiboAltoBoss", "EXPANSION.TBC"), mapID = 564, name = _G.YiboCore.Locale:Get("YiboAltoBoss", "INSTANCE.564"), abbr = "BT" },
    { expansion = _G.YiboCore.Locale:Get("YiboAltoBoss", "EXPANSION.TBC"), mapID = 534, name = _G.YiboCore.Locale:Get("YiboAltoBoss", "INSTANCE.534"), abbr = "MH" },
    { expansion = _G.YiboCore.Locale:Get("YiboAltoBoss", "EXPANSION.TBC"), mapID = 550, name = _G.YiboCore.Locale:Get("YiboAltoBoss", "INSTANCE.550"), abbr = "TK" },
    { expansion = _G.YiboCore.Locale:Get("YiboAltoBoss", "EXPANSION.TBC"), mapID = 548, name = _G.YiboCore.Locale:Get("YiboAltoBoss", "INSTANCE.548"), abbr = "SSC" },
    { expansion = _G.YiboCore.Locale:Get("YiboAltoBoss", "EXPANSION.TBC"), mapID = 544, name = _G.YiboCore.Locale:Get("YiboAltoBoss", "INSTANCE.544"), abbr = "Mag" },
    { expansion = _G.YiboCore.Locale:Get("YiboAltoBoss", "EXPANSION.TBC"), mapID = 565, name = _G.YiboCore.Locale:Get("YiboAltoBoss", "INSTANCE.565"), abbr = "Gruul" },
    { expansion = _G.YiboCore.Locale:Get("YiboAltoBoss", "EXPANSION.TBC"), mapID = 532, name = _G.YiboCore.Locale:Get("YiboAltoBoss", "INSTANCE.532"), abbr = "Kara" },
    { expansion = _G.YiboCore.Locale:Get("YiboAltoBoss", "EXPANSION.CLASSIC"), mapID = 531, name = _G.YiboCore.Locale:Get("YiboAltoBoss", "INSTANCE.531"), abbr = "AQ40" },
    { expansion = _G.YiboCore.Locale:Get("YiboAltoBoss", "EXPANSION.CLASSIC"), mapID = 509, name = _G.YiboCore.Locale:Get("YiboAltoBoss", "INSTANCE.509"), abbr = "AQ20" },
    { expansion = _G.YiboCore.Locale:Get("YiboAltoBoss", "EXPANSION.CLASSIC"), mapID = 469, name = _G.YiboCore.Locale:Get("YiboAltoBoss", "INSTANCE.469"), abbr = "BWL" },
    { expansion = _G.YiboCore.Locale:Get("YiboAltoBoss", "EXPANSION.CLASSIC"), mapID = 409, name = _G.YiboCore.Locale:Get("YiboAltoBoss", "INSTANCE.409"), abbr = "MC" },
}

local function DB()
    YiboAltoBossDB = YiboAltoBossDB or {}
    YiboAltoBossDB.characters = YiboAltoBossDB.characters or {}
    YiboAltoBossDB.settings = YiboAltoBossDB.settings or {}
    YiboAltoBossDB.settings.normalInstanceLimit = tonumber(YiboAltoBossDB.settings.normalInstanceLimit) or 5
    YiboAltoBossDB.settings.lockoutColumns = YiboAltoBossDB.settings.lockoutColumns or {}
    local settings = YiboAltoBossDB.settings
    settings.previewColumns = settings.previewColumns or {}
    for key, item in pairs(settings.lockoutColumns) do
        local fieldID = "instance:" .. tostring(key)
        if settings.previewColumns[fieldID] == nil then
            settings.previewColumns[fieldID] = item.enabled == true
        end
    end
    return YiboAltoBossDB
end

local function Now()
    return (GetServerTime and GetServerTime()) or time()
end

local function CurrentKey()
    return YAB.GetCurrentCharKey and YAB.GetCurrentCharKey()
end

local function CurrentRealm()
    return YAB.GetCurrentRealm and YAB.GetCurrentRealm() or GetRealmName() or _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.UNKNOWN_REALM")
end

local function ShortName(name)
    name = tostring(name or _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.UNKNOWN_INSTANCE"))
    local count, index = 0, 1
    while index <= #name do
        local byte = name:byte(index)
        index = index + (byte < 128 and 1 or byte < 224 and 2 or byte < 240 and 3 or 4)
        count = count + 1
        if count >= 4 then return name:sub(1, index - 1) end
    end
    return name
end

local function BuildInstanceCatalog()
    if instanceCatalog then return instanceCatalog end
    instanceCatalog = {}
    if EJ_GetNumTiers and EJ_SelectTier and EJ_GetInstanceByIndex and EJ_GetInstanceInfo then
        local previousTier = EJ_GetCurrentTier and EJ_GetCurrentTier()
        local tierCount = EJ_GetNumTiers()
        for tier = 1, tierCount do
            EJ_SelectTier(tier)
            local expansion = (EJ_GetTierInfo and EJ_GetTierInfo(tier)) or (_G.YiboCore.Locale:Get("YiboAltoBoss", "UI.EXPANSION") .. tostring(tier))
            for _, isRaid in ipairs({ false, true }) do
                for index = 1, 200 do
                    local instanceID = EJ_GetInstanceByIndex(index, isRaid)
                    if not instanceID then break end
                    local name = EJ_GetInstanceInfo(instanceID)
                    local mapID = select(10, EJ_GetInstanceInfo(instanceID))
                    if name and not instanceCatalog[tostring(instanceID)] then
                        instanceCatalog[tostring(instanceID)] = {
                            key = "ej:" .. tostring(instanceID), instanceID = instanceID,
                            mapID = mapID,
                            name = name, shortName = ShortName(name), expansion = expansion,
                            abbreviation = Abbreviation(name, "EJ" .. tostring(instanceID)),
                            isRaid = isRaid,
                            tierOrder = EXPANSION_ORDER[expansion] or (tierCount - tier + 1),
                            indexOrder = index,
                        }
                    end
                end
            end
        end
        if previousTier then EJ_SelectTier(previousTier) end
    end

    local names = {}
    for _, item in pairs(instanceCatalog) do names[item.name] = true end
    local legacyIndex = {}
    for _, definition in ipairs(LEGACY_RAIDS) do
        legacyIndex[definition.expansion] = (legacyIndex[definition.expansion] or 0) + 1
        local localizedName = GetRealZoneText and GetRealZoneText(definition.mapID)
        local name = localizedName and localizedName ~= "" and localizedName or definition.name
        if not names[name] then
            local key = "legacy:" .. tostring(definition.mapID)
            instanceCatalog[key] = {
                key = key, instanceID = definition.mapID,
                mapID = definition.mapID,
                name = name, shortName = ShortName(name), expansion = definition.expansion,
                abbreviation = Abbreviation(name, definition.abbr),
                isRaid = true, tierOrder = EXPANSION_ORDER[definition.expansion],
                indexOrder = legacyIndex[definition.expansion],
            }
            names[name] = true
        end
    end
    return instanceCatalog
end

function YAB.GetInstanceCatalog()
    return BuildInstanceCatalog()
end
function YAB.InvalidateInstanceCatalog() instanceCatalog = nil end

function YAB.SetLockoutColumnEnabled(key, enabled)
    local db = DB()
    local item = BuildInstanceCatalog()[tostring(key)]
    if not item then
        for _, candidate in pairs(BuildInstanceCatalog()) do
            if candidate.key == key then item = candidate; break end
        end
    end
    item = item or db.settings.lockoutColumns[tostring(key)]
    if item then
        local itemKey = item.key or tostring(key)
        db.settings.previewColumns["instance:" .. itemKey] = not not enabled
        if YAB.PersistDB then YAB.PersistDB() end
        if YAB.NotifyCorePageChanged then YAB.NotifyCorePageChanged() end
    end
end

function YAB.IsLockoutColumnEnabled(key)
    return DB().settings.previewColumns["instance:" .. tostring(key)] == true
end

function YAB.GetLockoutPreviewFieldDefinitions()
    local db, items, seen = DB(), {}, {}
    for _, item in pairs(BuildInstanceCatalog()) do
        items[#items + 1] = item
        seen[item.key] = true
    end
    for key, item in pairs(db.settings.lockoutColumns) do
        if not seen[key] then
            local copy = {}
            for field, value in pairs(item) do copy[field] = value end
            copy.key = key
            items[#items + 1] = copy
        end
    end
    table.sort(items, function(a, b)
        if (a.tierOrder or 999) ~= (b.tierOrder or 999) then return (a.tierOrder or 999) < (b.tierOrder or 999) end
        if a.isRaid ~= b.isRaid then return a.isRaid == true end
        if (a.indexOrder or 999) ~= (b.indexOrder or 999) then return (a.indexOrder or 999) < (b.indexOrder or 999) end
        return tostring(a.key) < tostring(b.key)
    end)
    local result, counts = {}, {}
    for _, item in ipairs(items) do
        local label = item.expansion or _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.OTHER")
        counts[label] = (counts[label] or 0) + 1
        local page = math.floor((counts[label] - 1) / 12) + 1
        result[#result + 1] = { id = "instance:" .. item.key, title = item.name or item.key,
            group = string.format("%s · %d", label, page) }
    end
    return result
end

local function EnsureCharacter(key)
    if not key then return nil end
    local db = DB()
    local record = db.characters[key] or {}
    record.instanceLockouts = record.instanceLockouts or {}
    record.statistics = record.statistics or { bosses = {}, instances = {}, recent = {} }
    record.statistics.bosses = record.statistics.bosses or {}
    record.statistics.instances = record.statistics.instances or {}
    record.statistics.recent = record.statistics.recent or {}
    db.characters[key] = record
    return record
end

local UpdateProgressMonitor
local function Notify()
    if UpdateProgressMonitor then UpdateProgressMonitor() end
    if YAB.PersistDB then YAB.PersistDB() end
    if YAB.NotifyCorePageChanged then YAB.NotifyCorePageChanged() end
end

local function InstanceInfo()
    local name, instanceType, difficultyID, difficultyName, maxPlayers, _, _, instanceID, _, lfgDungeonID = GetInstanceInfo()
    return name, instanceType, difficultyID, difficultyName, maxPlayers, instanceID, lfgDungeonID
end

local function IsNormalFiveMan()
    local _, instanceType, difficultyID, _, maxPlayers, _, lfgDungeonID = InstanceInfo()
    return instanceType == "party"
        and tonumber(maxPlayers or 0) <= 5
        and tonumber(difficultyID or 0) == 1
        and not lfgDungeonID
end

local function PruneThrottle(bucket, now)
    local kept = {}
    for _, entry in ipairs(bucket.entries or {}) do
        if now - (tonumber(entry.at) or 0) < 3600 then kept[#kept + 1] = entry end
    end
    bucket.entries = kept
end

function YAB.RecordNormalInstanceEntry()
    if not IsNormalFiveMan() then return end
    local name, _, difficultyID, difficultyName, _, instanceID = InstanceInfo()
    if not instanceID then return end
    local db, now = DB(), Now()
    local realm = CurrentRealm()
    local bucket = throttleRuntime[realm] or { entries = {} }
    PruneThrottle(bucket, now)
    local key = tostring(instanceID) .. ":" .. tostring(difficultyID or 1)
    for _, entry in ipairs(bucket.entries) do
        if entry.key == key then throttleRuntime[realm] = bucket; return end
    end
    local character = EnsureCharacter(CurrentKey())
    if character then
        local statKey = tostring(name) .. ":" .. tostring(difficultyID or 1)
        local stat = character.statistics.instances[statKey] or { name = name, difficultyID = difficultyID, runs = 0, firstAt = now }
        stat.runs = (stat.runs or 0) + 1
        stat.lastAt = now
        character.statistics.instances[statKey] = stat
    end
    bucket.entries[#bucket.entries + 1] = {
        key = key, name = ShortName(name), difficultyID = difficultyID,
        difficultyName = difficultyName or _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.NORMAL"), at = now,
    }
    throttleRuntime[realm] = bucket
    Notify()
end

function YAB.GetThrottleStatus()
    local db, now = DB(), Now()
    local realm = CurrentRealm()
    local bucket = throttleRuntime[realm] or { entries = {} }
    PruneThrottle(bucket, now)
    throttleRuntime[realm] = bucket
    local earliest
    for _, entry in ipairs(bucket.entries) do
        earliest = math.min(earliest or (entry.at + 3600), entry.at + 3600)
    end
    return #bucket.entries, db.settings.normalInstanceLimit, earliest, bucket.entries
end

local function SameLockouts(left, right, key)
    if key == "resetAt" and type(left) == "number" and type(right) == "number" then return math.abs(left - right) <= 2 end
    if type(left) ~= type(right) then return false end
    if type(left) ~= "table" then return left == right end
    for field, value in pairs(left) do if not SameLockouts(value, right[field], field) then return false end end
    for field in pairs(right) do if left[field] == nil then return false end end
    return true
end

function YAB.RefreshInstanceLockouts()
    local key = CurrentKey()
    local record = EnsureCharacter(key)
    if not record or not GetNumSavedInstances then return end
    local lockouts, now, directoryChanged = {}, Now(), false
    for index = 1, GetNumSavedInstances() do
        local name, id, reset, difficultyID, locked, extended, _, _, maxPlayers, difficultyName, numEncounters, _, _, instanceID = GetSavedInstanceInfo(index)
        if locked and name then
            local lockKey = tostring(instanceID or id or name) .. ":" .. tostring(difficultyID or difficultyName or "normal")
            local item = {
                key = lockKey, name = name, shortName = ShortName(name), id = id,
                instanceID = instanceID, resetAt = reset and now + reset or 0,
                difficultyID = difficultyID,
                difficultyName = difficultyName or (GetDifficultyInfo and GetDifficultyInfo(difficultyID)) or tostring(difficultyID or ""),
                maxPlayers = maxPlayers,
                locked = locked, extended = extended, bosses = {},
            }
            if GetSavedInstanceEncounterInfo then
                local bossCount = 0
                for bossIndex = 1, 20 do
                    local bossName, _, isKilled = GetSavedInstanceEncounterInfo(index, bossIndex)
                    if not bossName then break end
                    -- Return #4 is not a DungeonEncounterID. Resolve the
                    -- localized API label only inside a verified map/difficulty
                    -- directory, then persist its stable business identity.
                    local encounterID = YAB.TargetCatalog and YAB.TargetCatalog:ResolveSavedEncounter(instanceID, difficultyID, bossName)
                    bossCount = bossCount + 1
                    item.bosses[#item.bosses + 1] = { name = bossName, killed = isKilled, encounterID = encounterID }
                end
                item.bossCount = tonumber(numEncounters) or bossCount
                if YAB.TargetCatalog and YAB.TargetCatalog:ObserveLegacyLockout(item) then directoryChanged = true end
                for _, boss in ipairs(item.bosses) do
                    boss.encounterID = YAB.TargetCatalog and YAB.TargetCatalog:ResolveSavedEncounter(instanceID, difficultyID, boss.name)
                end
            end
            lockouts[lockKey] = item
        end
    end
    local changed = not record.instanceLockoutsObservedAt or not SameLockouts(record.instanceLockouts, lockouts)
    record.instanceLockouts = lockouts
    record.instanceLockoutsObservedAt = now
    if YAB.GetDungeonRunToken then YAB.GetDungeonRunToken() end
    if YAB.PlannedTargets and YAB.PlannedTargets.providerRef then
        record.targetLockoutCycles = { weekly = YAB.PlannedTargets:Period("weekly"), daily = YAB.PlannedTargets:Period("daily") }
        YAB.PlannedTargets:ScheduleChange()
        if directoryChanged then
            YiboCore.Contracts:NotifyChanged("YiboAltoBoss", YAB.PlannedTargets.catalogRef, { reason = "legacy-directory-observed" })
        end
    end
    if changed then Notify() end
end

function YAB.GetLockoutColumns(context)
    local db, result, seen = DB(), {}, {}
    local function Add(item, key)
        if not item then return end
        local mapID = item.mapID or item.instanceID
        local identity = mapID and ("instance:" .. tostring(mapID)) or ("name:" .. tostring(item.name or key))
        if seen[identity] then return end
        seen[identity] = true
        result[#result + 1] = {
            key = item.key or key,
            name = item.name or key,
            shortName = item.shortName or ShortName(item.name or key),
            abbreviation = item.abbreviation or Abbreviation(item.name or key, item.instanceID and ("ID" .. tostring(item.instanceID)) or nil),
            difficultyName = item.difficultyName,
            expansion = item.expansion,
            instanceID = mapID,
            mapID = mapID,
            isRaid = item.isRaid,
            tierOrder = item.tierOrder,
            indexOrder = item.indexOrder,
        }
    end

    local preview = context and context.preview
    if not preview then
        -- The formal page is the complete account matrix.  Pinning only
        -- controls the hover projection and must never remove page columns.
        for key, item in pairs(BuildInstanceCatalog()) do Add(item, item.key or key) end
    else
        -- Hover starts with the user's fixed columns.
        for key, item in pairs(BuildInstanceCatalog()) do
            if YAB.IsLockoutColumnEnabled(item.key or key) then Add(item, item.key or key) end
        end
        for key, item in pairs(db.settings.lockoutColumns or {}) do
            if YAB.IsLockoutColumnEnabled(key) then
                local catalogItem = item.instanceID and BuildInstanceCatalog()[tostring(item.instanceID)]
                Add(catalogItem or item, item.key or key)
            end
        end
    end
    -- Active lockouts supplement both projections.  On the formal page this
    -- also keeps a saved instance visible if Encounter Journal data is not
    -- ready yet; in hover it is the temporary-column half of the union rule.
    for _, charKey in ipairs(YAB.GetAccountCharacterKeys and YAB.GetAccountCharacterKeys(context) or {}) do
        local record = EnsureCharacter(charKey)
        for key, item in pairs(record.instanceLockouts or {}) do
            if not item.resetAt or item.resetAt <= 0 or item.resetAt > Now() then
                local catalogItem = item.instanceID and BuildInstanceCatalog()[tostring(item.instanceID)]
                Add(catalogItem or item, key)
            end
        end
    end
    table.sort(result, function(a, b)
        local leftTier, rightTier = a.tierOrder or 999, b.tierOrder or 999
        if leftTier ~= rightTier then return leftTier < rightTier end
        if a.isRaid ~= b.isRaid then return a.isRaid == true end
        local leftIndex, rightIndex = a.indexOrder or 999, b.indexOrder or 999
        if leftIndex ~= rightIndex then return leftIndex < rightIndex end
        return tostring(a.shortName) < tostring(b.shortName)
    end)
    return result
end

local function NormalDungeonProgress(record, column)
    if column.isRaid or (column.difficultyID and column.difficultyID ~= 1) or not YAB.DungeonRuns then return end
    local mapID = tonumber(column.mapID or column.instanceID)
    if not mapID then return end
    if YAB.DungeonRuns:IsStale(record, mapID, 1) then
        return "unknown", Core.Locale:Get("YiboAltoBoss", "TP.STALE")
    end
    local killed = YAB.DungeonRuns:GetProgress(record, mapID, 1)
    if killed == 0 then return end
    local total
    if YAB.TargetCatalog then
        for _, target in ipairs(YAB.TargetCatalog:Query().targets or {}) do
            if target.kind == "instance" and target.mapID == mapID and not target.isRaid then
                for _, difficulty in ipairs(target.difficulties or {}) do
                    if difficulty.id == 1 and difficulty.complete and #(difficulty.encounters or {}) > 0 then
                        total = #difficulty.encounters
                        break
                    end
                end
                break
            end
        end
    end
    -- Verified MoP Stockade roster: Hogger, Lord Overheat, Randolph Moloch.
    -- The general death whitelist is deliberately incomplete and is not a total.
    if not total and mapID == 34 then total = 3 end
    if total and killed <= total then
        return killed == total and "clear" or "progress", Core.Locale:Get("YiboAltoBoss", "LOCKOUT.PROGRESS", killed, total)
    end
    return "progress", Core.Locale:Get("YiboAltoBoss", "LOCKOUT.KILL_COUNT", killed)
end

function YAB.GetLockoutStatus(charKey, column)
    local record = EnsureCharacter(charKey)
    local lockout = record and record.instanceLockouts and record.instanceLockouts[column.key]
    if lockout and column.difficultyID and lockout.difficultyID ~= column.difficultyID then lockout = nil end
    if not lockout and record and record.instanceLockouts then
        for _, candidate in pairs(record.instanceLockouts) do
            if ((column.instanceID and candidate.instanceID == column.instanceID) or (candidate.name == column.name))
                and (not column.difficultyID or candidate.difficultyID == column.difficultyID) then
                lockout = candidate
                break
            end
        end
    end
    if not lockout then
        local status, label = NormalDungeonProgress(record, column)
        if status then return status, label, nil end
        if not record.instanceLockoutsObservedAt then return "unknown", Core.Locale:Get("YiboAltoBoss", "LOCKOUT.UNKNOWN"), nil end
        return "open", Core.Locale:Get("YiboAltoBoss", "LOCKOUT.OPEN"), nil
    end
    local killed, total = 0, tonumber(lockout.bossCount) or 0
    for _, boss in ipairs(lockout.bosses or {}) do if boss.killed then killed = killed + 1 end end
    local completed = total > 0 and killed >= total
    local label = completed and Core.Locale:Get("YiboAltoBoss", "LOCKOUT.CLEAR") or (total > 0 and Core.Locale:Get("YiboAltoBoss", "LOCKOUT.PROGRESS", killed, total) or Core.Locale:Get("YiboAltoBoss", "LOCKOUT.LOCKED"))
    return completed and "clear" or "locked", label, lockout
end

function YAB.GetLockoutTooltip(charKey, column)
    local status, label, lockout = YAB.GetLockoutStatus(charKey, column)
    local record = EnsureCharacter(charKey)
    local options = DB().settings.lockoutTooltip or {}
    local mapID = tonumber(column.mapID or column.instanceID)
    local difficultyID = lockout and lockout.difficultyID or column.difficultyID or 1
    local function Text(key, ...) return Core.Locale:Get("YiboAltoBoss", key, ...) end
    local difficulty = lockout and lockout.difficultyName or (GetDifficultyInfo and GetDifficultyInfo(difficultyID))
    if column.isRaid and not lockout then difficulty = nil end
    local heading = difficulty and Text("TP.TITLE", column.name, difficulty) or column.name
    local colors = Core.UITheme and Core.UITheme.Colors or {}
    if not lockout and not column.isRaid and status == "open" then label = Text("TP.NOT_STARTED") end
    local lines = { { kind = "pair", label = heading, value = label,
        labelColor = colors.text, valueColor = status == "clear" and colors.success or colors.accent } }
    if not lockout and not column.isRaid and YAB.DungeonRuns:IsStale(record, mapID, difficultyID) then
        lines[#lines + 1] = { kind = "text", text = Text("TP.STALE_HINT"), color = colors.muted }
    end
    if lockout and lockout.resetAt and lockout.resetAt > Now() then
        lines[#lines + 1] = { kind = "pair", label = Text("TP.RESET"), value = date("%m-%d %H:%M", lockout.resetAt) }
    end
    local history, byEncounter, byName = {}, {}, {}
    for _, boss in pairs(record.statistics.bosses or {}) do
        if (mapID and boss.instanceID == mapID or boss.instanceName == column.name)
            and (boss.difficultyID or 1) == difficultyID then
            history[#history + 1] = boss
            if boss.encounterID then byEncounter[boss.encounterID] = boss end
            byName[boss.name] = boss
        end
    end
    local roster = {}
    if lockout then
        for _, boss in ipairs(lockout.bosses or {}) do
            local stat
            for _, candidate in ipairs(history) do if candidate.name == boss.name then stat = candidate; break end end
            roster[#roster + 1] = { name = boss.name, killed = boss.killed == true, stat = stat }
        end
    elseif not column.isRaid then
        local directory
        if YAB.TargetCatalog then
            for _, target in ipairs(YAB.TargetCatalog:Query().targets or {}) do
                if target.kind == "instance" and target.mapID == mapID then
                    for _, d in ipairs(target.difficulties or {}) do
                        if d.id == difficultyID and d.complete then directory = d.encounters; break end
                    end
                    break
                end
            end
        end
        if directory then
            for _, boss in ipairs(directory) do
                local stat = byEncounter[boss.id] or byName[boss.name]
                roster[#roster + 1] = { name = boss.name, stat = stat,
                    killed = YAB.DungeonRuns:IsCompleted(record, mapID, difficultyID, boss.id, stat and stat.npcID) }
            end
        else
            -- Historical names identify known bosses; lifetime counts never imply current completion.
            table.sort(history, function(a, b)
                if (a.encounterID or 0) ~= (b.encounterID or 0) then return (a.encounterID or 0) < (b.encounterID or 0) end
                return a.name < b.name
            end)
            for _, boss in ipairs(history) do
                roster[#roster + 1] = { name = boss.name, stat = boss,
                    killed = YAB.DungeonRuns:IsCompleted(record, mapID, difficultyID, boss.encounterID, boss.npcID) }
            end
        end
    end
    if #roster > 0 then lines[#lines + 1] = { kind = "spacer" } end
    for _, boss in ipairs(roster) do
        local key = boss.killed == true and "TP.KILLED" or boss.killed == false and "TP.ALIVE" or "TP.UNKNOWN"
        lines[#lines + 1] = { kind = "pair", label = boss.name, value = Text(key), labelColor = colors.text,
            valueColor = boss.killed and colors.success or colors.text }
        local details = {}
        if options.historyKills and boss.stat then details[#details + 1] = Text("TP.HISTORY", tonumber(boss.stat.kills) or 0) end
        if options.lastKill and boss.stat and boss.stat.lastAt then details[#details + 1] = Text("TP.LAST", date("%m-%d %H:%M", boss.stat.lastAt)) end
        if #details > 0 then lines[#lines + 1] = { kind = "text", text = table.concat(details, "  ·  "), color = colors.muted } end
    end
    -- Without a current raid lockout, history is shown only when explicitly requested.
    if column.isRaid and not lockout and (options.historyKills or options.lastKill) then
        table.sort(history, function(a, b) return a.name < b.name end)
        for _, boss in ipairs(history) do
            local details = {}
            if options.historyKills then details[#details + 1] = Text("TP.HISTORY", tonumber(boss.kills) or 0) end
            if options.lastKill and boss.lastAt then details[#details + 1] = Text("TP.LAST", date("%m-%d %H:%M", boss.lastAt)) end
            lines[#lines + 1] = { kind = "pair", label = boss.name, value = table.concat(details, "  ·  ") }
        end
    end
    if options.entryCount then
        for _, stat in pairs(record.statistics.instances or {}) do
            if stat.name == column.name and stat.difficultyID == difficultyID then
                lines[#lines + 1] = { kind = "pair", label = Text("TP.ENTRIES"), value = Text("TP.TIMES", tonumber(stat.runs) or 0) }
                break
            end
        end
    end
    return lines
end

function YAB.RecordEncounterKill(encounterName, encounterID, evidence)
    evidence = evidence or {}
    local key = CurrentKey()
    local record = EnsureCharacter(key)
    if not record or not encounterName then return end
    local instanceName, instanceType, difficultyID, _, maxPlayers, instanceID = InstanceInfo()
    if instanceType ~= "party" and instanceType ~= "raid" then return end
    local now = Now()
    local legacyToken = tostring(instanceName) .. ":" .. tostring(difficultyID) .. ":" .. tostring(encounterName)
    local identity = tonumber(encounterID) and tonumber(encounterID) > 0 and ("encounter:" .. encounterID)
        or evidence.npcID and ("npc:" .. evidence.npcID)
    local token = identity and ("instance:" .. tostring(instanceID) .. ":" .. tostring(difficultyID) .. ":" .. identity) or legacyToken
    local guidToken = evidence.guid and ("guid:" .. evidence.guid)
    if guidToken and record.statistics.recent[guidToken] and now - record.statistics.recent[guidToken] < 3600 then return end
    local dungeon = instanceType == "party" and tonumber(maxPlayers or 0) <= 5
        and identity and YAB.DungeonRuns
    if dungeon then
        YAB.GetDungeonRunToken(evidence.guid)
        local npcID = evidence.npcID
        if not npcID and encounterID then
            for id, nativeID in pairs(YAB.DungeonBossCatalog[instanceID] or {}) do
                if nativeID == tonumber(encounterID) then npcID = id; break end
            end
        end
        if not YAB.DungeonRuns:Claim(record, instanceID, difficultyID, instanceName, identity, npcID, evidence.guid) then return end
    else
        -- Raid recording retains its existing short-window correlation.
        for _, recentKey in ipairs({ token, legacyToken }) do
            if record.statistics.recent[recentKey] and now - record.statistics.recent[recentKey] < 60 then return end
        end
    end
    for recentKey, at in pairs(record.statistics.recent) do
        if type(at) ~= "number" or now - at > 3600 then record.statistics.recent[recentKey] = nil end
    end
    record.statistics.recent[token], record.statistics.recent[legacyToken] = now, now
    if guidToken then record.statistics.recent[guidToken] = now end
    -- Enrich an existing legacy statistic in place; do not duplicate its total.
    local statKey = record.statistics.bosses[token] and token or record.statistics.bosses[legacyToken] and legacyToken or token
    if not record.statistics.bosses[statKey] then
        for existingKey, stat in pairs(record.statistics.bosses) do
            if stat.instanceID == instanceID and stat.difficultyID == difficultyID
                and ((evidence.npcID and stat.npcID == evidence.npcID) or stat.name == encounterName) then
                statKey = existingKey
                break
            end
        end
    end
    local boss = record.statistics.bosses[statKey] or { name = encounterName, instanceName = instanceName, kills = 0, firstAt = now }
    boss.kills = (boss.kills or 0) + 1
    boss.lastAt = now
    boss.instanceID, boss.difficultyID = instanceID, difficultyID
    boss.encounterID = tonumber(encounterID) or boss.encounterID
    boss.npcID = evidence.npcID or boss.npcID
    boss.lastSource = evidence.source or "encounter-event"
    record.statistics.bosses[statKey] = boss
    Notify()
end

function YAB.GetDungeonRunToken(guid)
    local name, kind, difficultyID, _, maxPlayers, mapID = InstanceInfo()
    maxPlayers = tonumber(maxPlayers)
    if kind ~= "party" or not maxPlayers or maxPlayers < 1 or maxPlayers > 5 or not YAB.DungeonRuns then return end
    local record = EnsureCharacter(CurrentKey())
    if not record then return end
    if not guid and UnitGUID then
        for _, unit in ipairs({ "target", "boss1", "boss2", "boss3", "boss4" }) do
            local value = UnitGUID(unit)
            if value and value:match("^Creature%-") then guid = value; break end
        end
    end
    return YAB.DungeonRuns:Observe(record, mapID, difficultyID, name, guid)
end

function YAB.RecordDungeonDeath(guid, name)
    if type(guid) ~= "string" or not name then return end
    local npcID = tonumber(guid:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-"))
    if not npcID then return end
    local _, instanceType, difficultyID, _, maxPlayers, instanceID = InstanceInfo()
    if instanceType ~= "party" or tonumber(maxPlayers or 0) > 5 then return end
    local bosses = YAB.DungeonBossCatalog and YAB.DungeonBossCatalog[instanceID]
    local encounterID = bosses and bosses[npcID]
    if encounterID == nil then return end
    if YAB.TargetCatalog and YAB.TargetCatalog.ResolveSavedEncounter then
        local currentID = YAB.TargetCatalog:ResolveSavedEncounter(instanceID, difficultyID, name)
        if type(currentID) == "number" and currentID > 0 then encounterID = currentID end
    end
    YAB.RecordEncounterKill(name, encounterID > 0 and encounterID or nil, {
        npcID = npcID, guid = guid, source = "unit-died",
    })
end

function YAB.ResetInstanceKillDedupe(instanceName)
    local record = EnsureCharacter(CurrentKey())
    if not record then return end
    if YAB.DungeonRuns then
        local difficultyID = (GetDungeonDifficultyID and GetDungeonDifficultyID()) or 1
        YAB.DungeonRuns:Reset(record, instanceName, difficultyID)
    end
    local prefixes = { tostring(instanceName) .. ":" }
    for _, stat in pairs(record.statistics.bosses) do
        if stat.instanceName == instanceName and stat.instanceID then
            prefixes[#prefixes + 1] = "instance:" .. stat.instanceID .. ":"
        end
    end
    for token in pairs(record.statistics.recent) do
        for _, prefix in ipairs(prefixes) do
            if token:sub(1, #prefix) == prefix then record.statistics.recent[token] = nil; break end
        end
    end
    Notify()
end

local frame = CreateFrame("Frame")
local activeNormalMap
local function MarkProgressLeave(record, mapID)
    local state = (record.statistics.dungeonCycles or {})[tostring(mapID) .. ":1"]
    if state and next(state.completed or {}) then YAB.DungeonRuns:Leave(record, mapID, 1) end
end
local function SyncDungeonDeathListener()
    local _, instanceType, difficultyID, _, maxPlayers, mapID = InstanceInfo()
    local record = EnsureCharacter(CurrentKey())
    local normalMap = instanceType == "party" and tonumber(maxPlayers or 0) <= 5 and difficultyID == 1 and mapID or nil
    if record and YAB.DungeonRuns then
        if activeNormalMap and activeNormalMap ~= normalMap then MarkProgressLeave(record, activeNormalMap) end
        if not activeNormalMap then
            -- Covers login outside, missed exits and pre-timeout-format data.
            -- Unknown old observation times expire immediately, without
            -- deleting completion facts or pretending the dungeon reset.
            for key, state in pairs(record.statistics.dungeonCycles or {}) do
                local savedMap = tonumber(key:match("^(%d+):1$"))
                if savedMap and savedMap ~= normalMap then
                    YAB.DungeonRuns:IsStale(record, savedMap, 1)
                    MarkProgressLeave(record, savedMap)
                end
            end
        end
    end
    activeNormalMap = normalMap
    if instanceType == "party" and tonumber(maxPlayers or 0) <= 5 then
        YAB.GetDungeonRunToken()
        frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    else
        frame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    end
    if UpdateProgressMonitor then UpdateProgressMonitor() end
end
local requestQueued, requestPending, requestToken, lastRequestAt = false, false, 0, -math.huge
local function ScheduleRequest()
    if requestQueued or requestPending then return end
    requestQueued = true
    local delay = math.max(1, 5 - ((GetTime and GetTime() or 0) - lastRequestAt))
    C_Timer.After(delay, function()
        requestQueued = false
        if requestPending then return end
        YAB.RecordNormalInstanceEntry()
        if not RequestRaidInfo then YAB.RefreshInstanceLockouts(); return end
        requestPending, lastRequestAt = true, GetTime and GetTime() or 0
        requestToken = requestToken + 1
        local token = requestToken
        RequestRaidInfo()
        C_Timer.After(5, function()
            if requestPending and requestToken == token then
                requestPending = false
                YAB.RefreshInstanceLockouts()
            end
        end)
    end)
end

local function IsResetMessage(message)
    if type(message) ~= "string" then return false end
    for _, name in ipairs({ "INSTANCE_RESET_SUCCESS", "INSTANCE_RESET_FAILED", "INSTANCE_RESET_FAILED_ZONING", "INSTANCE_RESET_FAILED_OFFLINE" }) do
        local format = _G[name]
        if type(format) == "string" then
            local pattern = format:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"):gsub("%%%%s", "(.+)"):gsub("%%%%d", "%%d+")
            local instanceName = message:match("^" .. pattern .. "$")
            if instanceName then return true, name == "INSTANCE_RESET_SUCCESS" and instanceName or nil end
        end
    end
    return false
end

for _, event in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_LOGOUT", "RAID_INSTANCE_WELCOME", "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED_INDOORS", "UPDATE_INSTANCE_INFO", "ENCOUNTER_END", "BOSS_KILL", "CHAT_MSG_SYSTEM" }) do frame:RegisterEvent(event) end
frame:SetScript("OnEvent", function(_, event, encounterID, encounterName, difficultyID, _, success)
    if event == "PLAYER_LOGOUT" then
        local record = EnsureCharacter(CurrentKey())
        if record and activeNormalMap and YAB.DungeonRuns then YAB.DungeonRuns:Leave(record, activeNormalMap, 1) end
        return
    end
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local _, subevent, _, _, _, _, _, guid, name = CombatLogGetCurrentEventInfo()
        if subevent == "UNIT_DIED" then
            YAB.GetDungeonRunToken(guid)
            YAB.RecordDungeonDeath(guid, name)
        end
        return
    end
    if event == "UPDATE_INSTANCE_INFO" then
        requestPending = false
        YAB.RefreshInstanceLockouts()
        return
    end
    if event == "ENCOUNTER_END" then
        if tonumber(success) == 1 then YAB.RecordEncounterKill(encounterName, encounterID) end
        C_Timer.After(1, YAB.RefreshInstanceLockouts)
        return
    end
    if event == "BOSS_KILL" then
        YAB.RecordEncounterKill(encounterName, encounterID)
        return
    end
    if event == "CHAT_MSG_SYSTEM" then
        local isReset, resetName = IsResetMessage(encounterID)
        if resetName then YAB.ResetInstanceKillDedupe(resetName) end
        if isReset then ScheduleRequest() end
        return
    end
    SyncDungeonDeathListener()
    ScheduleRequest()
end)

-- Only nonempty, unexpired normal progress needs the periodic safety check.
-- The OnUpdate handler is detached entirely when that work set is empty.
local progressElapsed = 0
local progressStates = setmetatable({}, { __mode = "k" })
local monitoringProgress = false
local function CheckProgress(_, elapsed)
    progressElapsed = progressElapsed + elapsed
    if progressElapsed < 15 or not YAB.DungeonRuns then return end
    progressElapsed = 0
    SyncDungeonDeathListener()
    local changed = false
    for _, record in pairs(DB().characters) do
        if record.statistics then
            local previous = progressStates[record] or {}
            progressStates[record] = previous
            for key in pairs(record.statistics.dungeonCycles or {}) do
                local mapID = tonumber(key:match("^(%d+):1$"))
                if mapID then
                    local stale = YAB.DungeonRuns:IsStale(record, mapID, 1)
                    if previous[key] ~= stale and (previous[key] ~= nil or stale) then changed = true end
                    previous[key] = stale
                end
            end
        end
    end
    if changed then Notify() end
    if UpdateProgressMonitor then UpdateProgressMonitor() end
end

UpdateProgressMonitor = function()
    local needed = false
    if YAB.DungeonRuns then
        for _, record in pairs(DB().characters) do
            for key, state in pairs(record.statistics and record.statistics.dungeonCycles or {}) do
                local mapID = tonumber(key:match("^(%d+):1$"))
                if mapID and next(state.completed or {}) and not YAB.DungeonRuns:IsStale(record, mapID, 1) then
                    needed = true
                    break
                end
            end
            if needed then break end
        end
    end
    if needed == monitoringProgress then return end
    monitoringProgress = needed
    progressElapsed = 0
    frame:SetScript("OnUpdate", needed and CheckProgress or nil)
end
