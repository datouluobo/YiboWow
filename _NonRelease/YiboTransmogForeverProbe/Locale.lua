local _, P = ...
local en = {
    ready = "Ready: /ytf scan, /ytf item ID|link, /ytf cat ID, /ytf bags, /ytf quest, /ytf verify, /ytf report. Read-only; reload or log out to save.",
    help = "/ytf scan; /ytf item ID|link; /ytf cat ID; /ytf bags; /ytf quest; /ytf verify; /ytf report. Quest-complete windows are sampled automatically and verified 3s after turn-in.",
    sampled = "Saved sample %d (%s): %d rows. /ytf report to copy the summary.",
    unavailable = "Sampling stopped: unsupported client or unknown saved-data schema. Existing data is preserved.",
    not_ready = "Enter the game world before sampling.",
    invalid = "Use a positive integer ID or an item link.",
    no_quest = "Open a quest detail or quest-complete window first.",
    no_pending = "No turned-in quest to verify. Open the quest-complete window, turn the quest in, then try again.",
    no_sample = "No sample has been captured in this client yet.",
    title = "Yibo transmog evidence - select all / copy",
    close = "Close",
    report_error = "Report could not be displayed: %s",
}
local zh = {
    ready = "已就绪：/ytf scan、/ytf item 物品ID或链接、/ytf cat 分类ID、/ytf bags、/ytf quest、/ytf verify、/ytf report。只读；重载或退出后落盘。",
    help = "/ytf scan；/ytf item 物品ID或链接；/ytf cat 分类ID；/ytf bags；/ytf quest；/ytf verify；/ytf report。任务交付窗口会自动采样，交付 3 秒后自动核对。",
    sampled = "已保存样本 %d（%s）：%d 行。/ytf report 复制摘要。",
    unavailable = "已停止采样：客户端不匹配或存档结构未知。已有数据保持原样。",
    not_ready = "请进入游戏世界后再采样。",
    invalid = "请输入正整数ID或物品链接。",
    no_quest = "请先打开任务详情或任务交付窗口。",
    no_pending = "没有可核对的已交付任务。请先打开任务交付窗口并交付，再重试。",
    no_sample = "当前客户端尚无采样。",
    title = "Yibo 幻化取证 - 全选后复制",
    close = "关闭",
    report_error = "无法显示报告：%s",
}
-- Independent non-release probe; it neither requires Core nor saves a language preference.
local locale = type(GetLocale) == "function" and GetLocale() or "enUS"
P.text = (locale == "zhCN" or locale == "zhTW") and zh or en
