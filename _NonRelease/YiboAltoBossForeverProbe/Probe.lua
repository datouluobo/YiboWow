local addonName, P = ...
local VERSION = "0.1.0"
local MAX_SAMPLES, MAX_EVENTS, MAX_LOCKOUTS, MAX_BOSSES, MAX_TOTAL_BOSSES = 24, 120, 64, 64, 512
local db, session, inWorld, active, pending, reportWindow
local generation = 0
local function pack(...) return { n = select("#", ...), ... } end
local function restricted(value)
    if type(issecretvalue) ~= "function" then return false end
    local ok, result = pcall(issecretvalue, value)
    return not ok or result
end
local function clean(value, depth, seen)
    if restricted(value) then return "<restricted>" end
    local kind = type(value)
    if kind == "nil" then return "<nil>" end
    if kind == "string" then
        return #value > 512 and string.sub(value, 1, 512) .. "<truncated>" or value
    end
    if kind == "number" then
        return (value ~= value or value == math.huge or value == -math.huge) and "<non-finite>" or value
    end
    if kind == "boolean" then return value end
    if kind ~= "table" then return "<" .. kind .. ">" end
    if depth >= 4 then return "<depth-limit>" end
    if seen[value] then return "<cycle>" end
    seen[value] = true
    local result, count = {}, 0
    for key, item in pairs(value) do
        count = count + 1
        if count > 64 then result.__truncated = true; break end
        if not restricted(key) and (type(key) == "string" or type(key) == "number") then
            result[key] = clean(item, depth + 1, seen)
        end
    end
    seen[value] = nil
    return result
end
local function safe(value)
    local ok, result = pcall(clean, value, 0, {})
    if ok then return result end
    return "<unreadable>"
end
local function resolve(path)
    local value = _G
    for segment in string.gmatch(path, "[^.]+") do
        if type(value) ~= "table" then return nil end
        value = value[segment]
    end
    return value
end
local function results(raw, offset)
    local result = { status = "callable_unverified", count = raw.n - offset, values = {}, types = {} }
    for i = offset + 1, math.min(raw.n, offset + 32) do
        result.values[i - offset] = safe(raw[i])
        result.types[i - offset] = restricted(raw[i]) and "restricted" or type(raw[i])
    end
    if raw.n > offset + 32 then result.truncated = true end
    return result
end
local function call(path, ...)
    local ok, fn = pcall(resolve, path)
    if not ok then return { status = "error", error = safe(fn) } end
    if type(fn) ~= "function" then return { status = "missing" } end
    local raw = pack(pcall(fn, ...))
    if not raw[1] then return { status = "error", error = safe(raw[2]) } end
    return results(raw, 1)
end
local function say(key, ...)
    print("|cff20e070[YiboAltoBossForeverProbe]|r " .. string.format(P.text[key], ...))
end
local function integer(value)
    return type(value) == "number" and value >= 0 and value < math.huge and value == math.floor(value)
end
local function targetMatches()
    local build = call("GetBuildInfo")
    return build.values and build.values[4] == 16001
        and safe(WOW_PROJECT_ID) == 18 and safe(WOW_PROJECT_CAMELOT) == 18
end
local reads = {
    { "GetBuildInfo" }, { "GetLocale" }, { "GetServerTime" }, { "GetTime" },
    { "UnitGUID", "player" }, { "UnitLevel", "player" }, { "GetInstanceInfo" },
    { "IsInInstance" }, { "GetRealZoneText" }, { "GetDungeonDifficultyID" },
    { "GetRaidDifficultyID" }, { "C_GameRules.GetActiveGameMode" },
    { "C_GameRules.GetCurrentGameMode" }, { "C_Seasons.GetActiveSeason" },
    { "C_DateAndTime.GetSecondsUntilDailyReset" }, { "C_DateAndTime.GetSecondsUntilWeeklyReset" },
}
local candidates = { "GetNumSavedInstances", "GetSavedInstanceInfo", "GetSavedInstanceEncounterInfo",
    "C_RaidLocks.IsEncounterComplete", "RequestRaidInfo", "ResetInstances" }
local function sample(trigger, label)
    if not db or not active or not inWorld then return false end
    local s = {
        id = db.nextSample + 1, sessionID = session.id, probeVersion = VERSION, trigger = trigger,
        label = safe(label), calls = {}, candidates = {}, constants = {
            WOW_PROJECT_ID = safe(WOW_PROJECT_ID), WOW_PROJECT_CAMELOT = safe(WOW_PROJECT_CAMELOT),
        },
        scopeStatus = "unverified", businessSemantics = "unverified", readiness = "unverified",
        characterRef = "UnitGUID(player); probe-local evidence, not a Core character key",
        coverage = "native cached lockouts only; no server refresh, catalogue, completion or reset inference",
        eventSequence = db.nextEvent,
    }
    for _, spec in ipairs(reads) do s.calls[spec[1]] = call(unpack(spec)) end
    for _, path in ipairs(candidates) do
        local ok, fn = pcall(resolve, path)
        s.candidates[path] = ok and type(fn) == "function"
    end
    s.lockouts = { count = call("GetNumSavedInstances"), rows = {}, countStatus = "unknown",
        encounterCountField = 11, encounterCountFieldSemantics = "candidate classic layout; verify on target" }
    local count = s.lockouts.count.values and s.lockouts.count.values[1]
    if integer(count) then
        s.lockouts.countStatus = "observed_count_unverified"
        s.lockouts.truncated = count > MAX_LOCKOUTS
        local total = 0
        for index = 1, math.min(count, MAX_LOCKOUTS) do
            local info = call("GetSavedInstanceInfo", index)
            local row = { index = index, info = info, encounters = {}, encounterStatus = "unknown" }
            local bosses = info.values and info.values[11]
            if integer(bosses) then
                local limit = math.min(bosses, MAX_BOSSES, MAX_TOTAL_BOSSES - total)
                row.encounterStatus = "candidate_count_unverified"
                row.truncated = bosses > limit
                for boss = 1, limit do
                    row.encounters[boss] = { index = boss, info = call("GetSavedInstanceEncounterInfo", index, boss) }
                end
                total = total + limit
            end
            s.lockouts.rows[#s.lockouts.rows + 1] = row
        end
    end
    db.nextSample = s.id
    db.samples[#db.samples + 1] = s
    while #db.samples > MAX_SAMPLES do table.remove(db.samples, 1); db.droppedSamples = db.droppedSamples + 1 end
    return s
end
local function queueSample()
    if pending or not C_Timer or type(C_Timer.After) ~= "function" then return end
    pending = true
    local expected = generation
    local ok = pcall(C_Timer.After, 2, function()
        if expected ~= generation then return end
        pending = false
        sample("event_batch_plus_2s_unverified")
    end)
    if not ok then pending = false end
end
local function serialize(value)
    local kind = type(value)
    if kind == "string" then return string.format("%q", value) end
    if kind == "number" or kind == "boolean" then return tostring(value) end
    if kind ~= "table" then return "nil" end
    local keys, parts = {}, { "{" }
    for key in pairs(value) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    for _, key in ipairs(keys) do parts[#parts + 1] = "[" .. serialize(key) .. "]=" .. serialize(value[key]) .. ",\n" end
    parts[#parts + 1] = "}"
    return table.concat(parts)
end
local function reportText()
    if not db or #db.samples == 0 then return nil end
    return "-- Local technical evidence includes player GUID and native instance/boss names.\nreturn " .. serialize({
        schema = 1, probeVersion = VERSION, session = session, samples = db.samples, events = db.events,
        registration = P.registration, droppedSamples = db.droppedSamples, droppedEvents = db.droppedEvents,
        interpretation = "Raw results only; absence, zero, errors and elapsed time do not prove business support or resets.",
    })
end
local function report()
    local content = reportText()
    if not content then say("no_sample"); return end
    if not reportWindow then
        local f = CreateFrame("Frame", nil, UIParent)
        f:SetSize(720, 500); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG"); f:EnableMouse(true)
        local bg = f:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(0.04, 0.04, 0.04, 0.98)
        local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOP", 0, -14); title:SetText(P.text.title)
        local close = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        close:SetSize(90, 24); close:SetPoint("BOTTOM", 0, 10); close:SetText(P.text.close)
        close:SetScript("OnClick", function() f:Hide() end)
        local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 16, -40); scroll:SetPoint("BOTTOMRIGHT", -34, 44)
        local edit = CreateFrame("EditBox", nil, scroll)
        edit:SetMultiLine(true); edit:SetAutoFocus(false); edit:SetFontObject(ChatFontNormal)
        edit:SetWidth(650); edit:SetMaxLetters(0)
        edit:SetScript("OnEscapePressed", function() f:Hide() end)
        scroll:SetScrollChild(edit); f.edit = edit; reportWindow = f
    end
    reportWindow:Show(); reportWindow.edit:SetText(content); reportWindow.edit:SetFocus(); reportWindow.edit:HighlightText()
end
local frame = CreateFrame("Frame")
P.registration = {}
local events = { "ADDON_LOADED", "PLAYER_ENTERING_WORLD", "PLAYER_LEAVING_WORLD", "PLAYER_LOGOUT",
    "ZONE_CHANGED_NEW_AREA", "RAID_INSTANCE_WELCOME", "UPDATE_INSTANCE_INFO", "INSTANCE_SAVED",
    "INSTANCE_RESET_SUCCESS", "INSTANCE_RESET_FAILED", "ENCOUNTER_START", "ENCOUNTER_END",
    "BOSS_KILL", "INSTANCE_ENCOUNTER_ENGAGE_UNIT", "PLAYER_DIFFICULTY_CHANGED" }
for _, event in ipairs(events) do
    local ok, err = pcall(frame.RegisterEvent, frame, event)
    P.registration[event] = ok and "registered" or safe(err)
end
frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        if ... ~= addonName or session then return end
        if not targetMatches() then say("target_error"); return end
        local existing = YiboAltoBossForeverProbeDB
        if existing and (type(existing) ~= "table" or existing.schema ~= 1
            or type(existing.samples) ~= "table" or type(existing.events) ~= "table"
            or not integer(existing.nextSample) or not integer(existing.nextEvent) or not integer(existing.sessions)
            or not integer(existing.droppedSamples) or not integer(existing.droppedEvents)) then say("db_error"); return end
        db = existing or { schema = 1, samples = {}, events = {}, nextSample = 0, nextEvent = 0,
            sessions = 0, droppedSamples = 0, droppedEvents = 0 }
        YiboAltoBossForeverProbeDB = db
        db.sessions = db.sessions + 1
        session = { id = db.sessions, previousSampleID = db.samples[#db.samples] and db.samples[#db.samples].id,
            build = call("GetBuildInfo"), startedAt = call("GetServerTime") }
        say("ready"); return
    end
    if not db then return end
    if event == "PLAYER_ENTERING_WORLD" then inWorld = true end
    if event == "PLAYER_LEAVING_WORLD" or event == "PLAYER_LOGOUT" then
        inWorld = false; generation = generation + 1; pending = false
        if event == "PLAYER_LOGOUT" then active = false end
    end
    if not active then return end
    db.nextEvent = db.nextEvent + 1
    db.events[#db.events + 1] = {
        sequence = db.nextEvent, sessionID = session.id, event = event, args = results(pack(...), 0),
        at = call("GetServerTime"), elapsed = call("GetTime"), instance = call("GetInstanceInfo"),
    }
    while #db.events > MAX_EVENTS do table.remove(db.events, 1); db.droppedEvents = db.droppedEvents + 1 end
    if inWorld then queueSample() end
end)
SLASH_YIBOALTOBOSSFOREVERPROBE1 = "/yaf"
SlashCmdList.YIBOALTOBOSSFOREVERPROBE = function(message)
    local command, label = tostring(message or ""):match("^%s*(%S*)%s*(.-)%s*$")
    command = string.lower(command or "")
    if command == "report" then
        local ok, err = pcall(report)
        if not ok then say("report_error", safe(err)) end
    elseif command == "stop" then
        active = false; generation = generation + 1; pending = false; say("stopped")
    elseif command == "start" or command == "scan" then
        if not db or not inWorld or command == "scan" and not active then say("inactive"); return end
        if command == "start" then active = true; say("started") end
        local s = sample(command, label)
        if s then say("sampled", s.id, #db.samples) end
    else say("help") end
end
-- Test access is addon-local; no business service, runtime model, or shared state is published.
P.call, P.reportText = call, reportText
