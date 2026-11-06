local _, NS = ...

NS.Text = {
    enUS = {
        prefix = "Mount client probe: ", help = "/ymp inventory | sources | tooltip | status",
        wrongClient = "This probe is for Mists Classic only; no data was saved.",
        apiMissing = "The native Mount Journal API is unavailable.", inventorySaved = "Native mount journal sample saved.",
        sourcesSaved = "Native source-name sample saved.", tooltipMissing = "No readable unit is attached to GameTooltip.",
        tooltipSummary = "Tooltip unit=%s, spellID=%s; scanned auras=%d, mount spell matches=%d.",
        statusEmpty = "No saved sample.", status = "Mount records=%d; client Interface=%s.",
    },
    zhCN = {
        prefix = "坐骑客户端探针：", help = "/ymp inventory | sources | tooltip | status",
        wrongClient = "此探针仅适用于熊猫人之谜怀旧服；未保存数据。",
        apiMissing = "当前客户端未提供原生坐骑日志 API。", inventorySaved = "原生坐骑日志采样已保存。",
        sourcesSaved = "原生来源名称采样已保存。", tooltipMissing = "GameTooltip 未关联可读取单位。",
        tooltipSummary = "提示单位=%s，法术ID=%s；扫描光环=%d 个，匹配坐骑法术=%d 个。",
        statusEmpty = "尚无采样记录。", status = "坐骑记录=%d；客户端 Interface=%s。",
    },
}

function NS:T(key)
    local locale = GetLocale and GetLocale() or "enUS"
    if locale == "zhTW" then locale = "zhCN" end
    local texts = NS.Text[locale] or NS.Text.enUS
    return texts[key] or NS.Text.enUS[key] or key
end
