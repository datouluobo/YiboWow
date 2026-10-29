if _G.YAB and _G.YAB.CoreReady == false then return end
local ADDON_NAME = ...

local YAB = _G.YAB or {}
_G.YAB = YAB

YiboAltoBossDB = YiboAltoBossDB or {}

local curCharName = UnitName("player") or "Unknown"
local curRealm = GetRealmName() or "Unknown"
local curCharKey = curCharName .. "-" .. curRealm
local PHASE_TTL_SECONDS = 6 * 60 * 60
local MIN_RESPAWN_SAMPLE_SECONDS = 30
local CUSTOM_RARE_RESET_SECONDS = 24 * 60 * 60
local PERSONAL_COMBAT_EVIDENCE_TTL_SECONDS = 45
local bossById = {}
local bossByKey = {}
local npcTargets = {}
local customTargetCache = {}
local recentPersonalCombatTargets = {}
local personalCombatTargetCount, nextPersonalCombatSweep = 0, 0
local PERSONAL_COMBAT_TARGET_LIMIT = 512
local EnsureWorldTables

local function GetServerTimestamp()
    if GetServerTime then
        return GetServerTime()
    end
    return time()
end

local DEFAULT_BOSSES = {
    { key = "ordos", type = "single_npc", id = 72057, name = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.ORDOS"), reset = "weekly", order = 10, group = "world_boss" },
    { key = "celestials", type = "single_npc", name = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.AUGUST_CELESTIALS"), reset = "weekly", order = 20, group = "world_boss", allowedNpcIds = { 71952, 71953, 71954, 71955 }, npcNames = { [71952] = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.CHI_JI"), [71953] = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.XUEN"), [71954] = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.NIUZAO"), [71955] = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.YU_LON") }, trackPhase = false, hideAction = true, hidePhase = true },
    { key = "nalak", type = "single_npc", id = 69099, name = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.NALAK"), reset = "weekly", order = 30, group = "world_boss" },
    { key = "oondasta", type = "single_npc", id = 69161, name = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.OONDASTA"), reset = "weekly", order = 40, group = "world_boss" },
    { key = "galleon", type = "single_npc", id = 62346, name = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.GALLEON"), reset = "weekly", order = 50, group = "world_boss" },
    { key = "sha_of_anger", type = "single_npc", id = 60491, name = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.SHA_OF_ANGER"), reset = "weekly", order = 60, group = "world_boss" },
    { key = "warbringer_jade_forest", type = "location_rule", name = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.WARBRINGER_JADE_FOREST"), reset = "manual", order = 210, group = "warbringer", zoneKey = "jade_forest", zone = "翡翠林", allowedNpcIds = { 69769, 69841, 69842 } },
    { key = "warbringer_kun_lai_summit", type = "location_rule", name = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.WARBRINGER_KUN_LAI_SUMMIT"), reset = "manual", order = 220, group = "warbringer", zoneKey = "kun_lai_summit", zone = "昆莱山", allowedNpcIds = { 69769, 69841, 69842 } },
    { key = "warbringer_townlong_steppes", type = "location_rule", name = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.WARBRINGER_TOWNLONG_STEPPES"), reset = "manual", order = 230, group = "warbringer", zoneKey = "townlong_steppes", zone = "螳螂高原", allowedNpcIds = { 69769, 69841, 69842 } },
    { key = "warbringer_krasarang_wilds", type = "location_rule", name = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.WARBRINGER_KRASARANG_WILDS"), reset = "manual", order = 240, group = "warbringer", zoneKey = "krasarang_wilds", zone = "卡桑琅丛林", allowedNpcIds = { 69769, 69841, 69842 } },
    { key = "warbringer_dread_wastes", type = "location_rule", name = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.WARBRINGER_DREAD_WASTES"), reset = "manual", order = 250, group = "warbringer", zoneKey = "dread_wastes", zone = "恐惧废土", allowedNpcIds = { 69769, 69841, 69842 } },
}

local STANDARD_WORLD_BOSS_KEYS = {
    "ordos",
    "celestials",
    "nalak",
    "oondasta",
    "galleon",
    "sha_of_anger",
}

local TARGET_GROUPS = {
    { key = "world_boss", name = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.WORLD_BOSSES"), order = 10 },
    { key = "warbringer", name = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.WARBRINGERS"), order = 20 },
    { key = "custom", name = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.CUSTOM_TARGETS"), order = 30 },
}

-- These are server-side weekly loot-lockout flags, not player quest progress.
local WORLD_BOSS_LOCKOUT_IDS = {
    [62346] = 32098, -- 炮舰 / Galleon
    [60491] = 32099, -- 怒之煞 / Sha of Anger
    [69099] = 32518, -- 纳拉克 / Nalak
    [69161] = 32519, -- 乌达斯塔 / Oondasta
    celestials = 33117, -- 四天神共享周常锁定
    ordos = 33118, -- 斡耳朵斯周常锁定
}

local function CopyDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then
                target[key] = {}
            end
            CopyDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

local function EnsureSeenOrder(charKey)
    local maxSeen = 0
    for _, info in pairs(YiboAltoBossDB.knownChars) do
        if info.seenOrder and info.seenOrder > maxSeen then
            maxSeen = info.seenOrder
        end
    end

    if not YiboAltoBossDB.knownChars[charKey].seenOrder then
        YiboAltoBossDB.knownChars[charKey].seenOrder = maxSeen + 1
    end
end

local function GetCurrentWeeklyResetKey()
    if C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset then
        local secondsUntilReset = C_DateAndTime.GetSecondsUntilWeeklyReset()
        if type(secondsUntilReset) == "number" and secondsUntilReset > 0 then
            local nextResetAt = GetServerTimestamp() + math.floor(secondsUntilReset + 0.5)
            local normalizedResetAt = nextResetAt - (nextResetAt % 60)
            return "weekly:" .. tostring(normalizedResetAt)
        end
    end
    local serverTime = GetServerTimestamp()
    return date("%Y-%W", serverTime)
end

local function GetTargetResetKey(boss)
    if boss and boss.reset == "weekly" then
        return GetCurrentWeeklyResetKey()
    end
    return nil
end

local function IsKillActive(killData, boss)
    if not (killData and killData.killed) then
        return false
    end
    if boss and boss.reset == "respawn" then
        local killedAt = tonumber(killData.updatedAt) or 0
        -- Records written before expiresAt existed derive the same deadline
        -- from their original kill timestamp.
        local expiresAt = tonumber(killData.expiresAt)
        if not expiresAt and killedAt > 0 then
            expiresAt = killedAt + CUSTOM_RARE_RESET_SECONDS
            killData.expiresAt = expiresAt
        end
        return expiresAt and expiresAt > GetServerTimestamp() or false
    end
    local resetKey = GetTargetResetKey(boss)
    return not resetKey or killData.resetKey == resetKey
end

local function ExtractNpcIDFromGUID(guid)
    if type(guid) ~= "string" then
        return nil
    end

    local unitType, _, _, _, _, npcId = strsplit("-", guid)
    if unitType ~= "Creature" and unitType ~= "Vehicle" then
        return nil
    end

    npcId = tonumber(npcId)
    if npcId and npcId > 0 then
        return npcId
    end
    return nil
end

local function ExtractPhaseIDFromGUID(guid)
    if type(guid) ~= "string" then
        return nil
    end

    local unitType, _, _, _, zoneUID = strsplit("-", guid)
    if unitType ~= "Creature" and unitType ~= "Vehicle" then
        return nil
    end

    zoneUID = tonumber(zoneUID)
    if zoneUID and zoneUID > 0 then
        return zoneUID
    end
    return nil
end

local function ExtractSpawnInfoFromGUID(guid)
    if type(guid) ~= "string" then
        return nil
    end

    local unitType = strsplit("-", guid)
    if unitType ~= "Creature" and unitType ~= "Vehicle" then
        return nil
    end

    local timeRaw = tonumber(string.sub(guid, -6), 16)
    local indexRaw = tonumber(string.sub(guid, -10, -6), 16)
    if not timeRaw or not indexRaw then
        return nil
    end

    local serverTime = GetServerTimestamp()
    local spawnTime = (serverTime - (serverTime % (2 ^ 23))) + bit.band(timeRaw, 0x7fffff)
    if spawnTime > serverTime then
        spawnTime = spawnTime - ((2 ^ 23) - 1)
    end

    local spawnIndex = bit.rshift(bit.band(indexRaw, 0xffff8), 3)
    return {
        spawnTime = spawnTime,
        spawnIndex = spawnIndex,
        signature = tostring(spawnTime) .. ":" .. tostring(spawnIndex),
    }
end

local function RebuildBossCache()
    wipe(bossById)
    wipe(bossByKey)
    wipe(npcTargets)
    for _, boss in ipairs(DEFAULT_BOSSES) do
        local key = boss.key or tostring(boss.id)
        boss.key = key
        boss.type = boss.type or "single_npc"
        boss.group = boss.group or "world_boss"
        bossByKey[key] = boss
        if boss.id then
            bossById[boss.id] = boss
            npcTargets[boss.id] = npcTargets[boss.id] or {}
            npcTargets[boss.id][#npcTargets[boss.id] + 1] = boss
        end
        if boss.allowedNpcIds then
            for _, npcId in ipairs(boss.allowedNpcIds) do
                npcTargets[npcId] = npcTargets[npcId] or {}
                npcTargets[npcId][#npcTargets[npcId] + 1] = boss
            end
        end
    end

    wipe(customTargetCache)
    for _, custom in pairs(YiboAltoBossDB.customTargets or {}) do
        local key = custom.key or ("custom:" .. tostring(custom.id))
        custom.key = key
        custom.group = "custom"
        custom.type = custom.type or "single_npc"
        -- Custom NPCs are ordinary rares by default. Their completion
        -- expires 24 hours after the kill, independent of the daily reset.
        custom.reset = custom.reset or "respawn"
        local entry = {
            key = key,
            id = custom.id,
            type = custom.type,
            group = "custom",
            name = custom.name,
            reset = custom.reset,
            order = custom.order or 9000,
            isCustom = true,
        }
        customTargetCache[key] = entry
        bossByKey[key] = entry
        if entry.id then
            bossById[entry.id] = bossById[entry.id] or entry
            npcTargets[entry.id] = npcTargets[entry.id] or {}
            npcTargets[entry.id][#npcTargets[entry.id] + 1] = entry
        end
    end
end

local function NotifyTargetCatalogChanged()
    if YAB.TargetCatalog then YAB.TargetCatalog:Invalidate() end
    local plans = YAB.PlannedTargets
    if plans and plans.catalogRef and _G.YiboCore and _G.YiboCore.Contracts then
        _G.YiboCore.Contracts:NotifyChanged("YiboAltoBoss", plans.catalogRef, { reason = "target-catalog-changed" })
    end
end

local function GetTargetKey(target)
    if type(target) == "table" then
        return target.key or (target.id and tostring(target.id)) or target.name
    end
    return tostring(target)
end

local function GetBossDefinition(target)
    if YAB.Holiday and YAB.Holiday.GetBoss then
        local holiday = YAB.Holiday:GetBoss(target)
        if holiday then return holiday end
    end
    if type(target) == "number" then
        return bossById[target]
    end
    if type(target) == "string" then
        return bossByKey[target] or customTargetCache[target] or bossById[tonumber(target) or -1]
    end
    if type(target) == "table" then
        return bossByKey[target.key] or (target.id and bossById[target.id]) or nil
    end
    return nil
end

-- Stable location keys own the rule; native names are only bilingual input aliases.
local ZONE_ALIASES = {
    ["jade_forest"] = { "翡翠林", "The Jade Forest" },
    ["kun_lai_summit"] = { "昆莱山", "Kun-Lai Summit" },
    ["townlong_steppes"] = { "螳螂高原", "Townlong Steppes" },
    ["krasarang_wilds"] = { "卡桑琅丛林", "Krasarang Wilds" },
    ["dread_wastes"] = { "恐惧废土", "Dread Wastes" },
}
local function IsZoneMatch(zoneKey, zone, subZone)
    if not zoneKey or zoneKey == "" then return true end
    for _, alias in ipairs(ZONE_ALIASES[zoneKey] or {}) do
        if alias == zone or alias == subZone then return true end
    end
    return false
end

local function IsTargetEnabled(target)
    local boss = GetBossDefinition(target)
    if not boss then
        return false
    end
    local display = YiboAltoBossDB.display or {}
    local groups = display.groups or {}
    local items = display.items or {}
    local groupEnabled = groups[boss.group]
    if groupEnabled == nil then
        groupEnabled = true
    end
    if not groupEnabled then
        return false
    end
    local itemEnabled = items[boss.key]
    if itemEnabled == nil then
        return true
    end
    return not not itemEnabled
end

local function ResolveTargetsByNpcContext(npcId, zone, subZone)
    local items = npcTargets[tonumber(npcId) or -1] or {}
    local matched = {}
    for _, boss in ipairs(items) do
        if IsTargetEnabled(boss) then
            if boss.type == "location_rule" then
                if IsZoneMatch(boss.zoneKey, zone, subZone) then
                    matched[#matched + 1] = boss
                end
            else
                matched[#matched + 1] = boss
            end
        end
    end
    return matched
end

-- TrackingV3 is loaded after Core.lua and consumes these narrow adapters.  The
-- business cache remains private; the tracker never writes character or legacy
-- world-state tables directly.
function YAB.GetServerTimestamp()
    return GetServerTimestamp()
end

function YAB.ExtractNpcIDFromGUID(guid)
    return ExtractNpcIDFromGUID(guid)
end

function YAB.ExtractPhaseIDFromGUID(guid)
    return ExtractPhaseIDFromGUID(guid)
end

function YAB.ExtractSpawnInfoFromGUID(guid)
    return ExtractSpawnInfoFromGUID(guid)
end

function YAB.ResolveTargetsByNpcContext(npcId, zone, subZone)
    return ResolveTargetsByNpcContext(npcId, zone, subZone)
end

local function EnsureRespawnSamplesTable()
    YiboAltoBossDB.respawnSamples = YiboAltoBossDB.respawnSamples or {}
    return YiboAltoBossDB.respawnSamples
end

local function RemapLegacyTargetKey(rawKey)
    if rawKey == nil then
        return nil
    end
    local numeric = tonumber(rawKey)
    if not numeric then
        return tostring(rawKey)
    end
    local boss = GetBossDefinition(numeric)
    if not boss then
        return tostring(rawKey)
    end
    return GetTargetKey(boss)
end

local function MigrateLegacyTargetKeys()
    for _, charData in pairs(YiboAltoBossDB.characters or {}) do
        local migratedKills = {}
        for rawKey, value in pairs(charData.kills or {}) do
            migratedKills[RemapLegacyTargetKey(rawKey)] = value
        end
        charData.kills = migratedKills

        local migratedPhases = {}
        for rawKey, value in pairs(charData.phases or {}) do
            migratedPhases[RemapLegacyTargetKey(rawKey)] = value
        end
        charData.phases = migratedPhases
    end

    local realms = EnsureWorldTables()
    for _, realmState in pairs(realms) do
        local migratedBosses = {}
        for rawKey, bossState in pairs(realmState.bosses or {}) do
            migratedBosses[RemapLegacyTargetKey(rawKey)] = bossState
        end
        realmState.bosses = migratedBosses
    end

    for _, sample in ipairs(EnsureRespawnSamplesTable()) do
        if not sample.targetKey then
            sample.targetKey = RemapLegacyTargetKey(sample.bossId)
        end
    end
end

local LEGACY_CELESTIAL_KEYS = {
    "celestial_niuzao",
    "celestial_yulon",
    "celestial_chiji",
    "celestial_xuen",
}

local LEGACY_CELESTIAL_NAMES = {
    celestial_niuzao = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.NIUZAO"),
    celestial_yulon = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.YU_LON"),
    celestial_chiji = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.CHI_JI"),
    celestial_xuen = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.XUEN"),
}

local function MigrateCelestialTargets()
    for _, charData in pairs(YiboAltoBossDB.characters or {}) do
        local firstKill, firstKillName
        for _, legacyKey in ipairs(LEGACY_CELESTIAL_KEYS) do
            local killData = charData.kills and charData.kills[legacyKey]
            if killData and killData.killed and (not firstKill or (killData.updatedAt or 0) < (firstKill.updatedAt or 0)) then
                firstKill = killData
                firstKillName = LEGACY_CELESTIAL_NAMES[legacyKey]
            end
            if charData.kills then
                charData.kills[legacyKey] = nil
            end
            if charData.phases then
                charData.phases[legacyKey] = nil
            end
        end
        if firstKill and firstKill.resetKey == GetCurrentWeeklyResetKey()
            and not (charData.kills and charData.kills.celestials) then
            firstKill.actualName = firstKill.actualName or firstKillName
            charData.kills.celestials = firstKill
        end
        if charData.lootLockouts then
            charData.lootLockouts.celestials = nil
        end
    end

    for _, realmState in pairs(EnsureWorldTables()) do
        if realmState.bosses then
            for _, legacyKey in ipairs(LEGACY_CELESTIAL_KEYS) do
                realmState.bosses[legacyKey] = nil
            end
        end
    end
end

-- v1.5 早期包可能把原有四个世界 Boss 的逐项显示状态保存为 false，
-- 结果主表只剩新增的斡耳朵斯与四天神。仅修复这一完整的异常组合一次，
-- 后续用户自行调整的显示勾选始终保留。
local function RepairV15WorldBossVisibility()
    local meta = YiboAltoBossDB.meta or {}
    if meta.v15WorldBossVisibilityRepaired then
        return
    end

    local display = YiboAltoBossDB.display or {}
    local items = display.items or {}
    local legacyKeys = { "nalak", "oondasta", "galleon", "sha_of_anger" }
    local hiddenCount = 0
    for _, key in ipairs(legacyKeys) do
        if items[key] == false then
            hiddenCount = hiddenCount + 1
        end
    end

    if hiddenCount == #legacyKeys and items.ordos ~= false and items.celestials ~= false then
        for _, key in ipairs(legacyKeys) do
            items[key] = nil
        end
    end

    display.items = items
    YiboAltoBossDB.display = display
    meta.v15WorldBossVisibilityRepaired = true
    YiboAltoBossDB.meta = meta
end

local function IsWorldBossGroupEnabled()
    local display = YiboAltoBossDB.display or {}
    local groups = display.groups or {}
    local value = groups.world_boss
    if value == nil then
        return true
    end
    return not not value
end

local function AppendMissingStandardWorldBosses(items)
    if not IsWorldBossGroupEnabled() then
        return
    end

    local present = {}
    for _, boss in ipairs(items) do
        if boss and boss.key then
            present[boss.key] = true
        end
    end

    for _, key in ipairs(STANDARD_WORLD_BOSS_KEYS) do
        if not present[key] then
            -- This recovery path must not depend on the runtime boss cache: it is
            -- specifically used when a saved display state has lost canonical rows.
            local boss
            for _, candidate in ipairs(DEFAULT_BOSSES) do
                if candidate.key == key then
                    boss = candidate
                    break
                end
            end
            if boss then
                items[#items + 1] = boss
                present[key] = true
            end
        end
    end

    table.sort(items, function(left, right)
        local leftCustom = left.isCustom and 1 or 0
        local rightCustom = right.isCustom and 1 or 0
        if leftCustom ~= rightCustom then
            return leftCustom < rightCustom
        end
        local leftOrder = tonumber(left.order) or 9999
        local rightOrder = tonumber(right.order) or 9999
        if leftOrder ~= rightOrder then
            return leftOrder < rightOrder
        end
        return tostring(left.name) < tostring(right.name)
    end)
end

local function AppendRespawnSample(sample)
    local samples = EnsureRespawnSamplesTable()
    samples[#samples + 1] = sample
end

local function GetPhaseReasonLabel(unit)
    if not UnitPhaseReason then
        return nil
    end

    local reason = UnitPhaseReason(unit)
    if type(reason) == "string" and reason ~= "" then
        return reason
    end
    if type(reason) == "number" then
        return "phase:" .. reason
    end
    return nil
end

local function BuildObservationLabel(unit)
    local labels = {}
    local phaseReason = GetPhaseReasonLabel(unit)
    if phaseReason then
        labels[#labels + 1] = phaseReason
    end

    local zone = GetRealZoneText and GetRealZoneText() or nil
    if zone and zone ~= "" then
        labels[#labels + 1] = zone
    end

    local subZone = GetSubZoneText and GetSubZoneText() or nil
    if subZone and subZone ~= "" and subZone ~= zone then
        labels[#labels + 1] = subZone
    end

    local instanceName, _, difficultyName = GetInstanceInfo()
    if instanceName and instanceName ~= "" and instanceName ~= zone then
        labels[#labels + 1] = instanceName
    end
    if difficultyName and difficultyName ~= "" then
        labels[#labels + 1] = difficultyName
    end

    if #labels == 0 then
        labels[#labels + 1] = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.CURRENT_INSTANCE")
    end
    return table.concat(labels, " / ")
end

local function EnsureChar(charKey)
    local chars = YiboAltoBossDB.characters
    if not chars[charKey] then
        chars[charKey] = {
            kills = {},
            phases = {},
            lootLockouts = {},
        }
    end
    if not chars[charKey].kills then
        chars[charKey].kills = {}
    end
    if not chars[charKey].phases then
        chars[charKey].phases = {}
    end
    if not chars[charKey].lootLockouts then
        chars[charKey].lootLockouts = {}
    end
    if not chars[charKey].instanceLockouts then
        chars[charKey].instanceLockouts = {}
    end
    if not chars[charKey].statistics then
        chars[charKey].statistics = { bosses = {}, instances = {}, recent = {} }
    end
    return chars[charKey]
end

local function GetServerFromKey(charKey)
    return charKey and charKey:match("-(.+)$") or ""
end

local function GetNameFromKey(charKey)
    return charKey and charKey:match("^(.-)-") or charKey or "?"
end

local function GetShortRealmName(realm)
    if not realm or realm == "" then
        return _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.UNKNOWN")
    end
    return realm
end

local function NormalizeViewMode(viewMode)
    if viewMode == true or viewMode == "all" then
        return "all"
    end
    if viewMode == "other" then
        return "other"
    end
    return "current"
end

local function IsRealmVisibleForView(realm, viewMode)
    viewMode = NormalizeViewMode(viewMode)
    if viewMode == "all" then
        return true
    end
    if viewMode == "other" then
        return realm ~= curRealm
    end
    return realm == curRealm
end

local function CompareRealmOrder(leftRealm, rightRealm)
    leftRealm = tostring(leftRealm or "")
    rightRealm = tostring(rightRealm or "")
    if leftRealm == rightRealm then
        return 0
    end
    if leftRealm == curRealm then
        return -1
    end
    if rightRealm == curRealm then
        return 1
    end
    if leftRealm < rightRealm then
        return -1
    end
    return 1
end

local function GetKnownOtherRealms()
    local seen = {}
    local items = {}
    for charKey, info in pairs(YiboAltoBossDB.knownChars or {}) do
        local realm = info.realm or GetServerFromKey(charKey)
        if realm and realm ~= "" and realm ~= curRealm and not seen[realm] then
            seen[realm] = true
            items[#items + 1] = realm
        end
    end
    table.sort(items, function(left, right)
        return CompareRealmOrder(left, right) < 0
    end)
    return items
end

local function RefreshCurrentCharacterCache()
    local level = UnitLevel("player") or 1
    local classToken = select(2, UnitClass("player")) or "UNKNOWN"
    local info = YiboAltoBossDB.knownChars[curCharKey]
    if not info then
        info = {}
        YiboAltoBossDB.knownChars[curCharKey] = info
    end
    info.name = curCharName
    info.realm = curRealm
    info.realmName = curRealm
    info.displayName = curCharName .. "-" .. curRealm
    info.class = classToken
    info.level = level
    info.lastSeenAt = time()
end

function YAB.NormalizeLevelExpr(expr)
    return _G.YiboCore.LevelFilter:Normalize(expr)
end

function YAB.ValidateLevelExpr(expr)
    return _G.YiboCore.LevelFilter:Validate(expr)
end

local function NormalizePhaseLabel(phaseText, zone, subZone, phaseId)
    if phaseId and tonumber(phaseId) and tonumber(phaseId) > 0 then
        local numericId = tonumber(phaseId)
        return "phaseid:" .. numericId, tostring(numericId)
    end

    local raw = tostring(phaseText or "")
    local phaseNum = raw:match("[Pp][Hh][Aa][Ss][Ee]%s*:?(%d+)")
    if not phaseNum then
        phaseNum = raw:match("[Pp](%d+)")
    end
    if phaseNum then
        return "phase:" .. phaseNum, "P" .. phaseNum
    end
    if raw:find(_G.YiboCore.Locale:Get("YiboAltoBoss", "UI.RARE")) then
        return "unknown", _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.RARE")
    end
    if subZone and subZone ~= "" then
        return "unknown", subZone
    end
    if zone and zone ~= "" then
        return "unknown", zone
    end
    if raw ~= "" then
        local compact = raw:gsub("%s*/%s*", "·")
        compact = compact:gsub("^phase:", "P")
        return "unknown", compact
    end
    return "unknown", _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.UNKNOWN")
end

local function IsStablePhaseKey(phaseKey)
    return type(phaseKey) == "string" and (
        phaseKey:find("^phaseid:") == 1
        or phaseKey:find("^phase:") == 1
        or phaseKey == "unknown"
    )
end

local function MergePhaseState(target, source)
    if not source then
        return target
    end

    local sourceObservedAt = tonumber(source.observedAt) or 0
    local targetObservedAt = tonumber(target.observedAt) or 0
    if sourceObservedAt > targetObservedAt then
        target.observedAt = source.observedAt
        target.lastObservedBy = source.lastObservedBy
        target.observedSource = source.observedSource
        target.zone = source.zone
        target.zoneKey = source.zoneKey
        target.subZone = source.subZone
        target.rawPhase = source.rawPhase
    end

    local sourceKilledAt = tonumber(source.lastKilledAt) or 0
    local targetKilledAt = tonumber(target.lastKilledAt) or 0
    if sourceKilledAt > targetKilledAt then
        target.lastKilledAt = source.lastKilledAt
        target.lastKilledBy = source.lastKilledBy
        target.killSource = source.killSource
    end

    if source.phaseLabel and source.phaseLabel ~= "" then
        if not target.phaseLabel or target.phaseLabel == "" or target.phaseLabel == _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.UNKNOWN") then
            target.phaseLabel = source.phaseLabel
        elseif sourceObservedAt >= targetObservedAt then
            target.phaseLabel = source.phaseLabel
        end
    end
    target.phaseId = target.phaseId or source.phaseId
    target.phaseDisplayId = target.phaseDisplayId or source.phaseDisplayId
    target.realm = target.realm or source.realm
    return target
end

EnsureWorldTables = function()
    YiboAltoBossDB.worldState = YiboAltoBossDB.worldState or {}
    YiboAltoBossDB.worldState.realms = YiboAltoBossDB.worldState.realms or {}
    return YiboAltoBossDB.worldState.realms
end

local function NormalizeLegacyWorldState()
    local realms = EnsureWorldTables()
    for _, realmState in pairs(realms) do
        local referencedCatalogKeys = {}
        for _, bossState in pairs(realmState.bosses or {}) do
            local mergedUnknown = nil
            local unstableKeys = {}
            local latestObservedState = nil
            local latestObservedAt = 0
            for phaseKey, phaseState in pairs(bossState.phases or {}) do
                local observedAt = tonumber(phaseState.observedAt or 0) or 0
                if observedAt > latestObservedAt then
                    latestObservedAt = observedAt
                    latestObservedState = phaseState
                end
                if IsStablePhaseKey(phaseKey) then
                    referencedCatalogKeys[phaseKey] = true
                else
                    unstableKeys[#unstableKeys + 1] = phaseKey
                    mergedUnknown = MergePhaseState(mergedUnknown or {
                        phaseKey = "unknown",
                        phaseLabel = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.UNKNOWN"),
                        realm = phaseState.realm,
                    }, phaseState)
                end
            end

            if mergedUnknown then
                local existingUnknown = bossState.phases.unknown
                if existingUnknown then
                    mergedUnknown = MergePhaseState(existingUnknown, mergedUnknown)
                end
                mergedUnknown.phaseKey = "unknown"
                bossState.phases.unknown = mergedUnknown
                referencedCatalogKeys.unknown = true
                for _, phaseKey in ipairs(unstableKeys) do
                    bossState.phases[phaseKey] = nil
                end
            end
            if bossState.lastKilledAt then
                local targetState = latestObservedState or bossState.phases.unknown
                if not targetState then
                    targetState = {
                        phaseKey = "unknown",
                        phaseLabel = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.UNKNOWN"),
                        realm = next(bossState.phases or {}) and nil or nil,
                    }
                    bossState.phases.unknown = targetState
                    referencedCatalogKeys.unknown = true
                end
                if not targetState.lastKilledAt or tonumber(targetState.lastKilledAt) < tonumber(bossState.lastKilledAt) then
                    targetState.lastKilledAt = bossState.lastKilledAt
                    targetState.lastKilledBy = bossState.lastKilledBy
                    targetState.killSource = bossState.killSource
                end
                bossState.lastKilledAt = nil
                bossState.lastKilledBy = nil
                bossState.killSource = nil
            end
        end

        realmState.phaseCatalog = realmState.phaseCatalog or {}
        for phaseKey in pairs(realmState.phaseCatalog) do
            if not referencedCatalogKeys[phaseKey] then
                realmState.phaseCatalog[phaseKey] = nil
            end
        end
        if referencedCatalogKeys.unknown then
            local unknownEntry = realmState.phaseCatalog.unknown or {
                phaseKey = "unknown",
                phaseId = "?",
                displayId = "?",
                sampleLabel = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.UNKNOWN"),
            }
            unknownEntry.phaseKey = "unknown"
            unknownEntry.phaseId = unknownEntry.phaseId or "?"
            unknownEntry.displayId = unknownEntry.displayId or "?"
            unknownEntry.sampleLabel = unknownEntry.sampleLabel or _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.UNKNOWN")
            realmState.phaseCatalog.unknown = unknownEntry
        end
    end
end

local function EnsureRealmWorldState(realm)
    local realms = EnsureWorldTables()
    realms[realm] = realms[realm] or { bosses = {}, phaseCatalog = {}, nextPhaseId = 1 }
    realms[realm].bosses = realms[realm].bosses or {}
    realms[realm].phaseCatalog = realms[realm].phaseCatalog or {}
    realms[realm].nextPhaseId = tonumber(realms[realm].nextPhaseId) or 1
    return realms[realm]
end

local function EnsureBossWorldState(realm, bossId)
    local realmState = EnsureRealmWorldState(realm)
    local key = tostring(bossId)
    realmState.bosses[key] = realmState.bosses[key] or { phases = {} }
    realmState.bosses[key].phases = realmState.bosses[key].phases or {}
    return realmState.bosses[key]
end

local function ClearPhaseKillState(phaseState)
    if not phaseState then
        return
    end
    phaseState.lastKilledAt = nil
    phaseState.lastKilledBy = nil
    phaseState.killSource = nil
end

local function RecordBossRespawnSample(realm, bossId, phaseState, phaseKey, phaseLabel, phaseDisplayId, observedAt, observedBy, source, spawnTime)
    -- Frozen compatibility path. TrackingV3 is the sole writer for new samples;
    -- legacy samples remain read-only historical input.
    if YAB.TrackingV3 then return false end
    local killedAt = tonumber(phaseState.lastKilledAt) or 0
    if killedAt <= 0 or observedAt <= killedAt then
        return false
    end

    local respawnedAt = tonumber(spawnTime) or 0
    if respawnedAt <= killedAt then
        -- Without a valid creature spawn timestamp, falling back to the
        -- observation time would anchor samples to "when we noticed it",
        -- which shifts predictions later than the actual respawn.
        ClearPhaseKillState(phaseState)
        return false
    end
    local elapsed = respawnedAt - killedAt
    local sampledKillAt = tonumber(phaseState.lastRespawnSampleKilledAt) or 0
    if elapsed < MIN_RESPAWN_SAMPLE_SECONDS or sampledKillAt == killedAt then
        ClearPhaseKillState(phaseState)
        return false
    end

    AppendRespawnSample({
        realm = realm,
        bossId = tonumber(bossId) or bossId,
        targetKey = tostring(bossId),
        phaseKey = phaseKey,
        phaseLabel = phaseLabel,
        phaseDisplayId = phaseDisplayId,
        killedAt = killedAt,
        observedAt = observedAt,
        respawnedAt = respawnedAt,
        elapsedSeconds = elapsed,
        killedBy = phaseState.lastKilledBy,
        observedBy = observedBy,
        source = source,
    })
    phaseState.lastRespawnSampleKilledAt = killedAt
    phaseState.lastRespawnSampleAt = observedAt
    phaseState.lastRespawnSampleSeconds = elapsed
    ClearPhaseKillState(phaseState)
    return true
end

local function UpsertWorldPhaseState(realm, bossId, phaseText, charKey, payload)
    payload = payload or {}
    local realmState = EnsureRealmWorldState(realm)
    local bossState = EnsureBossWorldState(realm, bossId)
    local phaseKey, phaseLabel = NormalizePhaseLabel(phaseText, payload.zone, payload.subZone, payload.phaseId)
    local catalog = realmState.phaseCatalog
    local catalogEntry = catalog[phaseKey]
    if not catalogEntry then
        local nextId = realmState.nextPhaseId or 1
        catalogEntry = {
            phaseKey = phaseKey,
            phaseId = payload.phaseId and tostring(payload.phaseId) or tostring(nextId),
            displayId = payload.phaseId and tostring(payload.phaseId) or string.format("%02d", nextId),
            sampleLabel = phaseLabel,
        }
        catalog[phaseKey] = catalogEntry
        if not payload.phaseId then
            realmState.nextPhaseId = nextId + 1
        end
    elseif phaseLabel and phaseLabel ~= "" then
        catalogEntry.sampleLabel = phaseLabel
        if payload.phaseId and tonumber(payload.phaseId) and tonumber(payload.phaseId) > 0 then
            catalogEntry.phaseId = tostring(payload.phaseId)
            catalogEntry.displayId = tostring(payload.phaseId)
        end
    end
    local phaseState = bossState.phases[phaseKey]
    if not phaseState then
        phaseState = {
            phaseKey = phaseKey,
            phaseLabel = phaseLabel,
        }
        bossState.phases[phaseKey] = phaseState
    end

    phaseState.phaseLabel = phaseLabel or phaseState.phaseLabel
    phaseState.phaseId = payload.phaseId and tostring(payload.phaseId) or phaseState.phaseId or catalogEntry.phaseId
    phaseState.phaseDisplayId = catalogEntry.displayId
    phaseState.rawPhase = phaseText or phaseState.rawPhase
    phaseState.realm = realm
    phaseState.zone = payload.zone or phaseState.zone
    phaseState.subZone = payload.subZone or phaseState.subZone

    if payload.observedAt then
        local observedAt = tonumber(payload.observedAt) or 0
        local spawnTime = tonumber(payload.spawnTime) or nil
        local spawnIndex = tonumber(payload.spawnIndex) or nil
        local spawnSignature = payload.spawnSignature or nil
        local currentSignature = phaseState.spawnSignature
        if spawnSignature and currentSignature and spawnSignature ~= currentSignature then
            RecordBossRespawnSample(
                realm,
                bossId,
                phaseState,
                phaseKey,
                phaseLabel or phaseState.phaseLabel,
                catalogEntry.displayId,
                observedAt,
                charKey or phaseState.lastObservedBy,
                payload.source or phaseState.observedSource,
                spawnTime
            )
        end
        if spawnTime then
            phaseState.spawnTime = spawnTime
        end
        if spawnIndex then
            phaseState.spawnIndex = spawnIndex
        end
        if spawnSignature then
            phaseState.spawnSignature = spawnSignature
        end
        phaseState.observedAt = payload.observedAt
        phaseState.lastObservedBy = charKey or phaseState.lastObservedBy
        phaseState.observedSource = payload.source or phaseState.observedSource
    end
    if payload.killedAt then
        phaseState.lastKilledAt = payload.killedAt
        phaseState.lastKilledBy = charKey or phaseState.lastKilledBy
        phaseState.killSource = payload.source or phaseState.killSource
    end
    return phaseState
end

local function CleanupExpiredPhases()
    local now = time()
    for _, charData in pairs(YiboAltoBossDB.characters) do
        for npcId, phaseData in pairs(charData.phases or {}) do
            local observedAt = tonumber(phaseData.observedAt) or 0
            if observedAt <= 0 or (now - observedAt) >= PHASE_TTL_SECONDS then
                charData.phases[npcId] = nil
            end
        end
    end
end

local function CleanupExpiredWorldState()
    local now = time()
    local realms = EnsureWorldTables()
    for realm, realmState in pairs(realms) do
        for bossId, bossState in pairs(realmState.bosses or {}) do
            for phaseKey, phaseState in pairs(bossState.phases or {}) do
                local observedAt = tonumber(phaseState.observedAt) or 0
                local killedAt = tonumber(phaseState.lastKilledAt) or 0
                local staleObserved = observedAt <= 0 or (now - observedAt) >= PHASE_TTL_SECONDS
                local staleKilled = killedAt > 0 and (now - killedAt) >= PHASE_TTL_SECONDS
                if staleObserved then
                    phaseState.observedAt = nil
                    phaseState.lastObservedBy = nil
                    phaseState.observedSource = nil
                    phaseState.zone = nil
                    phaseState.subZone = nil
                    phaseState.rawPhase = nil
                end
                if staleKilled then
                    phaseState.lastKilledAt = nil
                    phaseState.lastKilledBy = nil
                    phaseState.killSource = nil
                end
                if not phaseState.observedAt and not phaseState.lastKilledAt then
                    bossState.phases[phaseKey] = nil
                end
            end
            if not next(bossState.phases or {}) then
                realmState.bosses[bossId] = nil
            end
        end
        if not next(realmState.bosses or {}) then
            realms[realm] = nil
        end
    end
end

local function EnsureDB()
    CopyDefaults(YiboAltoBossDB, {
        knownChars = {},
        characters = {},
        customTargets = {},
        filters = {
            levelExpr = "90",
        },
        settings = {
            showHolidayBosses = true,
            accountPage = "boss",
            normalInstanceLimit = 5,
            lockoutColumns = {},
            previewColumns = {
                kills = true,
                action = true,
                phase = true,
            },
        },
        display = {
            groups = {
                world_boss = true,
                warbringer = true,
                custom = true,
            },
            items = {},
        },
        ui = { viewMode = "current", settingsExpandedGroups = {} },
        worldState = {
            realms = {},
        },
        respawnSamples = {},
        trackingV3 = {
            schemaVersion = 3,
            realms = {},
            samples = {},
            diagnostics = {},
            meta = {},
        },
        meta = {
            weeklyResetKey = GetCurrentWeeklyResetKey(),
        },
    })

    RefreshCurrentCharacterCache()
    EnsureSeenOrder(curCharKey)
    EnsureChar(curCharKey)
    RebuildBossCache()
    MigrateLegacyTargetKeys()
    MigrateCelestialTargets()
    RepairV15WorldBossVisibility()
    CleanupExpiredPhases()
    CleanupExpiredWorldState()
    NormalizeLegacyWorldState()
end

local function ResetRecurringStateIfNeeded()
    local currentWeeklyKey = GetCurrentWeeklyResetKey()
    local meta = YiboAltoBossDB.meta or {}
    local weeklyChanged = meta.weeklyResetKey ~= currentWeeklyKey
    local changed = weeklyChanged

    for _, charData in pairs(YiboAltoBossDB.characters or {}) do
        for bossId, killData in pairs(charData.kills or {}) do
            local boss = GetBossDefinition(bossId)
            if boss and boss.reset == "weekly" and weeklyChanged then
                charData.kills[bossId] = nil
            elseif boss and boss.reset == "respawn" and not IsKillActive(killData, boss) then
                charData.kills[bossId] = nil
                changed = true
            end
        end
        if weeklyChanged then
            charData.lootLockouts = {}
        end
    end

    YiboAltoBossDB.meta.weeklyResetKey = currentWeeklyKey
    return changed
end

local function GetLootLockout(charData, groupKey)
    if not groupKey then
        return nil
    end
    local lockout = (charData.lootLockouts or {})[groupKey]
    if lockout and lockout.resetKey == GetCurrentWeeklyResetKey() then
        return lockout
    end
    return nil
end

local function RefreshLootLockout(charData, boss)
    local groupKey = boss and boss.lootLockoutGroup
    if not groupKey then
        return
    end

    local firstKillKey, firstKillInfo
    for _, candidate in ipairs(DEFAULT_BOSSES) do
        if candidate.lootLockoutGroup == groupKey then
            local candidateKill = charData.kills[candidate.key]
            if candidateKill and candidateKill.killed and candidateKill.resetKey == GetCurrentWeeklyResetKey()
                and (not firstKillInfo or (candidateKill.updatedAt or 0) < (firstKillInfo.updatedAt or 0)) then
                firstKillKey = candidate.key
                firstKillInfo = candidateKill
            end
        end
    end

    charData.lootLockouts = charData.lootLockouts or {}
    if firstKillKey then
        charData.lootLockouts[groupKey] = {
            firstKillKey = firstKillKey,
            resetKey = GetCurrentWeeklyResetKey(),
        }
    else
        charData.lootLockouts[groupKey] = nil
    end
end

local function MarkBossKilled(charKey, bossId, source, phaseId, actualNpcId)
    local boss = GetBossDefinition(bossId)
    if not boss then
        return false
    end

    local charData = EnsureChar(charKey or curCharKey)
    local bossKey = GetTargetKey(boss)
    local existing = charData.kills[bossKey]
    local resetKey = GetTargetResetKey(boss)
    local alreadyCompleted = IsKillActive(existing, boss)
    -- Character completion is intentionally independent from world lifecycle
    -- tracking.  TrackingV3 owns alive/death evidence and respawn samples.
    if alreadyCompleted then
        return false
    end

    local killedAt = GetServerTimestamp()
    charData.kills[bossKey] = {
        killed = true,
        updatedAt = killedAt,
        source = source or "manual",
        resetKey = resetKey,
    }
    if boss.reset == "respawn" then
        charData.kills[bossKey].expiresAt = killedAt + CUSTOM_RARE_RESET_SECONDS
    end
    if actualNpcId then
        charData.kills[bossKey].actualNpcId = actualNpcId
        charData.kills[bossKey].actualName = (boss.npcNames and boss.npcNames[actualNpcId]) or boss.name
    end
    RefreshLootLockout(charData, boss)
    return true
end

local persistenceReady = false
function YAB.PersistDB()
    YiboAltoBossDB = YiboAltoBossDB or {}
    if not persistenceReady then EnsureDB(); persistenceReady = true end
end

function YAB.GetAddonName()
    return "YiboAltoBoss"
end

function YAB.GetCurrentCharKey()
    return curCharKey
end

function YAB.GetCurrentRealm()
    return curRealm
end

function YAB.GetCurrentRealmLabel()
    return GetShortRealmName(curRealm)
end

function YAB.NormalizeViewMode(viewMode)
    return NormalizeViewMode(viewMode)
end

function YAB.IsAllServersViewMode(viewMode)
    return NormalizeViewMode(viewMode) == "all"
end

function YAB.GetOtherRealmNames()
    EnsureDB()
    return GetKnownOtherRealms()
end

function YAB.GetCurrentCharacterName()
    return curCharName
end

function YAB.GetCurrentPhaseInfo()
    CleanupExpiredPhases()
    local charData = EnsureChar(curCharKey)
    local currentZone = GetRealZoneText and GetRealZoneText() or nil
    local currentSubZone = GetSubZoneText and GetSubZoneText() or nil
    local bestPhase, bestScore, bestObservedAt = nil, -1, 0

    for targetKey, phaseData in pairs(charData.phases or {}) do
        local boss = GetBossDefinition(targetKey)
        if boss and IsTargetEnabled(boss) then
            local numericPhaseId = tonumber(phaseData.phaseId)
            local observedAt = tonumber(phaseData.observedAt) or 0
            if numericPhaseId and numericPhaseId > 0 and observedAt > 0 then
                local score = 0
                if currentZone and phaseData.zone == currentZone then
                    score = score + 2
                end
                if currentSubZone and phaseData.subZone == currentSubZone then
                    score = score + 3
                end
                if score > bestScore or (score == bestScore and observedAt > bestObservedAt) then
                    bestPhase = {
                        phaseId = tostring(numericPhaseId),
                        phase = phaseData.phase,
                        observedAt = observedAt,
                        zone = phaseData.zone,
                        subZone = phaseData.subZone,
                        npcId = boss.id or nil,
                        targetKey = targetKey,
                        targetName = boss.name or tostring(targetKey),
                    }
                    bestScore = score
                    bestObservedAt = observedAt
                end
            end
        end
    end

    return bestPhase
end

function YAB.GetLevelFilterExpr()
    return (YiboAltoBossDB.filters and YiboAltoBossDB.filters.levelExpr) or ""
end

function YAB.SetLevelFilterExpr(expr)
    local valid, normalized, badToken = YAB.ValidateLevelExpr(expr)
    if not valid then
        return false, badToken
    end
    YiboAltoBossDB.filters.levelExpr = normalized
    YAB.PersistDB()
    if YAB.NotifyCorePageChanged then
        YAB.NotifyCorePageChanged()
    end
    if YAB.RefreshSettingsUI then
        YAB.RefreshSettingsUI()
    end
    return true, normalized
end

function YAB.ToggleBossKill(charKey, bossId)
    if YAB.Holiday and YAB.Holiday:IsBoss(bossId) then
        YAB.Holiday:ToggleManual(bossId, charKey)
        return
    end
    local charData = EnsureChar(charKey)
    local boss = GetBossDefinition(bossId)
    if not boss or not IsTargetEnabled(boss) then
        return
    end
    local bossKey = GetTargetKey(boss)
    local killData = charData.kills[bossKey]
    if IsKillActive(killData, boss) then
        charData.kills[bossKey] = nil
        RefreshLootLockout(charData, boss)
    else
        charData.kills[bossKey] = nil
        MarkBossKilled(charKey, bossKey, "manual")
    end
    YAB.PersistDB()
    if YAB.NotifyCorePageChanged then
        YAB.NotifyCorePageChanged()
    end
end

function YAB.RecordBossManually(charKey, bossId)
    YAB.CheckForReset()
    if YAB.Holiday and YAB.Holiday:IsBoss(bossId) then
        local changed = YAB.Holiday:ToggleManual(bossId, charKey or curCharKey)
        return changed, changed and _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.UPDATED_THE_SEASONAL_BOSS_MANUAL_MARK") or _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.THIS_STATUS_WAS_RECORDED_AUTOMATICALLY_AND_CANNOT_BE_OVERWRITTEN_MANUALL")
    end
    local boss = GetBossDefinition(bossId)
    if not boss or not IsTargetEnabled(boss) then
        return false, _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.TARGET_UNAVAILABLE")
    end
    if not MarkBossKilled(charKey or curCharKey, boss.key, "manual_recovery") then
        return false, boss.name .. _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.ALREADY_HAS_A_KILL_RECORDED_THIS_WEEK")
    end
    YAB.PersistDB()
    if YAB.NotifyCorePageChanged then
        YAB.NotifyCorePageChanged()
    end
    return true, _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.RECORDED_YOUR_KILL_OF") .. boss.name .. _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.LABEL")
end

function YAB.IsBossKilled(charKey, bossId)
    if YAB.Holiday and YAB.Holiday:IsBoss(bossId) then
        return YAB.Holiday:GetStatus(charKey, bossId) == "completed"
    end
    local charData = EnsureChar(charKey)
    local boss = GetBossDefinition(bossId)
    if not boss then
        return false
    end
    local bossKey = GetTargetKey(boss)
    local killInfo = charData.kills[bossKey]
    if IsKillActive(killInfo, boss) then
        return true
    end
    if killInfo and boss.reset == "respawn" then
        charData.kills[bossKey] = nil
    end
    return false
end

function YAB.GetKillInfo(charKey, bossId)
    if YAB.Holiday and YAB.Holiday:IsBoss(bossId) then
        local _, record = YAB.Holiday:GetStatus(charKey, bossId)
        return record
    end
    local charData = EnsureChar(charKey)
    local boss = GetBossDefinition(bossId)
    if not boss then
        return nil
    end
    return charData.kills[GetTargetKey(boss)]
end

function YAB.GetBossKillStatus(charKey, bossId)
    if YAB.Holiday and YAB.Holiday:IsBoss(bossId) then
        return YAB.Holiday:GetStatus(charKey, bossId)
    end
    local charData = EnsureChar(charKey)
    local boss = GetBossDefinition(bossId)
    if not boss then
        return "unavailable"
    end

    local bossKey = GetTargetKey(boss)
    local killInfo = charData.kills[bossKey]
    if IsKillActive(killInfo, boss) then
        return "killed", killInfo
    end
    if killInfo and boss.reset == "respawn" then
        charData.kills[bossKey] = nil
    end

    local lockout = GetLootLockout(charData, boss.lootLockoutGroup)
    if lockout then
        return "loot_locked", lockout, GetBossDefinition(lockout.firstKillKey)
    end
    return "available"
end

function YAB.RecordPhase(targetRef, phaseText, charKey)
    charKey = charKey or curCharKey
    local charData = EnsureChar(charKey)
    local observedAt = time()
    local zone = GetRealZoneText and GetRealZoneText() or nil
    local subZone = GetSubZoneText and GetSubZoneText() or nil
    local boss = GetBossDefinition(targetRef)
    if not boss or boss.trackPhase == false then
        return
    end
    local bossKey = GetTargetKey(boss)
    charData.phases[bossKey] = {
        phaseId = nil,
        phase = phaseText or "?",
        observedAt = observedAt,
        zone = zone,
        subZone = subZone,
    }
    UpsertWorldPhaseState(GetServerFromKey(charKey), bossKey, phaseText, charKey, {
        observedAt = observedAt,
        zone = zone,
        subZone = subZone,
        source = "RecordPhase",
    })
    YAB.PersistDB()
    if YAB.NotifyCorePageChanged then
        YAB.NotifyCorePageChanged()
    end
end

function YAB.GetVisiblePhases(charKey)
    CleanupExpiredPhases()
    local charData = EnsureChar(charKey or curCharKey)
    local items = {}
    for targetKey, phaseData in pairs(charData.phases or {}) do
        items[#items + 1] = {
            targetKey = targetKey,
            phase = phaseData.phase,
            observedAt = phaseData.observedAt,
        }
    end
    table.sort(items, function(left, right)
        return (left.observedAt or 0) > (right.observedAt or 0)
    end)
    return items
end

function YAB.GetPhaseForTarget(charKey, npcId)
    CleanupExpiredPhases()
    local charData = EnsureChar(charKey or curCharKey)
    local boss = GetBossDefinition(npcId)
    if not boss then
        return nil
    end
    local phaseData = charData.phases[GetTargetKey(boss)]
    if not phaseData then
        return nil
    end
    return phaseData.phase, phaseData.observedAt
end

function YAB.GetPhaseInfo(charKey, npcId)
    CleanupExpiredPhases()
    local charData = EnsureChar(charKey or curCharKey)
    local boss = GetBossDefinition(npcId)
    if not boss then
        return nil
    end
    return charData.phases[GetTargetKey(boss)]
end

function YAB.AddCustomTarget(input, localizedName)
    local value = tonumber(input)
    if not value or value <= 0 then
        return false, _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.ENTER_A_VALID_NPC_ID")
    end

    local key = tostring(value)
    if YiboAltoBossDB.customTargets[key] then
        return false, _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.THIS_NPC_ID_ALREADY_EXISTS")
    end

    local name = type(localizedName) == "string" and localizedName ~= "" and localizedName or (_G.YiboCore.Locale:Get("YiboAltoBoss", "UI.CUSTOM_TARGET") .. value)
    YiboAltoBossDB.customTargets[key] = {
        key = "custom:" .. key,
        id = value,
        name = name,
        group = "custom",
        reset = "respawn",
    }
    RebuildBossCache()
    NotifyTargetCatalogChanged()
    YAB.PersistDB()
    if YAB.NotifyCorePageChanged then
        YAB.NotifyCorePageChanged()
    end
    if YAB.RefreshSettingsUI then
        YAB.RefreshSettingsUI()
    end
    return true
end

function YAB.AddCurrentTarget()
    if not UnitExists or not UnitExists("target") then
        return false, _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.SELECT_AN_NPC_FIRST")
    end

    local npcId = ExtractNpcIDFromGUID(UnitGUID("target"))
    if not npcId then
        return false, _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.THE_SELECTED_TARGET_IS_NOT_A_RECOGNIZABLE_NPC")
    end

    local name = UnitName and UnitName("target") or nil
    local ok, err = YAB.AddCustomTarget(npcId, name)
    if not ok then
        return false, err
    end
    return true, _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.ADDED_CURRENT_TARGET") .. tostring(name or "NPC") .. " (ID: " .. tostring(npcId) .. ")"
end

function YAB.UpdateCustomTargetName(npcId, localizedName)
    local name = type(localizedName) == "string" and localizedName or ""
    local custom = YiboAltoBossDB and YiboAltoBossDB.customTargets and YiboAltoBossDB.customTargets[tostring(npcId)]
    if not custom or name == "" or custom.name == name then
        return false
    end

    custom.name = name
    RebuildBossCache()
    NotifyTargetCatalogChanged()
    return true
end

function YAB.RemoveCustomTarget(input)
    local value = tonumber(input)
    if not value or value <= 0 then
        return false, _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.ENTER_THE_NPC_ID_TO_REMOVE")
    end

    local idKey = tostring(value)
    local custom = YiboAltoBossDB.customTargets[idKey]
    if not custom then
        return false, _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.CUSTOM_NPC_NOT_FOUND")
    end

    local targetKey = custom.key or ("custom:" .. idKey)
    YiboAltoBossDB.customTargets[idKey] = nil

    local display = YiboAltoBossDB.display or {}
    display.items = display.items or {}
    display.items[targetKey] = nil
    YiboAltoBossDB.display = display

    for _, charData in pairs(YiboAltoBossDB.characters or {}) do
        if charData.kills then
            charData.kills[targetKey] = nil
        end
        if charData.phases then
            charData.phases[targetKey] = nil
        end
    end

    for _, realmState in pairs(EnsureWorldTables()) do
        if realmState.bosses then
            realmState.bosses[targetKey] = nil
        end
    end

    local retainedSamples = {}
    for _, sample in ipairs(EnsureRespawnSamplesTable()) do
        if tostring(sample.targetKey or "") ~= targetKey and tonumber(sample.bossId) ~= value then
            retainedSamples[#retainedSamples + 1] = sample
        end
    end
    YiboAltoBossDB.respawnSamples = retainedSamples

    RebuildBossCache()
    NotifyTargetCatalogChanged()
    YAB.PersistDB()
    if YAB.NotifyCorePageChanged then
        YAB.NotifyCorePageChanged()
    end
    if YAB.RefreshSettingsUI then
        YAB.RefreshSettingsUI()
    end
    return true, _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.REMOVED_CUSTOM_TARGET") .. idKey
end

function YAB.GetAllBossList()
    local items = {}
    for _, boss in ipairs(DEFAULT_BOSSES) do
        items[#items + 1] = boss
    end
    for _, custom in pairs(YiboAltoBossDB.customTargets) do
        items[#items + 1] = GetBossDefinition(custom.key or ("custom:" .. tostring(custom.id))) or {
            key = custom.key or ("custom:" .. tostring(custom.id)),
            id = custom.id,
            name = custom.name,
            reset = "manual",
            group = "custom",
            isCustom = true,
        }
    end
    table.sort(items, function(left, right)
        local leftCustom = left.isCustom and 1 or 0
        local rightCustom = right.isCustom and 1 or 0
        if leftCustom ~= rightCustom then
            return leftCustom < rightCustom
        end
        local leftOrder = tonumber(left.order) or 9999
        local rightOrder = tonumber(right.order) or 9999
        if leftOrder ~= rightOrder then
            return leftOrder < rightOrder
        end
        return tostring(left.name) < tostring(right.name)
    end)
    return items
end

function YAB.GetBossList()
    local items = {}
    for _, boss in ipairs(YAB.GetAllBossList()) do
        if IsTargetEnabled(boss) then
            items[#items + 1] = boss
        end
    end
    AppendMissingStandardWorldBosses(items)
    if YAB.Holiday and YAB.Holiday.GetActiveBosses then
        for _, boss in ipairs(YAB.Holiday:GetActiveBosses()) do
            items[#items + 1] = boss
        end
    end
    table.sort(items, function(left, right)
        local leftOrder, rightOrder = tonumber(left.order) or 9999, tonumber(right.order) or 9999
        if leftOrder ~= rightOrder then return leftOrder < rightOrder end
        return tostring(left.name) < tostring(right.name)
    end)
    return items
end

function YAB.GetPhaseTargets()
    local items = {}
    for _, boss in ipairs(YAB.GetBossList()) do
        if boss.trackPhase ~= false then
            items[#items + 1] = {
                key = boss.key,
                id = boss.id,
                name = boss.name,
                isCustom = boss.isCustom,
            }
        end
    end
    return items
end

function YAB.GetDisplayGroups()
    local items = {}
    for _, group in ipairs(TARGET_GROUPS) do
        items[#items + 1] = group
    end
    return items
end

function YAB.GetDisplayState()
    return YiboAltoBossDB.display or { groups = {}, items = {} }
end

function YAB.IsTargetEnabled(target)
    return IsTargetEnabled(target)
end

function YAB.IsDisplayGroupEnabled(groupKey)
    local display = YAB.GetDisplayState()
    local value = display.groups[groupKey]
    if value == nil then
        return true
    end
    return not not value
end

function YAB.IsDisplayItemChecked(targetKey)
    local display = YAB.GetDisplayState()
    local value = display.items[targetKey]
    if value == nil then
        return true
    end
    return not not value
end

function YAB.SetDisplayGroupEnabled(groupKey, enabled)
    YiboAltoBossDB.display.groups[groupKey] = not not enabled
    YAB.PersistDB()
    if YAB.NotifyCorePageChanged then
        YAB.NotifyCorePageChanged()
    end
    if YAB.RefreshSettingsUI then
        YAB.RefreshSettingsUI()
    end
end

function YAB.SetDisplayItemEnabled(targetKey, enabled)
    YiboAltoBossDB.display.items[targetKey] = not not enabled
    YAB.PersistDB()
    if YAB.NotifyCorePageChanged then
        YAB.NotifyCorePageChanged()
    end
    if YAB.RefreshSettingsUI then
        YAB.RefreshSettingsUI()
    end
end

function YAB.GetCharacterIdentity(charKey)
    local Core = _G.YiboCore
    local id = Core.Characters:ResolveLegacyKey(charKey)
    return id and Core.Characters:Get(id, { identityOnly = true }) or nil
end

function YAB.FormatCharacterName(charKey, viewMode, original)
    local Core = _G.YiboCore
    local identity = YAB.GetCharacterIdentity(charKey)
    if not identity then return YAB.Text("IDENTITY.UNKNOWN") end
    return Core.Characters:FormatName(identity, {
        nameMode = original and "original" or "short",
        realmMode = NormalizeViewMode(viewMode) == "current" and "omit" or "full",
    })
end

function YAB.GetPhaseColumns(viewMode)
    if YAB.TrackingV3 then
        return YAB.TrackingV3:GetPhaseColumns(viewMode)
    end
    viewMode = NormalizeViewMode(viewMode)
    CleanupExpiredWorldState()
    local columns = {}
    local currentRealm = YAB.GetCurrentRealm()
    local realms = EnsureWorldTables()

    for realm, realmState in pairs(realms) do
        if IsRealmVisibleForView(realm, viewMode) then
            for _, bossState in pairs(realmState.bosses or {}) do
                for phaseKey, phaseState in pairs(bossState.phases or {}) do
                    local compositeKey = realm .. "::" .. phaseKey
                    if not columns[compositeKey] then
                        local catalogEntry = (realmState.phaseCatalog or {})[phaseKey]
                        columns[compositeKey] = {
                            key = compositeKey,
                            realm = realm,
                            phaseKey = phaseKey,
                            label = phaseState.phaseLabel or _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.UNKNOWN"),
                            displayId = catalogEntry and catalogEntry.displayId or phaseState.phaseDisplayId or "00",
                            sortObservedAt = tonumber(phaseState.observedAt or phaseState.lastKilledAt or 0) or 0,
                        }
                    else
                        local observedAt = tonumber(phaseState.observedAt or phaseState.lastKilledAt or 0) or 0
                        if observedAt > columns[compositeKey].sortObservedAt then
                            columns[compositeKey].sortObservedAt = observedAt
                        end
                    end
                end
            end
        end
    end

    local items = {}
    for _, column in pairs(columns) do
        items[#items + 1] = column
    end
    table.sort(items, function(left, right)
        if left.realm ~= right.realm then
            return CompareRealmOrder(left.realm, right.realm) < 0
        end
        local leftDisplay = tonumber(left.displayId)
        local rightDisplay = tonumber(right.displayId)
        if leftDisplay and rightDisplay and leftDisplay ~= rightDisplay then
            return leftDisplay < rightDisplay
        end
        if tostring(left.displayId) ~= tostring(right.displayId) then
            return tostring(left.displayId) < tostring(right.displayId)
        end
        return left.sortObservedAt > right.sortObservedAt
    end)

    if #items == 0 then
        local fallbackRealm = currentRealm
        if viewMode == "other" then
            local otherRealms = YAB.GetOtherRealmNames()
            fallbackRealm = otherRealms[1] or currentRealm
        end
        items[1] = {
            key = fallbackRealm .. "::unknown",
            realm = fallbackRealm,
            phaseKey = "unknown",
            label = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.UNKNOWN"),
            displayId = "00",
            sortObservedAt = 0,
        }
    end
    return items
end

-- The optional context belongs to one synchronous view calculation only.
local function GetPhaseEstimate(bossKey, context)
    if context then
        context.estimates = context.estimates or {}
        local cached = context.estimates[bossKey]
        if cached ~= nil then return cached or nil end
        local estimate = YAB.GetBossRespawnEstimate and YAB.GetBossRespawnEstimate(bossKey, context) or nil
        context.estimates[bossKey] = estimate or false
        return estimate
    end
    return YAB.GetBossRespawnEstimate and YAB.GetBossRespawnEstimate(bossKey) or nil
end

function YAB.GetBossPhaseState(bossId, column, context)
    if not column then
        return nil
    end
    if not context or not context.cleaned then
        CleanupExpiredWorldState()
        if context then context.cleaned = true end
    end
    local boss = GetBossDefinition(bossId)
    if not boss then
        return nil
    end
    local bossKey = GetTargetKey(boss)
    if YAB.TrackingV3 then
        local state = YAB.TrackingV3:GetPhaseState(column.realm, bossKey, column.phaseKey)
        if not state then return nil end
        local estimate = GetPhaseEstimate(bossKey, context)
        state.respawnEstimateMode = estimate and estimate.mode or nil
        state.respawnEstimateSeconds = estimate and estimate.estimateSeconds or nil
        state.respawnEstimateSamples = estimate and estimate.sampleCount or 0
        state.respawnEstimateEffectiveSamples = estimate and estimate.effectiveSampleCount or 0
        state.respawnEstimateExcludedSamples = estimate and estimate.excludedSampleCount or 0
        state.respawnEstimateConfidence = estimate and estimate.confidence or nil
        state.respawnEstimateObservedMinSeconds = estimate and estimate.minSeconds or nil
        state.respawnEstimateObservedMaxSeconds = estimate and estimate.maxSeconds or nil
        state.respawnEstimateMinSeconds = estimate and estimate.windowMinSeconds or nil
        state.respawnEstimateMaxSeconds = estimate and estimate.windowMaxSeconds or nil
        state.respawnEstimateRealmCount = estimate and estimate.sampleRealmCount or 0
        state.respawnEstimateV3Samples = estimate and estimate.v3SampleCount or 0
        state.respawnEstimateLegacySamples = estimate and estimate.legacySampleCount or 0
        state.lastRespawnSampleAt = estimate and estimate.lastRespawnSampleAt or nil
        state.lastRespawnSampleSeconds = estimate and estimate.lastRespawnSampleSeconds or nil
        return state
    end
    local realms = EnsureWorldTables()
    local realmState = realms[column.realm]
    local bossState = realmState and realmState.bosses and realmState.bosses[tostring(bossKey)] or nil
    local phaseState = bossState and bossState.phases and bossState.phases[column.phaseKey] or nil
    if not phaseState then
        return nil
    end
    local estimate = GetPhaseEstimate(bossKey, context)
    return {
        realm = column.realm,
        phaseKey = column.phaseKey,
        phaseLabel = phaseState.phaseLabel or column.label or _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.UNKNOWN"),
        phaseDisplayId = phaseState.phaseDisplayId or column.displayId or "00",
        observedAt = phaseState.observedAt,
        lastObservedBy = phaseState.lastObservedBy,
        observedSource = phaseState.observedSource,
        lastKilledAt = phaseState.lastKilledAt,
        lastKilledBy = phaseState.lastKilledBy,
        killSource = phaseState.killSource,
        respawnEstimateMode = estimate and estimate.mode or nil,
        respawnEstimateSeconds = estimate and estimate.estimateSeconds or nil,
        respawnEstimateSamples = estimate and estimate.sampleCount or 0,
        respawnEstimateEffectiveSamples = estimate and estimate.effectiveSampleCount or 0,
        respawnEstimateExcludedSamples = estimate and estimate.excludedSampleCount or 0,
        respawnEstimateConfidence = estimate and estimate.confidence or nil,
        respawnEstimateObservedMinSeconds = estimate and estimate.minSeconds or nil,
        respawnEstimateObservedMaxSeconds = estimate and estimate.maxSeconds or nil,
        respawnEstimateMinSeconds = estimate and estimate.windowMinSeconds or nil,
        respawnEstimateMaxSeconds = estimate and estimate.windowMaxSeconds or nil,
        respawnEstimateRealmCount = estimate and estimate.sampleRealmCount or 0,
        lastRespawnSampleAt = estimate and estimate.lastRespawnSampleAt or phaseState.lastRespawnSampleAt,
        lastRespawnSampleSeconds = estimate and estimate.lastRespawnSampleSeconds or phaseState.lastRespawnSampleSeconds,
        zone = phaseState.zone,
        subZone = phaseState.subZone,
        rawPhase = phaseState.rawPhase,
    }
end

function YAB.GetBossPhaseSummary(viewMode)
    local columns = YAB.GetPhaseColumns(viewMode)
    local bosses = YAB.GetBossList()
    local activeKills = 0
    local tracked = 0
    local context = {}
    for _, boss in ipairs(bosses) do
        for _, column in ipairs(columns) do
            local state = YAB.GetBossPhaseState(boss.key, column, context)
            if state then
                tracked = tracked + 1
                if state.lastKilledAt then
                    activeKills = activeKills + 1
                end
            end
        end
    end
    return activeKills, tracked
end

local function BuildRespawnEstimate(samples)
    if not samples or #samples == 0 then
        return nil
    end

    table.sort(samples)
    local function Quantile(sorted, q)
        if #sorted == 1 then
            return sorted[1]
        end
        local pos = ((#sorted - 1) * q) + 1
        local lower = math.floor(pos)
        local upper = math.ceil(pos)
        if lower == upper then
            return sorted[lower]
        end
        local weight = pos - lower
        return math.floor((sorted[lower] * (1 - weight)) + (sorted[upper] * weight) + 0.5)
    end

    local rawCount = #samples
    local count = rawCount
    local sum = 0
    for _, seconds in ipairs(samples) do
        sum = sum + seconds
    end

    local median = Quantile(samples, 0.5)
    local deviations = {}
    for _, seconds in ipairs(samples) do
        deviations[#deviations + 1] = math.abs(seconds - median)
    end
    table.sort(deviations)
    local mad = Quantile(deviations, 0.5)
    local tolerance = math.max(60, mad * 3)

    local filtered, rejected = {}, {}
    for _, seconds in ipairs(samples) do
        if math.abs(seconds - median) <= tolerance then
            filtered[#filtered + 1] = seconds
        else
            rejected[#rejected + 1] = seconds
        end
    end
    if #filtered == 0 then
        filtered = samples
    end
    table.sort(filtered)
    count = #filtered
    sum = 0
    for _, seconds in ipairs(filtered) do
        sum = sum + seconds
    end

    median = Quantile(filtered, 0.5)

    local average = math.floor((sum / count) + 0.5)
    local estimateSeconds = math.floor((((median * 2) + average) / 3) + 0.5)
    local minSeconds = filtered[1]
    local maxSeconds = filtered[count]
    local p20 = Quantile(filtered, 0.2)
    local p80 = Quantile(filtered, 0.8)
    local spreadSeconds = maxSeconds - minSeconds
    local windowMinSeconds = minSeconds
    local windowMaxSeconds = maxSeconds
    local mode = "range"
    local confidence = "preliminary"
    if count >= 4 and spreadSeconds <= 90 then
        mode = "fixed"
        windowMinSeconds = estimateSeconds
        windowMaxSeconds = estimateSeconds
        confidence = "high"
    elseif count >= 3 and spreadSeconds <= 180 then
        mode = "fixed"
        windowMinSeconds = estimateSeconds
        windowMaxSeconds = estimateSeconds
        confidence = "medium"
    elseif count >= 2 then
        windowMinSeconds = math.min(p20, p80)
        windowMaxSeconds = math.max(p20, p80)
        confidence = "reference"
    end

    return {
        sampleCount = rawCount,
        rawSampleCount = rawCount,
        effectiveSampleCount = count,
        filteredSampleCount = #filtered,
        excludedSampleCount = #rejected,
        mode = mode,
        estimateSeconds = estimateSeconds,
        medianSeconds = median,
        averageSeconds = average,
        minSeconds = minSeconds,
        maxSeconds = maxSeconds,
        windowMinSeconds = windowMinSeconds,
        windowMaxSeconds = windowMaxSeconds,
        madSeconds = mad,
        spreadSeconds = spreadSeconds,
        confidence = confidence,
    }
end

function YAB.FormatRespawnConfidence(value)
    local keys = {
        preliminary = "UI.PRELIMINARY", high = "UI.HIGH", medium = "UI.MEDIUM", reference = "UI.REFERENCE",
        ["初步"] = "UI.PRELIMINARY", ["较高"] = "UI.HIGH", ["中等"] = "UI.MEDIUM", ["参考"] = "UI.REFERENCE",
        Preliminary = "UI.PRELIMINARY", High = "UI.HIGH", Medium = "UI.MEDIUM", Reference = "UI.REFERENCE",
    }
    local key = keys[value]
    return key and _G.YiboCore.Locale:Get("YiboAltoBoss", key) or tostring(value or "")
end

function YAB.GetBossRespawnEstimate(bossId, context)
    if not context or not context.databaseReady then
        EnsureDB()
        if context then context.databaseReady = true end
    end
    local boss = GetBossDefinition(bossId)
    local bossKey = boss and GetTargetKey(boss) or tostring(bossId)
    local samples = {}
    local sampleRealms = {}
    local latestSample
    local capturedCount = 0
    local v3SampleCount, legacySampleCount = 0, 0
    local sourceSamples = YAB.TrackingV3 and YAB.TrackingV3:GetSamples(bossKey, true) or EnsureRespawnSamplesTable()
    for _, sample in ipairs(sourceSamples) do
        local sampleTargetKey = sample.bossKey or sample.targetKey or tostring(sample.bossId)
        if tostring(sampleTargetKey) == tostring(bossKey) then
            local elapsed = tonumber(sample.elapsedSeconds) or 0
            if sample.status == nil or sample.status == "complete" then
                capturedCount = capturedCount + 1
                if sample.provenance == "v3" then v3SampleCount = v3SampleCount + 1
                elseif sample.provenance == "v2_legacy" then legacySampleCount = legacySampleCount + 1 end
            end
            local sampleRealm = sample.realmKey or sample.realm
            if sampleRealm and sampleRealm ~= "" then sampleRealms[sampleRealm] = true end
            if elapsed >= MIN_RESPAWN_SAMPLE_SECONDS and sample.modelEligible ~= false then
                samples[#samples + 1] = elapsed
                local completedAt = sample.completedAt or sample.observedAt
                local latestCompletedAt = latestSample and (latestSample.completedAt or latestSample.observedAt)
                if not latestSample or (tonumber(completedAt) or 0) > (tonumber(latestCompletedAt) or 0) then latestSample = sample end
            end
        end
    end
    local estimate = BuildRespawnEstimate(samples)
    if not estimate then return nil end
    estimate.sampleCount = capturedCount
    estimate.rawSampleCount = capturedCount
    estimate.excludedSampleCount = math.max(0, capturedCount - (tonumber(estimate.effectiveSampleCount) or 0))
    estimate.v3SampleCount = v3SampleCount
    estimate.legacySampleCount = legacySampleCount

    local realmCount = 0
    for _ in pairs(sampleRealms) do realmCount = realmCount + 1 end
    estimate.sampleRealmCount = realmCount
    estimate.lastRespawnSampleAt = latestSample and (latestSample.completedAt or latestSample.observedAt) or nil
    estimate.lastRespawnSampleSeconds = latestSample and latestSample.elapsedSeconds or nil
    estimate.pendingCycleCount = YAB.TrackingV3 and YAB.TrackingV3:GetPendingCount(bossKey) or 0
    return estimate
end

function YAB.GetRespawnPredictionEntries(viewMode, limit, activeOnly)
    CleanupExpiredWorldState()
    local realms = EnsureWorldTables()
    viewMode = NormalizeViewMode(viewMode)
    local items = {}
    local context = {}
    for realm, realmState in pairs(realms) do
        if IsRealmVisibleForView(realm, viewMode) then
            for bossId, bossState in pairs(realmState.bosses or {}) do
                local hasActivePhase = false
                for _, phaseState in pairs(bossState.phases or {}) do
                    if phaseState.lastKilledAt then
                        hasActivePhase = true
                        break
                    end
                end
                if (not activeOnly) or hasActivePhase then
                    local estimate = YAB.GetBossRespawnEstimate(bossId, context)
                    if estimate then
                        local boss = GetBossDefinition(bossId)
                        items[#items + 1] = {
                            realm = realm,
                            bossId = bossId,
                            bossName = boss and boss.name or tostring(bossId),
                            sampleCount = estimate.sampleCount,
                            mode = estimate.mode,
                            estimateSeconds = estimate.estimateSeconds,
                            medianSeconds = estimate.medianSeconds,
                            averageSeconds = estimate.averageSeconds,
                            minSeconds = estimate.minSeconds,
                            maxSeconds = estimate.maxSeconds,
                            windowMinSeconds = estimate.windowMinSeconds,
                            windowMaxSeconds = estimate.windowMaxSeconds,
                            spreadSeconds = estimate.spreadSeconds,
                            confidence = estimate.confidence,
                            hasActivePhase = hasActivePhase,
                        }
                    end
                end
            end
        end
    end

    table.sort(items, function(left, right)
        local leftActive = left.hasActivePhase and 1 or 0
        local rightActive = right.hasActivePhase and 1 or 0
        if leftActive ~= rightActive then
            return leftActive > rightActive
        end
        if (left.sampleCount or 0) ~= (right.sampleCount or 0) then
            return (left.sampleCount or 0) > (right.sampleCount or 0)
        end
        if left.realm ~= right.realm then
            return CompareRealmOrder(left.realm, right.realm) < 0
        end
        return tostring(left.bossName) < tostring(right.bossName)
    end)

    if limit and limit > 0 and #items > limit then
        while #items > limit do
            table.remove(items)
        end
    end
    return items
end

function YAB.GetRecentRespawnSamples(viewMode, limit)
    EnsureDB()
    viewMode = NormalizeViewMode(viewMode)
    local items = {}
    for _, sample in ipairs(EnsureRespawnSamplesTable()) do
        if IsRealmVisibleForView(sample.realm, viewMode) then
            local boss = GetBossDefinition(tonumber(sample.bossId) or sample.bossId)
            if not boss and sample.targetKey then
                boss = GetBossDefinition(sample.targetKey)
            end
            items[#items + 1] = {
                realm = sample.realm,
                bossId = sample.targetKey or sample.bossId,
                bossName = boss and boss.name or tostring(sample.targetKey or sample.bossId),
                phaseKey = sample.phaseKey,
                phaseLabel = sample.phaseLabel,
                phaseDisplayId = sample.phaseDisplayId,
                killedAt = sample.killedAt,
                observedAt = sample.observedAt,
                elapsedSeconds = sample.elapsedSeconds,
                killedBy = sample.killedBy,
                observedBy = sample.observedBy,
                source = sample.source,
            }
        end
    end
    table.sort(items, function(left, right)
        return (tonumber(left.observedAt) or 0) > (tonumber(right.observedAt) or 0)
    end)
    if limit and limit > 0 and #items > limit then
        while #items > limit do
            table.remove(items)
        end
    end
    return items
end

function YAB.CheckForReset()
    if not YiboAltoBossDB or not YiboAltoBossDB.meta then
        return false
    end
    local changed = ResetRecurringStateIfNeeded()
    if changed then
        YAB.PersistDB()
        if YAB.NotifyCorePageChanged then
            YAB.NotifyCorePageChanged()
        end
    end
    return changed
end

function YAB.RecordKillByNpcID(npcId, source, charKey, phaseId)
    if not npcId then
        return false
    end

    YAB.CheckForReset()
    local zone = GetRealZoneText and GetRealZoneText() or nil
    local subZone = GetSubZoneText and GetSubZoneText() or nil
    local changed = false
    for _, boss in ipairs(ResolveTargetsByNpcContext(tonumber(npcId), zone, subZone)) do
        local characterEligible = source == "weekly_lockout"
            or source == "quest_flag"
            or source == "manual_recovery"
            or boss.reset ~= "weekly"
        if characterEligible and MarkBossKilled(charKey or curCharKey, boss.key, source or "combat_personal", phaseId, tonumber(npcId)) then
            changed = true
        end
    end
    if changed then
        YAB.PersistDB()
        if YAB.NotifyCorePageChanged then
            YAB.NotifyCorePageChanged()
        end
    end
    return changed
end

local function RecordObservedWorldDeath(guid)
    local changed = YAB.TrackingV3 and YAB.TrackingV3:ApplyGUID(guid, "DEATH_EVIDENCE", "unit_died") or false
    local diagnosticChanged = YAB.TrackingV3 and YAB.TrackingV3:ConsumeDiagnosticsDirty() or false
    if changed or diagnosticChanged then
        YAB.PersistDB()
        if changed and YAB.NotifyCorePageChanged then YAB.NotifyCorePageChanged() end
    end
    return changed
end

local function RememberLiveBossFromCombat(guid, npcID)
    if not npcID or not npcTargets[npcID] then return false end
    local changed = YAB.TrackingV3 and YAB.TrackingV3:ApplyGUID(guid, "ALIVE_EVIDENCE", "combat_log") or false
    local diagnosticChanged = YAB.TrackingV3 and YAB.TrackingV3:ConsumeDiagnosticsDirty() or false
    if changed or diagnosticChanged then YAB.PersistDB() end
    return changed
end

local function IsLiveCombatEvidence(subEvent)
    if type(subEvent) ~= "string" then return false end
    return subEvent == "SWING_DAMAGE"
        or subEvent == "SWING_MISSED"
        or subEvent == "RANGE_DAMAGE"
        or subEvent == "RANGE_MISSED"
        or subEvent:find("_DAMAGE$", 1, false) ~= nil
        or subEvent:find("_MISSED$", 1, false) ~= nil
        or subEvent:find("^SPELL_CAST_", 1, false) ~= nil
        or subEvent == "SPELL_AURA_APPLIED"
        or subEvent == "SPELL_AURA_REFRESH"
end

function YAB.ObserveUnit(unit, source)
    if not unit or not UnitExists(unit) then
        return false
    end

    local isDead = (UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit))
        or (UnitIsDead and UnitIsDead(unit))
    if isDead then
        return false
    end

    local guid = UnitGUID(unit)
    local customNameChanged = false
    if unit == "target" then
        local npcId = ExtractNpcIDFromGUID(guid)
        local name = UnitName and UnitName(unit) or nil
        if npcId and name then
            customNameChanged = YAB.UpdateCustomTargetName(npcId, name)
        end
    end
    local changed = YAB.TrackingV3 and YAB.TrackingV3:ApplyGUID(guid, "ALIVE_EVIDENCE", source or unit) or false
    local diagnosticChanged = YAB.TrackingV3 and YAB.TrackingV3:ConsumeDiagnosticsDirty() or false
    if changed or diagnosticChanged or customNameChanged then
        YAB.PersistDB()
        if (changed or customNameChanged) and YAB.NotifyCorePageChanged then YAB.NotifyCorePageChanged() end
        if customNameChanged and YAB.RefreshSettingsUI then YAB.RefreshSettingsUI(true) end
        if customNameChanged and YAB.RefreshCoreSettingsPage then YAB.RefreshCoreSettingsPage() end
    end
    return changed or customNameChanged
end

local function IsCurrentPlayerCombatSource(guid)
    if not guid or not UnitGUID then
        return false
    end
    return guid == UnitGUID("player")
        or guid == UnitGUID("pet")
        or guid == UnitGUID("vehicle")
end

local function ForgetPersonalCombatTarget(guid)
    if recentPersonalCombatTargets[guid] then
        recentPersonalCombatTargets[guid] = nil
        personalCombatTargetCount = personalCombatTargetCount - 1
    end
end

local function RememberPersonalCombatTarget(guid, npcID)
    -- Only registered targets can produce a kill; ordinary mobs need no cache.
    if not npcID or not npcTargets[npcID] then return end
    local now = GetServerTimestamp()
    if now >= nextPersonalCombatSweep then
        for key, at in pairs(recentPersonalCombatTargets) do
            if now - at > PERSONAL_COMBAT_EVIDENCE_TTL_SECONDS then ForgetPersonalCombatTarget(key) end
        end
        nextPersonalCombatSweep = now + 1
    end
    if not recentPersonalCombatTargets[guid] then
        if personalCombatTargetCount >= PERSONAL_COMBAT_TARGET_LIMIT then
            local oldestGUID, oldestAt
            for key, at in pairs(recentPersonalCombatTargets) do
                if not oldestAt or at < oldestAt then oldestGUID, oldestAt = key, at end
            end
            if oldestGUID then ForgetPersonalCombatTarget(oldestGUID) end
        end
        personalCombatTargetCount = personalCombatTargetCount + 1
    end
    recentPersonalCombatTargets[guid] = now
end

local function HasRecentPersonalCombatEvidence(guid)
    local observedAt = tonumber(recentPersonalCombatTargets[guid])
    if not observedAt then
        return false
    end
    if GetServerTimestamp() - observedAt > PERSONAL_COMBAT_EVIDENCE_TTL_SECONDS then
        ForgetPersonalCombatTarget(guid)
        return false
    end
    return true
end

local function ObserveTrackedUnits()
    local units = { "target", "focus", "mouseover", "boss1", "boss2", "boss3", "boss4" }
    for _, unit in ipairs(units) do
        YAB.ObserveUnit(unit, unit)
    end
end

local function HasPendingWorldBossQuestChecks()
    if not C_QuestLog or not C_QuestLog.IsQuestFlaggedCompleted then
        return false
    end
    local charData = EnsureChar(curCharKey)
    local resetKey = GetCurrentWeeklyResetKey()
    for bossId, questId in pairs(WORLD_BOSS_LOCKOUT_IDS) do
        if C_QuestLog.IsQuestFlaggedCompleted(questId) then
            local boss = GetBossDefinition(bossId)
            local bossKey = boss and GetTargetKey(boss)
            local kill = bossKey and charData.kills[bossKey]
            if not (kill and kill.killed and kill.resetKey == resetKey) then return true end
        end
    end
    return false
end

local function SyncWorldBossQuestKills()
    if not C_QuestLog or not C_QuestLog.IsQuestFlaggedCompleted then
        return false
    end

    local changed = false
    for bossId, questId in pairs(WORLD_BOSS_LOCKOUT_IDS) do
        local boss = GetBossDefinition(bossId)
        if boss and IsTargetEnabled(boss) and C_QuestLog.IsQuestFlaggedCompleted(questId) then
            if MarkBossKilled(curCharKey, bossId, "weekly_lockout") then
                changed = true
            end
        end
    end

    if changed then
        YAB.PersistDB()
        if YAB.NotifyCorePageChanged then
            YAB.NotifyCorePageChanged()
        end
    end
    return changed
end

function YAB.SyncWorldBossQuestKillsIfNeeded()
    if not HasPendingWorldBossQuestChecks() then
        return false
    end
    if InCombatLockdown and InCombatLockdown() then
        return false
    end
    return SyncWorldBossQuestKills()
end

local function HandleCombatLogEvent()
    if not CombatLogGetCurrentEventInfo then
        return
    end

    local _, subEvent, _, sourceGUID, _, _, _, destGUID = CombatLogGetCurrentEventInfo()
    if subEvent == "UNIT_DIED" then
        RecordObservedWorldDeath(destGUID)
        -- A death event alone is only world-state evidence.  When the player,
        -- pet, or vehicle recently damaged this exact NPC, it is also strong
        -- enough to complete a non-weekly target.  Weekly bosses remain gated
        -- by their existing lockout flow in RecordKillByNpcID.
        if HasRecentPersonalCombatEvidence(destGUID) then
            local npcId = ExtractNpcIDFromGUID(destGUID)
            if npcId then
                YAB.RecordKillByNpcID(npcId, "combat_personal", curCharKey, ExtractPhaseIDFromGUID(destGUID))
            end
            ForgetPersonalCombatTarget(destGUID)
        end
        return
    end
    -- Damage, casts, and aura events prove that this GUID is a living spawn.
    -- Remember either side so raid combat is enough to collect its death timer,
    -- even when this client never targets or mouses over the boss directly.
    if IsLiveCombatEvidence(subEvent) then
        local sourceID = ExtractNpcIDFromGUID(sourceGUID)
        local destID = ExtractNpcIDFromGUID(destGUID)
        if destID and npcTargets[destID] and IsCurrentPlayerCombatSource(sourceGUID) then
            RememberPersonalCombatTarget(destGUID, destID)
        end
        local changed = RememberLiveBossFromCombat(sourceGUID, sourceID)
        changed = RememberLiveBossFromCombat(destGUID, destID) or changed
        if changed and YAB.NotifyCorePageChanged then YAB.NotifyCorePageChanged() end
    end
    if subEvent ~= "PARTY_KILL" then
        return
    end

    local npcId = ExtractNpcIDFromGUID(destGUID)
    if not npcId then
        return
    end

    local trackingChanged = YAB.TrackingV3 and YAB.TrackingV3:ApplyGUID(destGUID, "DEATH_EVIDENCE", "party_kill", { strongEvidence = true })
    local diagnosticChanged = YAB.TrackingV3 and YAB.TrackingV3:ConsumeDiagnosticsDirty() or false
    if trackingChanged or diagnosticChanged then
        YAB.PersistDB()
        if trackingChanged and YAB.NotifyCorePageChanged then YAB.NotifyCorePageChanged() end
    end
    YAB.RecordKillByNpcID(npcId, "combat_personal", curCharKey, ExtractPhaseIDFromGUID(destGUID))
    if C_Timer and C_Timer.After then
        C_Timer.After(1, function() YAB.SyncWorldBossQuestKillsIfNeeded() end)
    end
end

local function HandleWorldEntry()
    EnsureDB()
    YAB.CheckForReset()
    if YAB.Holiday and YAB.Holiday.RequestCalendar then YAB.Holiday:RequestCalendar() end
    if YAB.Holiday and YAB.Holiday.ObserveCurrent and YAB.Holiday:ObserveCurrent() then
        YAB.PersistDB()
    end
    ObserveTrackedUnits()
    if YAB.TrackingV3 and YAB.TrackingV3:Cleanup() then
        YAB.TrackingV3:ConsumeDiagnosticsDirty()
        YAB.PersistDB()
        if YAB.NotifyCorePageChanged then YAB.NotifyCorePageChanged() end
    end
    YAB.SyncWorldBossQuestKillsIfNeeded()
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
eventFrame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
eventFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
eventFrame:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
eventFrame:RegisterEvent("QUEST_LOG_UPDATE")
eventFrame:RegisterEvent("LFG_COMPLETION_REWARD")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("CALENDAR_UPDATE_EVENT_LIST")
local holidayQueueEvents = {
    LFG_ROLE_UPDATE = true, LFG_UPDATE = true, LFG_QUEUE_STATUS_UPDATE = true,
    LFG_PROPOSAL_SHOW = true, LFG_PROPOSAL_UPDATE = true, LFG_PROPOSAL_DONE = true,
    LFG_PROPOSAL_FAILED = true, LFG_PROPOSAL_SUCCEEDED = true,
    LFG_ROLE_CHECK_SHOW = true, LFG_ROLE_CHECK_HIDE = true,
}
for event in pairs(holidayQueueEvents) do eventFrame:RegisterEvent(event) end
eventFrame:SetScript("OnEvent", function(_, event, ...)
    local arg1 = ...
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        EnsureDB()
        if YAB.TrackingV3 then YAB.TrackingV3:Initialize() end
        YAB.PersistDB()
    elseif event == "PLAYER_LOGIN" then
        EnsureDB()
        YAB.CheckForReset()
        YAB.SyncWorldBossQuestKillsIfNeeded()
        if YAB.CoreIntegration and YAB.CoreIntegration.Initialize then
            local ok, errorMessage = YAB.CoreIntegration:Initialize()
            if not ok and DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
                DEFAULT_CHAT_FRAME:AddMessage(_G.YiboCore.Locale:Get("YiboAltoBoss", "CHAT.CORE_INTEGRATION_FAILED") .. tostring(errorMessage))
            end
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        HandleWorldEntry()
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        HandleCombatLogEvent()
    elseif event == "PLAYER_TARGET_CHANGED" then
        YAB.ObserveUnit("target", "target")
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        YAB.ObserveUnit("mouseover", "mouseover")
    elseif event == "PLAYER_FOCUS_CHANGED" then
        YAB.ObserveUnit("focus", "focus")
    elseif event == "INSTANCE_ENCOUNTER_ENGAGE_UNIT" then
        ObserveTrackedUnits()
    elseif event == "LFG_COMPLETION_REWARD" then
        local changed = false
        if YAB.Holiday and YAB.Holiday.RecordCompletionReward then
            changed = YAB.Holiday:RecordCompletionReward() or changed
        end
        if YAB.Holiday and YAB.Holiday.ObserveCurrent then
            changed = YAB.Holiday:ObserveCurrent() or changed
        end
        if changed then
            YAB.PersistDB()
            if YAB.NotifyCorePageChanged then YAB.NotifyCorePageChanged() end
        end
    elseif event == "QUEST_LOG_UPDATE" or event == "PLAYER_REGEN_ENABLED" then
        YAB.SyncWorldBossQuestKillsIfNeeded()
        if event == "QUEST_LOG_UPDATE" and YAB.Holiday and YAB.Holiday.ObserveCurrent and YAB.Holiday:ObserveCurrent() then
            YAB.PersistDB()
            if YAB.NotifyCorePageChanged then YAB.NotifyCorePageChanged() end
        end
    elseif event == "CALENDAR_UPDATE_EVENT_LIST" then
        if _G.YiboCore.Calendar and _G.YiboCore.Calendar:IsReading() then return end
        -- The calendar is populated asynchronously after login.  Rebuild the
        -- account page once its event list is available so active holiday
        -- bosses are not omitted until the next reload.
        if YAB.Holiday and YAB.Holiday.OnCalendarUpdated then YAB.Holiday:OnCalendarUpdated() end
        local changed = YAB.Holiday and YAB.Holiday.ObserveCurrent and YAB.Holiday:ObserveCurrent()
        if changed then YAB.PersistDB() end
        if YAB.NotifyCorePageChanged then YAB.NotifyCorePageChanged() end
    elseif holidayQueueEvents[event] then
        if YAB.Holiday then YAB.Holiday:RefreshQueueState() end
    end
end)
