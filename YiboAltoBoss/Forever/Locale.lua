if not _G.YAB.CoreReady then return end
local Core = _G.YiboCore
Core.Locale:Register("YiboAltoBoss", "zh", {
    ["FOREVER.TITLE"] = "目标与副本进度",
    ["FOREVER.NPC_HINT"] = "输入 NPC ID。击杀标记由玩家手动添加和撤销。",
    ["FOREVER.CUSTOM_EMPTY"] = "输入 NPC ID 添加。点击列表中的目标可填入 ID。",
    ["FOREVER.ADD_TARGETS"] = "在设置中按 NPC ID 添加自定义目标。",
    ["FOREVER.NO_CHARACTERS"] = "当前范围没有可显示的角色记录。",
    ["FOREVER.NO_INSTANCE_DATA"] = "尚无已采集的副本进度。",
    ["FOREVER.FIELD_HIDDEN"] = "当前视图已隐藏进度字段。",
    ["FOREVER.NOT_MARKED"] = "未标记",
    ["FOREVER.MANUAL_MARK"] = "手动标记",
    ["FOREVER.MANUAL_AT"] = "手动标记于 %s",
    ["FOREVER.TOGGLE_MARK"] = "左键添加或撤销当前角色的标记。",
    ["FOREVER.SNAPSHOT_AT"] = "采集于 %s",
    ["FOREVER.STORE_MISMATCH"] = "无限服存档格式不兼容，加载已停止。",
    ["FOREVER.START_FAILED"] = "目标与副本进度加载失败：%s",
})
Core.Locale:Register("YiboAltoBoss", "en", {
    ["FOREVER.TITLE"] = "Targets and Instance Progress",
    ["FOREVER.NPC_HINT"] = "Enter an NPC ID. Kill marks are added and cleared manually.",
    ["FOREVER.CUSTOM_EMPTY"] = "Enter an NPC ID to add a target. Select a listed target to fill its ID.",
    ["FOREVER.ADD_TARGETS"] = "Add custom targets by NPC ID in Settings.",
    ["FOREVER.NO_CHARACTERS"] = "There are no character records in this scope.",
    ["FOREVER.NO_INSTANCE_DATA"] = "No instance progress has been collected.",
    ["FOREVER.FIELD_HIDDEN"] = "The progress field is hidden in this view.",
    ["FOREVER.NOT_MARKED"] = "Unmarked",
    ["FOREVER.MANUAL_MARK"] = "Manual mark",
    ["FOREVER.MANUAL_AT"] = "Manually marked at %s",
    ["FOREVER.TOGGLE_MARK"] = "Left-click to add or clear the current character's mark.",
    ["FOREVER.SNAPSHOT_AT"] = "Observed at %s",
    ["FOREVER.STORE_MISMATCH"] = "The Forever saved data format is incompatible. Loading stopped.",
    ["FOREVER.START_FAILED"] = "Targets and Instance Progress could not start: %s",
})
