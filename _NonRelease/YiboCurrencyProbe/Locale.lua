local _, NS = ...

NS.Text = {
    enUS = {
        prefix = "Currency client probe: ", help = "/ycp capture | status",
        wrongClient = "This probe is for Mists Classic only; no data was saved.",
        saved = "Native API sample saved.", empty = "No saved sample.",
        report = "Interface=%s, moneyAPI=%s, moneyCopper=%s, currencyInfoAPI=%s, listSizeAPI=%s, rows=%d",
    },
    zhCN = {
        prefix = "货币客户端探针：", help = "/ycp capture | status",
        wrongClient = "此探针仅适用于熊猫人之谜怀旧服；未保存数据。",
        saved = "原生 API 采样已保存。", empty = "尚无采样记录。",
        report = "Interface=%s，金币 API=%s，铜币=%s，货币详情 API=%s，列表 API=%s，列表行=%d",
    },
}

function NS:T(key)
    local locale = GetLocale and GetLocale() or "enUS"
    if locale == "zhTW" then locale = "zhCN" end
    local texts = NS.Text[locale] or NS.Text.enUS
    return texts[key] or NS.Text.enUS[key] or key
end
