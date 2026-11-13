local addonName = ...
local TARGET = { project = 1, mainline = 1, interface = 120105 }
local DB_NAME = "YiboBeastPathsRetailPetProbeDB"
local frame = CreateFrame("Frame")
local Probe = { target = "Retail", historyLimit = 20, events = {} }
local function Pack(...) return { n = select("#", ...), ... } end
local function Protected(fn, ...)
    if type(fn) ~= "function" then return { status = "missing" } end
    local result = Pack(pcall(fn, ...))
    if not result[1] then return { status = "error", error = tostring(result[2]) } end
    return { status = "ok", values = { unpack(result, 2, result.n) } }
end
local function IsTarget()
    return _G.WOW_PROJECT_ID == TARGET.project and _G.WOW_PROJECT_MAINLINE == TARGET.mainline
end
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
local function Push(list, value)
    list[#list + 1] = value
end
local function CallList(fn)
    local r = Protected(fn)
    if r.status ~= "ok" then return r end
    local value = r.values[1]
    if type(value) ~= "table" then return { status = "invalid", kind = type(value) } end
    local rows, seen, duplicates, malformed = {}, {}, 0, 0
    for _, pet in pairs(value) do
        if type(pet) ~= "table" or type(pet.slotID) ~= "number" then
            malformed = malformed + 1
        else
            if seen[pet.slotID] then duplicates = duplicates + 1 end
            seen[pet.slotID] = true
            Push(rows, { slotID = pet.slotID, name = pet.name, icon = pet.icon, level = pet.level,
                familyName = pet.familyName, specialization = pet.specialization, type = pet.type,
                displayID = pet.displayID, petNumber = pet.petNumber, creatureID = pet.creatureID })
        end
    end
    table.sort(rows, function(a, b) return a.slotID < b.slotID end)
    return { status = "ok", count = #rows, duplicates = duplicates, malformed = malformed, rows = rows }
end
local function BuildSnapshot(trigger)
    local api = _G.C_StableInfo or {}
    local constants = _G.Constants and Constants.PetConsts_PostCata or {}
    local maxSlots = constants.NUM_PET_SLOTS_HUNTER
    local activeMax = constants.MAX_SUMMONABLE_HUNTER_PETS
    local extraIndex = type(constants.EXTRA_PET_STABLE_SLOT) == "number"
        and constants.EXTRA_PET_STABLE_SLOT + 1 or nil
    local spec = Protected(_G.GetSpecialization)
    local specIndex = spec.status == "ok" and spec.values[1] or nil
    local specInfo = type(specIndex) == "number" and Protected(_G.GetSpecializationInfo, specIndex)
        or { status = "missing" }
    local snapshot = {
        at = type(_G.time) == "function" and time() or 0, trigger = trigger,
        version = { GetBuildInfo() }, project = _G.WOW_PROJECT_ID, mainline = _G.WOW_PROJECT_MAINLINE,
        stableVisible = type(_G.StableFrame) == "table" and StableFrame.IsShown
            and StableFrame:IsShown() or false,
        isAtStableMaster = Protected(api.IsAtStableMaster),
        active = CallList(api.GetActivePetList), stabled = CallList(api.GetStabledPetList),
        activeCount = Protected(api.GetNumActivePets), stableCount = Protected(api.GetNumStablePets),
        slotProbe = { maxSlots = maxSlots, activeMax = activeMax, status = "unavailable" },
        extraProbe = { index = extraIndex, bonusAvailable = Protected(api.IsBonusPetSlotAvailable),
            specializationID = specInfo.status == "ok" and specInfo.values[1] or nil },
    }
    if type(extraIndex) == "number" and extraIndex >= 1 and extraIndex <= 300 and extraIndex % 1 == 0 then
        local extra = Protected(api.GetStablePetInfo, extraIndex)
        snapshot.extraProbe.status = extra.status
        if extra.status == "ok" then
            local pet = extra.values[1]
            snapshot.extraProbe.present = type(pet) == "table"
            if type(pet) == "table" then
                snapshot.extraProbe.slotID = pet.slotID
                snapshot.extraProbe.petNumber = pet.petNumber
            end
        end
    else
        snapshot.extraProbe.status = "missing-constant"
    end
    if type(maxSlots) == "number" and maxSlots > 0 and maxSlots <= 300 then
        local slots, occupied, errors, nils = {}, {}, 0, 0
        snapshot.slotProbe.status = "ok"
        for index = 1, maxSlots do
            local r = Protected(api.GetStablePetInfo, index)
            if r.status ~= "ok" then errors = errors + 1
            elseif type(r.values[1]) ~= "table" then nils = nils + 1
            else
                local pet = r.values[1]
                occupied[#occupied + 1] = index
                slots[#slots + 1] = { slotID = index, name = pet.name, displayID = pet.displayID,
                    petNumber = pet.petNumber, creatureID = pet.creatureID }
            end
        end
        snapshot.slotProbe.occupied = #occupied
        snapshot.slotProbe.first = occupied[1]
        snapshot.slotProbe.last = occupied[#occupied]
        snapshot.slotProbe.errors, snapshot.slotProbe.nilSlots = errors, nils
        snapshot.slotProbe.rows = slots
        snapshot.slotProbe.semantics = "Retail UI slot constants; categories require in-game confirmation"
    end
    return snapshot
end
function Probe:Scan(trigger)
    if not IsTarget() then print("[YBP Retail Probe] STOP wrong product; no probe writes"); return end
    local core = CoreReady()
    if not core then print("[YBP Retail Probe] STOP Core API13/ready/identity unavailable; no probe writes"); return end
    local id = core.Characters:GetCurrentID()
    if type(id) ~= "string" or id == "" then print("[YBP Retail Probe] STOP character identity unavailable; no probe writes"); return end
    local snapshot = BuildSnapshot(trigger)
    snapshot.characterID = id
    local db = _G[DB_NAME]
    if type(db) == "table" and db.schema ~= nil and db.schema ~= 1 then
        print("[YBP Retail Probe] STOP unknown probe schema; saved data preserved"); return
    end
    if type(db) ~= "table" then db = {}; _G[DB_NAME] = db end
    db.schema = 1
    db.characters = type(db.characters) == "table" and db.characters or {}
    local record = db.characters[id]
    if type(record) ~= "table" then record = { samples = {} }; db.characters[id] = record end
    record.samples = type(record.samples) == "table" and record.samples or {}
    record.samples[#record.samples + 1] = snapshot
    while #record.samples > self.historyLimit do table.remove(record.samples, 1) end
    record.latest = snapshot
    self.record = record
    print("[YBP Retail Probe] sampled; detail is local in probe SavedVariables"); self:Report()
end
function Probe:Report()
    local s = self.record and self.record.latest
    if not s then print("[YBP Retail Probe] no sample; use /yrx scan"); return end
    local function state(v)
        if not v then return "missing" end
        local value = v.count ~= nil and v.count or (v.values and v.values[1])
        return v.status .. (value ~= nil and (":" .. tostring(value)) or ":nil")
    end
    local p = s.slotProbe or {}
    local samples = self.record.samples and #self.record.samples or 0
    local version, build, _, interface = GetBuildInfo()
    print(string.format("[YBP Retail Probe] build=%s interface=%s project=%s locale=%s trigger=%s visible=%s atStable=%s samples=%d",
        tostring(version .. "/" .. build), tostring(interface), tostring(s.project), GetLocale(),
        tostring(s.trigger), tostring(s.stableVisible), state(s.isAtStableMaster), samples))
    print(string.format("[YBP Retail Probe] lists active=%s stable=%s; apiCounts active=%s stable=%s",
        state(s.active), state(s.stabled), state(s.activeCount), state(s.stableCount)))
    print(string.format("[YBP Retail Probe] slotConstants max=%s active=%s slotRead=%s occupied=%s first=%s last=%s nil=%s errors=%s completeness=unverified; petEvents=%d",
        tostring(p.maxSlots), tostring(p.activeMax), tostring(p.status), tostring(p.occupied), tostring(p.first),
        tostring(p.last), tostring(p.nilSlots), tostring(p.errors), #self.events))
    local trail = {}
    for i = math.max(1, #self.events - 11), #self.events do trail[#trail + 1] = self.events[i].event end
    print("[YBP Retail Probe] recent events=" .. table.concat(trail, ","))
end
function Probe:Detail()
    local s = self.record and self.record.latest
    if not s then self:Report(); return end
    local function slots(group)
        if not group or group.status ~= "ok" then return "n/a" end
        local out = {}
        for _, pet in ipairs(group.rows) do out[#out + 1] = tostring(pet.slotID) end
        return table.concat(out, ",")
    end
    print("[YBP Retail Probe] active slotIDs=" .. slots(s.active))
    print("[YBP Retail Probe] stable slotIDs=" .. slots(s.stabled))
    print("[YBP Retail Probe] all native slots=" .. slots(s.slotProbe and { status = "ok", rows = s.slotProbe.rows }))
end
function Probe:Command(message)
    local command = (message or ""):match("^%s*(%S*)")
    if command == "scan" then self:Scan("manual")
    elseif command == "detail" then self:Detail()
    elseif command == "report" or command == "" then self:Report()
    else print("[YBP Retail Probe] /yrx scan | report | detail") end
end
frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "PLAYER_LOGIN" then
        if not IsTarget() then print("[YBP Retail Probe] STOP wrong product; target probe inactive"); return end
        local core = CoreReady()
        if not core then print("[YBP Retail Probe] Core unavailable; probe will not write"); return end
        Probe.core = core
        _G.SlashCmdList = _G.SlashCmdList or {}
        _G.SlashCmdList.YIBOBEASTPATHSRETAILPETPROBE = function(msg) Probe:Command(msg) end
        for _, e in ipairs({ "PET_STABLE_SHOW", "PET_STABLE_UPDATE", "PET_STABLE_CLOSED", "PET_INFO_UPDATE" }) do frame:RegisterEvent(e) end
        print("[YBP Retail Probe] ready; read-only game API; /yrx scan")
        Probe:Scan("login")
    elseif IsTarget() and Probe.core then
        Probe.events[#Probe.events + 1] = { event = event, at = time() }
        if #Probe.events > 100 then table.remove(Probe.events, 1) end
    end
end)
_G.SLASH_YIBOBEASTPATHSRETAILPETPROBE1 = "/yrx"
_G.SlashCmdList = _G.SlashCmdList or {}
_G.SlashCmdList.YIBOBEASTPATHSRETAILPETPROBE = function(msg) Probe:Command(msg) end
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PET_STABLE_SHOW")
frame:RegisterEvent("PET_STABLE_UPDATE")
frame:RegisterEvent("PET_STABLE_CLOSED")
frame:RegisterEvent("PET_INFO_UPDATE")
