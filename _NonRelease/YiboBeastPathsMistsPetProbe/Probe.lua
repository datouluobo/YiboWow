local addonName = ...
local TARGET = { project = 19, interface = 50504 }
local DB_NAME = "YiboBeastPathsMistsPetProbeDB"
local frame = CreateFrame("Frame")
local Probe = { target = "Mists", historyLimit = 20, events = {}, stableOpen = false }
local function Pack(...) return { n = select("#", ...), ... } end
local function Protected(fn, ...)
    if type(fn) ~= "function" then return { status = "missing" } end
    local result = Pack(pcall(fn, ...))
    if not result[1] then return { status = "error", error = tostring(result[2]) } end
    local values = { n = result.n - 1 }
    for i = 2, result.n do
        local v = result[i]
        if type(v) == "number" or type(v) == "string" or type(v) == "boolean" then values[i - 1] = v end
    end
    return { status = "ok", values = values }
end
local function IsTarget() return _G.WOW_PROJECT_ID == TARGET.project end
local function CoreReady()
    local core = _G.YiboCore
    if not (core and core.CheckAPIVersion and core:CheckAPIVersion(13)
        and core.HasCapability and core.IsInitialized and core:IsInitialized()) then return nil end
    for name, version in pairs({ ["character-identity"] = 1, characters = 1 }) do
        if not core:HasCapability(name, version) then return nil end
    end
    if not (core.Characters and core.Characters.GetCurrentID) then return nil end
    return core
end
local function First(r) return r and r.values and r.values[1] end
local function Positive(v) return type(v) == "number" and v > 0 and v == math.floor(v) end
local function Bounds()
    local active, eachPage, pages = _G.NUM_PET_ACTIVE_SLOTS, _G.NUM_PET_STABLE_SLOTS, _G.NUM_PET_STABLE_PAGES
    local verifiedShape = Positive(active) and Positive(eachPage) and Positive(pages)
        and active <= 20 and eachPage * pages <= 1000
    return { active = verifiedShape and active or 5, stable = verifiedShape and eachPage * pages or 200,
        source = verifiedShape and "native-ui-constants" or "provisional-mists", verified = false }
end
local function BuildSnapshot(trigger)
    local bounds, stableAPI = Bounds(), _G.C_StableInfo or {}
    local s = { at = time(), trigger = trigger, version = { GetBuildInfo() }, project = _G.WOW_PROJECT_ID,
        locale = GetLocale(), stableOpen = Probe.stableOpen, bounds = bounds,
        activeCount = Protected(stableAPI.GetNumActivePets), stableCount = Protected(stableAPI.GetNumStablePets),
        purchasedSlots = Protected(_G.GetNumStableSlots), slots = {}, counts = { active = 0, stable = 0, nilSlots = 0, errors = 0 },
        capabilities = { slotInfo = type(_G.GetStablePetInfo) == "function",
            stableDisplay = type(_G.C_PlayerInfo and C_PlayerInfo.GetPetStableCreatureDisplayInfoID) == "function",
            activeCount = type(stableAPI.GetNumActivePets) == "function",
            stableCount = type(stableAPI.GetNumStablePets) == "function" }, completeness = "unverified" }
    local max = bounds.active + bounds.stable
    for index = 1, max do
        local info = Protected(_G.GetStablePetInfo, index)
        local raw = info.values or {}
        local occupied = info.status == "ok" and (raw[1] ~= nil or raw[2] ~= nil)
        local display = occupied and Protected(_G.C_PlayerInfo and C_PlayerInfo.GetPetStableCreatureDisplayInfoID, index)
            or { status = "not-read" }
        local slot = { index = index, group = index <= bounds.active and "active" or "stable",
            info = info, occupied = occupied, icon = raw[1], name = raw[2], level = raw[3],
            family = raw[4], specialization = raw[5], display = display }
        if info.status ~= "ok" then s.counts.errors = s.counts.errors + 1
        elseif not occupied then s.counts.nilSlots = s.counts.nilSlots + 1
        else
            s.counts[slot.group] = s.counts[slot.group] + 1
            slot.displayID = First(display)
            if display.status == "error" or display.status == "missing" then s.counts.errors = s.counts.errors + 1 end
        end
        s.slots[index] = slot
    end
    return s
end
function Probe:Scan(trigger)
    if not IsTarget() then print("[YBP Mists Probe] STOP wrong product; no probe writes"); return end
    local core = CoreReady()
    if not core then print("[YBP Mists Probe] STOP Core API13/ready/identity unavailable; no probe writes"); return end
    local id = core.Characters:GetCurrentID()
    if type(id) ~= "string" or id == "" then print("[YBP Mists Probe] STOP character identity unavailable; no probe writes"); return end
    local s = BuildSnapshot(trigger); s.characterID = id
    local db = _G[DB_NAME]
    if type(db) == "table" and db.schema ~= nil and db.schema ~= 1 then
        print("[YBP Mists Probe] STOP unknown probe schema; saved data preserved"); return
    end
    if type(db) ~= "table" then db = {}; _G[DB_NAME] = db end
    db.schema = 1; db.characters = type(db.characters) == "table" and db.characters or {}
    local record = db.characters[id]
    if type(record) ~= "table" then record = { samples = {} }; db.characters[id] = record end
    record.samples = type(record.samples) == "table" and record.samples or {}
    record.samples[#record.samples + 1] = s
    while #record.samples > self.historyLimit do table.remove(record.samples, 1) end
    record.latest = s; self.record = record
    print("[YBP Mists Probe] sampled; detail is local in probe SavedVariables"); self:Report()
end
function Probe:Report()
    local s = self.record and self.record.latest
    if not s then print("[YBP Mists Probe] no sample; use /ymx scan"); return end
    local function first(r) return r and r.status .. (First(r) ~= nil and (":" .. tostring(First(r))) or "") or "missing" end
    print(string.format("[YBP Mists Probe] build=%s interface=%s project=%s locale=%s trigger=%s stableOpen=%s bounds=%s:%d+%d",
        tostring(s.version[1] .. "/" .. s.version[2]), tostring(select(4, GetBuildInfo())), tostring(s.project), s.locale,
        tostring(s.trigger), tostring(s.stableOpen), s.bounds.source, s.bounds.active, s.bounds.stable))
    print(string.format("[YBP Mists Probe] counts active=%s stable=%s purchased=%s; scanned=%d occupied=%d nil=%d errors=%d complete=%s; petEvents=%d",
        first(s.activeCount), first(s.stableCount), first(s.purchasedSlots), #s.slots,
        s.counts.active + s.counts.stable, s.counts.nilSlots, s.counts.errors, s.completeness, #self.events))
    local occupied = {}; for _, slot in ipairs(s.slots) do if slot.occupied then occupied[#occupied + 1] = slot.index end end
    print("[YBP Mists Probe] occupied slotIDs=" .. table.concat(occupied, ","))
    local trail = {}
    for i = math.max(1, #self.events - 11), #self.events do trail[#trail + 1] = self.events[i].event end
    print("[YBP Mists Probe] recent events=" .. table.concat(trail, ","))
end
function Probe:Command(message)
    local command = (message or ""):match("^%s*(%S*)")
    if command == "scan" then self:Scan("manual")
    elseif command == "report" or command == "" then self:Report()
    else print("[YBP Mists Probe] /ymx scan | report") end
end
frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "PLAYER_LOGIN" then
        if not IsTarget() then print("[YBP Mists Probe] STOP wrong product; target probe inactive"); return end
        local core = CoreReady()
        if not core then print("[YBP Mists Probe] Core unavailable; probe will not write"); return end
        Probe.core = core
        _G.SlashCmdList = _G.SlashCmdList or {}
        _G.SlashCmdList.YIBOBEASTPATHSMISTSPETPROBE = function(msg) Probe:Command(msg) end
        print("[YBP Mists Probe] ready; read-only game API; /ymx scan")
        Probe:Scan("login")
    elseif IsTarget() and Probe.core then
        if event == "PET_STABLE_SHOW" then Probe.stableOpen = true
        elseif event == "PET_STABLE_CLOSED" then Probe.stableOpen = false end
        Probe.events[#Probe.events + 1] = { event = event, at = time() }
        if #Probe.events > 100 then table.remove(Probe.events, 1) end
    end
end)
_G.SLASH_YIBOBEASTPATHSMISTSPETPROBE1 = "/ymx"
_G.SlashCmdList = _G.SlashCmdList or {}
_G.SlashCmdList.YIBOBEASTPATHSMISTSPETPROBE = function(msg) Probe:Command(msg) end
for _, event in ipairs({ "PLAYER_LOGIN", "PET_STABLE_SHOW", "PET_STABLE_UPDATE", "PET_STABLE_CLOSED",
    "UNIT_PET", "UNIT_NAME_UPDATE", "PET_UI_UPDATE" }) do frame:RegisterEvent(event) end
