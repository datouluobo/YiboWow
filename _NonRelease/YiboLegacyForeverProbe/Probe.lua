local addonName, P = ...
-- 0.1.1 (2026-11-20): scan whole GetCategoryList after L0 showed only class roots were covered.
local VERSION, MAX_SAMPLES, MAX_LIST, MAX_CRITERIA, MAX_NODES, MAX_LEVELS = "0.1.2", 8, 4096, 64, 256, 60
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
    if depth >= 6 then return "<depth-limit>" end
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
-- No purchase/refund/commit/load calls are made; staged trait changes are only observed.
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
local function value(result, index) return result and result.values and result.values[index] end
local function positive(v)
    return type(v) == "number" and v > 0 and v < 2147483648 and v == math.floor(v)
end
local function counter(v)
    return type(v) == "number" and v >= 0 and v <= 9007199254740990 and v == math.floor(v)
end
local function validStore(store)
    if store == nil then return true end
    if type(store) ~= "table" or store.schema ~= 1 or type(store.samples) ~= "table"
        or not counter(store.nextSample) or not counter(store.sessions) or #store.samples > MAX_SAMPLES then return false end
    local count = 0
    for index, sample in pairs(store.samples) do
        count = count + 1
        if not positive(index) or index > #store.samples or type(sample) ~= "table"
            or not positive(sample.id) or sample.id > store.nextSample then return false end
    end
    return count == #store.samples
end
local function say(key, ...)
    print("|cff20e070[YiboLegacyForeverProbe]|r " .. string.format(P.text[key], ...))
end
local function isForever()
    local build = read("GetBuildInfo")
    return value(build, 4) == 16001 and type(WOW_PROJECT_CAMELOT) == "number"
        and WOW_PROJECT_ID == WOW_PROJECT_CAMELOT
end
local function consts()
    return type(Constants) == "table" and type(Constants.LegacyConsts) == "table" and Constants.LegacyConsts or {}
end

local function achievement(id, pointsCurrency)
    local row = { achievementID = id, info = read("GetAchievementInfo", id), category = read("GetAchievementCategory", id),
        valid = read("C_AchievementInfo.IsValidAchievement", id), numCriteria = read("GetAchievementNumCriteria", id),
        criteria = {} }
    if positive(pointsCurrency) then
        row.legacyPoints = read("C_Traits.GetTraitCurrencyForAchievement", pointsCurrency, id)
    end
    local n = first(row.numCriteria)
    if counter(n) then
        for i = 1, math.min(n, MAX_CRITERIA) do row.criteria[i] = read("GetAchievementCriteriaInfo", id, i) end
        row.criteriaTruncated = n > MAX_CRITERIA or nil
    end
    return row
end

-- Legacy categories: default per-class category IDs from LegacyConsts, their ancestors' roots,
-- and every GetCategoryList entry under those roots. Completeness against the native panel is unverified.
local function categoryInfo(id)
    local r = read("GetCategoryInfo", id)
    return r, value(r, 2)
end
local function collectCategories(c)
    local defaults, roots, rows, order, chainOf = {}, {}, {}, {}, {}
    for key, id in pairs(c) do
        if type(key) == "string" and string.find(key, "^LEGACY_DEFAULT_CATEGORY_") and positive(id) then defaults[key] = id end
    end
    local function chain(id)
        if chainOf[id] then return chainOf[id] end
        local list, cur, guard = {}, id, 0
        while positive(cur) and guard < 16 do
            list[#list + 1] = cur
            local _, parent = categoryInfo(cur)
            cur, guard = parent, guard + 1
        end
        chainOf[id] = list
        return list
    end
    local listed = read("GetCategoryList")
    local all, inList = {}, {}
    if type(first(listed)) == "table" then
        for _, id in ipairs(first(listed)) do if positive(id) then all[#all + 1] = id; inList[id] = true end end
    end
    for _, id in pairs(defaults) do if not inList[id] then all[#all + 1] = id end end
    -- 0.1.1: Forever's list (29 entries in L0) is scanned in full; roots are reported, not used as a filter.
    for _, id in ipairs(all) do local l = chain(id); roots[l[#l]] = true end
    for _, id in ipairs(all) do
        local l = chain(id)
        if not rows[id] then
            local info = categoryInfo(id)
            rows[id] = { categoryID = id, info = info, chain = l, inCategoryList = inList[id] == true,
                counts = read("GetCategoryNumAchievements", id), countsIncludeAll = read("GetCategoryNumAchievements", id, true) }
            order[#order + 1] = id
        end
    end
    table.sort(order)
    local rootList = {}
    for id in pairs(roots) do rootList[#rootList + 1] = id end
    table.sort(rootList)
    return { defaults = defaults, roots = rootList, order = order, rows = rows,
        categoryListSize = #all, categoryListStatus = listed.status }
end

local function collectChallenges(cats, pointsCurrency)
    local list, seen = {}, {}
    for _, catID in ipairs(cats.order) do
        local row = cats.rows[catID]
        local total = math.max(tonumber(first(row.countsIncludeAll)) or 0, tonumber(first(row.counts)) or 0)
        row.achievementIDs = {}
        for i = 1, math.min(total, 512) do
            local id = first(read("GetAchievementInfo", catID, i))
            if positive(id) then
                row.achievementIDs[#row.achievementIDs + 1] = id
                if not seen[id] then seen[id] = true; list[#list + 1] = achievement(id, pointsCurrency) end
            end
        end
    end
    return list
end

local TREE_KEYS = { professions = "LEGACY_TREE_PROFESSIONS_ID", adventure = "LEGACY_TREE_ADVENTURE_ID",
    progression = "LEGACY_TREE_PROGRESSION_ID" }
local function collectTrees(c)
    local trees = { activeConfig = read("C_ClassTalents.GetActiveConfigID") }
    for name, key in pairs(TREE_KEYS) do
        local treeID = c[key]
        local t = { treeID = safe(treeID) }
        if positive(treeID) then
            t.configID = read("C_Traits.GetConfigIDByTreeID", treeID)
            local configID = first(t.configID)
            if positive(configID) then
                t.configInfo = read("C_Traits.GetConfigInfo", configID)
                t.treeInfo = read("C_Traits.GetTreeInfo", configID, treeID)
                t.currencyIncludingStaged = read("C_Traits.GetTreeCurrencyInfo", configID, treeID, false)
                t.currencyCommittedOnly = read("C_Traits.GetTreeCurrencyInfo", configID, treeID, true)
                t.hasStagedChanges = read("C_Traits.ConfigHasStagedChanges", configID)
                local cur = first(t.currencyIncludingStaged)
                local currencyID = type(cur) == "table" and type(cur[1]) == "table" and cur[1].traitCurrencyID
                if positive(currencyID) then
                    t.maxAvailableLimited = read("C_Traits.GetMaxAvailableTraitCurrency", currencyID, true)
                    t.maxAvailableUnlimited = read("C_Traits.GetMaxAvailableTraitCurrency", currencyID, false)
                    t.currencyInfo = read("C_Traits.GetTraitCurrencyInfo", currencyID)
                end
                t.nodes = {}
                local nodes = first(read("C_Traits.GetTreeNodes", treeID))
                if type(nodes) == "table" then
                    for i = 1, math.min(#nodes, MAX_NODES) do
                        if positive(nodes[i]) then t.nodes[#t.nodes + 1] = read("C_Traits.GetNodeInfo", configID, nodes[i]) end
                    end
                end
            end
        end
        trees[name] = t
    end
    return trees
end

local function collectRenown(c)
    local f = c.LEGACY_REWARD_TRACK_FACTION_ID
    local r = { factionID = safe(f) }
    if not positive(f) then return r end
    r.level = read("C_MajorFactions.GetCurrentRenownLevel", f)
    r.data = read("C_MajorFactions.GetMajorFactionData", f)
    r.maximum = read("C_MajorFactions.HasMaximumRenown", f)
    r.levels = read("C_MajorFactions.GetRenownLevels", f)
    r.rewards = {}
    local levels = first(r.levels)
    if type(levels) == "table" then
        -- 0.1.2: rewards are keyed by the renown level value (L0 showed 15/25/40/55), not the list index.
        for i = 1, math.min(#levels, MAX_LEVELS) do
            local lv = type(levels[i]) == "table" and levels[i].level or levels[i]
            if positive(lv) then r.rewards[i] = read("C_MajorFactions.GetRenownRewardsForLevel", f, lv) end
        end
    end
    return r
end

local function capture(kind, number)
    if not db then say("unavailable"); return end
    if not inWorld then say("not_ready"); return end
    local c = consts()
    local s = { probeVersion = VERSION, kind = kind, capturedAt = read("GetServerTime"), monotonicTime = read("GetTime"),
        build = read("GetBuildInfo"), locale = read("GetLocale"), projectID = safe(WOW_PROJECT_ID),
        camelotID = safe(WOW_PROJECT_CAMELOT), guid = read("UnitGUID", "player"), name = read("UnitFullName", "player"),
        level = read("UnitLevel", "player"), class = read("UnitClass", "player"), sessionID = session.id,
        gameMode = read("C_GameRules.GetActiveGameMode"), observationsOnly = true,
        scope = "probe-local current observer; account/character ownership of points unverified",
        location = { map = read("C_Map.GetBestMapForUnit", "player"), instance = read("GetInstanceInfo"),
            zone = read("GetRealZoneText"), subzone = read("GetSubZoneText") },
        legacyConsts = safe(c), events = safe(session.events), eventCounts = safe(session.counts), registration = safe(P.registration),
        ui = { addonLoaded = read("C_AddOns.IsAddOnLoaded", "Blizzard_LegacySystem"), frame = type(LegacySystemFrame),
            toggle = type(ToggleLegacySystemUI), util = type(LegacySystem) } }
    local pointsCurrency = c.LEGACY_POINTS_TRAIT_CURRENCY_ID
    if kind == "ach" then
        s.challenges = { achievement(number, pointsCurrency) }
    else
        s.renown = collectRenown(c)
        s.trees = collectTrees(c)
        s.categories = collectCategories(c)
        s.challenges = collectChallenges(s.categories, pointsCurrency)
    end
    db.nextSample = db.nextSample + 1; s.id = db.nextSample
    db.samples[#db.samples + 1] = s
    while #db.samples > MAX_SAMPLES do table.remove(db.samples, 1) end
    say("sampled", s.id, kind, s.categories and #s.categories.order or 0, #s.challenges)
    return s
end

local function str(v) if type(v) == "table" then return "<table>" end return tostring(v) end
local function line(out, ...) local p = {} for i = 1, select("#", ...) do p[i] = str((select(i, ...))) end out[#out + 1] = table.concat(p, " ") end
local function currencyLine(r)
    local list = first(r)
    if type(list) ~= "table" or type(list[1]) ~= "table" then return str(r and r.status) end
    local x = list[1]
    return string.format("id=%s quantity=%s spent=%s maxQuantity=%s", str(x.traitCurrencyID), str(x.quantity), str(x.spent), str(x.maxQuantity))
end
-- Compact copyable summary; the full raw sample is in SavedVariables after reload/logout.
local function reportText()
    if not db or #db.samples == 0 then return nil end
    local s, out = db.samples[#db.samples], {}
    line(out, "YiboLegacyForeverProbe", VERSION, "sample", s.id, s.kind, "session", s.sessionID)
    line(out, "build", value(s.build, 1), value(s.build, 2), value(s.build, 4), "project", s.projectID, s.camelotID, "locale", first(s.locale))
    line(out, "player", value(s.name, 1), "level", first(s.level), "class", value(s.class, 2), "gameMode", first(s.gameMode), s.gameMode and s.gameMode.status)
    line(out, "map", first(s.location.map), "zone", first(s.location.zone), first(s.location.subzone),
        "instance", value(s.location.instance, 1), value(s.location.instance, 2), value(s.location.instance, 8))
    line(out, "ui", "addonLoaded", first(s.ui.addonLoaded), "frame", s.ui.frame, "toggle", s.ui.toggle)
    if type(s.legacyConsts) == "table" then
        local keys = {}
        for k in pairs(s.legacyConsts) do keys[#keys + 1] = k end
        table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
        for _, k in ipairs(keys) do line(out, "const", k, s.legacyConsts[k]) end
    end
    if s.renown then
        local d = first(s.renown.data)
        line(out, "renown faction", s.renown.factionID, "level", first(s.renown.level), s.renown.level and s.renown.level.status,
            "earned", type(d) == "table" and d.renownReputationEarned, "threshold", type(d) == "table" and d.renownLevelThreshold,
            "unlocked", type(d) == "table" and d.isUnlocked, "levels", type(first(s.renown.levels)) == "table" and #first(s.renown.levels))
        local levels = first(s.renown.levels)
        if type(levels) == "table" then
            for i, lv in ipairs(levels) do
                local names, rewards = {}, first(s.renown.rewards[i])
                if type(rewards) == "table" then
                    for _, rw in ipairs(rewards) do
                        if type(rw) == "table" then
                            local keys = {}
                            for k, v in pairs(rw) do if type(v) ~= "table" then keys[#keys + 1] = tostring(k) .. "=" .. str(v) end end
                            table.sort(keys); names[#names + 1] = "{" .. table.concat(keys, " ") .. "}"
                        end
                    end
                else names[1] = "status=" .. str(s.renown.rewards[i] and s.renown.rewards[i].status) end
                if type(lv) == "table" then
                    line(out, "  level", i, "lvl", lv.level, "locked", lv.locked, "threshold", lv.renownReputationEarned or lv.threshold, "rewards", table.concat(names, ","))
                else line(out, "  level", i, lv, "rewards", table.concat(names, ",")) end
            end
        end
    end
    if s.trees then
        for _, name in ipairs({ "professions", "adventure", "progression" }) do
            local t = s.trees[name]
            line(out, "tree", name, t.treeID, "config", first(t.configID), "staged", first(t.hasStagedChanges),
                "nodes", t.nodes and #t.nodes)
            if t.currencyIncludingStaged then
                line(out, "  withStaged", currencyLine(t.currencyIncludingStaged))
                line(out, "  committed", currencyLine(t.currencyCommittedOnly))
                line(out, "  maxAvailable", first(t.maxAvailableLimited), first(t.maxAvailableUnlimited))
            end
        end
    end
    if s.categories then
        line(out, "categories", #s.categories.order, "roots", table.concat(s.categories.roots, ","), "listSize", s.categories.categoryListSize)
        for _, id in ipairs(s.categories.order) do
            local r = s.categories.rows[id]
            line(out, "cat", id, value(r.info, 1), "parent", value(r.info, 2), "counts", value(r.counts, 1), value(r.counts, 2),
                value(r.counts, 3), "all", first(r.countsIncludeAll), "ids", r.achievementIDs and #r.achievementIDs)
        end
    end
    -- 0.1.2: criteria are listed only for point-bearing challenges (or single ach samples); supporting
    -- achievements get one line with a completed-criteria count to keep the copy window manageable.
    local done, mine, pointed, pointedDone = 0, 0, 0, 0
    for _, a in ipairs(s.challenges or {}) do
        local i, pts = a.info, first(a.legacyPoints)
        local isPoint = type(pts) == "number" and pts > 0
        if value(i, 4) == true then done = done + 1 end
        if value(i, 13) == true then mine = mine + 1 end
        if isPoint then pointed = pointed + 1; if value(i, 4) == true then pointedDone = pointedDone + 1 end end
        if isPoint or s.kind == "ach" then
            line(out, "ach", a.achievementID, value(i, 2), "cat", first(a.category), "completed", value(i, 4), "byMe", value(i, 13),
                "earnedBy", value(i, 14), "flags", value(i, 9), "pts", pts, "crit#", first(a.numCriteria), "desc", value(i, 8))
            for n, cr in ipairs(a.criteria) do
                line(out, "  crit", n, value(cr, 1), "done", value(cr, 3), value(cr, 4), "/", value(cr, 5), value(cr, 9), "type", value(cr, 2), "asset", value(cr, 8))
            end
        else
            local critDone = 0
            for _, cr in ipairs(a.criteria) do if value(cr, 3) == true then critDone = critDone + 1 end end
            line(out, "sup", a.achievementID, value(i, 2), "cat", first(a.category), "completed", value(i, 4), "byMe", value(i, 13),
                "crit", critDone, "/", first(a.numCriteria))
        end
    end
    line(out, "challenges", #(s.challenges or {}), "completed", done, "byMe", mine, "pointed", pointed, "pointedCompleted", pointedDone)
    local counts = {}
    for k, v in pairs(s.eventCounts or {}) do counts[#counts + 1] = k .. "=" .. str(v) end
    table.sort(counts)
    line(out, "events", table.concat(counts, " "))
    return table.concat(out, "\n")
end
local function report()
    local content = reportText()
    if not content then say("no_sample"); return end
    if not reportWindow then
        local f = CreateFrame("Frame", nil, UIParent)
        f:SetSize(760, 520); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG"); f:EnableMouse(true)
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
        edit:SetWidth(690); edit:SetMaxLetters(0); edit:SetScript("OnEscapePressed", function() f:Hide() end)
        scroll:SetScrollChild(edit); f.edit = edit; reportWindow = f
    end
    reportWindow:Show(); reportWindow.edit:SetText(content); reportWindow.edit:SetFocus(); reportWindow.edit:HighlightText()
end

local frame = CreateFrame("Frame")
P.registration = {}
for _, event in ipairs({ "ADDON_LOADED", "PLAYER_ENTERING_WORLD", "PLAYER_LEAVING_WORLD", "PLAYER_LOGOUT",
    "ACHIEVEMENT_EARNED", "CRITERIA_UPDATE", "CRITERIA_EARNED", "MAJOR_FACTION_RENOWN_LEVEL_CHANGED", "MAJOR_FACTION_UNLOCKED",
    "TRAIT_CONFIG_CREATED", "TRAIT_CONFIG_UPDATED", "TRAIT_TREE_CURRENCY_INFO_UPDATED", "TRAIT_NODE_CHANGED",
    "ZONE_CHANGED_NEW_AREA", "PLAYER_LEVEL_UP", "SKILL_LINES_CHANGED" }) do
    local ok, err = pcall(frame.RegisterEvent, frame, event)
    P.registration[event] = ok and "registered" or safe(err)
end
frame:SetScript("OnEvent", function(_, event, ...)
    local arg = ...
    if event == "ADDON_LOADED" and arg == addonName then
        if session then return end
        if not isForever() then say("unavailable"); return end
        local existing = YiboLegacyForeverProbeDB
        if not validStore(existing) then say("unavailable"); return end
        YiboLegacyForeverProbeDB = existing or { schema = 1, nextSample = 0, sessions = 0, samples = {} }
        db = YiboLegacyForeverProbeDB; db.sessions = db.sessions + 1
        session = { id = db.sessions, events = {}, counts = {}, previousSampleID = db.samples[#db.samples] and db.samples[#db.samples].id }
        say("ready")
    end
    if not session or (event == "ADDON_LOADED" and arg ~= addonName) then return end
    if event == "PLAYER_ENTERING_WORLD" then inWorld = true end
    if event == "PLAYER_LEAVING_WORLD" or event == "PLAYER_LOGOUT" then inWorld = false end
    session.counts[event] = (session.counts[event] or 0) + 1
    if event == "CRITERIA_UPDATE" and session.counts[event] > 8 then return end
    session.events[#session.events + 1] = { event = event, clock = read("GetTime"), args = safe(pack(...)) }
    while #session.events > 48 do table.remove(session.events, 1) end
    -- Events only record timing/arguments. No scans, filter changes or trait operations are triggered.
end)
SLASH_YIBOLEGACYFOREVERPROBE1 = "/ylg"
SlashCmdList.YIBOLEGACYFOREVERPROBE = function(message)
    local command, argument = string.match(message or "", "^%s*(%S*)%s*(.-)%s*$")
    command = string.lower(command or "")
    if command == "report" then
        local ok, err = pcall(report); if not ok then say("report_error", tostring(err)) end
    elseif command == "scan" then
        capture("scan")
    elseif command == "ach" then
        local id = tonumber(argument)
        if not positive(id) then say("invalid"); return end
        capture("ach", id)
    else say("help") end
end
P.capture, P.reportText = capture, reportText
