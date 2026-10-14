-- Run from repository root: lua YiboAltoBoss/_NonRelease/Tests/InstanceKillsSpec.lua [probe sample]
local root = "YiboAltoBoss/"
local checks, now, language, api = 0, 1000, "en", 13
local current = { name = "The Stockade", instanceType = "party", difficultyID = 1, maxPlayers = 5, instanceID = 34 }
local frames, combat, resources = {}, {}, {}
local function check(value, label)
    checks = checks + 1
    assert(value, label)
end
GetServerTime = function() return now end
GetTime = GetServerTime
time, date = os.time, os.date
GetRealmName = function() return "Realm" end
GetDifficultyInfo = function(id) return id == 2 and "Heroic" or "Normal" end
GetNumSavedInstances = function() return 0 end
GetInstanceInfo = function()
    return current.name, current.instanceType, current.difficultyID, GetDifficultyInfo(current.difficultyID),
        current.maxPlayers, nil, nil, current.instanceID, nil, nil
end
CombatLogGetCurrentEventInfo = function() return unpack(combat) end
C_Timer = { After = function() end }
INSTANCE_RESET_SUCCESS = "%s has been reset."
INSTANCE_RESET_FAILED = "Cannot reset %s."
CreateFrame = function()
    local frame = { events = {} }
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:UnregisterEvent(event) self.events[event] = nil end
    function frame:UnregisterAllEvents() self.events = {} end
    function frame:SetScript(script, callback) self.scripts = self.scripts or {}; self.scripts[script] = callback; if script == "OnEvent" then self.callback = callback end end
    frames[#frames + 1] = frame
    return frame
end
YiboCore = {
    AccountView = {},
    CheckAPIVersion = function(_, minimum) return api >= minimum end,
    HasCapability = function() return api >= 13 end,
    IsInitialized = function() return true end,
    Locale = {
        Register = function(_, owner, lang, values) resources[lang] = values end,
        Get = function(_, owner, key, ...) return string.format(assert(resources[language][key], key), ...) end,
    },
}
YAB = { GetCurrentCharKey = function() return "Tester-Realm" end }
dofile(root .. "LockoutLocale.lua")
local resourceCount = 0
for key, zh in pairs(resources.zh) do
    resourceCount = resourceCount + 1
    local en = assert(resources.en[key], key)
    local function signature(value)
        local result = {}; for token in value:gmatch("%%[sd]") do result[#result + 1] = token end
        return table.concat(result)
    end
    assert(signature(zh) == signature(en), key .. " format signature")
end
check(resourceCount == 35, "all 35 resource pairs have matching format arguments")
dofile(root .. "DungeonBossCatalog.lua")
dofile(root .. "DungeonRuns.lua")
dofile(root .. "InstanceLockouts.lua")
local frame = frames[#frames]
local function event(name, ...) frame.callback(frame, name, ...) end
local function reset()
    YiboAltoBossDB = { characters = {}, settings = {} }
    current = { name = "The Stockade", instanceType = "party", difficultyID = 1, maxPlayers = 5, instanceID = 34 }
    now = 1000
    event("PLAYER_ENTERING_WORLD")
end
local function death(id, suffix, name)
    combat = { now, "UNIT_DIED", false, "", "", 0, 0,
        "Creature-0-4539-34-24955-" .. id .. "-" .. (suffix or "000000001"), name or "Boss", 0 }
    event("COMBAT_LOG_EVENT_UNFILTERED")
end
local function totals()
    local total, rows = 0, 0
    local record = YiboAltoBossDB.characters["Tester-Realm"]
    for _, stat in pairs(record and record.statistics.bosses or {}) do total, rows = total + stat.kills, rows + 1 end
    return total, rows
end
reset()
check(frame.events.COMBAT_LOG_EVENT_UNFILTERED, "party death listener active")
death(46383, "A", "Randolph Moloch")
check(totals() == 1, "boss death recorded")
death(46383, "A", "Randolph Moloch")
event("BOSS_KILL", 1146, "Randolph Moloch")
event("ENCOUNTER_END", 1146, "Randolph Moloch", 1, 1, 1)
check(totals() == 1, "death/native events deduplicated")
death(46382, "TRASH", "Petty Criminal")
death(46482, "FRIENDLY", "Mortimer Moloch")
check(totals() == 1, "trash and scripted NPC ignored")
now = now + 2
event("CHAT_MSG_SYSTEM", "Cannot reset The Stockade.")
death(46383, "B", "Randolph Moloch")
check(totals() == 1, "failed reset preserves dedupe")
event("CHAT_MSG_SYSTEM", "The Stockade has been reset.")
death(46383, "B", "Randolph Moloch")
check(totals() == 2, "successful reset allows a new kill inside 60 seconds")
now = now + 61
death(46383, "B", "Randolph Moloch")
check(totals() == 2, "same death GUID still deduplicated after 60 seconds")
current.difficultyID = 2
death(46383, "HEROIC", "Randolph Moloch")
local total, rows = totals()
check(total == 3 and rows == 2, "difficulty identities separate")
current.instanceID = 9999
death(46383, "WRONGMAP", "Randolph Moloch")
check(totals() == 3, "same NPC ID in another map ignored")
current.instanceType = "raid"
event("PLAYER_ENTERING_WORLD")
check(not frame.events.COMBAT_LOG_EVENT_UNFILTERED, "listener disabled outside five-player dungeon")
death(46383, "RAID", "Randolph Moloch")
check(totals() == 3, "raid excluded from dungeon fallback")
reset()
current.instanceID = 1004
death(60040, "SCRIPTED", "Commander Durand")
event("ENCOUNTER_END", 1425, "High Inquisitor Whitemane", 1, 1, 0)
check(totals() == 0, "scripted NPC death and failed native encounter do not count")
event("ENCOUNTER_END", 1425, "High Inquisitor Whitemane", 1, 1, 1)
check(totals() == 1, "scripted encounter native success remains supported")
reset()
YAB.TargetCatalog = { ResolveSavedEncounter = function() return 9000 end }
death(46383, "DIRECTORY", "Randolph Moloch")
event("BOSS_KILL", 9000, "Encounter display name")
check(totals() == 1, "client encounter identity correlates differently named native/death signals")
YAB.TargetCatalog = nil
reset()
YAB.RefreshInstanceLockouts()
death(46264, "C", "Lord Overheat")
local column = { key = "ej:238", mapID = 34, name = "The Stockade" }
local function TooltipText()
    local lines = {}
    for _, row in ipairs(YAB.GetLockoutTooltip("Tester-Realm", column)) do
        lines[#lines + 1] = type(row) == "table" and (row.kind == "pair" and (tostring(row.label) .. " " .. tostring(row.value)) or row.text or "") or row
    end
    return table.concat(lines, "\n")
end
YiboAltoBossDB.settings.lockoutTooltip = { historyKills = true, lastKill = true }
local text = TooltipText()
check(text:find("Lord Overheat", 1, true) and text:find("1 lifetime kills", 1, true), "history visible without saved lockout")
local record = YiboAltoBossDB.characters["Tester-Realm"]
record.instanceLockouts["34:1"] = {
    name = "The Stockade", instanceID = 34, difficultyID = 1, difficultyName = "Normal", resetAt = 2000,
    bossCount = 3, bosses = { { name = "Lord Overheat", killed = true }, { name = "Hogger" }, { name = "Randolph Moloch" } },
}
local state, label = YAB.GetLockoutStatus("Tester-Realm", column)
check(state == "locked" and label == "1/3", "active lockout progress preserved")
text = TooltipText()
check(text:find("Lord Overheat Defeated", 1, true) and text:find("1 lifetime kills", 1, true), "active lockout and history share the localized detail")
record.instanceLockouts["34:1"] = nil
language = "zh"
check(YAB.GetLockoutStatus("Tester-Realm", column) == "progress", "current run status also visible in Chinese")
text = TooltipText()
check(text:find("1/3", 1, true) and text:find("Lord Overheat", 1, true), "owner language changes; dynamic NPC name unchanged")
language = "en"
reset()
YiboAltoBossDB.characters["Tester-Realm"] = { statistics = {
    bosses = { ["The Stockade:1:Randolph Moloch"] = { name = "Randolph Moloch", instanceName = "The Stockade", kills = 7, firstAt = 100 } },
    instances = {}, recent = {},
} }
death(46383, "D", "Randolph Moloch")
total, rows = totals()
check(total == 8 and rows == 1, "legacy history enriched without losing/duplicating total")
if arg[1] then
    reset()
    INSTANCE_RESET_SUCCESS = "%s 已被重置。"
    dofile(arg[1])
    for _, sample in ipairs(YiboAltoBossProbeDB.events) do
        now = math.floor(sample.elapsed)
        current = sample.instance
        if sample.event == "COMBAT_LOG_EVENT_UNFILTERED" then
            combat = { now, sample.subevent, false, sample.sourceGUID or "", sample.sourceName or "", 0, 0,
                sample.destGUID, sample.destName, sample.destFlags }
            event(sample.event)
        elseif frame.events[sample.event] then
            event(sample.event, unpack(sample.args or {}))
        end
    end
    total, rows = totals()
    check(total == 3 and rows == 2, "real probe replay: Moloch twice, Overheat once; no trash/Mortimer")
    local recent = YiboAltoBossDB.characters["Tester-Realm"].statistics.recent
    local uncleared = false
    for token in pairs(recent) do if token:find("instance:34:", 1, true) == 1 then uncleared = true end end
    check(not uncleared, "real Chinese reset-success message invalidates instance dedupe")
end
-- Actual Core event bridge, public DBM callback stub and source collector.
YiboCore.Defaults = { Copy = function(self, value)
    if type(value) ~= "table" then return value end
    local copy = {}; for k, v in pairs(value) do copy[k] = self:Copy(v) end; return copy
end }
YiboCore.Capabilities = { Register = function() end }
YiboCore.Print = function(_, text) error(text) end
YiboCore.Text = function(_, key) return key end
dofile("YiboCore/Runtime/Events.lua")
local fighting = true
local currentIdentity = "Player-A"
YiboCore.Characters = { GetCurrentID = function() return currentIdentity end }
UnitAffectingCombat = function() return fighting end
INSTANCE_RESET_SUCCESS = "%s has been reset."
YAB.TargetCatalog = {
    Query = function() return { targets = {
        { kind = "instance", mapID = 34, difficulties = { { id = 1, complete = true, encounters = {
            { id = 1146, journalID = 466, name = "Randolph Moloch" },
        } } } },
        { kind = "instance", mapID = 1007, difficulties = { { id = 1, complete = true, encounters = {
            { id = 1426, journalID = 659, name = "Instructor Chillheart" },
        } } } },
    } } end,
}
DBM = nil
dofile(root .. "DungeonDBM.lua")
local bridge = YAB.DungeonDBM
check(bridge and not bridge:Attach(), "DBM absent: optional bridge unavailable")
reset()
death(46383, "INDEPENDENT", "Randolph Moloch")
check(totals() == 1, "independent recording still works without DBM")
local function NewDBM()
    return {
        callbacks = {},
        RegisterCallback = function(self, name, callback)
            self.callbacks[name] = self.callbacks[name] or {}
            table.insert(self.callbacks[name], callback)
        end,
        UnregisterCallback = function(self, name, callback)
            for i = #(self.callbacks[name] or {}), 1, -1 do
                if self.callbacks[name][i] == callback then table.remove(self.callbacks[name], i) end
            end
        end,
    }
end
DBM = NewDBM()
bridge.frame.callback(bridge.frame, "ADDON_LOADED", "DBM-Core")
bridge:Attach()
check(#DBM.callbacks.DBM_Kill == 1, "late registration and repeated attachment are idempotent")
local function dbm(name, mod)
    for _, callback in ipairs(DBM.callbacks[name] or {}) do callback(name, mod) end
end
reset()
local moloch = { id = "466", encounterId = 1146 }
YiboCore.Events:FireIsolated(bridge.eventName, {
    version = 2, source = "DBM", characterID = "Player-A", mapID = 34, difficultyID = 1,
    run = YAB.GetDungeonRunToken(), encounterID = 1146, name = "Randolph Moloch",
})
check(totals() == 0, "incompatible normalized event version ignored")
dbm("DBM_Pull", moloch)
death(46383, "THREE_SOURCES", "Randolph Moloch")
now = now + 120
dbm("DBM_Kill", moloch)
event("BOSS_KILL", 1146, "Randolph Moloch")
check(totals() == 1, "DBM/native/death remain one kill beyond 60 seconds")
event("CHAT_MSG_SYSTEM", "The Stockade has been reset.")
dbm("DBM_Pull", moloch)
dbm("DBM_Kill", moloch)
check(totals() == 2, "DBM kill in new reset cycle counts again")
dbm("DBM_Kill", moloch)
check(totals() == 2, "repeated DBM kill ignored")
event("CHAT_MSG_SYSTEM", "The Stockade has been reset.")
dbm("DBM_Pull", moloch)
event("CHAT_MSG_SYSTEM", "The Stockade has been reset.")
dbm("DBM_Kill", moloch)
check(totals() == 2, "stale DBM completion after reset rejected")
reset()
current.instanceID, current.name = 1007, "Scholomance"
local chillheart = { id = "659", encounterId = 1426 }
death(58633, "PHASE_ONE", "Instructor Chillheart")
check(totals() == 0, "complex encounter phase death still excluded")
dbm("DBM_Pull", chillheart)
dbm("DBM_Kill", chillheart)
check(totals() == 1, "DBM completes complex dungeon encounter")
now = now + 120
event("ENCOUNTER_END", 1426, "Instructor Chillheart", 1, 5, 1)
check(totals() == 1, "late native completion does not duplicate DBM")
event("CHAT_MSG_SYSTEM", "Scholomance has been reset.")
dbm("DBM_Pull", chillheart)
dbm("DBM_Wipe", chillheart)
dbm("DBM_Kill", chillheart)
check(totals() == 1, "wipe is not a kill")
dbm("DBM_Kill", { id = "659", encounterId = 1426 })
check(totals() == 1, "kill without matching observed pull rejected")
local wrongNamespace = { id = "1426" }
dbm("DBM_Pull", wrongNamespace)
dbm("DBM_Kill", wrongNamespace)
check(totals() == 1, "DBM module ID is not treated as DungeonEncounterID")
dbm("DBM_Pull", chillheart)
current.difficultyID = 2
dbm("DBM_Kill", chillheart)
check(totals() == 1, "difficulty changed since pull rejected")
current.difficultyID = 1
dbm("DBM_Pull", chillheart)
local getKey = YAB.GetCurrentCharKey
YAB.GetCurrentCharKey = function() return "Another-Realm" end
currentIdentity = "Player-B"
dbm("DBM_Kill", chillheart)
YAB.GetCurrentCharKey = getKey
currentIdentity = "Player-A"
check(totals() == 1, "character changed since pull rejected")
fighting = false
dbm("DBM_Pull", chillheart)
dbm("DBM_Kill", chillheart)
check(totals() == 1, "unengaged callback not trusted")
fighting = true
dbm("DBM_TestModStarted")
dbm("DBM_Pull", chillheart)
dbm("DBM_Kill", chillheart)
check(totals() == 1, "DBM demo signals suppressed")
now = now + 61
dbm("DBM_Pull", chillheart)
dbm("DBM_Kill", chillheart)
check(totals() == 2, "real encounter resumes after demo guard")
reset()
bridge.testUntil = nil
current.instanceID, current.name = 1007, "Scholomance"
YAB.GetDungeonRunToken("Creature-0-4539-1007-11111-58633-AAA")
dbm("DBM_Pull", chillheart)
combat = { now, "UNIT_DIED", false, "", "", 0, 0,
    "Creature-0-4539-1007-22222-99999-BBB", "Trash", 0 }
event("COMBAT_LOG_EVENT_UNFILTERED")
dbm("DBM_Kill", chillheart)
check(totals() == 1, "instance scope first confirmed during pull binds DBM result to actual run")
event("CHAT_MSG_SYSTEM", "Scholomance has been reset.")
dbm("DBM_Pull", chillheart)
bridge.frame.callback(bridge.frame, "PLAYER_ENTERING_WORLD")
dbm("DBM_Kill", chillheart)
check(totals() == 1, "world transition discards stale pull")
reset()
event("BOSS_KILL", 1146, "Randolph Moloch")
dofile(root .. "DungeonRuns.lua")
now = now + 500
event("BOSS_KILL", 1146, "Randolph Moloch")
check(totals() == 1, "per-run completion survives module reload and long delay")
reset()
current.difficultyID = 2
YAB.GetDungeonRunToken()
local heroicRecord = YiboAltoBossDB.characters["Tester-Realm"]
heroicRecord.instanceLockouts = {
    heroic = { instanceID = 34, difficultyID = 2, resetAt = now + 10 },
}
event("BOSS_KILL", 1146, "Randolph Moloch")
now = now + 11
event("BOSS_KILL", 1146, "Randolph Moloch")
check(totals() == 2, "observed heroic lockout expiry opens a new dungeon cycle")
event("CHAT_MSG_SYSTEM", "The Stockade has been reset.")
event("BOSS_KILL", 1146, "Randolph Moloch")
check(totals() == 2, "normal reset does not invalidate a heroic completion")
GetDungeonDifficultyID = function() return 2 end
event("CHAT_MSG_SYSTEM", "The Stockade has been reset.")
event("BOSS_KILL", 1146, "Randolph Moloch")
check(totals() == 3, "reset uses the selected dungeon difficulty")
GetDungeonDifficultyID = nil
reset()
current.instanceType, current.maxPlayers, current.instanceID = "raid", 25, 580
YiboAltoBossDB.characters = {}
dbm("DBM_Pull", moloch)
dbm("DBM_Kill", moloch)
check(totals() == 0, "DBM bridge never records raids")
event("BOSS_KILL", 725, "Raid Boss")
event("BOSS_KILL", 725, "Raid Boss")
check(totals() == 1, "raid retains original 60-second dedupe")
now = now + 61
event("BOSS_KILL", 725, "Raid Boss")
check(totals() == 2 and not YiboAltoBossDB.characters["Tester-Realm"].statistics.dungeonCycles,
    "raid behavior and database remain outside dungeon cycle tracking")
bridge:Detach()
check(#DBM.callbacks.DBM_Kill == 0, "detach unregisters DBM callbacks")
DBM = { RegisterCallback = false }
check(not bridge:Attach(), "incompatible DBM callback API degrades safely")
DBM = NewDBM()
local register = DBM.RegisterCallback
local registrationCount = 0
DBM.RegisterCallback = function(self, name, callback)
    registrationCount = registrationCount + 1
    if registrationCount == 3 then error("incompatible registration") end
    register(self, name, callback)
end
check(not bridge:Attach(), "partial callback registration failure rejected")
local remaining = 0
for _, callbacks in pairs(DBM.callbacks) do remaining = remaining + #callbacks end
check(remaining == 0, "partial attachment rolls back registered callbacks")
bridge:Shutdown()
check(not YiboCore.Events:HasListeners(bridge.eventName), "shutdown cleans Core subscription")
api = 12
YAB = { GetCurrentCharKey = function() return "Tester-Realm" end }
dofile(root .. "LockoutLocale.lua")
dofile(root .. "InstanceLockouts.lua")
check(not YAB.LockoutLocaleReady and not YAB.RecordDungeonDeath, "old Core stops locale-dependent module")
dofile(root .. "CoreIntegration.lua")
local ok, err = YAB.CoreIntegration:Initialize()
check(not ok and err:find("API v13", 1, true), "old Core receives explicit upgrade requirement")
print("InstanceKillsSpec: " .. checks .. " checks passed")
