local YAB = _G.YAB
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
    { expansion = "巫妖王之怒", mapID = 724, name = "红玉圣殿", abbr = "RS" },
    { expansion = "巫妖王之怒", mapID = 631, name = "冰冠堡垒", abbr = "ICC" },
    { expansion = "巫妖王之怒", mapID = 649, name = "十字军的试炼", abbr = "ToC" },
    { expansion = "巫妖王之怒", mapID = 249, name = "奥妮克希亚的巢穴", abbr = "Ony" },
    { expansion = "巫妖王之怒", mapID = 603, name = "奥杜尔", abbr = "ULD" },
    { expansion = "巫妖王之怒", mapID = 624, name = "阿尔卡冯的宝库", abbr = "VoA" },
    { expansion = "巫妖王之怒", mapID = 616, name = "永恒之眼", abbr = "EoE" },
    { expansion = "巫妖王之怒", mapID = 615, name = "黑曜石圣殿", abbr = "OS" },
    { expansion = "巫妖王之怒", mapID = 533, name = "纳克萨玛斯", abbr = "NAXX" },
    { expansion = "燃烧的远征", mapID = 580, name = "太阳之井高地", abbr = "SWP" },
    { expansion = "燃烧的远征", mapID = 564, name = "黑暗神殿", abbr = "BT" },
    { expansion = "燃烧的远征", mapID = 534, name = "海加尔峰", abbr = "MH" },
    { expansion = "燃烧的远征", mapID = 550, name = "风暴要塞", abbr = "TK" },
    { expansion = "燃烧的远征", mapID = 548, name = "毒蛇神殿", abbr = "SSC" },
    { expansion = "燃烧的远征", mapID = 544, name = "玛瑟里顿的巢穴", abbr = "Mag" },
    { expansion = "燃烧的远征", mapID = 565, name = "格鲁尔的巢穴", abbr = "Gruul" },
    { expansion = "燃烧的远征", mapID = 532, name = "卡拉赞", abbr = "Kara" },
    { expansion = "经典旧世", mapID = 531, name = "安其拉神殿", abbr = "AQ40" },
    { expansion = "经典旧世", mapID = 509, name = "安其拉废墟", abbr = "AQ20" },
    { expansion = "经典旧世", mapID = 469, name = "黑翼之巢", abbr = "BWL" },
    { expansion = "经典旧世", mapID = 409, name = "熔火之心", abbr = "MC" },
}

local function DB()
    YiboAltoBossDB = YiboAltoBossDB or {}
    YiboAltoBossDB.characters = YiboAltoBossDB.characters or {}
    YiboAltoBossDB.settings = YiboAltoBossDB.settings or {}
    YiboAltoBossDB.settings.normalInstanceLimit = tonumber(YiboAltoBossDB.settings.normalInstanceLimit) or 5
    YiboAltoBossDB.settings.lockoutColumns = YiboAltoBossDB.settings.lockoutColumns or {}
    return YiboAltoBossDB
end

local function Now()
    return (GetServerTime and GetServerTime()) or time()
end

local function CurrentKey()
    return YAB.GetCurrentCharKey and YAB.GetCurrentCharKey()
end

local function CurrentRealm()
    return YAB.GetCurrentRealm and YAB.GetCurrentRealm() or GetRealmName() or "未知服务器"
end

local function ShortName(name)
    name = tostring(name or "未知副本")
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
            local expansion = (EJ_GetTierInfo and EJ_GetTierInfo(tier)) or ("资料片 " .. tostring(tier))
            for _, isRaid in ipairs({ false, true }) do
                for index = 1, 200 do
                    local instanceID = EJ_GetInstanceByIndex(index, isRaid)
                    if not instanceID then break end
                    local name = EJ_GetInstanceInfo(instanceID)
                    if name and not instanceCatalog[tostring(instanceID)] then
                        instanceCatalog[tostring(instanceID)] = {
                            key = "ej:" .. tostring(instanceID), instanceID = instanceID,
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

function YAB.SetLockoutColumnEnabled(key, enabled)
    local db = DB()
    local item = BuildInstanceCatalog()[tostring(key)]
    if not item then
        for _, candidate in pairs(BuildInstanceCatalog()) do
            if candidate.key == key then item = candidate; break end
        end
    end
    if item then
        db.settings.lockoutColumns[item.key] = {
            enabled = not not enabled, name = item.name, shortName = item.shortName,
            abbreviation = item.abbreviation, expansion = item.expansion, instanceID = item.instanceID,
        }
        if YAB.PersistDB then YAB.PersistDB() end
        if YAB.NotifyCorePageChanged then YAB.NotifyCorePageChanged() end
    end
end

function YAB.IsLockoutColumnEnabled(key)
    local saved = DB().settings.lockoutColumns[tostring(key)]
    return saved and saved.enabled == true or false
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

local function Notify()
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
        difficultyName = difficultyName or "普通", at = now,
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

function YAB.RefreshInstanceLockouts()
    local key = CurrentKey()
    local record = EnsureCharacter(key)
    if not record or not GetNumSavedInstances then return end
    local lockouts, now = {}, Now()
    for index = 1, GetNumSavedInstances() do
        local name, id, reset, difficultyID, locked, extended, _, _, maxPlayers, _, _, _, _, instanceID = GetSavedInstanceInfo(index)
        if locked and name then
            local lockKey = tostring(instanceID or id or name) .. ":" .. tostring(difficultyID or difficultyName or "normal")
            local item = {
                key = lockKey, name = name, shortName = ShortName(name), id = id,
                instanceID = instanceID, resetAt = reset and now + reset or 0,
                difficultyID = difficultyID,
                difficultyName = GetDifficultyInfo and (select(2, GetDifficultyInfo(difficultyID)) or "") or tostring(difficultyID or ""),
                maxPlayers = maxPlayers,
                locked = locked, extended = extended, bosses = {},
            }
            if GetSavedInstanceEncounterInfo then
                local bossCount = 0
                for bossIndex = 1, 20 do
                    local bossName, _, isKilled, encounterID = GetSavedInstanceEncounterInfo(index, bossIndex)
                    if not bossName then break end
                    bossCount = bossCount + 1
                    item.bosses[#item.bosses + 1] = { name = bossName, killed = isKilled, encounterID = encounterID }
                end
                item.bossCount = bossCount
            end
            lockouts[lockKey] = item
        end
    end
    record.instanceLockouts = lockouts
    record.instanceLockoutsObservedAt = now
    Notify()
end

function YAB.GetLockoutColumns(context)
    local db, result, seen = DB(), {}, {}
    local function Add(item, key)
        if not item then return end
        local identity = item.instanceID and ("instance:" .. tostring(item.instanceID)) or ("name:" .. tostring(item.name or key))
        if seen[identity] then return end
        seen[identity] = true
        result[#result + 1] = {
            key = item.key or key,
            name = item.name or key,
            shortName = item.shortName or ShortName(item.name or key),
            abbreviation = item.abbreviation or Abbreviation(item.name or key, item.instanceID and ("ID" .. tostring(item.instanceID)) or nil),
            difficultyName = item.difficultyName,
            expansion = item.expansion,
            instanceID = item.instanceID,
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
        for key, item in pairs(db.settings.lockoutColumns or {}) do
            if item.enabled then
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

function YAB.GetLockoutStatus(charKey, column)
    local record = EnsureCharacter(charKey)
    local lockout = record and record.instanceLockouts and record.instanceLockouts[column.key]
    if not lockout and record and record.instanceLockouts then
        for _, candidate in pairs(record.instanceLockouts) do
            if (column.instanceID and candidate.instanceID == column.instanceID) or (candidate.name == column.name) then
                lockout = candidate
                break
            end
        end
    end
    if not lockout then
        if not record.instanceLockoutsObservedAt then return "unknown", "未扫描", nil end
        return "open", "未锁定", nil
    end
    local killed, total = 0, tonumber(lockout.bossCount) or 0
    for _, boss in ipairs(lockout.bosses or {}) do if boss.killed then killed = killed + 1 end end
    local completed = total > 0 and killed >= total
    local label = completed and "已完成" or (total > 0 and string.format("%d/%d", killed, total) or "已锁定")
    return completed and "clear" or "locked", label, lockout
end

function YAB.GetLockoutTooltip(charKey, column)
    local status, label, lockout = YAB.GetLockoutStatus(charKey, column)
    if not lockout then return { "未发现当前副本锁定" } end
    local charRecord = EnsureCharacter(charKey)
    local lines = { "状态：" .. label }
    for _, stat in pairs(charRecord.statistics.instances or {}) do
        if stat.name == lockout.name and stat.difficultyID == lockout.difficultyID then
            lines[#lines + 1] = "历史进入：" .. tostring(stat.runs or 0) .. " 次"
            break
        end
    end
    if lockout.difficultyName and lockout.difficultyName ~= "" then lines[#lines + 1] = "难度：" .. lockout.difficultyName end
    if lockout.resetAt and lockout.resetAt > 0 then lines[#lines + 1] = "重置：" .. date("%m-%d %H:%M", lockout.resetAt) end
    for _, boss in ipairs(lockout.bosses or {}) do
        local history
        for _, stat in pairs(charRecord.statistics.bosses or {}) do
            if stat.name == boss.name and stat.instanceName == lockout.name then history = stat.kills; break end
        end
        lines[#lines + 1] = (boss.killed and "已击杀  " or "未击杀  ") .. boss.name .. (history and ("  · 历史 " .. tostring(history) .. " 次") or "")
    end
    return lines
end

function YAB.RecordEncounterKill(encounterName, encounterID)
    local key = CurrentKey()
    local record = EnsureCharacter(key)
    if not record or not encounterName then return end
    local instanceName, instanceType, difficultyID = InstanceInfo()
    if instanceType ~= "party" and instanceType ~= "raid" then return end
    local now, token = Now(), tostring(instanceName) .. ":" .. tostring(difficultyID) .. ":" .. tostring(encounterName)
    if record.statistics.recent[token] and now - record.statistics.recent[token] < 60 then return end
    record.statistics.recent[token] = now
    local boss = record.statistics.bosses[token] or { name = encounterName, instanceName = instanceName, kills = 0, firstAt = now }
    boss.kills = (boss.kills or 0) + 1
    boss.lastAt = now
    record.statistics.bosses[token] = boss
    Notify()
end

local frame = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "RAID_INSTANCE_WELCOME", "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED_INDOORS", "UPDATE_INSTANCE_INFO", "ENCOUNTER_END", "BOSS_KILL", "CHAT_MSG_SYSTEM" }) do frame:RegisterEvent(event) end
frame:SetScript("OnEvent", function(_, event, encounterID, encounterName, difficultyID, _, success)
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
        C_Timer.After(0.5, YAB.RefreshInstanceLockouts)
        return
    end
    C_Timer.After(1, function()
        if RequestRaidInfo then RequestRaidInfo() end
        YAB.RefreshInstanceLockouts()
        YAB.RecordNormalInstanceEntry()
    end)
end)
