local language = GetLocale and GetLocale() or "enUS"
local message = (language == "zhCN" or language == "zhTW")
    and "|cff20e070[Yibo]|r 隐兽寻踪：未选择适用的客户端清单，请安装匹配客户端的插件包。"
    or "|cff20e070[Yibo]|r Beast Paths: No supported target was selected. Install the matching client package."
if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage(message) end
