local addonName, P = ...
local VERSION, PAGE_SIZE, MAX_SAMPLES, MAX_LIST = "0.1.0", 100, 18, 4096
local db, session, inWorld, reportWindow
local function pack(...) return { n = select("#", ...), ... } end
local function restricted(value)
    if type(issecretvalue) ~= "function" then return false end
    local ok, result = pcall(issecretvalue, value)
    return not ok or result == true
end
local function clean(value, depth, seen)
    if restricted(value) then return "<restricted>" end
    local kind = type(value)
    if kind == "nil" then return "<nil>" end
    if kind == "boolean" then return value end
    if kind == "string" then return string.sub(value, 1, 2048) end
    if kind == "number" then
        if value ~= value or value == math.huge or value == -math.huge then return "<non-finite>" end
        return value
    end
    if kind ~= "table" then return "<" .. kind .. ">" end
    if depth >= 5 then return "<depth-limit>" end
    if seen[value] then return "<cycle>" end
    seen[value] = true
    local result, count = {}, 0
    for key, item in pairs(value) do
        count = count + 1
        if count > MAX_LIST then result.__truncated = true; break end
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
-- Call sites below are a fixed read-only whitelist. Slash input is never an API path or expression.
local function read(path, ...)
    local fn = resolve(path)
    if type(fn) ~= "function" then return { status = "missing" } end
    local raw = pack(pcall(fn, ...))
    if not raw[1] then return { status = "error", error = safe(raw[2]) } end
    local result = { status = "returned_unverified", n = raw.n - 1, values = {}, types = {} }
    for i = 2, raw.n do
        result.values[i - 1] = safe(raw[i])
        result.types[i - 1] = restricted(raw[i]) and "restricted" or type(raw[i])
    end
    return result
end
local function first(result) return result and result.values and result.values[1] end
local function positive(value)
    return type(value) == "number" and value > 0 and value < 2147483648 and value == math.floor(value)
end
local function counter(value)
    return type(value) == "number" and value >= 0 and value <= 9007199254740990 and value == math.floor(value)
end
local function validStore(value)
    if value == nil then return true end
    if type(value) ~= "table" or value.schema ~= 1 or type(value.samples) ~= "table"
        or not counter(value.nextSample) or not counter(value.sessions) or #value.samples > MAX_SAMPLES then return false end
    local count = 0
    for index, sample in pairs(value.samples) do
        count = count + 1
        if not positive(index) or index > #value.samples or type(sample) ~= "table"
            or not positive(sample.id) or sample.id > value.nextSample then return false end
    end
    return count == #value.samples
end
local function say(key, ...)
    print("|cff20e070[YiboProgressForeverProbe]|r " .. string.format(P.text[key], ...))
end
local function isForever()
    local build = read("GetBuildInfo")
    return first(build) == "1.60.1" and build.values[4] == 16001
        and safe(WOW_PROJECT_ID) == 18 and safe(WOW_PROJECT_CAMELOT) == 18
end
local function ids(result)
    local raw, list, seen = first(result), {}, {}
    if type(raw) ~= "table" then return list, "not_a_table" end
    local count, rejected = 0, 0
    for key, value in pairs(raw) do
        if key ~= "__truncated" then
            count = count + 1
            if positive(key) and positive(value) and not seen[value] then
                seen[value] = true; list[#list + 1] = value
            else rejected = rejected + 1 end
        end
    end
    table.sort(list)
    return list, { observedEntries = count, rejectedEntries = rejected, truncated = raw.__truncated == true,
        completeness = "unverified; visible/filter/readiness semantics require client comparison" }
end
local function spell(id)
    return { spellID = id, modernInfo = read("C_Spell.GetSpellInfo", id), legacyInfo = read("GetSpellInfo", id),
        modernCooldown = read("C_Spell.GetSpellCooldown", id), legacyCooldown = read("GetSpellCooldown", id),
        modernCharges = read("C_Spell.GetSpellCharges", id), legacyCharges = read("GetSpellCharges", id) }
end
local function recipe(id)
    return { recipeID = id, info = read("C_TradeSkillUI.GetRecipeInfo", id),
        profession = read("C_TradeSkillUI.GetProfessionInfoByRecipeID", id),
        cooldown = read("C_TradeSkillUI.GetRecipeCooldown", id),
        link = read("C_TradeSkillUI.GetRecipeLink", id), spell = spell(id),
        identityStatus = "recipeID-to-spellID relation unverified; spell lookup is a candidate comparison only" }
end
local function mount(id)
    return { mountID = id, info = read("C_MountJournal.GetMountInfoByID", id),
        extra = read("C_MountJournal.GetMountInfoExtraByID", id),
        collectionScope = "unverified; values are raw tuple positions, not an account collection claim" }
end
local professionReads = {
    "C_TradeSkillUI.IsTradeSkillReady", "C_TradeSkillUI.IsTradeSkillLinked", "C_TradeSkillUI.IsTradeSkillGuild",
    "C_TradeSkillUI.IsTradeSkillGuildMember", "C_TradeSkillUI.IsNPCCrafting", "C_TradeSkillUI.GetBaseProfessionInfo",
    "C_TradeSkillUI.GetTradeSkillLine", "IsTradeSkillLinked", "IsTradeSkillGuild", "GetTradeSkillLine",
    "GetNumTradeSkills", "C_TradeSkillUI.GetAllRecipeIDs", "C_TradeSkillUI.GetFilteredRecipeIDs",
}
local function capture(kind, number)
    if not db then say("unavailable"); return end
    if not inWorld then say("not_ready"); return end
    if not positive(number) then say("invalid"); return end
    local s = { probeVersion = VERSION, kind = kind, pageOrID = number, rows = {}, calls = {},
        capturedAt = read("GetServerTime"), monotonicTime = read("GetTime"), build = read("GetBuildInfo"),
        locale = read("GetLocale"), guid = read("UnitGUID", "player"), level = read("UnitLevel", "player"),
        class = read("UnitClass", "player"), projectID = safe(WOW_PROJECT_ID), sessionID = session.id,
        observationsOnly = true, scope = "probe-local current observer; ownership/shared scope unverified",
        readiness = "operator-opened native window; readiness and completion unverified",
        events = safe(session.events), eventCounts = safe(session.counts), registration = safe(P.registration),
        reset = { daily = read("C_DateAndTime.GetSecondsUntilDailyReset"), weekly = read("C_DateAndTime.GetSecondsUntilWeeklyReset"),
            legacyQuest = read("GetQuestResetTime"), semantics = "raw clocks; no recipe/activity reset inference" } }
    if kind == "mount" then s.rows[1] = mount(number)
    elseif kind == "spell" then s.rows[1] = spell(number)
    elseif kind == "mounts" then
        s.calls.mountIDs = read("C_MountJournal.GetMountIDs")
        s.calls.mountCount = read("C_MountJournal.GetNumMounts")
        local list; list, s.listShape = ids(s.calls.mountIDs)
        s.observedIDCount, s.pageSize = #list, PAGE_SIZE
        for i = (number - 1) * PAGE_SIZE + 1, math.min(number * PAGE_SIZE, #list) do s.rows[#s.rows + 1] = mount(list[i]) end
    elseif kind == "cooldown" or kind == "recipe" then
        for _, path in ipairs(professionReads) do s.calls[path] = read(path) end
        s.ownership = "raw window flags retained; not interpreted as current-character learning evidence"
        if kind == "recipe" then s.rows[1] = recipe(number)
        else
            local list; list, s.listShape = ids(s.calls["C_TradeSkillUI.GetAllRecipeIDs"])
            s.observedIDCount, s.pageSize = #list, PAGE_SIZE
            for i = (number - 1) * PAGE_SIZE + 1, math.min(number * PAGE_SIZE, #list) do s.rows[#s.rows + 1] = recipe(list[i]) end
            s.legacyRows = {}
            local count = first(s.calls.GetNumTradeSkills)
            if positive(count) then
                s.legacyObservedCount = count
                for index = (number - 1) * PAGE_SIZE + 1, math.min(number * PAGE_SIZE, count, MAX_LIST) do
                    s.legacyRows[#s.legacyRows + 1] = { index = index, info = read("GetTradeSkillInfo", index),
                        link = read("GetTradeSkillRecipeLink", index), cooldown = read("GetTradeSkillCooldown", index) }
                end
            end
        end
    end
    db.nextSample = db.nextSample + 1; s.id = db.nextSample
    db.samples[#db.samples + 1] = s
    while #db.samples > MAX_SAMPLES do table.remove(db.samples, 1) end
    say("sampled", s.id, kind, #s.rows + #(s.legacyRows or {}))
    return s
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
    return "-- Raw observations include current observer GUID. No collection/cooldown scope is inferred.\nreturn "
        .. serialize({ schema = 1, probeVersion = VERSION, session = session, latest = db.samples[#db.samples] })
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
        edit:SetWidth(650); edit:SetMaxLetters(0); edit:SetScript("OnEscapePressed", function() f:Hide() end)
        scroll:SetScrollChild(edit); f.edit = edit; reportWindow = f
    end
    reportWindow:Show(); reportWindow.edit:SetText(content); reportWindow.edit:SetFocus(); reportWindow.edit:HighlightText()
end
local frame = CreateFrame("Frame")
P.registration = {}
for _, event in ipairs({ "ADDON_LOADED", "PLAYER_ENTERING_WORLD", "PLAYER_LEAVING_WORLD", "PLAYER_LOGOUT", "TRADE_SKILL_SHOW",
    "TRADE_SKILL_CLOSE", "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_DATA_SOURCE_CHANGED", "NEW_MOUNT_ADDED",
    "COMPANION_UPDATE", "SPELL_UPDATE_COOLDOWN", "SPELL_UPDATE_CHARGES", "UNIT_SPELLCAST_SUCCEEDED" }) do
    local ok, err = pcall(frame.RegisterEvent, frame, event)
    P.registration[event] = ok and "registered" or safe(err)
end
frame:SetScript("OnEvent", function(_, event, ...)
    local arg = ...
    if event == "ADDON_LOADED" and arg == addonName then
        if session then return end
        if not isForever() then say("unavailable"); return end
        local existing = YiboProgressForeverProbeDB
        if not validStore(existing) then
            say("unavailable"); return
        end
        YiboProgressForeverProbeDB = existing or { schema = 1, nextSample = 0, sessions = 0, samples = {} }
        db = YiboProgressForeverProbeDB; db.sessions = db.sessions + 1
        session = { id = db.sessions, events = {}, counts = {}, previousSampleID = db.samples[#db.samples] and db.samples[#db.samples].id }
        say("ready")
    end
    if not session or (event == "ADDON_LOADED" and arg ~= addonName) then return end
    if event == "UNIT_SPELLCAST_SUCCEEDED" and arg ~= "player" then return end
    if event == "PLAYER_ENTERING_WORLD" then inWorld = true end
    if event == "PLAYER_LEAVING_WORLD" or event == "PLAYER_LOGOUT" then inWorld = false end
    session.counts[event] = (session.counts[event] or 0) + 1
    session.events[#session.events + 1] = { event = event, clock = read("GetTime"), args = safe(pack(...)) }
    while #session.events > 32 do table.remove(session.events, 1) end
    -- Events only record timing/arguments. No scans, filter changes, spell casts or interactions are triggered.
end)
SLASH_YIBOPROGRESSFOREVERPROBE1 = "/ypg"
SlashCmdList.YIBOPROGRESSFOREVERPROBE = function(message)
    local command, argument = string.match(message or "", "^%s*(%S*)%s*(.-)%s*$")
    command = string.lower(command or "")
    if command == "report" then
        local ok, err = pcall(report); if not ok then say("report_error", tostring(err)) end
    elseif command == "mounts" or command == "cooldown" or command == "mount" or command == "recipe" or command == "spell" then
        local value = argument == "" and (command == "mounts" or command == "cooldown") and 1 or tonumber(argument)
        if not positive(value) then say("invalid"); return end
        capture(command, value)
    else say("help") end
end
P.capture, P.reportText = capture, reportText
