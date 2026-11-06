local _, P = ...
P.locales = {
    en = {
        ready = "Ready. /yaf start begins read-only recording; /yaf report copies the retained evidence.",
        help = "/yaf start; /yaf scan <label>; /yaf stop; /yaf report. Reload/logout to save to disk.",
        started = "Recording started. Enter the instance and open the native raid information normally.",
        stopped = "Recording stopped. /yaf report copies the evidence; reload/logout saves it to disk.",
        sampled = "Sample %d saved; retained samples: %d. Lockout and reset semantics remain unverified.",
        inactive = "Recording is off. Enter the world and use /yaf start first.",
        target_error = "Sampling stopped: expected the verified Forever project 18 / Interface 16001. Existing data is preserved.",
        db_error = "Unknown or malformed saved-data schema; sampling stopped and existing data preserved.",
        no_sample = "No retained samples. Enter the world and use /yaf start.",
        title = "AltoBoss Forever evidence - select all / copy",
        close = "Close",
        report_error = "Could not display the report: %s",
    },
    zh = {
        ready = "已就绪。/yaf start 开始只读取证；/yaf report 复制保留的证据。",
        help = "/yaf start 开始；/yaf scan <标签> 采样；/yaf stop 停止；/yaf report 复制。重载或退出后落盘。",
        started = "已开始记录。请正常进入副本，并由你打开原生团队信息。",
        stopped = "已停止记录。/yaf report 复制证据；重载或退出后落盘。",
        sampled = "已保存样本 %d；保留 %d 份样本。锁定与重置语义仍待核验。",
        inactive = "尚未开始记录。进入世界后先输入 /yaf start。",
        target_error = "已停止采样：需要已验证的无限项目 18 / Interface 16001。原有存档已保留。",
        db_error = "存档版本未知或结构损坏，已停止采样并保留原有数据。",
        no_sample = "尚无样本。进入世界后输入 /yaf start。",
        title = "AltoBoss 无限副本证据 - 全选后复制",
        close = "关闭",
        report_error = "无法显示报告：%s",
    },
}
-- This independent diagnostic has no Core dependency or persistent language setting.
local locale = type(GetLocale) == "function" and GetLocale() or "enUS"
P.text = P.locales[(locale == "zhCN" or locale == "zhTW") and "zh" or "en"]
