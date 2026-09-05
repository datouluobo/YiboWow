local Addon = _G.YiboCurrency

-- The order below is the native Currency tab's functional grouping. Status is
-- data provenance, not a visibility rule: legacy balances remain readable.
local function Currency(id, title, short, expansion, sourceType, status)
    return { id = "currency:" .. id, currencyID = id, title = title, shortTitle = short, icon = nil,
        expansion = expansion, source = "currency", sourceType = sourceType or "标准货币",
        status = status or "仅存量遗留", totalAllowed = true, verified = "pending-client" }
end

local function Item(id, title, short, expansion, status)
    return { id = "item:" .. id, itemID = id, title = title, shortTitle = short, icon = nil,
        expansion = expansion, source = "item", sourceType = "物品代币",
        status = status or "仅存量遗留", totalAllowed = true, verified = "pending-client" }
end

local CURRENT = "当前可获取"
local LEGACY = "仅存量遗留"
local EXPIRED = "过期"

Addon.Catalog = {
    { id = "money", title = "金币", shortTitle = "金币", icon = "Interface\\MoneyFrame\\UI-GoldIcon", expansion = "通用", source = "money", sourceType = "金币", status = CURRENT, totalAllowed = true, verified = "implemented" },

    -- PvP
    Currency(392, "荣誉点数", "荣誉", "全版本通用", nil, CURRENT),
    Currency(390, "征服点数", "征服", "大地的裂变/熊猫人之谜", nil, CURRENT),
    Currency(1900, "竞技场点数", "竞技场", "巫妖王之怒", nil, EXPIRED),
    Item(43589, "冬拥湖荣誉奖章", "冬拥章", "巫妖王之怒", LEGACY),
    Item(43228, "岩石守卫者的碎片", "岩石碎片", "巫妖王之怒", LEGACY),
    Item(20558, "战歌峡谷荣誉奖章", "战歌", "全版本通用", LEGACY),
    Item(20559, "阿拉希盆地荣誉奖章", "阿拉希", "全版本通用", LEGACY),
    Item(29024, "风暴之眼荣誉奖章", "风暴眼", "燃烧的远征/巫妖王之怒", LEGACY),
    Item(47395, "征服之岛荣誉奖章", "征服之岛", "巫妖王之怒/大地的裂变", LEGACY),
    Item(42425, "远古海滩荣誉奖章", "远古海滩", "巫妖王之怒/大地的裂变", LEGACY),
    Currency(391, "托尔巴拉德奖章", "托巴奖章", "大地的裂变/熊猫人之谜", nil, LEGACY),
    Currency(789, "染血铸币", "染血币", "熊猫人之谜", nil, CURRENT),
    Item(20560, "奥特兰克山谷荣誉奖章", "奥山", "全版本通用", LEGACY),

    -- 地下城与团队
    Item(29434, "公正徽章", "公正章", "燃烧的远征", LEGACY),
    Item(40752, "英雄纹章", "英雄章", "巫妖王之怒", LEGACY),
    Item(45624, "征服纹章", "征服章", "巫妖王之怒", LEGACY),
    Item(40753, "勇气纹章", "勇气章", "巫妖王之怒", LEGACY),
    Item(47241, "凯旋纹章", "凯旋章", "巫妖王之怒", LEGACY),
    Item(49426, "寒冰纹章", "寒冰章", "巫妖王之怒", LEGACY),
    Currency(2589, "赛德里尔精华", "赛德里尔", "巫妖王之怒（十字军试炼）", nil, LEGACY),
    Currency(2711, "亵渎者的天灾石", "亵渎天灾石", "巫妖王之怒（冰冠堡垒）", nil, LEGACY),
    Currency(395, "正义点数", "正义", "大地的裂变/熊猫人之谜", nil, LEGACY),
    Currency(396, "勇气点数", "勇气", "大地的裂变", nil, LEGACY),
    Currency(614, "黑暗之尘", "黑暗尘", "大地的裂变（巨龙之魂）", nil, LEGACY),
    Currency(615, "堕落死亡之翼精华", "死翼精华", "大地的裂变（巨龙之魂）", nil, LEGACY),
    Currency(3350, "至尊石碎片", "至尊碎片", "熊猫人之谜", nil, CURRENT),
    Currency(3414, "至尊石碎块", "至尊碎块", "熊猫人之谜", nil, CURRENT),
    Currency(3416, "至尊石聚簇", "至尊聚簇", "熊猫人之谜", nil, CURRENT),

    -- 熊猫人之谜
    Currency(776, "战火徽记", "战火章", "熊猫人之谜", nil, CURRENT),
    Currency(738, "次级好运符", "次级符", "熊猫人之谜", nil, CURRENT),
    Currency(777, "永恒铸币", "永恒币", "熊猫人之谜", nil, CURRENT),
    Currency(697, "长者的好运符", "长者符", "大地的裂变/熊猫人之谜", nil, LEGACY),
    Currency(752, "魔古命运符文", "魔古符", "熊猫人之谜", nil, CURRENT),

    -- 其它
    Currency(241, "冠军的徽记", "冠军章", "巫妖王之怒", nil, LEGACY),
    Currency(515, "暗月奖券", "暗月券", "全版本通用", nil, CURRENT),
    Currency(81, "美食家奖励", "美食奖", "巫妖王之怒/大地的裂变", "专业货币", LEGACY),
    Currency(402, "铁掌徽记", "铁掌章", "熊猫人之谜", "专业货币", CURRENT),
    Currency(61, "达拉然珠宝匠硬币", "珠宝币", "巫妖王之怒", "专业货币", LEGACY),
    Currency(361, "珠宝名匠的荣誉奖章", "名匠奖章", "大地的裂变", "专业货币", LEGACY),
    Currency(416, "世界之树印记", "世树章", "大地的裂变", nil, LEGACY),
    Currency(393, "化石考古碎片", "化石", "全版本通用", "考古货币", CURRENT),
}
