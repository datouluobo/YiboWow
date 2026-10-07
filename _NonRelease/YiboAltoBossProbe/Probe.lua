local ADDON = "YiboAltoBossProbe"
local MAX_EVENTS = 500
local db
local active = false

local function Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff20e070[YAB Probe]|r " .. tostring(message))
end

local function CurrentInstance()
    local name, instanceType, difficultyID, difficultyName, maxPlayers, _, _, instanceID, _, lfgDungeonID = GetInstanceInfo()
    return {
        name = name, instanceType = instanceType, difficultyID = difficultyID,
        difficultyName = difficultyName, maxPlayers = maxPlayers,
        instanceID = instanceID, lfgDungeonID = lfgDungeonID,
        zoneText = GetRealZoneText and GetRealZoneText() or nil,
    }
end

local function SavedInstancesSnapshot()
    local result = {}
    if type(GetNumSavedInstances) ~= "function" or type(GetSavedInstanceInfo) ~= "function" then
        return { available = false }
    end
    for index = 1, GetNumSavedInstances() or 0 do
        local name, lockoutID, resetSeconds, difficultyID, locked, extended, _, isRaid, maxPlayers, difficultyName, numEncounters, encounterProgress = GetSavedInstanceInfo(index)
        local entry = {
            name = name, lockoutID = lockoutID, resetSeconds = resetSeconds,
            difficultyID = difficultyID, locked = locked, extended = extended,
            isRaid = isRaid, maxPlayers = maxPlayers, difficultyName = difficultyName,
            numEncounters = numEncounters, encounterProgress = encounterProgress, bosses = {},
        }
        if type(GetSavedInstanceEncounterInfo) == "function" and tonumber(numEncounters) then
            for encounterIndex = 1, numEncounters do
                local bossName, _, isKilled = GetSavedInstanceEncounterInfo(index, encounterIndex)
                entry.bosses[#entry.bosses + 1] = { name = bossName, killed = isKilled }
            end
        end
        result[#result + 1] = entry
    end
    return result
end

local function Add(event, data)
    if not active or not db then return end
    data.time = date("!%Y-%m-%dT%H:%M:%SZ")
    data.elapsed = GetTime()
    data.event = event
    data.instance = CurrentInstance()
    local playerName, realm
    if UnitFullName then playerName, realm = UnitFullName("player") end
    data.player = playerName and (playerName .. "-" .. tostring(realm or GetRealmName())) or UnitName("player")
    db.events[#db.events + 1] = data
    if #db.events > MAX_EVENTS then table.remove(db.events, 1) end
end

local function Args(...)
    local result = {}
    for i = 1, select("#", ...) do
        local value = select(i, ...)
        local kind = type(value)
        if kind == "string" or kind == "number" or kind == "boolean" then result[i] = value
        elseif value == nil then result[i] = "<nil>"
        else result[i] = "<" .. kind .. ">" end
    end
    return result
end

local frame = CreateFrame("Frame")
local EVENTS = {
    "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED_INDOORS",
    "ENCOUNTER_START", "ENCOUNTER_END", "BOSS_KILL", "INSTANCE_ENCOUNTER_ENGAGE_UNIT",
    "CHAT_MSG_SYSTEM", "CHAT_MSG_MONSTER_YELL", "UPDATE_INSTANCE_INFO", "INSTANCE_SAVED",
    "INSTANCE_RESET_SUCCESS", "INSTANCE_RESET_FAILED",
}
for _, event in ipairs(EVENTS) do frame:RegisterEvent(event) end
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        if ... ~= ADDON then return end
        YiboAltoBossProbeDB = YiboAltoBossProbeDB or { events = {} }
        YiboAltoBossProbeDB.events = YiboAltoBossProbeDB.events or {}
        local version, build, dateText, interface = GetBuildInfo()
        YiboAltoBossProbeDB.meta = { version = version, build = build, date = dateText, interface = interface }
        db = YiboAltoBossProbeDB
        return
    end
    if event == "PLAYER_LOGIN" then
        Print("已加载。/yip on 后可记录击杀与游戏原生重置前后状态；完成后 /yip status、/reload。")
        return
    end
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local timestamp, subevent, _, sourceGUID, sourceName, sourceFlags, _, destGUID, destName, destFlags = CombatLogGetCurrentEventInfo()
        if subevent == "UNIT_DIED" or subevent == "PARTY_KILL" or subevent == "UNIT_DESTROYED" then
            Add(event, { timestamp = timestamp, subevent = subevent, sourceGUID = sourceGUID, sourceName = sourceName,
                sourceFlags = sourceFlags, destGUID = destGUID, destName = destName, destFlags = destFlags })
        end
        return
    end
    local eventArgs = Args(...)
    if event == "CHAT_MSG_SYSTEM" then
        local message = tostring(eventArgs[1] or "")
        if not message:find("重置") and not message:find("副本") and not message:lower():find("reset") then return end
    end
    Add(event, { args = eventArgs })
    if event == "UPDATE_INSTANCE_INFO" or event == "INSTANCE_SAVED"
        or event == "INSTANCE_RESET_SUCCESS" or event == "INSTANCE_RESET_FAILED" then
        Add("SAVED_INSTANCES_SNAPSHOT", { label = "after-" .. event, savedInstances = SavedInstancesSnapshot() })
    end
end)

if type(hooksecurefunc) == "function" and type(ResetInstances) == "function" then
    hooksecurefunc("ResetInstances", function()
        if not active then return end
        Add("SAVED_INSTANCES_SNAPSHOT", { label = "immediate-after-reset-call", savedInstances = SavedInstancesSnapshot() })
        Add("RESET_INSTANCES_CALLED", { args = {}, note = "Observed native ResetInstances call; probe did not initiate reset." })
        C_Timer.After(2, function()
            Add("SAVED_INSTANCES_SNAPSHOT", { label = "2s-after-reset-call", savedInstances = SavedInstancesSnapshot() })
        end)
    end)
end

local function Handle(message)
    local command, rest = tostring(message or ""):match("^%s*(%S*)%s*(.-)%s*$")
    command = (command or ""):lower()
    if command == "on" then
        active = true
        Add("PROBE_STARTED", { args = {}, note = "manual start" })
        Add("SAVED_INSTANCES_SNAPSHOT", { label = "sampling-start", savedInstances = SavedInstancesSnapshot() })
        Print("开始记录副本/遭遇事件与 Boss 死亡战斗日志。")
    elseif command == "off" then
        Add("PROBE_STOPPED", { args = {}, note = "manual stop" })
        active = false
        Print("已停止记录。")
    elseif command == "status" then
        Print(string.format("记录=%d 条；采集=%s；当前副本=%s。", db and #db.events or 0,
            active and "开启" or "关闭", tostring(CurrentInstance().name)))
        Print("/reload 后从 WTF/Account/<账号>/SavedVariables/YiboAltoBossProbe.lua 取样本。")
    elseif command == "clear" then
        if db then wipe(db.events) end
        Print("已清空探针记录。")
    else
        Print("用法：/yip on | off | status | clear。on 后通过游戏原生重置操作采样；探针不会主动重置。clear 会清除此探针的本地诊断样本。")
    end
end

SLASH_YIBOALTOBOSSPROBE1 = "/yip"
SlashCmdList.YIBOALTOBOSSPROBE = Handle
