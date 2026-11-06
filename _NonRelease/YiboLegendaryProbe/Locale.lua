local _, NS = ...

NS.Text = {
    enUS = {
        prefix = "Legendary API probe: ", help = "/yep capture | status",
        wrongClient = "This probe is for Mists Classic only; no data was saved.",
        captured = "Captured native API results; summary: %s.", empty = "No saved capture.",
        quest = "quest", faction = "faction", items = "items", equipment = "equipment",
    },
    zhCN = {
        prefix = "传说之路原生 API 探针：", help = "/yep capture | status",
        wrongClient = "此探针仅适用于熊猫人之谜怀旧服；未保存数据。",
        captured = "已采集原生 API 结果；摘要：%s。", empty = "尚无采样记录。",
        quest = "任务", faction = "阵营", items = "物品", equipment = "装备",
    },
}

function NS:T(key)
    local locale = GetLocale and GetLocale() or "enUS"
    if locale == "zhTW" then locale = "zhCN" end
    local texts = NS.Text[locale] or NS.Text.enUS
    return texts[key] or NS.Text.enUS[key] or key
end
