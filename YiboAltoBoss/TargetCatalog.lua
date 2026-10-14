if _G.YAB and _G.YAB.CoreReady == false then return end
local YAB = _G.YAB
local Catalog = {}
YAB.TargetCatalog = Catalog

-- Author-owned search aliases; IDs and availability come from the client.
local ALIASES = {
    MSV = { "魔古山宝库", "Mogu'shan Vaults" }, HoF = { "恐惧之心", "Heart of Fear" },
    ToES = { "永春台", "Terrace of Endless Spring" }, ToT = { "雷电王座", "Throne of Thunder", "潮汐王座", "Throne of the Tides" },
    SoO = { "决战奥格瑞玛", "围攻奥格瑞玛", "Siege of Orgrimmar" },
    TJS = { "青龙寺", "Temple of the Jade Serpent" }, SSB = { "风暴烈酒酿造厂", "Stormstout Brewery" },
    SPM = { "影踪禅院", "Shado-Pan Monastery" }, MSP = { "魔古山宫殿", "Mogu'shan Palace" },
    GSS = { "残阳关", "Gate of the Setting Sun" }, SNT = { "围攻砮皂寺", "围攻怒皂寺", "Siege of Niuzao Temple" },
    SH = { "血色大厅", "Scarlet Halls" }, SM = { "血色修道院", "Scarlet Monastery" }, Scholo = { "通灵学院", "Scholomance" },
    DS = { "巨龙之魂", "Dragon Soul" }, BH = { "巴拉丁监狱", "Baradin Hold" }, BoT = { "暮光堡垒", "The Bastion of Twilight" },
    FL = { "火焰之地", "Firelands" }, T4W = { "风神王座", "Throne of the Four Winds" }, BWD = { "黑翼血环", "Blackwing Descent" },
    SC = { "巨石之核", "The Stonecore" }, LCoT = { "托维尔失落之城", "Lost City of the Tol'vir" }, VP = { "旋云之巅", "The Vortex Pinnacle" },
    GB = { "格瑞姆巴托", "Grim Batol" }, HoO = { "起源大厅", "Halls of Origination" }, BRC = { "黑石岩窟", "Blackrock Caverns" },
    DM = { "死亡矿井", "The Deadmines", "厄运之槌", "Dire Maul" }, SFK = { "影牙城堡", "Shadowfang Keep" },
    ZA = { "祖阿曼", "Zul'Aman" }, ZG = { "祖尔格拉布", "Zul'Gurub" }, ET = { "时光之末", "End Time" },
    WoE = { "永恒之井", "Well of Eternity" }, HoT = { "暮光审判", "Hour of Twilight" },
    RS = { "红玉圣殿", "The Ruby Sanctum" }, ICC = { "冰冠堡垒", "Icecrown Citadel" },
    ToC = { "十字军的试炼", "Trial of the Crusader", "冠军的试炼", "Trial of the Champion" },
    Ony = { "奥妮克希亚的巢穴", "Onyxia's Lair" }, ULD = { "奥杜尔", "Ulduar" }, VoA = { "阿尔卡冯的宝库", "Vault of Archavon" },
    EoE = { "永恒之眼", "The Eye of Eternity" }, OS = { "黑曜石圣殿", "The Obsidian Sanctum" }, NAXX = { "纳克萨玛斯", "Naxxramas" },
    UK = { "乌特加德城堡", "Utgarde Keep" }, UP = { "乌特加德之巅", "Utgarde Pinnacle" }, Nexus = { "魔枢", "The Nexus" },
    Occ = { "魔环", "The Oculus" }, AN = { "艾卓-尼鲁布", "Azjol-Nerub" }, OK = { "安卡赫特：古代王国", "Ahn'kahet: The Old Kingdom" },
    DTK = { "达克萨隆要塞", "Drak'Tharon Keep" }, Gun = { "古达克", "Gundrak" }, VH = { "紫罗兰监狱", "The Violet Hold" },
    HoS = { "岩石大厅", "Halls of Stone" }, HoL = { "闪电大厅", "Halls of Lightning" }, CoS = { "净化斯坦索姆", "The Culling of Stratholme" },
    FoS = { "灵魂洪炉", "The Forge of Souls" }, PoS = { "萨隆矿坑", "Pit of Saron" }, HoR = { "映像大厅", "Halls of Reflection" },
    SWP = { "太阳之井高地", "太阳井高地", "Sunwell Plateau" }, BT = { "黑暗神殿", "Black Temple" },
    MH = { "海加尔峰", "海加尔山之战", "The Battle for Mount Hyjal" }, TK = { "风暴要塞", "Tempest Keep", "The Eye" },
    SSC = { "毒蛇神殿", "Serpentshrine Cavern" }, Mag = { "玛瑟里顿的巢穴", "Magtheridon's Lair" },
    Gruul = { "格鲁尔的巢穴", "Gruul's Lair" }, Kara = { "卡拉赞", "Karazhan" },
    Ramps = { "地狱火城墙", "Hellfire Ramparts" }, BF = { "鲜血熔炉", "The Blood Furnace" }, SHH = { "破碎大厅", "The Shattered Halls" },
    SP = { "奴隶围栏", "The Slave Pens" }, UB = { "幽暗沼泽", "The Underbog" }, SV = { "蒸汽地窟", "The Steamvault" },
    MT = { "法力陵墓", "Mana-Tombs" }, AC = { "奥金尼地穴", "Auchenai Crypts" }, Sethekk = { "塞泰克大厅", "Sethekk Halls" },
    SL = { "暗影迷宫", "Shadow Labyrinth" }, OHB = { "旧希尔斯布莱德丘陵", "逃离敦霍尔德", "Old Hillsbrad Foothills" },
    BM = { "黑色沼泽", "The Black Morass" }, Mech = { "能源舰", "The Mechanar" }, Bot = { "生态船", "The Botanica" },
    Arc = { "禁魔监狱", "The Arcatraz" }, MgT = { "魔导师平台", "Magisters' Terrace" },
    AQ40 = { "安其拉神殿", "Temple of Ahn'Qiraj" }, AQ20 = { "安其拉废墟", "Ruins of Ahn'Qiraj" },
    BWL = { "黑翼之巢", "Blackwing Lair" }, MC = { "熔火之心", "Molten Core" },
    RFK = { "剃刀沼泽", "Razorfen Kraul" }, RFD = { "剃刀高地", "Razorfen Downs" }, WC = { "哀嚎洞穴", "Wailing Caverns" },
    RFC = { "怒焰裂谷", "Ragefire Chasm" }, Strat = { "斯坦索姆", "Stratholme" }, Stocks = { "暴风城监狱", "The Stockade" },
    Mara = { "玛拉顿", "Maraudon" }, ZF = { "祖尔法拉克", "Zul'Farrak" }, ST = { "阿塔哈卡神庙", "沉没的神庙", "Sunken Temple" },
    BFD = { "黑暗深渊", "Blackfathom Deeps" }, Gnomer = { "诺莫瑞根", "Gnomeregan" }, BRD = { "黑石深渊", "Blackrock Depths" },
    BRS = { "黑石塔", "Blackrock Spire" }, LBRS = { "黑石塔下层", "Lower Blackrock Spire" }, UBRS = { "黑石塔上层", "Upper Blackrock Spire" },
    Ulda = { "奥达曼", "Uldaman" },
}
local WORLD = {
    { "ordos", "Ordos", "Ordos" }, { "celestials", "August Celestials", "四天神 天神" },
    { "nalak", "Nalak", "风暴领主" }, { "oondasta", "Oondasta", "乌达" },
    { "galleon", "Galleon", "炮舰" }, { "sha_of_anger", "Sha of Anger", "怒煞" },
}
local DIFFICULTIES = { 1, 2, 3, 4, 5, 6, 7, 9, 14, 15, 16, 17 }
local ENCOUNTER_ALIASES = {
    { "玛洛加尔领主", "Lord Marrowgar", "Marrowgar" }, { "亡语者女士", "Lady Deathwhisper", "LDW" },
    { "冰冠冰川炮舰战", "Icecrown Gunship Battle", "Gunship" }, { "死亡使者萨鲁法尔", "Deathbringer Saurfang", "DBS" },
    { "烂肠", "Festergut" }, { "腐面", "Rotface" }, { "普崔塞德教授", "Professor Putricide", "PP" },
    { "鲜血王子议会", "Blood Prince Council", "BPC" }, { "鲜血女王兰娜瑟尔", "Blood-Queen Lana'thel", "BQL" },
    { "踏梦者瓦莉瑟瑞娅", "Valithria Dreamwalker", "VDW" }, { "辛达苟萨", "Sindragosa" }, { "巫妖王", "The Lich King", "LK", "阿尔萨斯", "Arthas" },
    { "哈里昂", "Halion" }, { "奥妮克希亚", "Onyxia" }, { "玛里苟斯", "Malygos" }, { "萨塔里奥", "Sartharion" },
    { "尤格-萨隆", "Yogg-Saron", "Yogg" }, { "观察者奥尔加隆", "Algalon the Observer", "Algalon" },
    { "阿努巴拉克", "Anub'arak" }, { "克尔苏加德", "Kel'Thuzad", "KT" }, { "萨菲隆", "Sapphiron" },
    { "伊利丹·怒风", "Illidan Stormrage", "Illidan", "蛋总" }, { "凯尔萨斯·逐日者", "Kael'thas Sunstrider", "Kaelthas" },
    { "瓦丝琪", "Lady Vashj", "Vashj" }, { "基尔加丹", "Kil'jaeden", "KJ" }, { "阿克蒙德", "Archimonde" },
    { "猎手阿图门", "Attumen the Huntsman", "Attumen" }, { "玛克扎尔王子", "Prince Malchezaar", "Malchezaar" },
    { "拉格纳罗斯", "Ragnaros", "Rag" }, { "奈法利安", "Nefarian", "Nef" }, { "克苏恩", "C'Thun" },
    { "奥拉基尔", "Al'Akir" }, { "奥卓克希昂", "Ultraxion" }, { "死亡之翼的背脊", "Spine of Deathwing", "Spine" },
    { "疯狂的死亡之翼", "Madness of Deathwing", "Madness" },
    { "石头守卫", "The Stone Guard", "Stone Guard" }, { "受诅者魔封", "Feng the Accursed", "Feng" },
    { "缚灵者戈拉亚", "Gara'jal the Spiritbinder", "Garajal" }, { "先王之魂", "The Spirit Kings", "Spirit Kings" },
    { "伊拉贡", "Elegon" }, { "皇帝的意志", "Will of the Emperor", "WoE" },
    { "皇家宰相佐尔洛克", "Imperial Vizier Zor'lok", "Zorlok" }, { "刀锋领主塔亚克", "Blade Lord Ta'yak", "Tayak" },
    { "加拉隆", "Garalon" }, { "风领主梅尔加拉克", "Wind Lord Mel'jarak", "Meljarak" },
    { "琥珀塑形者昂舒克", "Amber-Shaper Un'sok", "Unsok" }, { "大女皇夏柯希尔", "Grand Empress Shek'zeer", "Shekzeer" },
    { "无尽守护者", "Protectors of the Endless" }, { "烛龙", "Tsulong" }, { "雷施", "Lei Shi" }, { "惧之煞", "Sha of Fear" },
    { "击碎者金罗克", "Jin'rokh the Breaker", "Jinrokh" }, { "赫利东", "Horridon" }, { "长者议会", "Council of Elders" },
    { "托多斯", "Tortos" }, { "墨格瑞拉", "Megaera" }, { "季鹍", "Ji-Kun", "Jikun" }, { "遗忘者杜鲁姆", "Durumu the Forgotten", "Durumu" },
    { "普利莫修斯", "Primordius" }, { "黑暗意志", "Dark Animus" }, { "铁穹", "Iron Qon" },
    { "魔古双后", "Twin Consorts" }, { "雷神", "Lei Shen", "Leishen" }, { "莱登", "Ra-den", "Raden" },
    { "伊墨苏斯", "Immerseus" }, { "堕落的守护者", "The Fallen Protectors" }, { "诺鲁什", "Norushen" },
    { "傲之煞", "Sha of Pride" }, { "迦拉卡斯", "Galakras" }, { "钢铁战蝎", "Iron Juggernaut" },
    { "库卡隆黑暗萨满", "Kor'kron Dark Shaman", "Dark Shaman" }, { "纳兹戈林将军", "General Nazgrim", "Nazgrim" },
    { "马尔考罗克", "Malkorok" }, { "潘达利亚战利品", "Spoils of Pandaria", "Spoils" }, { "嗜血的索克", "Thok the Bloodthirsty", "Thok" },
    { "攻城匠师黑索", "Siegecrafter Blackfuse", "Blackfuse" }, { "卡拉克西英杰", "Paragons of the Klaxxi", "Klaxxi" },
    { "加尔鲁什·地狱咆哮", "Garrosh Hellscream", "Garrosh", "脑残吼" },
}
local function EncounterAliases(encounter)
    for _, aliases in ipairs(ENCOUNTER_ALIASES) do for _, name in ipairs(aliases) do
        if name == encounter.name then encounter.aliases = aliases; return end
    end end
end
local function Copy(t) return YiboCore.Defaults:Copy(t) end
local function NameAliases(item)
    local aliases, abbreviation, matched = {}, item.abbreviation, nil
    for abbr, names in pairs(ALIASES) do
        for index, name in ipairs(names) do if name == item.name then
            abbreviation = abbr
            -- Colliding abbreviations share a search token, not each other's
            -- full names. SoO/MH have multiple translations of one instance.
            if abbr == "ToT" or abbr == "ToC" or abbr == "DM" then
                local first = math.floor((index - 1) / 2) * 2 + 1; matched = { names[first], names[first + 1] }
            else matched = names end
        end end
    end
    if abbreviation then aliases[#aliases + 1] = abbreviation end
    for _, name in ipairs(matched or ALIASES[abbreviation] or {}) do aliases[#aliases + 1] = name end
    return aliases
end
local function Encounters(journalID)
    local result, seen = {}, {}
    if not EJ_GetEncounterInfoByIndex then return result, false end
    for i = 1, 100 do
        local name, _, journalEncounterID, _, _, _, encounterID = EJ_GetEncounterInfoByIndex(i, journalID)
        if not name then return result, #result > 0 end
        -- Journal IDs and dungeon encounter IDs are separate namespaces.
        if type(encounterID) ~= "number" or encounterID <= 0 or seen[encounterID] then return result, false end
        seen[encounterID] = true
        result[#result + 1] = { id = encounterID, journalID = journalEncounterID, name = name }
    end
    return result, false
end
function Catalog:Build()
    local targets, byID = {}, {}
    local function Add(entry) if not byID[entry.id] then targets[#targets + 1], byID[entry.id] = entry, entry end end
    local bosses = {}; for _, b in ipairs(YAB.GetAllBossList()) do bosses[b.key] = b end
    for _, info in ipairs(WORLD) do
        local boss = bosses[info[1]]
        if boss then Add({ id = "world:" .. boss.key, bossKey = boss.key, kind = "world", name = boss.name,
            englishName = info[2], aliases = { info[2], info[3] }, complete = true, available = true, reset = "weekly" }) end
    end
    for _, boss in pairs(bosses) do
        if boss.isCustom then
            Add({ id = boss.key, bossKey = boss.key, npcID = boss.id, kind = "custom", name = boss.name,
                aliases = { tostring(boss.id) }, complete = true, available = true, reset = boss.reset })
        end
    end
    local holiday = YAB.Holiday and YAB.Holiday:GetBoss("holiday:coren-direbrew")
    if holiday then Add({ id = holiday.key, bossKey = holiday.key, kind = "holiday", name = holiday.name,
        englishName = "Coren Direbrew", aliases = { "Brewfest", "美酒节", "科林", "Coren" }, complete = true, available = true, reset = "daily" }) end
    local oldInstance = (EJ_GetCurrentInstance and EJ_GetCurrentInstance()) or (EncounterJournal and EncounterJournal.instanceID)
    local oldDifficulty = EJ_GetDifficulty and EJ_GetDifficulty()
    for _, item in pairs(YAB.GetInstanceCatalog()) do
        local journalID = item.key and tonumber(item.key:match("^ej:(%d+)$"))
        local mapID = not journalID and item.instanceID or nil
        if journalID and EJ_GetInstanceInfo then mapID = select(10, EJ_GetInstanceInfo(journalID)) end
        if type(mapID) ~= "number" or mapID <= 0 then mapID = nil end
        local id = journalID and ("journal:" .. journalID) or ("instance:" .. mapID)
        local entry = { id = id, kind = "instance", name = item.name, aliases = NameAliases(item), expansion = item.expansion,
            journalID = journalID, mapID = mapID, isRaid = item.isRaid, difficulties = {}, encounters = {}, complete = false }
        if journalID and EJ_SelectInstance and EJ_SetDifficulty and EJ_IsValidInstanceDifficulty then
            EJ_SelectInstance(journalID)
            for _, difficultyID in ipairs(DIFFICULTIES) do
                if EJ_IsValidInstanceDifficulty(difficultyID) then
                    EJ_SetDifficulty(difficultyID)
                    local encounters, complete = Encounters(journalID)
                    local name = GetDifficultyInfo and GetDifficultyInfo(difficultyID)
                    entry.difficulties[#entry.difficulties + 1] = { id = difficultyID, name = name or (_G.YiboCore.Locale:Get("YiboAltoBoss", "UI.DIFFICULTY") .. difficultyID), encounters = encounters, complete = complete }
                    if complete then entry.complete = true; entry.encounters = encounters end
                end
            end
        end
        -- Older raids without EJ data get source-owned stable encounter keys
        -- after a complete lockout scan. These are not DungeonEncounterIDs.
        if not journalID then
            local directories = YiboAltoBossDB.targetLegacyDirectories and YiboAltoBossDB.targetLegacyDirectories[mapID]
            for difficultyID, directory in pairs(directories and directories.difficulties or {}) do
                entry.difficulties[#entry.difficulties + 1] = { id = difficultyID, name = directory.name, encounters = Copy(directory.encounters), complete = true }
                entry.complete, entry.encounters = true, Copy(directory.encounters)
            end
        end
        table.sort(entry.difficulties, function(a, b) return a.id < b.id end)
        local encounters, seen = {}, {}
        for _, e in ipairs(entry.difficulties) do
            -- Normal five-player dungeons have no periodic saved lockout.
            e.trackable = e.id ~= 1
            for _, encounter in ipairs(e.encounters) do
                EncounterAliases(encounter)
                if not seen[encounter.id] then encounters[#encounters + 1], seen[encounter.id] = Copy(encounter), true end
            end
        end
        entry.encounters = encounters
        entry.searchCoverage = { instanceNames = #entry.aliases > 1 and "bilingual" or "client-locale", encounterNames = "client-locale-and-curated-aliases" }
        entry.available = mapID ~= nil
        if not mapID then entry.complete = false end
        entry.reason = not entry.complete and _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.CATALOG_UNCONFIRMED_VISIT_THE_INSTANCE_OR_REFRESH_RAID_INFORMATION_FIRST") or nil
        Add(entry)
    end
    if oldInstance and EJ_SelectInstance then EJ_SelectInstance(oldInstance) end
    if oldDifficulty and EJ_SetDifficulty then EJ_SetDifficulty(oldDifficulty) end
    table.sort(targets, function(a, b) if a.kind ~= b.kind then return a.kind < b.kind end; return a.name < b.name end)
    self.value, self.byID = { targets = targets }, byID
    return self.value
end
function Catalog:Query() return Copy(self.value or self:Build()) end
function Catalog:Get(id) if not self.byID then self:Build() end; return self.byID[id] end
function Catalog:Invalidate() self.value, self.byID = nil, nil end

function Catalog:ObserveLegacyLockout(lockout)
    if type(lockout.instanceID) ~= "number" or type(lockout.difficultyID) ~= "number" or not lockout.bossCount
        or lockout.bossCount == 0 or #lockout.bosses ~= lockout.bossCount then return false end
    local definition = self:Get("instance:" .. lockout.instanceID)
    if not definition or definition.journalID then return false end
    local seen = {}
    for _, boss in ipairs(lockout.bosses) do
        if not boss.name or seen[boss.name] then return false end
        seen[boss.name] = true
    end
    YiboAltoBossDB.targetLegacyDirectories = YiboAltoBossDB.targetLegacyDirectories or {}
    local root = YiboAltoBossDB.targetLegacyDirectories
    local map = root[lockout.instanceID] or { nextID = 0, difficulties = {} }
    local previous = map.difficulties[lockout.difficultyID]
    local byName, encounters, changed = {}, {}, not previous
    for _, difficulty in pairs(map.difficulties) do for _, e in ipairs(difficulty.encounters) do byName[e.name] = e.id end end
    for i, boss in ipairs(lockout.bosses) do
        local id = byName[boss.name]
        if not id then map.nextID = map.nextID + 1; id = "legacy:" .. lockout.instanceID .. ":" .. map.nextID end
        encounters[#encounters + 1] = { id = id, name = boss.name }
        if not previous or not previous.encounters[i] or previous.encounters[i].id ~= id then changed = true end
    end
    if previous and #previous.encounters ~= #encounters then changed = true end
    map.difficulties[lockout.difficultyID] = { name = lockout.difficultyName, encounters = encounters,
        observedAt = GetServerTime and GetServerTime() or time(), locale = GetLocale and GetLocale() }
    root[lockout.instanceID] = map
    if changed then self:Invalidate() end
    return changed
end

function Catalog:ResolveSavedEncounter(mapID, difficultyID, name)
    if not self.value then self:Build() end
    local resolved
    for _, definition in ipairs(self.value.targets) do if definition.kind == "instance" and definition.mapID == mapID then
        for _, difficulty in ipairs(definition.difficulties) do if difficulty.id == difficultyID and difficulty.complete then
            for _, encounter in ipairs(difficulty.encounters) do if encounter.name == name then
                if resolved and resolved ~= encounter.id then return nil end
                resolved = encounter.id
            end end
        end end
    end end
    return resolved
end
