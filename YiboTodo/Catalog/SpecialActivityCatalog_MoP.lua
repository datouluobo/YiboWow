local Addon = _G.YiboTodo
local Catalog = Addon.Catalog

-- Quest, NPC, and item identities were verified in-game.  These are the
-- quest-triggering fish items, not generic fishing silhouettes.
Catalog.specialActivities = {
    ["mop.nat-pagle.flying-tiger-gourami"] = { id = "mop.nat-pagle.flying-tiger-gourami", label = "飞行虎皮丝足鱼", questID = 31443, scope = "character", scheduleKind = "daily-07", resetHour = 7, monitoringGroupID = "nat-pagle", order = 10, iconItemID = 86542, defaultEnabled = true, verificationStatus = "verified", turnInNPCID = 63721 },
    ["mop.nat-pagle.spinefish-alpha"] = { id = "mop.nat-pagle.spinefish-alpha", label = "霸王刺皮鱼", questID = 31444, scope = "character", scheduleKind = "daily-07", resetHour = 7, monitoringGroupID = "nat-pagle", order = 20, iconItemID = 86544, defaultEnabled = true, verificationStatus = "verified", turnInNPCID = 63721 },
    ["mop.nat-pagle.mimic-octopus"] = { id = "mop.nat-pagle.mimic-octopus", label = "拟态章鱼", questID = 31446, scope = "character", scheduleKind = "daily-07", resetHour = 7, monitoringGroupID = "nat-pagle", order = 30, iconItemID = 86545, defaultEnabled = true, verificationStatus = "verified", turnInNPCID = 63721 },
    ["mop.brilltron-4000"] = { id = "mop.brilltron-4000", label = "布林顿 4000", questID = 31752, scope = "account", scheduleKind = "daily-07", resetHour = 7, monitoringGroupID = "brilltron-4000", order = 10, iconItemID = 87214, verificationStatus = "user-confirmed", npcID = 43929 },
}

local darkmoon = {
    -- 商业技能顺序与商业冷却保持一致。
    { 29506, "炼金", "调制饮料", 171, "Trade_Alchemy", true }, { 29508, "锻造", "贝贝需要两双鞋", 164, "Trade_BlackSmithing", true },
    { 29510, "附魔", "变废为宝", 333, "Trade_Engraving", true }, { 29511, "工程", "修一下又是一辆好坦克", 202, "Trade_Engineering", true },
    { 29515, "铭文", "书写未来", 773, "INV_Inscription_Tradeskill01", true }, { 29516, "珠宝加工", "光彩夺目的马戏团", 755, "INV_Misc_Gem_01", true },
    { 29517, "制皮", "关注奖品", 165, "Trade_LeatherWorking", true }, { 29520, "裁缝", "遍地旗帜！", 197, "Trade_Tailoring", true },
    -- 所有角色均可持有的生活技能固定为：钓鱼、烹饪、急救、考古。
    { 29513, "钓鱼", "咸湿老水手的最爱", 356, "Trade_Fishing", true }, { 29509, "烹饪", "让青蛙肉更松脆", 185, "INV_Misc_Food_15", true },
    { 29512, "急救", "救治伤员", 129, "Spell_Holy_Heal", true }, { 29507, "考古", "给小家伙们乐一乐", 794, "Trade_Archaeology", true },
    -- 采集类保持可选，默认不占用矩阵。
    { 29514, "草药学", "救命草", 182, "Trade_Herbalism", false }, { 29518, "采矿", "蒸汽坦克，重装上阵", 186, "Trade_Mining", false },
    { 29519, "剥皮", "皮革打磨", 393, "INV_Misc_Pelt_Wolf_01", false },
}
for index, entry in ipairs(darkmoon) do
    local questID, label, taskLabel, professionID, icon, defaultEnabled = unpack(entry)
    local id = "mop.darkmoon-faire." .. tostring(questID)
    Catalog.specialActivities[id] = { id = id, label = label, taskLabel = taskLabel, questID = questID, scope = "character", scheduleKind = "event-weekly", monitoringGroupID = "darkmoon-faire", order = index * 10, professionID = professionID, icon = "Interface\\Icons\\" .. icon, defaultEnabled = defaultEnabled, verificationStatus = "verified" }
end
