local _, P = ...
local resources = {
    enUS = {
        ready = "Ready. /ybf scan: talents; /ybf bags: bag positions; /ybf item <bag> <slot>: selected item; /ybf report: copy retained samples.",
        sampled = "Saved %s sample #%d. API results remain unverified evidence.",
        blocked = "Sampling stopped: %s. Existing evidence has been preserved.",
        invalid_item = "Use /ybf item <bag 0..4> <slot 1..200>; the slot must exist in the selected bag.",
        no_sample = "No samples yet. Enter the world and use /ybf scan or /ybf bags.",
        title = "Read-only evidence: Ctrl+C to copy; includes character GUID",
        close = "Close",
        report_error = "Report could not be opened: %s",
    },
    zhCN = {
        ready = "就绪。/ybf scan：天赋；/ybf bags：背包位置；/ybf item <袋> <槽>：指定物品；/ybf report：复制保留的样本。",
        sampled = "已保存 %s 样本 #%d。API 返回仍是待核实证据。",
        blocked = "停止采样：%s。已有证据保留。",
        invalid_item = "用法：/ybf item <袋 0..4> <槽 1..200>；槽位须在对应背包中存在。",
        no_sample = "暂无样本。进入世界后使用 /ybf scan 或 /ybf bags。",
        title = "只读取证：Ctrl+C 复制；包含角色 GUID",
        close = "关闭",
        report_error = "报告无法打开：%s",
    },
}
local locale = type(GetLocale) == "function" and GetLocale() or "enUS"
P.text = resources[(locale == "zhCN" or locale == "zhTW") and "zhCN" or "enUS"]
function P.Say(key, ...) print("|cff20e070[YiboBuildsForeverProbe]|r " .. string.format(P.text[key], ...)) end
