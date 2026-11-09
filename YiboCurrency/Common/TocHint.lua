local messages = {
    en = { TOC_TARGET_MISSING = "|cff20e070[Yibo]|r YiboCurrency: No supported target TOC was selected. Install the matching client package." },
    zh = { TOC_TARGET_MISSING = "|cff20e070[Yibo]|r YiboCurrency：未选择适用的目标 TOC，请安装匹配客户端的插件包。" },
}
local locale = GetLocale and GetLocale() or "enUS"
local language = (locale == "zhCN" or locale == "zhTW") and "zh" or "en"
if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage(messages[language].TOC_TARGET_MISSING) end
