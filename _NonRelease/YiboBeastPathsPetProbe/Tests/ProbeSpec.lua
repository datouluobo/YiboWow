-- Run from the workspace root with Lua 5.1. All IDs below are synthetic test fixtures.
local root = "_NonRelease/YiboBeastPathsPetProbe/"
local checks = 0
local function Check(value, message)
    checks = checks + 1
    assert(value, message)
end
local function Equal(actual, expected, message) Check(actual == expected, message .. ": " .. tostring(actual)) end

local function Environment(options)
    options = options or {}
    local frames, output, slots, ns = {}, {}, {}, {}
    local characterID = "Player-Test-A"
    local displayAPI = true
    _G.YiboBeastPathsPetProbeDB = options.db
    _G.YiboBeastPathsPetProbe = nil
    _G.SLASH_YIBOBEASTPATHSPETPROBE1 = nil
    _G.SlashCmdList = {}
    _G.WOW_PROJECT_MISTS_CLASSIC, _G.WOW_PROJECT_ID = 19, options.project or 19
    _G.NUM_PET_ACTIVE_SLOTS, _G.NUM_PET_STABLE_SLOTS, _G.NUM_PET_STABLE_PAGES = nil, nil, nil
    _G.PetStableFrame = { selectedPet = nil, IsShown = function() return true end }
    _G.GetLocale = function() return options.locale or "enUS" end
    _G.GetBuildInfo = function() return "5.5.4", options.build or "test-build", "test-date", 50504 end
    _G.UnitClass = function() return "Hunter", options.class or "HUNTER" end
    _G.UnitGUID = function(unit) return unit == "player" and characterID or "Pet-Test-GUID" end
    _G.UnitName = function(unit) return unit == "player" and "TestHunter" or "RenamedPet" end
    _G.UnitCreatureFamily = function() return "Quilen" end
    _G.UnitExists = function() return true end
    _G.IsLoggedIn = function() return false end
    _G.time = function() return 1234567890 end
    _G.DEFAULT_CHAT_FRAME = { AddMessage = function(_, value) output[#output + 1] = value end }
    _G.CreateFrame = function()
        local f = { events = {}, scripts = {} }
        function f:RegisterEvent(event) self.events[event] = true end
        function f:SetScript(name, fn) self.scripts[name] = fn end
        frames[#frames + 1] = f
        return f
    end
    _G.GetStablePetInfo = function(index)
        local slot = slots[index]
        if not slot then return nil end
        if slot.error then error("test-info-error") end
        return slot.icon or 100, slot.name or "RenamedPet", slot.level or 90, "Quilen", "Ferocity", nil, 777
    end
    _G.C_PlayerInfo = { GetPetStableCreatureDisplayInfoID = function(index)
        local slot = slots[index]
        if not displayAPI then error("test-display-error") end
        return slot and slot.display or 0
    end }
    _G.C_StableInfo = { GetNumActivePets = function() return 5 end, GetNumStablePets = function() return 200 end }
    _G.GetNumStableSlots = nil
    _G.YiboCore = {
        CheckAPIVersion = function() return not options.oldCore end,
        HasCapability = function(_, name) return not (options.noIdentity and name == "character-identity") end,
        IsInitialized = function() return true end,
        Capabilities = { Register = function() end },
        Characters = { GetCurrentID = function() return characterID end },
    }
    assert(loadfile("YiboCore/Runtime/Locale.lua"))()
    YiboCore.Locale.language = options.language or "en"
    for line in io.lines(root .. "YiboBeastPathsPetProbe.toc") do
        line = line:gsub("\r", "")
        if line:match("%.lua$") and not line:match("^#") then
            assert(loadfile(root .. line:gsub("\\", "/")))("YiboBeastPathsPetProbe", ns)
        end
    end
    local f = frames[1]
    local env = { probe = YiboBeastPathsPetProbe, slots = slots, output = output, frame = f, frames = frames, resources = ns.resources }
    function env:event(event, arg) f.scripts.OnEvent(f, event, arg) end
    function env:tick(elapsed) if f.scripts.OnUpdate then f.scripts.OnUpdate(f, elapsed) end end
    function env:character(id) characterID = id end
    function env:displayError(value) displayAPI = not value end
    return env
end

local e = Environment()
e.slots[1] = { display = 900001 }
e.slots[6] = { display = 900002 }
e.slots[205] = { display = 900003 }
e:event("PLAYER_LOGIN")
local p = e.probe
Check(p.ready, "hunter initializes")
Equal(SLASH_YIBOBEASTPATHSPETPROBE1, "/yhp", "single three-letter command")
local s = p:Scan("manual", "before-stable", true)
Equal(s.counts.active, 1, "active slots scanned")
Equal(s.counts.stable, 2, "last stable slot included")
Equal(s.completeness, "unverified", "outside-stable read does not prove completeness")
Equal(s.bounds.source, "provisional-mists", "fallback bounds identified")
Equal(s.slots[1].info.values.n, 7, "nil holes and raw return arity retained")
Equal(s.slots[1].info.values[7], 777, "extra raw returns retained")
Equal(s.slots[2].occupied, false, "empty slot not occupied")
Equal(s.apiCounts.purchasedSlots.status, "missing-api", "missing optional API captured")
Check(not p:Annotate(1, "jade"), "annotation requires open stable")
e:event("PET_STABLE_SHOW")
e:tick(0.3)
Equal(p:GetRecord().latest.reason, "PET_STABLE_SHOW", "deferred open read")
e:tick(1)
Equal(p:GetRecord().latest.reason, "stable-open-delayed", "second delayed read")
Check(not e.frame.scripts.OnUpdate, "timer stops when idle")
_G.NUM_PET_ACTIVE_SLOTS, _G.NUM_PET_STABLE_SLOTS, _G.NUM_PET_STABLE_PAGES = 5, 10, 20
s = p:Scan("manual", "stable-open", true)
Equal(s.bounds.source, "native-ui-constants", "UI constants detected")
Check(p:Annotate(1, "jade"), "visual jade mapping recorded")
Check(p:Annotate(6, "amethyst"), "visual amethyst mapping recorded")
Check(p:Annotate(205, "cobalt"), "visual cobalt mapping recorded")
e.slots[20] = { display = 900004 }
Check(p:Annotate(20, "jasper"), "visual jasper mapping recorded")
s = p:GetRecord().latest
for _, color in ipairs({ "jade", "amethyst", "cobalt", "jasper" }) do
    Equal(s.colors[color].active + s.colors[color].stable, 1, color .. " independently matched")
end
Equal(s.slots[1].originStatus, "unverified", "display match cannot prove rare origin")
e.slots[4] = { display = 900005 }
Check(not p:Annotate(4, "jade"), "multiple displays per color require review")
e.slots[4] = nil
Check(not p:Annotate(2, "jade"), "empty slot not annotated")
Check(not p:Annotate(1.5, "jade"), "fractional slot rejected")
e.slots[1].name = "CompletelyRenamed"
s = p:Scan("manual", "renamed", true)
Equal(s.slots[1].color, "jade", "renaming does not affect appearance matching")
e.slots[30], e.slots[1] = e.slots[1], nil
s = p:Scan("manual", "moved", true)
Equal(s.colors.jade.active, 0, "move clears active count")
Equal(s.colors.jade.stable, 1, "move updates stable count without duplicates")
e.slots[30] = nil
s = p:Scan("manual", "no-match", true)
Equal(s.colors.jade.stable, 0, "latest scan reflects current slots")
Equal(s.completeness, "unverified", "zero matches not claimed absent")
local lastOpen = p:GetRecord().lastOpenStable
e:event("PET_STABLE_CLOSED")
e.slots[6], e.slots[20], e.slots[205] = nil, nil, nil
e:tick(0.3)
Check(not p:GetRecord().latest.stableOpen, "close read marked outside stable")
Equal(p:GetRecord().lastOpenStable, lastOpen, "last open read remains diagnostic evidence")
local serial = p.serial
e:event("UNIT_PET", "party1")
e:tick(1)
Equal(p.serial, serial, "other players do not trigger reads")
e:event("UNIT_PET", "player")
e:event("PET_UI_UPDATE")
e:tick(0.3)
Equal(p.serial, serial + 1, "event burst coalesced")
e.slots[6] = { display = 0 }
s = p:Scan("manual", "zero-display", true)
Equal(s.counts.missingDisplay, 1, "zero display marked unknown")
e:displayError(true)
s = p:Scan("manual", "display-error", true)
Equal(s.counts.errors, 1, "display error isolated")
e:displayError(false)
e.slots[7] = { error = true }
s = p:Scan("manual", "info-error", true)
Equal(s.slots[7].info.status, "error", "info error captured")
_G.C_PlayerInfo = nil
s = p:Scan("manual", "missing-display-api", true)
Equal(s.slots[6].display.status, "missing-api", "missing display API captured")
_G.GetStablePetInfo = nil
s = p:Scan("manual", "missing-info-api", true)
Equal(s.counts.active + s.counts.stable, 0, "missing info API does not invent pets")
Equal(s.slots[1].info.status, "missing-api", "missing info API is explicit")
Equal(s.completeness, "unverified", "missing info API cannot establish absence")
for i = 1, 30 do p:Scan("manual", tostring(i), true) end
Equal(#p:GetRecord().samples, p.MAX_SAMPLES, "diagnostic samples bounded")
e:character("Player-Test-B")
s = p:Scan("manual", "other-character", true)
Equal(s.characterID, "Player-Test-B", "Core identity used")
Equal(#p:GetRecord().samples, 1, "character scans isolated")
p:Report()
p:Command("status")
p:Command("slot -1")
p:Command("color")
Check(#e.output > 10, "report commands render")
local saved = p.db
e = Environment()
e.slots[151] = { display = 900101, name = "SelectedPet" }
e.slots[152] = { display = 900101, name = "OtherPetSameAppearance" }
e:event("PLAYER_LOGIN")
e:event("PET_STABLE_SHOW")
p = e.probe
Check(not p:Annotate(nil, "cobalt"), "missing selection cannot pick arbitrary slot")
PetStableFrame.selectedPet = 151
Equal(p:Selected().slot.name, "SelectedPet", "selected native pet resolved")
p:Command("color cobalt")
Equal(p:GetMappings()[900101].color, "cobalt", "color command uses current selection")
Equal(p:GetRecord().colorObservations[1].slot.index, 151, "selected evidence records actual slot")
PetStableFrame.selectedPet = 152
Equal(p:Selected().slot.name, "OtherPetSameAppearance", "same display does not confuse native selection")
Check(not p:Annotate(nil, "jade"), "same display conflicting color rejected")
Check(p:GetMappings()[900101].conflicted, "contradictory display mapping suspended")
Equal(p:ReadSlot(151, p:GetBounds()).color, nil, "ambiguous mapping is not used")
Equal(#p:GetRecord().colorObservations, 2, "conflicting observations preserved")
PetStableFrame.selectedPet = 153
Check(not p:Annotate(nil, "jasper"), "empty selected slot cannot be annotated")
PetStableFrame.selectedPet = 999
Equal(p:ReadSelection().status, "no-valid-selection", "out of range selection rejected")
PetStableFrame.selectedPet = 151
PetStableFrame.IsShown = function() return false end
Equal(p:ReadSelection().status, "stable-not-visible", "hidden native frame invalidates selection")
PetStableFrame.IsShown = function() return true end
e:event("PET_STABLE_CLOSED")
Check(not p:Annotate(nil, "cobalt"), "closed stable selection cannot be reused")
local serial = p.serial
assert(loadfile(root .. "Probe.lua"))("YiboBeastPathsPetProbe", {})
Equal(p.serial, serial, "overlay residual path does not initialize twice")
Equal(YiboBeastPathsPetProbe, p, "overlay residual does not replace active probe")
Equal(#e.frames, 1, "TOC with overlay residual creates one event frame")
e = Environment({ db = saved, build = "next-build" })
e:event("PLAYER_LOGIN")
Equal(next(e.probe:GetMappings()), nil, "color mappings require review after build change")
e = Environment({ oldCore = true })
e:event("PLAYER_LOGIN")
Check(not e.probe.ready and not YiboBeastPathsPetProbeDB, "old Core stops before collection")
e = Environment({ noIdentity = true })
e:event("PLAYER_LOGIN")
Check(not e.probe.ready, "missing identity capability stops collection")
e = Environment({ project = 1 })
e:event("PLAYER_LOGIN")
Check(not e.probe.ready, "other client stops collection")
e = Environment({ class = "MAGE" })
e:event("PLAYER_LOGIN")
Check(not e.probe.ready, "non-hunter stops collection")
local foreignDB = { schemaVersion = 99, preserve = true }
e = Environment({ db = foreignDB })
e:event("PLAYER_LOGIN")
Check(not e.probe.ready and foreignDB.preserve, "unexpected schema preserved")

for _, language in ipairs({ "zh", "en" }) do
    e = Environment({ language = language, locale = language == "zh" and "enUS" or "zhCN" })
    e:event("PLAYER_LOGIN")
    e.probe:Command("")
    e.probe:Report()
    Check(not table.concat(e.output, "\n"):find("YiboBeastPathsPetProbe:"), "all report keys resolve")
    for key, value in pairs(e.resources.zh) do
        local en = e.resources.en[key]
        Check(type(en) == "string", "English key " .. key)
        local function Formats(text)
            local matches = {}
            for match in text:gmatch("%%[sd]") do matches[#matches + 1] = match end
            return table.concat(matches, ",")
        end
        Equal(Formats(value), Formats(en), "format parity " .. key)
    end
    Check(next(YiboCore.Locale:GetMissingEnglish("YiboBeastPathsPetProbe")) == nil, "no missing English resources")
end
print("PetProbe: " .. checks .. " checks passed (synthetic API fixtures; in-game verification pending).")
