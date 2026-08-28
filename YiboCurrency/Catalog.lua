local Addon = _G.YiboCurrency

-- Every entry is a baseline record: stable key, expansion/category and source
-- are explicit. `verified` documents the 5.5.4 probe status rather than
-- turning an absent API result into a zero balance.
Addon.Catalog = {
    { id="money", title="金币", expansion="其它与未归类", category="常规货币", source="money", verified=true },
    { id="currency:390", currencyID=390, title="征服点数", expansion="熊猫人之谜", category="常规货币", source="currency", verified=false },
    { id="currency:392", currencyID=392, title="荣誉点数", expansion="熊猫人之谜", category="常规货币", source="currency", verified=false },
    { id="currency:395", currencyID=395, title="正义点数", expansion="大地的裂变", category="常规货币", source="currency", verified=false },
    { id="currency:396", currencyID=396, title="勇气点数", expansion="熊猫人之谜", category="常规货币", source="currency", verified=false },
    { id="currency:697", currencyID=697, title="长者的好运符", expansion="熊猫人之谜", category="专业与系统货币", source="currency", verified=false },
    { id="currency:738", currencyID=738, title="次级好运符", expansion="熊猫人之谜", category="专业与系统货币", source="currency", verified=false },
    { id="currency:752", currencyID=752, title="魔古命运符文", expansion="熊猫人之谜", category="专业与系统货币", source="currency", verified=false },
    { id="currency:776", currencyID=776, title="战火徽记", expansion="熊猫人之谜", category="专业与系统货币", source="currency", verified=false },
    { id="currency:777", currencyID=777, title="永恒铸币", expansion="熊猫人之谜", category="常规货币", source="currency", verified=false },
    { id="currency:241", currencyID=241, title="冠军的徽记", expansion="巫妖王之怒", category="常规货币", source="currency", verified=false },
    { id="currency:61", currencyID=61, title="达拉然珠宝匠硬币", expansion="巫妖王之怒", category="专业与系统货币", source="currency", verified=false },
    { id="currency:81", currencyID=81, title="美食家奖励", expansion="大地的裂变", category="专业与系统货币", source="currency", verified=false },
    { id="archaeology:dwarf", currencyID=384, title="矮人考古碎片", expansion="考古", category="专业与系统货币", source="archaeology", verified=false },
    { id="archaeology:troll", currencyID=385, title="巨魔考古碎片", expansion="考古", category="专业与系统货币", source="archaeology", verified=false },
    { id="archaeology:fossil", currencyID=393, title="化石考古碎片", expansion="考古", category="专业与系统货币", source="archaeology", verified=false },
    { id="archaeology:night-elf", currencyID=394, title="暗夜精灵考古碎片", expansion="考古", category="专业与系统货币", source="archaeology", verified=false },
    { id="archaeology:orc", currencyID=397, title="兽人考古碎片", expansion="考古", category="专业与系统货币", source="archaeology", verified=false },
    { id="archaeology:draenei", currencyID=398, title="德莱尼考古碎片", expansion="考古", category="专业与系统货币", source="archaeology", verified=false },
    { id="archaeology:vrykul", currencyID=399, title="维库考古碎片", expansion="考古", category="专业与系统货币", source="archaeology", verified=false },
    { id="archaeology:nerubian", currencyID=400, title="蛛魔考古碎片", expansion="考古", category="专业与系统货币", source="archaeology", verified=false },
    { id="archaeology:tolvir", currencyID=401, title="托维尔考古碎片", expansion="考古", category="专业与系统货币", source="archaeology", verified=false },
    { id="archaeology:pandaren", currencyID=676, title="熊猫人考古碎片", expansion="考古", category="专业与系统货币", source="archaeology", verified=false },
    { id="archaeology:mogu", currencyID=677, title="魔古考古碎片", expansion="考古", category="专业与系统货币", source="archaeology", verified=false },
    { id="archaeology:mantid", currencyID=754, title="螳螂妖考古碎片", expansion="考古", category="专业与系统货币", source="archaeology", verified=false },
    { id="item:29434", itemID=29434, title="公正徽章", expansion="燃烧的远征", category="物品代币", source="item", verified=false },
    { id="item:20558", itemID=20558, title="战歌峡谷荣誉奖章", expansion="经典旧世（60 年代）", category="物品代币", source="item", verified=false },
    { id="item:20559", itemID=20559, title="阿拉希盆地荣誉奖章", expansion="经典旧世（60 年代）", category="物品代币", source="item", verified=false },
    { id="item:20560", itemID=20560, title="奥特兰克山谷荣誉奖章", expansion="经典旧世（60 年代）", category="物品代币", source="item", verified=false },
}
Addon.ExpansionOrder = { "熊猫人之谜", "大地的裂变", "巫妖王之怒", "燃烧的远征", "经典旧世（60 年代）", "自定义货币", "考古", "其它与未归类" }
Addon.CategoryOrder = { "常规货币", "专业与系统货币", "物品代币" }
