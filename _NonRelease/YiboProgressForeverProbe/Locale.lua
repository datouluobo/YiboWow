local _, P = ...
local en = {
    ready = "Ready: /ypg mounts, /ypg cooldown, /ypg report. Open the native collection/profession window first.",
    help = "/ypg mounts [page]; /ypg cooldown [page]; /ypg mount ID; /ypg recipe ID; /ypg spell ID; /ypg report. Pages contain up to 100 entries. Reload/logout to save.",
    sampled = "Saved sample %d (%s, %d rows). Raw observations require comparison with the native UI. /ypg report to copy.",
    unavailable = "Sampling stopped: unsupported client or unknown saved-data schema. Existing data is preserved.",
    not_ready = "Enter the game world before sampling.",
    invalid = "Use a positive integer for the page or ID.",
    no_sample = "No sample has been captured in this client yet.",
    title = "Yibo progress evidence - select all / copy",
    close = "Close",
    report_error = "Report could not be displayed: %s",
}
local zh = {
    ready = "已就绪：/ypg mounts 坐骑、/ypg cooldown 专业、/ypg report 报告。请先打开原生收藏或专业窗口。",
    help = "/ypg mounts [页码]；/ypg cooldown [页码]；/ypg mount ID；/ypg recipe ID；/ypg spell ID；/ypg report。每页最多100条，重载或退出后落盘。",
    sampled = "已保存样本 %d（%s，%d条）。原始观察须与原生界面对照；/ypg report 复制报告。",
    unavailable = "已停止采样：客户端不匹配或存档结构未知。已有数据保持原样。",
    not_ready = "请进入游戏世界后再采样。",
    invalid = "页码或ID必须是正整数。",
    no_sample = "当前客户端尚无采样。",
    title = "Yibo 成长取证 - 全选后复制",
    close = "关闭",
    report_error = "无法显示报告：%s",
}
-- Independent non-release probe; it neither requires Core nor saves a language preference.
local locale = type(GetLocale) == "function" and GetLocale() or "enUS"
P.text = (locale == "zhCN" or locale == "zhTW") and zh or en
