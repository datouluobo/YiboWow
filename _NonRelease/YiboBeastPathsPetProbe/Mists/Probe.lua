local addonName, ns = ...
local Probe = { VERSION = "0.1.1", MAX_SAMPLES = 24, stableOpen = false }
_G.YiboBeastPathsPetProbe = Probe
local COLORS = { "jade", "amethyst", "cobalt", "jasper" }
local COLOR_KEYS = { jade = "COLOR_JADE", amethyst = "COLOR_AMETHYST", cobalt = "COLOR_COBALT", jasper = "COLOR_JASPER" }
local frame = CreateFrame("Frame")
local Core

local function Pack(...) return { n = select("#", ...), ... } end
local function Now() return type(time) == "function" and time() or 0 end
local function Read(fn, ...)
    if type(fn) ~= "function" then return { status = "missing-api" } end
    local result = Pack(pcall(fn, ...))
    if not result[1] then return { status = "error", error = tostring(result[2]) } end
    local values = { n = result.n - 1 }
    for i = 2, result.n do
        local value = result[i]
        if type(value) == "number" or type(value) == "string" or type(value) == "boolean" then values[i - 1] = value end
    end
    return { status = "ok", values = values }
end
local function First(read) return read and read.values and read.values[1] end
local function Positive(value) return type(value) == "number" and value > 0 and value == math.floor(value) end
local function Text(key, ...) return Core.Locale:Get(addonName, key, ...) end
local function Show(value) return value == nil and "nil" or tostring(value) end
local function Print(message)
    local line = "|cff20e070[Yibo]|r " .. message
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage(line) else print(line) end
end

function Probe:GetBounds()
    local active = _G.NUM_PET_ACTIVE_SLOTS
    local perPage, pages = _G.NUM_PET_STABLE_SLOTS, _G.NUM_PET_STABLE_PAGES
    local native = Positive(active) and Positive(perPage) and Positive(pages)
        and active <= 20 and perPage * pages <= 1000
    return { active = native and active or 5, stable = native and perPage * pages or 200,
        source = native and "native-ui-constants" or "provisional-mists", verified = false }
end

function Probe:GetMappings()
    local mappings = self.db.colorMappings
    mappings[self.buildKey] = mappings[self.buildKey] or {}
    return mappings[self.buildKey]
end

function Probe:GetRecord()
    local id = Core.Characters:GetCurrentID()
    if type(id) ~= "string" or id == "" then return nil end
    self.db.characters[id] = self.db.characters[id] or { samples = {} }
    return self.db.characters[id], id
end

function Probe:ReadSlot(index, bounds)
    local info = Read(_G.GetStablePetInfo, index)
    local raw = info.values or {}
    local occupied = info.status == "ok" and (raw[1] ~= nil or raw[2] ~= nil)
    local display = occupied and Read(_G.C_PlayerInfo and C_PlayerInfo.GetPetStableCreatureDisplayInfoID, index)
        or { status = "not-read-empty-or-unavailable" }
    local displayID = First(display)
    local slot = { index = index, location = index <= bounds.active and "active" or "stable",
        info = info, display = display, occupied = occupied,
        name = raw[2], icon = raw[1], level = raw[3], family = raw[4], specialization = raw[5],
        displayID = Positive(displayID) and displayID or nil }
    local mapping = slot.displayID and self:GetMappings()[slot.displayID]
    if mapping and not mapping.conflicted then
        slot.color = mapping.color
        slot.matchKind = "visually-annotated-appearance"
        slot.originStatus = "unverified"
    end
    return slot
end

function Probe:ReadSelection()
    local ui, bounds = _G.PetStableFrame, self:GetBounds()
    if not self.stableOpen or not ui or type(ui.IsShown) ~= "function" or not ui:IsShown() then
        return { status = "stable-not-visible", observedAt = Now() }
    end
    local index = ui.selectedPet
    if not Positive(index) or index > bounds.active + bounds.stable then
        return { status = "no-valid-selection", observedAt = Now() }
    end
    return { status = "selected", observedAt = Now(), source = "PetStableFrame.selectedPet",
        slot = self:ReadSlot(index, bounds) }
end

function Probe:Selected()
    local selection = self:ReadSelection()
    local record = self:GetRecord()
    if record then record.lastSelection = selection end
    if selection.status ~= "selected" then Print(Text("SELECT_PET")); return selection end
    Print(Text("SELECTED", Show(selection.slot.name), Show(selection.slot.displayID)))
    self:PrintSlot(selection.slot)
    return selection
end

function Probe:Scan(reason, label, quiet)
    if not self.ready then return end
    local record, characterID = self:GetRecord()
    if not record then return end
    self.serial = self.serial + 1
    local bounds = self:GetBounds()
    local stableAPI = _G.C_StableInfo or {}
    local snapshot = { serial = self.serial, observedAt = Now(), reason = reason, label = label,
        characterID = characterID, client = self.client, stableOpen = self.stableOpen,
        bounds = bounds, completeness = "unverified", slots = {},
        capabilities = { stableInfo = type(_G.GetStablePetInfo) == "function",
            stableDisplay = type(_G.C_PlayerInfo and C_PlayerInfo.GetPetStableCreatureDisplayInfoID) == "function",
            activeCount = type(stableAPI.GetNumActivePets) == "function",
            stableCount = type(stableAPI.GetNumStablePets) == "function" },
        apiCounts = { active = Read(stableAPI.GetNumActivePets), stable = Read(stableAPI.GetNumStablePets),
            purchasedSlots = Read(_G.GetNumStableSlots) },
        summoned = { guid = Read(_G.UnitGUID, "pet"), name = Read(_G.UnitName, "pet"),
            family = Read(_G.UnitCreatureFamily, "pet"), exists = Read(_G.UnitExists, "pet") },
        selected = self:ReadSelection(),
        counts = { active = 0, stable = 0, missingDisplay = 0, errors = 0 }, colors = {} }
    for _, color in ipairs(COLORS) do snapshot.colors[color] = { active = 0, stable = 0 } end
    for index = 1, bounds.active + bounds.stable do
        local slot = self:ReadSlot(index, bounds)
        snapshot.slots[index] = slot
        if slot.info.status ~= "ok" then snapshot.counts.errors = snapshot.counts.errors + 1 end
        if slot.occupied then
            snapshot.counts[slot.location] = snapshot.counts[slot.location] + 1
            if not slot.displayID then snapshot.counts.missingDisplay = snapshot.counts.missingDisplay + 1 end
            if slot.display.status == "error" or slot.display.status == "missing-api" then
                snapshot.counts.errors = snapshot.counts.errors + 1
            end
            if slot.color then
                snapshot.colors[slot.color][slot.location] = snapshot.colors[slot.color][slot.location] + 1
            end
        end
    end
    record.latest = snapshot
    if self.stableOpen then record.lastOpenStable = snapshot end
    record.samples[#record.samples + 1] = snapshot
    if #record.samples > self.MAX_SAMPLES then table.remove(record.samples, 1) end
    if not quiet then self:PrintSummary(snapshot) end
    return snapshot
end

function Probe:PrintSummary(snapshot)
    local c = snapshot.counts
    Print(Text("SCAN", snapshot.serial, c.active, c.stable, c.missingDisplay, c.errors, Show(snapshot.stableOpen)))
end

function Probe:PrintSlot(slot)
    Print(Text("SLOT", slot.index, Text(slot.location == "active" and "ACTIVE" or "STABLED"),
        slot.occupied and Show(slot.name) or Text("EMPTY"), Show(slot.level), Show(slot.family), Show(slot.displayID),
        slot.color and Text(COLOR_KEYS[slot.color]) or Text("UNKNOWN"), slot.info.status, slot.display.status))
end

function Probe:Report()
    local record = self:GetRecord()
    local snapshot = record and record.latest
    if not snapshot then Print(Text("NO_SCAN")); return end
    self:PrintSummary(snapshot)
    Print(Text("REPORT", Show(snapshot.client.version), Show(snapshot.client.build), Show(snapshot.client.interface),
        snapshot.bounds.active + snapshot.bounds.stable,
        Text(snapshot.bounds.source == "native-ui-constants" and "BOUNDS_NATIVE" or "BOUNDS_FALLBACK"),
        Show(First(snapshot.apiCounts.active)), Show(First(snapshot.apiCounts.stable))))
    Print(Text("REPORT_CONTEXT", Show(snapshot.reason), Show(snapshot.label), Show(snapshot.observedAt),
        Show(snapshot.stableOpen), Show(record.lastOpenStable and record.lastOpenStable.serial)))
    self:Selected()
    for _, slot in ipairs(snapshot.slots) do if slot.occupied then self:PrintSlot(slot) end end
    local mappings = self:GetMappings()
    for _, color in ipairs(COLORS) do
        local ids = {}
        for displayID, entry in pairs(mappings) do
            if entry.color == color and not entry.conflicted then ids[#ids + 1] = displayID end
        end
        table.sort(ids)
        local values = snapshot.colors[color]
        Print(Text("COLOR_STATE", Text(COLOR_KEYS[color]), values.active + values.stable, values.active, values.stable,
            #ids > 0 and table.concat(ids, ",") or Text("UNKNOWN")))
    end
    Print(Text("EVIDENCE"))
    Print(Text("PERSIST"))
end

function Probe:Annotate(index, color)
    if not self.stableOpen or not COLOR_KEYS[color] then Print(Text("COLOR_USAGE")); return false end
    local selection
    if index == nil then
        selection = self:ReadSelection()
        if selection.status ~= "selected" then Print(Text("SELECT_PET")); return false end
        index = selection.slot.index
    end
    local bounds = self:GetBounds()
    if not Positive(index) or index > bounds.active + bounds.stable then Print(Text("SLOT_USAGE")); return false end
    local slot = self:ReadSlot(index, bounds)
    if not slot.occupied or not slot.displayID then Print(Text("NO_DISPLAY")); return false end
    local record = self:GetRecord()
    if record then
        record.colorObservations = record.colorObservations or {}
        record.colorObservations[#record.colorObservations + 1] = { observedAt = Now(), color = color,
            slot = slot, selectionSource = selection and selection.source or "explicit-slot" }
        if #record.colorObservations > self.MAX_SAMPLES then table.remove(record.colorObservations, 1) end
    end
    local mappings = self:GetMappings()
    if mappings[slot.displayID] and (mappings[slot.displayID].color ~= color or mappings[slot.displayID].conflicted) then
        mappings[slot.displayID].conflicted = true
        self:Scan("color-conflict", color, true)
        Print(Text("COLOR_CONFLICT")); return false
    end
    for displayID, entry in pairs(mappings) do
        if entry.color == color and displayID ~= slot.displayID then Print(Text("COLOR_CONFLICT")); return false end
    end
    mappings[slot.displayID] = mappings[slot.displayID] or { color = color, displayID = slot.displayID,
        evidence = "user-visual-annotation", annotatedAt = Now(), slot = index,
        characterID = Core.Characters:GetCurrentID(), client = self.client, originStatus = "unverified" }
    Print(Text("COLOR_SAVED", index, slot.displayID, Text(COLOR_KEYS[color])))
    self:Scan("color-annotation", color, true)
    return true
end

function Probe:Command(message)
    if not self.ready then return end
    local command, argument = tostring(message or ""):match("^%s*(%S*)%s*(.-)%s*$")
    command = command:lower()
    if command == "scan" then self:Scan("manual", argument:sub(1, 80))
    elseif command == "report" then self:Report()
    elseif command == "selected" then self:Selected()
    elseif command == "slot" then
        local index, bounds = tonumber(argument), self:GetBounds()
        if not Positive(index) or index > bounds.active + bounds.stable then Print(Text("SLOT_USAGE")); return end
        self:PrintSlot(self:ReadSlot(index, bounds))
    elseif command == "color" then
        local index, color = argument:match("^(%d+)%s+(%a+)$")
        if not index then color = argument:match("^(%a+)$") end
        self:Annotate(tonumber(index), color and color:lower())
    elseif command == "status" then
        local record, count = self:GetRecord(), 0
        for _, mapping in pairs(self:GetMappings()) do if not mapping.conflicted then count = count + 1 end end
        Print(Text("STATUS", self.VERSION, record and #record.samples or 0, self.MAX_SAMPLES, count))
    else Print(Text("HELP")) end
end

function Probe:Initialize()
    if self.ready then return true end
    Core = _G.YiboCore
    local locale = GetLocale and GetLocale() or "enUS"
    local language = (locale == "zhCN" or locale == "zhTW") and "zh" or "en"
    if not (Core and Core.CheckAPIVersion and Core:CheckAPIVersion(13) and Core.HasCapability
        and Core:HasCapability("localization", 1) and Core:HasCapability("character-identity", 1)
        and Core.Locale and Core.Locale.Register and Core.Locale.Get and Core.Characters and Core.Characters.GetCurrentID) then
        Print(ns.resources[language].CORE_REQUIRED)
        return false
    end
    if not (Core.IsInitialized and Core:IsInitialized()) then return false end
    Core.Locale:Register(addonName, "zh", ns.resources.zh)
    Core.Locale:Register(addonName, "en", ns.resources.en)
    local _, class = UnitClass("player")
    if not _G.WOW_PROJECT_MISTS_CLASSIC or WOW_PROJECT_ID ~= WOW_PROJECT_MISTS_CLASSIC or class ~= "HUNTER" then
        Print(Text("MISTS_REQUIRED")); return false
    end
    local db = _G.YiboBeastPathsPetProbeDB
    if type(db) ~= "table" then db = {}; _G.YiboBeastPathsPetProbeDB = db end
    -- This is a new, probe-owned schema. Preserve unexpected saved schemas for inspection.
    if db.schemaVersion and db.schemaVersion ~= 1 then Print(Text("SCHEMA_REQUIRED")); return false end
    db.schemaVersion = 1
    db.characters = db.characters or {}
    db.colorMappings = db.colorMappings or {}
    local version, build, buildDate, interface = GetBuildInfo()
    self.client = { version = version, build = build, buildDate = buildDate, interface = interface,
        projectID = WOW_PROJECT_ID, locale = locale }
    self.buildKey = table.concat({ Show(WOW_PROJECT_ID), Show(interface), Show(build) }, ":")
    self.db, self.ready = db, true
    local record = self:GetRecord()
    self.serial = record and record.latest and record.latest.serial or 0
    SLASH_YIBOBEASTPATHSPETPROBE1 = "/yhp"
    SlashCmdList.YIBOBEASTPATHSPETPROBE = function(message) self:Command(message) end
    for _, event in ipairs({ "PET_STABLE_SHOW", "PET_STABLE_UPDATE", "PET_STABLE_CLOSED", "UNIT_PET", "UNIT_NAME_UPDATE", "PET_UI_UPDATE" }) do
        frame:RegisterEvent(event)
    end
    Print(Text("READY"))
    self:Scan("login", nil, true)
    return true
end

-- One deferred read coalesces bursts; a second read after stable-open observes delayed data.
function Probe:Queue(reason, secondRead)
    self.pendingReason, self.pendingDelay = reason, 0.25
    self.secondReadDelay = secondRead and 1.25 or self.secondReadDelay
    frame:SetScript("OnUpdate", function(_, elapsed)
        if self.pendingDelay then
            self.pendingDelay = self.pendingDelay - elapsed
            if self.pendingDelay <= 0 then
                local reasonToRead = self.pendingReason
                self.pendingDelay, self.pendingReason = nil, nil
                self:Scan(reasonToRead, nil, true)
            end
        end
        if self.secondReadDelay then
            self.secondReadDelay = self.secondReadDelay - elapsed
            if self.secondReadDelay <= 0 then
                self.secondReadDelay = nil
                self:Scan("stable-open-delayed", nil, true)
            end
        end
        if not self.pendingDelay and not self.secondReadDelay then frame:SetScript("OnUpdate", nil) end
    end)
end

frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "PLAYER_LOGIN" or (event == "ADDON_LOADED" and arg1 == addonName and IsLoggedIn and IsLoggedIn()) then
        Probe:Initialize()
    elseif Probe.ready then
        if (event == "UNIT_PET" and arg1 ~= "player") or (event == "UNIT_NAME_UPDATE" and arg1 ~= "pet") then return end
        if event == "PET_STABLE_SHOW" then Probe.stableOpen = true
        elseif event == "PET_STABLE_CLOSED" then Probe.stableOpen = false; Probe.secondReadDelay = nil end
        if event ~= "ADDON_LOADED" then Probe:Queue(event, event == "PET_STABLE_SHOW") end
    end
end)
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
