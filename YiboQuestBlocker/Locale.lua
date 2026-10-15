local Core = _G.YiboCore
local YQB = _G.YQB or {}
_G.YQB = YQB

local function IsSupported()
    return not not (Core and Core.CheckAPIVersion and Core:CheckAPIVersion(13)
        and Core.HasCapability and Core:HasCapability("localization", 1)
        and Core:HasCapability("character-name-format", 1)
        and Core:HasCapability("basic-input", 1)
        and Core:HasCapability("account-view", 2)
        and Core:HasCapability("account-entry", 2)
        and Core:HasCapability("account-surface-budget", 2)
        and Core.Locale and Core.Locale.Register and Core.Locale.Get
        and Core.IsInitialized and Core:IsInitialized()
        and Core.AccountView and type(Core.AccountView.GetScrollSurfaceWidth) == "function" and Core.Entry and Core.Characters
        and Core.Characters.FormatName and Core.UITheme and Core.UITheme.CreateInput)
end

YQB.CoreCompatible = IsSupported() == true
if not YQB.CoreCompatible then
    if Core and Core.Print then
        Core:Print("YiboQuestBlocker requires YiboCore API 13 with localization:1, character-name-format:1, basic-input:1, account-view:2 and account-entry:2, account-surface-budget:2. Update YiboCore to enable QuestBlocker.")
    end
    return
end

Core.Locale:Register("YiboQuestBlocker", "zh", {
    ["CORE.UNAVAILABLE"] = "YiboCore 不可用。",
    ["CORE.UPGRADE"] = "需要 YiboCore API v13 及语言服务、角色名格式化、基础输入、账号页面与入口能力。请更新 YiboCore 后再使用任务屏蔽。 (account-surface-budget:2)",
    ["CORE.INTEGRATION_FAILED"] = "QuestBlocker Core 集成失败：%s",
    ["PAGE.TITLE"] = "任务屏蔽",
    ["PAGE.GLOBAL_FIELD"] = "全局屏蔽",
    ["PAGE.CHARACTER_FIELD"] = "角色屏蔽",
    ["PAGE.ALL_REALMS"] = "所有服务器",
    ["PAGE.DESCRIPTION"] = "角色身份、页面、入口、字段与排序由 Core 管理；拒绝规则、运行设置和诊断由 QuestBlocker 保存。",
    ["PAGE.ENTRY"] = "[Yibo] 任务屏蔽",
    ["PAGE.UNKNOWN_REALM"] = "未知服务器",
    ["PAGE.UNKNOWN_QUEST"] = "未知任务",
    ["PAGE.DAILY"] = "日常",
    ["PAGE.NORMAL"] = "普通",
    ["PAGE.HIDE_COMPLETE"] = "隐藏已完成",
    ["PAGE.LEVEL"] = "等级",
    ["PAGE.QUEST"] = "任务",
    ["PAGE.GLOBAL"] = "全局",
    ["PAGE.QUEST_ID"] = "任务 ID",
    ["PAGE.ADD_CURRENT"] = "+ 当前角色",
    ["PAGE.ADD_GLOBAL"] = "+ 全局",
    ["PAGE.ABANDON"] = "放弃日志中的已拒绝任务",
    ["PAGE.PAUSED_ABANDON"] = "暂停模式：不可手动放弃",
    ["PAGE.SUMMARY"] = "全局 %d · 当前 %d · 总计 %d",
    ["PAGE.CHARACTER"] = "角色",
    ["PAGE.BLOCKED_GROUP"] = "拒绝任务 (%d 个)",
    ["PAGE.CURRENT_GROUP"] = "当前角色任务 (%s)",
    ["PAGE.CURRENT_SUMMARY"] = "%d 个全局拒绝任务 · %d 名角色",
    ["PAGE.INVALID_LEVEL"] = "无效等级表达式：%s",
    ["PAGE.PROCESS_MODE"] = "处理模式",
    ["PAGE.CLEANUP_LABEL"] = "任务屏蔽个人设置",
    ["PAGE.CLEANUP_DETAIL"] = "%d 个个人拒绝任务",
    ["PAGE.NO_CHARACTER_CACHE"] = "无角色缓存",
    ["SETTINGS.MODE"] = "处理模式",
    ["SETTINGS.MODE_HELP"] = "拒绝模式（推荐）：在选择与接取阶段跳过或拒绝已屏蔽任务；若任务异常进入日志，会在交互结束后安全放弃。\n\n放弃模式（旧版兼容）：不干预选择与接取；已屏蔽任务进入日志后，在任务交互结束时自动放弃。\n\n暂停模式：不拦截、不自动放弃，也不能使用手动放弃；规则和矩阵继续保留，切回任一处理模式即可恢复。",
    ["SETTINGS.ADAPTER_STATUS"] = "适配状态",
    ["SETTINGS.ADAPTER_INCOMPATIBLE"] = "不兼容，请关闭自动接任务功能",
    ["SETTINGS.ADAPTER_SUPPORTED"] = "支持自动接任务",
    ["SETTINGS.ADAPTER_UNVERIFIED"] = "仅直接拒绝，续办待实机验证",
    ["SETTINGS.ADAPTER_LINE"] = "%s%s：%s",
    ["SETTINGS.NO_ADAPTERS"] = "未检测到已加载的已知自动接任务插件。未知插件同样只启用直接拒绝。",
    ["MODE.DIRECT"] = "处理模式：拒绝",
    ["MODE.ABANDON"] = "处理模式：放弃",
    ["MODE.PAUSED"] = "处理模式：暂停",
    ["CHAT.PREFIX"] = "|cff20e070[Yibo]|r 任务屏蔽：",
    ["CHAT.TURN_OFF_AUTO_ACCEPT"] = "请关闭自动接任务功能",
    ["CHAT.AUTO_ACCEPT_SUPPORTED"] = "支持自动接任务",
    ["FILTER.AT_LEAST"] = "以上",
    ["FILTER.AT_MOST"] = "以下",
    ["FILTER.EQUAL"] = "等于",
    ["FILTER.RANGE"] = "至",
    ["STATUS.AUTO_CONTINUE_STOPPED"] = "自动续办停止",
    ["STATUS.QUEUED_GLOBAL"] = "已标记全局拒绝任务，等待自动放弃：%s",
    ["STATUS.QUEUED_CHARACTER"] = "已标记个人拒绝任务，等待自动放弃：%s",
    ["STATUS.QUEUED_GLOBAL_CONFIRM"] = "已标记确认型全局拒绝任务，等待自动放弃：%s",
    ["STATUS.QUEUED_CHARACTER_CONFIRM"] = "已标记确认型个人拒绝任务，等待自动放弃：%s",
    ["STATUS.CANNOT_ABANDON"] = "任务无法放弃：%s",
    ["STATUS.DIRECT_REJECTED"] = "已按%s规则直接拒绝任务：%s",
    ["STATUS.SKIPPED"] = "已按%s规则在任务列表中跳过：%s",
    ["DIAGNOSTIC.DIRECT_REJECTED"] = "已直接拒绝",
    ["DIAGNOSTIC.GLOBAL_RULE"] = "全局规则",
    ["DIAGNOSTIC.CHARACTER_RULE"] = "当前角色规则",
    ["STATUS.GLOBAL"] = "全局",
    ["STATUS.PERSONAL"] = "个人",
    ["DIAGNOSTIC.CANNOT_HANDLE"] = "无法自动处理",
    ["DIAGNOSTIC.NO_DECLINE_API"] = "客户端未提供 DeclineQuest",
    ["DIAGNOSTIC.SKIPPED"] = "已在列表跳过",
})

Core.Locale:Register("YiboQuestBlocker", "en", {
    ["CORE.UNAVAILABLE"] = "YiboCore is unavailable.",
    ["CORE.UPGRADE"] = "YiboQuestBlocker requires YiboCore API v13 with localization, character-name formatting, basic-input, account-view and account-entry capabilities. Update YiboCore to use QuestBlocker. (account-surface-budget:2)",
    ["CORE.INTEGRATION_FAILED"] = "QuestBlocker Core integration failed: %s",
    ["PAGE.TITLE"] = "Quest Blocker",
    ["PAGE.GLOBAL_FIELD"] = "Global blocks",
    ["PAGE.CHARACTER_FIELD"] = "Character blocks",
    ["PAGE.ALL_REALMS"] = "All realms",
    ["PAGE.DESCRIPTION"] = "Core manages character identity, pages, entries, fields and ordering. QuestBlocker stores blocking rules, runtime settings and diagnostics.",
    ["PAGE.ENTRY"] = "[Yibo] Quest Blocker",
    ["PAGE.UNKNOWN_REALM"] = "Unknown realm",
    ["PAGE.UNKNOWN_QUEST"] = "Unknown quest",
    ["PAGE.DAILY"] = "Daily",
    ["PAGE.NORMAL"] = "Normal",
    ["PAGE.HIDE_COMPLETE"] = "Hide completed",
    ["PAGE.LEVEL"] = "Level",
    ["PAGE.QUEST"] = "Quest",
    ["PAGE.GLOBAL"] = "Global",
    ["PAGE.QUEST_ID"] = "Quest ID",
    ["PAGE.ADD_CURRENT"] = "+ Current character",
    ["PAGE.ADD_GLOBAL"] = "+ Global",
    ["PAGE.ABANDON"] = "Abandon blocked quests in log",
    ["PAGE.PAUSED_ABANDON"] = "Paused: manual abandon unavailable",
    ["PAGE.SUMMARY"] = "Global %d · Current %d · Total %d",
    ["PAGE.CHARACTER"] = "Character",
    ["PAGE.BLOCKED_GROUP"] = "Blocked quests (%d)",
    ["PAGE.CURRENT_GROUP"] = "Current character quests (%s)",
    ["PAGE.CURRENT_SUMMARY"] = "%d global blocked quests · %d characters",
    ["PAGE.INVALID_LEVEL"] = "Invalid level expression: %s",
    ["PAGE.PROCESS_MODE"] = "Processing mode",
    ["PAGE.CLEANUP_LABEL"] = "Personal quest blocking settings",
    ["PAGE.CLEANUP_DETAIL"] = "%d personal blocked quests",
    ["PAGE.NO_CHARACTER_CACHE"] = "No character cache",
    ["SETTINGS.MODE"] = "Processing mode",
    ["SETTINGS.MODE_HELP"] = "Reject mode (recommended): skip or reject blocked quests while choosing or accepting them. If one unexpectedly enters the log, abandon it safely after the interaction ends.\n\nAbandon mode (legacy): do not interfere with choosing or accepting; automatically abandon blocked quests from the log after the interaction ends.\n\nPaused: do not intercept, automatically abandon, or allow manual abandon. Rules and the matrix remain available; switch modes to resume processing.",
    ["SETTINGS.ADAPTER_STATUS"] = "Compatibility status",
    ["SETTINGS.ADAPTER_INCOMPATIBLE"] = "Incompatible; disable automatic quest acceptance",
    ["SETTINGS.ADAPTER_SUPPORTED"] = "Automatic quest acceptance supported",
    ["SETTINGS.ADAPTER_UNVERIFIED"] = "Direct rejection only; continuation not verified in game",
    ["SETTINGS.ADAPTER_LINE"] = "%s%s: %s",
    ["SETTINGS.NO_ADAPTERS"] = "No known automatic quest-acceptance addon is loaded. Unknown addons also use direct rejection only.",
    ["MODE.DIRECT"] = "Processing mode: Reject",
    ["MODE.ABANDON"] = "Processing mode: Abandon",
    ["MODE.PAUSED"] = "Processing mode: Paused",
    ["CHAT.PREFIX"] = "|cff20e070[Yibo]|r Quest Blocker: ",
    ["CHAT.TURN_OFF_AUTO_ACCEPT"] = "Disable automatic quest acceptance",
    ["CHAT.AUTO_ACCEPT_SUPPORTED"] = "Automatic quest acceptance supported",
    ["FILTER.AT_LEAST"] = "at least",
    ["FILTER.AT_MOST"] = "at most",
    ["FILTER.EQUAL"] = "equal to",
    ["FILTER.RANGE"] = "to",
    ["STATUS.AUTO_CONTINUE_STOPPED"] = "Automatic continuation stopped",
    ["STATUS.QUEUED_GLOBAL"] = "Marked global blocked quest for automatic abandon: %s",
    ["STATUS.QUEUED_CHARACTER"] = "Marked personal blocked quest for automatic abandon: %s",
    ["STATUS.QUEUED_GLOBAL_CONFIRM"] = "Marked confirmed global blocked quest for automatic abandon: %s",
    ["STATUS.QUEUED_CHARACTER_CONFIRM"] = "Marked confirmed personal blocked quest for automatic abandon: %s",
    ["STATUS.CANNOT_ABANDON"] = "Cannot abandon quest: %s",
    ["STATUS.DIRECT_REJECTED"] = "Directly rejected quest under the %s rule: %s",
    ["STATUS.SKIPPED"] = "Skipped quest in the list under the %s rule: %s",
    ["DIAGNOSTIC.DIRECT_REJECTED"] = "Rejected directly",
    ["DIAGNOSTIC.GLOBAL_RULE"] = "global rule",
    ["DIAGNOSTIC.CHARACTER_RULE"] = "current-character rule",
    ["STATUS.GLOBAL"] = "global",
    ["STATUS.PERSONAL"] = "personal",
    ["DIAGNOSTIC.CANNOT_HANDLE"] = "Cannot process automatically",
    ["DIAGNOSTIC.NO_DECLINE_API"] = "The client does not provide DeclineQuest",
    ["DIAGNOSTIC.SKIPPED"] = "Skipped in quest list",
})

function YQB.T(key, ...)
    return Core.Locale:Get("YiboQuestBlocker", key, ...)
end
