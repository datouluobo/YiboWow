local _, NS = ...

NS.Text = {
    enUS = {
        prefix = "Todo client probe: ", help = "/ytp report | start | snapshot | finish",
        wrongClient = "This probe is for Mists Classic only; no data was saved.",
        saved = "Native API snapshot saved.", empty = "No saved snapshot.",
        started = "Event capture started.", finished = "Event capture finished: %d events.",
        noCapture = "No event capture is active.",
    },
    zhCN = {
        prefix = "待办客户端探针：", help = "/ytp report | start | snapshot | finish",
        wrongClient = "此探针仅适用于熊猫人之谜怀旧服；未保存数据。",
        saved = "原生 API 快照已保存。", empty = "尚无采样记录。",
        started = "事件采集已开始。", finished = "事件采集已结束：%d 个事件。",
        noCapture = "当前没有进行中的事件采集。",
    },
}

function NS:T(key)
    local locale = GetLocale and GetLocale() or "enUS"
    if locale == "zhTW" then locale = "zhCN" end
    local texts = NS.Text[locale] or NS.Text.enUS
    return texts[key] or NS.Text.enUS[key] or key
end
