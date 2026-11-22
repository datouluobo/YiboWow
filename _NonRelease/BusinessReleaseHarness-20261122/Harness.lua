-- Packaged business-addon replay (2026-11-22, API14 wave).
-- Loads a real Core package TOC and a real business-addon package TOC in
-- client order inside one synthetic environment:
--   Core files -> Core SavedVariables -> ADDON_LOADED(YiboCore)
--   addon files -> addon SavedVariables -> ADDON_LOADED(addon)
--   PLAYER_LOGIN -> PLAYER_ENTERING_WORLD -> timers
-- Frames/client stubs come from _NonRelease/CoreForever/FrameFixture.lua;
-- the extra client API stubs below are listed explicitly so a missing API is
-- reported as a fixture gap rather than hidden.
-- Run from the repository root with Lua 5.1.
local H = {}

local PROJECTS = { Mists = 19, Forever = 18, Retail = 1 }
local CORE_STORES = { Mists = "YiboCoreDB", Forever = "YiboCoreForeverDB", Retail = "YiboCoreRetailDB" }

local function ReadToc(path)
    local files, meta = {}, {}
    local handle = assert(io.open(path, "rb"), "missing TOC " .. path)
    for line in handle:read("*a"):gmatch("[^\n]+") do
        line = line:gsub("\r", "")
        local key, value = line:match("^##%s*([^:]+):%s*(.-)%s*$")
        if key then meta[key] = value
        elseif line:match("%S") and not line:match("^#") then
            files[#files + 1] = (line:gsub("\\", "/"):gsub("^%s+", ""):gsub("%s+$", ""))
        end
    end
    handle:close()
    return files, meta
end
H.ReadToc = ReadToc

function H.Serialize(value, seen)
    seen = seen or {}
    if type(value) ~= "table" then return type(value) == "string" and string.format("%q", value) or tostring(value) end
    if seen[value] then return "<cycle>" end
    seen[value] = true
    local keys = {}
    for k in pairs(value) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local parts = {}
    for _, k in ipairs(keys) do parts[#parts + 1] = "[" .. H.Serialize(k, seen) .. "]=" .. H.Serialize(value[k], seen) end
    seen[value] = nil
    return "{" .. table.concat(parts, ",") .. "}"
end

function H.Copy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for k, v in pairs(value) do out[k] = H.Copy(v) end
    return out
end

-- Client APIs used by the business addons that FrameFixture does not provide.
-- Each stub returns "nothing observed" so no business data is invented.
local function InstallClientStubs(env)
    local noop = function() end
    -- Frame methods missing from FrameFixture (fixture gaps, not addon behaviour).
    local methods = getmetatable(env.UIParent).__index
    if not methods.SetParent then
        function methods:SetParent(parent)
            if self.parent then
                for i, child in ipairs(self.parent.children) do if child == self then table.remove(self.parent.children, i); break end end
            end
            self.parent = parent
            if parent then parent.children[#parent.children + 1] = self end
        end
    end
    env.hooksecurefunc = function(a, b, c)
        local tbl, name, hook = env, a, b
        if type(a) == "table" then tbl, name, hook = a, b, c end
        local original = tbl[name]
        tbl[name] = function(...) local r = { original and original(...) }; hook(...); return unpack(r) end
    end
    env.IsLoggedIn = function() return env.TEST_LOGGED_IN == true end
    env.GetLocale = env.GetLocale
    env.C_AddOns.IsAddOnLoaded = function(name) return env.TEST_LOADED[name] == true end
    env.C_AddOns.GetAddOnMetadata = function(name, key)
        local meta = env.TEST_META[name]; return meta and meta[key]
    end
    env.C_AddOns.GetAddOnInfo = function(name) if env.TEST_META[name] then return name, env.TEST_META[name].Title end end
    env.C_AddOns.GetNumAddOns = function() return 0 end
    env.IsAddOnLoaded = env.C_AddOns.IsAddOnLoaded
    env.GetAddOnMetadata = env.C_AddOns.GetAddOnMetadata
    env.GetNumAddOns = function() return 0 end
    env.ReloadUI = noop
    env.PlaySound = noop
    env.SOUNDKIT = setmetatable({}, { __index = function() return 0 end })
    env.GetQuestID = function() return 0 end
    env.AcceptQuest, env.DeclineQuest, env.ConfirmAcceptQuest, env.CloseQuest = noop, noop, noop, noop
    env.GetNumQuestLogEntries = function() return 0 end
    env.C_QuestLog = env.C_QuestLog or {
        IsQuestFlaggedCompleted = function() return false end,
        GetNumQuestLogEntries = function() return 0, 0 end,
        GetInfo = function() return nil end,
        GetLogIndexForQuestID = function() return nil end,
        IsOnQuest = function() return false end,
        GetQuestObjectives = function() return {} end,
        GetTitleForQuestID = function() return nil end,
    }
    env.IsQuestFlaggedCompleted = function() return false end
    env.GetQuestsCompleted = function() return {} end
    env.C_GossipInfo = env.C_GossipInfo or { GetAvailableQuests = function() return {} end, GetActiveQuests = function() return {} end, GetOptions = function() return {} end, SelectAvailableQuest = noop }
    env.C_CurrencyInfo = env.C_CurrencyInfo or { GetCurrencyInfo = function() return nil end }
    env.GetCurrencyInfo = function() return nil end
    env.C_Reputation = env.C_Reputation or { GetFactionDataByID = function() return nil end }
    env.GetFactionInfoByID = function() return nil end
    env.GetItemCount = function() return 0 end
    env.GetInventoryItemID = function() return nil end
    env.GetInventoryItemLink = function() return nil end
    env.GetItemInfo = function() return nil end
    env.GetItemIcon = function() return nil end
    env.GetSpellInfo = function() return nil end
    env.GetSpellTexture = function() return nil end
    env.IsSpellKnown = function() return false end
    env.GetSpellCooldown = function() return 0, 0, 0 end
    env.C_Spell = env.C_Spell or { GetSpellInfo = function() return nil end, GetSpellCooldown = function() return nil end, GetSpellTexture = function() return nil end }
    env.C_TradeSkillUI = env.C_TradeSkillUI or {}
    env.GetProfessions = function() return nil end
    env.GetProfessionInfo = function() return nil end
    env.GetNumTradeSkills = function() return 0 end
    env.GetTradeSkillLine = function() return nil end
    env.UnitExists = function(unit) return unit == "player" end
    env.UnitIsDeadOrGhost = function() return false end
    env.UnitAffectingCombat = function() return false end
    env.IsInInstance = function() return false, "none" end
    env.GetInstanceInfo = function() return nil end
    env.GetNumSavedInstances = function() return 0 end
    env.RequestRaidInfo = noop
    env.GetQuestResetTime = function() return 3600 end
    env.C_DateAndTime = env.C_DateAndTime or {
        GetSecondsUntilDailyReset = function() return 3600 end,
        GetSecondsUntilWeeklyReset = function() return 86400 end,
        GetCurrentCalendarTime = function() local t = os.date("*t", 1792339474); return { year = t.year, month = t.month, monthDay = t.day, weekday = t.wday, hour = t.hour, minute = t.min } end,
    }
    env.C_Calendar = env.C_Calendar or {
        OpenCalendar = noop, GetNumDayEvents = function() return 0 end, GetDayEvent = function() return nil end,
        GetMonthInfo = function() local t = os.date("*t", 1792339474); return { month = t.month, year = t.year, numDays = 30, firstWeekday = 1 } end,
        SetAbsMonth = noop, SetMonth = noop,
    }
    env.CalendarFrame = nil
    env.GetMoney = function() return 0 end
    env.GetCursorPosition = function() return 0, 0 end
    env.IsShiftKeyDown, env.IsControlKeyDown, env.IsAltKeyDown = function() return false end, function() return false end, function() return false end
    env.ChatFrame_OpenChat = noop
    env.StaticPopup_Show = noop
    env.StaticPopup_Hide = noop
    env.CloseDropDownMenus = noop
    env.Settings = nil
    env.InterfaceOptions_AddCategory = noop
    env.GetCVar = function() return nil end
    env.GetScreenWidth, env.GetScreenHeight = function() return 1600 end, function() return 1000 end
    env.GetPhysicalScreenSize = function() return 2560, 1440 end
    env.UnitGroupRolesAssigned = function() return "NONE" end
    env.GetSpecialization = function() return nil end
    env.C_Item.GetItemInfoInstant = function() return nil end
    env.C_Item.GetItemCount = function() return 0 end
    env.C_Item.GetItemIconByID = function() return nil end
    env.C_Item.RequestLoadItemDataByID = noop
    env.C_Item.IsItemDataCachedByID = function() return false end
    env.Item = { CreateFromItemID = function() return { ContinueOnItemLoad = noop, IsItemEmpty = function() return true end } end }
    env.math, env.string, env.table = math, string, table
    env.strsplit = function(sep, s) local out = {}; for part in (s .. sep):gmatch("(.-)" .. sep:gsub("%p", "%%%0")) do out[#out + 1] = part end; return unpack(out) end
    env.strjoin = function(sep, ...) return table.concat({ ... }, sep) end
    env.format = string.format
    env.floor, env.ceil, env.max, env.min, env.abs = math.floor, math.ceil, math.max, math.min, math.abs
    env.strlower, env.strupper, env.strsub, env.strlen, env.strfind, env.gsub = string.lower, string.upper, string.sub, string.len, string.find, string.gsub
    env.tContains = function(t, v) for _, x in ipairs(t) do if x == v then return true end end return false end
    env.CopyTable = H.Copy
    env.Mixin = function(o, ...) for _, m in ipairs({ ... }) do for k, v in pairs(m) do o[k] = v end end return o end
    env.securecallfunction = function(f, ...) return f(...) end
    env.geterrorhandler = function() return function(e) env.TEST_ERRORS[#env.TEST_ERRORS + 1] = tostring(e) end end
end

-- opts: client (Mists/Forever/Retail), coreRoot, addonRoot, addon, saved
-- (table SVname -> value), coreSaved, locale, configure(env) before Core.
function H.Boot(opts)
    local client = opts.client or "Mists"
    local env = setmetatable({ TEST_GUID = "Player-4800-0ABCDEF1", TEST_MESSAGES = {}, TEST_TIMERS = {}, TEST_ERRORS = {},
        TEST_LOADED = {}, TEST_META = {}, WOW_PROJECT_ID = PROJECTS[client], WOW_PROJECT_MAINLINE = 1, WOW_PROJECT_CAMELOT = 18,
        YiboCoreDB = { sentinel = "mists" }, YiboCoreForeverDB = { sentinel = "forever" }, YiboCoreRetailDB = { sentinel = "retail" },
    }, { __index = _G })
    env._G = env
    local function LoadFile(path, name, private)
        local chunk = assert(loadfile(path)); setfenv(chunk, env); chunk(name, private)
    end
    LoadFile("_NonRelease/CoreForever/FrameFixture.lua", "YiboCore", {})
    InstallClientStubs(env)
    if client ~= "Mists" then env.WOW_PROJECT_MISTS_CLASSIC = 19 end
    local locale = opts.locale or "zhCN"
    env.GetLocale = function() return locale end
    if opts.configure then opts.configure(env) end

    local function Event(event, ...)
        local args = { ... }
        local frames = {}
        for i, frame in ipairs(env.TEST_FRAMES) do frames[i] = frame end
        for _, frame in ipairs(frames) do
            if frame.events and frame.events[event] and frame.scripts.OnEvent then frame.scripts.OnEvent(frame, event, unpack(args)) end
        end
    end
    local function Flush(rounds)
        for _ = 1, rounds or 3 do
            local timers = env.TEST_TIMERS; env.TEST_TIMERS = {}
            if #timers == 0 then break end
            for _, timer in ipairs(timers) do timer[2]() end
        end
    end
    local function LoadAddon(root, name, saved)
        local files, meta = ReadToc(root .. "/" .. name .. ".toc")
        env.TEST_META[name] = meta
        local private = {}
        for _, file in ipairs(files) do
            assert(file:match("%.lua$"), "non-Lua TOC entry not supported by harness: " .. file)
            LoadFile(root .. "/" .. file, name, private)
        end
        -- SavedVariables are restored after the files run, before ADDON_LOADED.
        for sv, value in pairs(saved or {}) do env[sv] = value end
        env.TEST_LOADED[name] = true
        Event("ADDON_LOADED", name)
        return files, meta
    end

    local coreSaved = opts.coreSaved
    if coreSaved == nil then
        coreSaved = { marker = "core-keep", schemaVersion = 11, settings = { language = "auto" },
            clientScope = { target = client, projectID = PROJECTS[client], rulesetState = "unknown" }, characters = { byID = {} } }
    end
    local coreFiles = LoadAddon(opts.coreRoot, "YiboCore", { [CORE_STORES[client]] = coreSaved })
    local Core = env.YiboCore

    -- Count business registrations made by this addon (successful only).
    local counts = { RegisterAddon = 0, RegisterPage = 0, RegisterBusinessEntry = 0, CleanupOwner = 0 }
    local function Wrap(owner, method, key)
        if not (owner and type(owner[method]) == "function") then return end
        local original = owner[method]
        owner[method] = function(self, name, ...)
            local a, b, c = original(self, name, ...)
            if name == opts.addon and a then counts[key] = counts[key] + 1 end
            return a, b, c
        end
    end
    if Core then
        Wrap(Core, "RegisterAddon", "RegisterAddon")
        Wrap(Core.AccountView, "RegisterPage", "RegisterPage")
        Wrap(Core.Entry, "RegisterBusinessEntry", "RegisterBusinessEntry")
        Wrap(Core.CharacterCleanup, "RegisterOwner", "CleanupOwner")
    end
    local files, meta = LoadAddon(opts.addonRoot, opts.addon, opts.saved)
    env.TEST_LOGGED_IN = true
    Event("PLAYER_LOGIN")
    Event("PLAYER_ENTERING_WORLD", true, false)
    Flush()
    return { env = env, Core = Core, Event = Event, Flush = Flush, counts = counts, files = files, meta = meta, coreFiles = coreFiles }
end

function H.Checker(label)
    local state = { label = label, passed = 0, failed = {} }
    function state.Check(value, name)
        if value then state.passed = state.passed + 1 else state.failed[#state.failed + 1] = name end
        return value
    end
    function state.Report()
        print(string.format("%s: %d passed, %d failed", state.label, state.passed, #state.failed))
        for _, name in ipairs(state.failed) do print("  FAIL " .. name) end
        return #state.failed == 0
    end
    return state
end

function H.HasMessage(env, patterns)
    for _, message in ipairs(env.TEST_MESSAGES) do
        for _, pattern in ipairs(patterns) do if tostring(message):find(pattern) then return true, message end end
    end
    return false
end

return H
