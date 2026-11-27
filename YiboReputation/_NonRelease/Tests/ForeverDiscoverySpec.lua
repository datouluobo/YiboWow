-- Forever Target Dynamic Reputation Discovery Spec
local function assertEqual(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", message or "assertion failed", tostring(expected), tostring(actual)))
    end
end

local function assertTrue(condition, message)
    if not condition then error(message or "assertion failed: expected true") end
end

-- Setup WoW Globals & Project Environment
_G.WOW_PROJECT_CAMELOT = 18
_G.WOW_PROJECT_ID = _G.WOW_PROJECT_CAMELOT
_G.GetServerTime = function() return 2000 end
_G.IsLoggedIn = function() return true end
_G.SlashCmdList = {}

_G.CreateFrame = function(frameType, name, parent, template)
    local frame = { scripts = {}, events = {} }
    function frame:SetScript(name, handler) self.scripts[name] = handler end
    function frame:GetScript(name) return self.scripts[name] end
    function frame:RegisterEvent(event) self.events[event] = true; return true end
    function frame:UnregisterEvent(event) self.events[event] = nil end
    function frame:SetPoint() end
    function frame:SetSize() end
    function frame:SetHeight() end
    function frame:SetWidth() end
    function frame:Show() end
    function frame:Hide() end
    function frame:SetBackdrop() end
    function frame:SetBackdropColor() end
    function frame:EnableMouse() end
    return frame
end

-- Mock Core
local currentID = "player-reputation-guid-1"
local registeredPages = {}
local registeredOwners = {}
local mockCore = {
    CheckAPIVersion = function(self, version) return version <= 14 end,
    IsInitialized = function(self) return true end,
    HasCapability = function(self, name, version) return true end,
    RegisterAddon = function(self, name, info) return true end,
    Text = function(self, key) return key end,
    Defaults = {
        Copy = function(self, t)
            if type(t) ~= "table" then return t end
            local copy = {}
            for k, v in pairs(t) do copy[k] = self:Copy(v) end
            return copy
        end
    },
    Locale = { Get = function(self, key) return key end },
    Characters = {
        GetCurrentID = function() return currentID end,
        GetCurrent = function() return { id = currentID, name = "RepChar", realm = "RepRealm" } end,
        FormatName = function(self, char) return char.name or "Unknown" end,
        Get = function(self, id) return { id = id, name = "Char-" .. id } end,
    },
    AccountView = {
        RegisterPage = function(self, name, def)
            registeredPages[def.id] = def
            return true
        end,
        NotifyPageChanged = function() end,
        Toggle = function() end,
        GetScrollSurfaceWidth = function() end,
        FitRepeatedColumnWidth = function() end,
        GetColumnPage = function() return {}, {} end,
        UpdateColumnPager = function() end,
    },
    Entry = {
        RegisterBusinessEntry = function() return true end,
    },
    CharacterCleanup = {
        RegisterOwner = function(self, name, owner)
            registeredOwners[name] = owner
            return true
        end
    },
    UITheme = {
        Font = { section = "font-section", assist = "font-assist", body = "font-body" },
        Colors = { text = {1,1,1}, muted = {0.5,0.5,0.5}, row = {0.1,0.1,0.1}, alternate = {0.2,0.2,0.2}, accent = {0,1,0}, warning = {1,0,0} },
        CreateText = function()
            local t = {}
            function t:SetPoint() end
            function t:SetHeight() end
            function t:SetWidth() end
            function t:SetText() end
            function t:SetTextColor() end
            function t:SetShown() end
            function t:SetJustifyH() end
            function t:SetWordWrap() end
            function t:GetText() return "" end
            return t
        end,
        CreateButton = function()
            local b = {}
            function b:SetPoint() end
            function b:SetScript() end
            function b:SetState() end
            function b:SetShown() end
            return b
        end,
        CreateScrollFrame = function()
            local s = {}
            function s:SetPoint() end
            function s:SetScrollChild() end
            function s:SetWidth() end
            function s:GetWidth() return 500 end
            function s:SetContentHeight() end
            function s:SetShown() end
            function s:HookScript() end
            return s
        end,
        CreateDropdown = function()
            local d = {}
            function d:SetPoint() end
            function d:SetOptions() end
            function d:SetValue() end
            function d:SetOnValueChanged() end
            return d
        end,
        CreateInput = function()
            local inp = {}
            function inp:SetPoint() end
            function inp:SetShown() end
            function inp:GetText() return "" end
            return inp
        end,
        CreatePixelBorder = function() end,
        GetMatrixInsets = function() end,
        GetCharacterMatrixColumnWidth = function() end,
        CreateMatrixHeader = function() end,
        ApplyPixelBackdrop = function(_, f) return f end,
        GetPixelSize = function(_, _, n) return n or 1 end,
        SetPixelAnchor = function(_, _, fn) if fn then fn() end end,
    }
}
_G.YiboCore = mockCore

-- Mock Reputation Native APIs
local mockFactionsList = {}
local mockFactionsByID = {}
_G.C_Reputation = {
    GetNumFactions = function() return #mockFactionsList end,
    GetFactionDataByIndex = function(index) return mockFactionsList[index] end,
    GetFactionDataByID = function(id) return mockFactionsByID[id] end,
}

-- Load files
_G.YiboReputationForeverDB = nil
dofile("YiboReputation/Forever/Namespace.lua")
dofile("YiboReputation/Locales/Interface.lua")
dofile("YiboReputation/Forever/Store.lua")
dofile("YiboReputation/Forever/Scanner.lua")
dofile("YiboReputation/Forever/Format.lua")
dofile("YiboReputation/Common/Display.lua")
dofile("YiboReputation/Forever/MatrixData.lua")
dofile("YiboReputation/Common/AccountMatrixView.lua")
dofile("YiboReputation/Common/Page.lua")
dofile("YiboReputation/Forever/Bootstrap.lua")

local Addon = _G.YiboReputation

-- Test 0: an API13 Core (pixel-line migration) is refused before any write.
mockCore.CheckAPIVersion = function(self, version) return version <= 13 end
local savedPrint = Addon.Print; Addon.Print = function() end
assertTrue(not Addon:Initialize() and not Addon.initialized and Addon.Store.db == nil, "API13 Core should be refused")
Addon.Print = savedPrint
mockCore.CheckAPIVersion = function(self, version) return version <= 14 end

-- Test 1: Initialize
assertTrue(Addon:Initialize(), "Bootstrap:Initialize should succeed")
assertTrue(Addon.initialized, "Addon should be initialized")
assertEqual(Addon.Store.db.schema, 1, "schema should be 1")
assertEqual(type(Addon.Store.db.factionDirectory), "table", "factionDirectory should be table")

-- Test 2: Baseline Scan with 0 factions (empty list)
Addon.Scanner.inWorld = true
mockFactionsList = {}
mockFactionsByID = {}
local scanned = Addon.Scanner:Scan()
assertTrue(scanned, "Scan should succeed on empty reputation list")
assertEqual(Addon.Store.freshID, currentID, "freshID should match current character")
assertEqual(Addon.Store.error, nil, "Error state should be nil on empty list")
local dir = Addon.Store:GetFactionDirectory()
assertEqual(next(dir), nil, "Directory should initially be empty")

-- Test 3: Discovering new factions (Stormwind with 1200, Ironforge with 0 at Revered)
mockFactionsList = {
    { factionID = 101, name = "Stormwind", reaction = 5, currentReactionThreshold = 0,
      nextReactionThreshold = 3000, currentStanding = 1200, isHeader = false, isHeaderWithRep = false, isAccountWide = false },
    { factionID = 102, name = "Ironforge", reaction = 7, currentReactionThreshold = 0,
      nextReactionThreshold = 21000, currentStanding = 0, isHeader = false, isHeaderWithRep = false, isAccountWide = false },
}
mockFactionsByID[101] = mockFactionsList[1]
mockFactionsByID[102] = mockFactionsList[2]

_G.GetServerTime = function() return 2050 end
assertTrue(Addon.Scanner:Scan(), "Scan should collect factions")

dir = Addon.Store:GetFactionDirectory()
assertTrue(dir[101] ~= nil, "Faction 101 should be discovered")
assertTrue(dir[102] ~= nil, "Faction 102 should be discovered")
assertEqual(dir[101].name, "Stormwind", "Directory should store faction name")
assertEqual(dir[102].name, "Ironforge", "Directory should store faction name")

local char1Snapshot = Addon.Store.db.characters[currentID]
assertTrue(char1Snapshot ~= nil, "Character snapshot should exist")
assertEqual(char1Snapshot.factions[101].value, 1200, "Stormwind standing should be 1200")
assertEqual(char1Snapshot.factions[102].value, 0, "Ironforge standing should be 0 (confirmed zero)")

-- Test 4: Second character login with Darnassus in list, actively query known 101 and 102
currentID = "player-reputation-guid-2"
mockFactionsList = {
    { factionID = 103, name = "Darnassus", reaction = 4, currentReactionThreshold = 0,
      nextReactionThreshold = 3000, currentStanding = 500, isHeader = false, isHeaderWithRep = false, isAccountWide = false },
}
mockFactionsByID[103] = mockFactionsList[1]
-- Active query detail for 101 succeeds for char-2
mockFactionsByID[101] = { factionID = 101, name = "Stormwind", reaction = 4, currentReactionThreshold = 0,
      nextReactionThreshold = 3000, currentStanding = 100, isHeader = false, isHeaderWithRep = false, isAccountWide = false }
-- Active query detail for 102 unavailable for char-2
mockFactionsByID[102] = nil

_G.GetServerTime = function() return 2100 end
assertTrue(Addon.Scanner:Scan(), "Scan for char-2 should succeed and actively query directory IDs")

dir = Addon.Store:GetFactionDirectory()
assertTrue(dir[101] ~= nil and dir[102] ~= nil and dir[103] ~= nil, "Directory should be union of all characters: 101, 102, 103")

local char2Snapshot = Addon.Store.db.characters[currentID]
assertEqual(char2Snapshot.factions[103].value, 500, "Char-2 has Darnassus 500")
assertEqual(char2Snapshot.factions[101].value, 100, "Char-2 actively retrieved Stormwind 100")
assertEqual(char2Snapshot.factions[102], nil, "Char-2 unavailable faction 102 is nil")

-- Test 5: Watch faction and check monitored preview
assertTrue(Addon.Store:ToggleWatched(101), "Toggle watch should succeed")
assertEqual(Addon.Store.db.settings.watchedFactionIDs[1], 101, "Watched factions should contain 101")

-- Test 6: Delete character cleans snapshot but retains directory
local cleanupOwner = registeredOwners[Addon.NAME]
assertTrue(cleanupOwner ~= nil, "Cleanup owner should be registered")
local inspect = cleanupOwner.Inspect({ id = "player-reputation-guid-1" })
assertTrue(inspect.hasData, "Char-1 should have data")

cleanupOwner.Delete({ id = "player-reputation-guid-1" })
local afterDeleteDir = Addon.Store:GetFactionDirectory()
assertTrue(afterDeleteDir[101] ~= nil, "Directory must retain ID 101 after char-1 deletion")
assertTrue(afterDeleteDir[102] ~= nil, "Directory must retain ID 102 after char-1 deletion")
assertTrue(afterDeleteDir[103] ~= nil, "Directory must retain ID 103 after char-1 deletion")
assertEqual(Addon.Store.db.characters["player-reputation-guid-1"], nil, "Char-1 snapshot should be deleted")

print("ForeverReputationDiscoverySpec passed successfully.")
