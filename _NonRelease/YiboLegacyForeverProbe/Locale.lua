local _, P = ...
local en = {
    ready = "Ready: /ylg scan to sample, /ylg report to copy. Read-only; reload or log out to save.",
    help = "/ylg scan; /ylg ach ID; /ylg report. scan = constants, renown, trees, challenges, location. Reload/logout to save.",
    sampled = "Saved sample %d (%s): %d categories, %d challenges. /ylg report to copy the summary.",
    unavailable = "Sampling stopped: unsupported client or unknown saved-data schema. Existing data is preserved.",
    not_ready = "Enter the game world before sampling.",
    invalid = "Use a positive integer achievement ID.",
    no_sample = "No sample has been captured in this client yet.",
    title = "Yibo Legacy evidence - select all / copy",
    close = "Close",
    report_error = "Report could not be displayed: %s",
}
local zh = {
    ready = "已就绪：/ylg scan 采样，/ylg report 复制摘要。只读；重载或退出后落盘。",
    help = "/ylg scan；/ylg ach 成就ID；/ylg report。scan 采集常量、名望、传承树、挑战与位置；重载或退出后落盘。",
    sampled = "已保存样本 %d（%s）：%d 个分类、%d 项挑战。/ylg report 复制摘要。",
    unavailable = "已停止采样：客户端不匹配或存档结构未知。已有数据保持原样。",
    not_ready = "请进入游戏世界后再采样。",
    invalid = "成就ID必须是正整数。",
    no_sample = "当前客户端尚无采样。",
    title = "Yibo 传承取证 - 全选后复制",
    close = "关闭",
    report_error = "无法显示报告：%s",
}
-- Independent non-release probe; it neither requires Core nor saves a language preference.
local locale = type(GetLocale) == "function" and GetLocale() or "enUS"
P.text = (locale == "zhCN" or locale == "zhTW") and zh or en
