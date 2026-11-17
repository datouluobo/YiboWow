-- Forever Target Dynamic Currency Discovery Spec
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
_G.GetServerTime = function() return 1000 end
_G.GetMoney = function() return 12345 end
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
local currentID = "player-guild-guid-1"
local registeredPages = {}
local registeredOwners = {}
local mockCore = {
    CheckAPIVersion = function(self, version) return version <= 13 end,
    IsInitialized = function(self) return true end,
    HasCapability = function(self, name, version) return true end,
    RegisterAddon = function(self, name, info) return true end,
    CreateItemPicker = function(self) return {} end,
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
        GetCurrent = function() return { id = currentID, name = "TestChar", realm = "TestRealm" } end,
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
        GetColumnPage = function() return {}, {} end,
        UpdateColumnPager = function() end,
    },
    Contracts = {
        Register = function() return true end,
        NotifyChanged = function() end,
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
    ItemResolver = {
        GetInfo = function(self, id) return { name = "Item " .. tostring(id), icon = "item-icon" } end,
        Parse = function() return {} end,
        Request = function() end,
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
        CreateDropdown = function() return {} end,
        CreateInput = function()
            local inp = {}
            function inp:SetPoint() end
            function inp:SetShown() end
            function inp:GetText() return "" end
            return inp
        end,
    }
}
_G.YiboCore = mockCore

-- Mock Currency Native APIs
local mockCurrencyList = {}
local mockCurrencyDetails = {}
_G.C_CurrencyInfo = {
    GetCurrencyListSize = function() return #mockCurrencyList end,
    GetCurrencyListInfo = function(index)
        local row = mockCurrencyList[index]
        if not row then return nil end
        return { name = row.name, isHeader = row.isHeader or false, iconFileID = row.icon or 1234, currencyID = row.id }
    end,
    GetCurrencyListLink = function(index)
        local row = mockCurrencyList[index]
        return row and ("|Hcurrency:" .. row.id .. ":0|h") or nil
    end,
    GetCurrencyInfo = function(id)
        local det = mockCurrencyDetails[id]
        if not det then return nil end
        return { name = det.name, quantity = det.quantity, iconFileID = det.icon or 1234, currencyID = id }
    end
}

-- Load target files
_G.YiboCurrencyForeverDB = nil
dofile("YiboCurrency/Forever/Namespace.lua")
dofile("YiboCurrency/Locales/zhCN.lua")
dofile("YiboCurrency/Locales/enUS.lua")
dofile("YiboCurrency/Common/NativeAPI.lua")
dofile("YiboCurrency/Common/NativeDiscovery.lua")
dofile("YiboCurrency/Common/NativeStore.lua")
dofile("YiboCurrency/Common/Catalog.lua")
dofile("YiboCurrency/Forever/Catalog.lua")
dofile("YiboCurrency/Forever/Store.lua")
dofile("YiboCurrency/Forever/Scanner.lua")
dofile("YiboCurrency/Forever/CustomItems.lua")
dofile("YiboCurrency/ArchiveProvider.lua")
dofile("YiboCurrency/Forever/AccountPage.lua")
dofile("YiboCurrency/Forever/Bootstrap.lua")

local Addon = _G.YiboCurrency

-- Test 1: Initialize
assertTrue(Addon:Initialize(), "Bootstrap:Initialize should succeed")
assertTrue(Addon.initialized, "Addon should be marked initialized")
assertTrue(Addon.Store.nativeStore ~= nil, "nativeStore should be initialized")
assertEqual(Addon.Store.db.schema, 1, "schema should be 1")

-- Test 2: Scan in empty list (Forever 0-line baseline)
Addon.Scanner.inWorld = true
mockCurrencyList = {}
mockCurrencyDetails = {}
local scanned = Addon.Scanner:Scan(true)
assertTrue(scanned, "Scan should succeed on empty currency list")
assertEqual(Addon.Store.db.characters[currentID].moneyCopper, 12345, "money should be saved")
local dir = Addon.Store:GetNativeDirectory()
assertEqual(next(dir), nil, "Directory should initially be empty")

-- Test 3: Discovered new currencies (e.g. ID 100 with qty 50, ID 200 with qty 0)
mockCurrencyList = {
    { id = 100, name = "Honor Points", isHeader = false, icon = 1001 },
    { id = 200, name = "Conquest Points", isHeader = false, icon = 1002 },
}
mockCurrencyDetails[100] = { name = "Honor Points", quantity = 50, icon = 1001 }
mockCurrencyDetails[200] = { name = "Conquest Points", quantity = 0, icon = 1002 }

_G.GetServerTime = function() return 1050 end
assertTrue(Addon.Scanner:Scan(true), "Scan should collect currencies")

dir = Addon.Store:GetNativeDirectory()
assertTrue(dir[100] ~= nil, "Currency 100 should be in directory")
assertTrue(dir[200] ~= nil, "Currency 200 should be in directory")
assertEqual(dir[100].name, "Honor Points", "Directory should store currency name")
assertEqual(dir[200].name, "Conquest Points", "Directory should store currency name")

-- Verify Values
local val100, state100 = Addon.Store:GetNativeCurrency(currentID, 100)
assertEqual(val100, 50, "Currency 100 value should be 50")
assertEqual(state100, "known", "Currency 100 state should be known")

local val200, state200 = Addon.Store:GetNativeCurrency(currentID, 200)
assertEqual(val200, 0, "Currency 200 value should be 0 (confirmed zero)")
assertEqual(state200, "known", "Currency 200 state should be known")

-- Test 4: Fields & Discovered Catalog
local fields = Addon.AccountPage:Fields()
local found100, found200, foundMoney = false, false, false
for _, f in ipairs(fields) do
    if f.id == "money" then foundMoney = true end
    if f.id == "currency:100" then found100 = true end
    if f.id == "currency:200" then found200 = true end
end
assertTrue(foundMoney, "Fields should include money")
assertTrue(found100, "Fields should include currency:100")
assertTrue(found200, "Fields should include currency:200")

-- Test 5: Switch character (char-2) with empty list -> active query for known ID
currentID = "player-guild-guid-2"
mockCurrencyList = {} -- char-2 list is collapsed / empty
mockCurrencyDetails[100] = { name = "Honor Points", quantity = 15, icon = 1001 }
-- 200 detail unavailable for char-2
mockCurrencyDetails[200] = nil

_G.GetServerTime = function() return 1100 end
assertTrue(Addon.Scanner:Scan(true), "Scan for char-2 should succeed")

-- Char-2 should query known ID 100 from directory
local char2Val100, char2State100 = Addon.Store:GetNativeCurrency(currentID, 100)
assertEqual(char2Val100, 15, "Char-2 should have 15 honor points from active query")
assertEqual(char2State100, "known", "Char-2 state should be known")

local char2Val200, char2State200 = Addon.Store:GetNativeCurrency(currentID, 200)
assertEqual(char2Val200, nil, "Char-2 should have nil for unavailable detail")
assertEqual(char2State200, "unknown", "Char-2 state should be unknown")

-- Verify char-1 is unaffected
local char1Val100 = Addon.Store:GetNativeCurrency("player-guild-guid-1", 100)
assertEqual(char1Val100, 50, "Char-1 should still have 50 honor points")

-- Test 6: Preview column setting
local regPage = registeredPages[Addon.PAGE_ID]
assertTrue(regPage ~= nil, "AccountPage should be registered")
assertTrue(regPage.SetPreviewFieldVisible("currency:100", true), "Should allow preview for currency:100")
assertEqual(Addon.Store.db.settings.previewColumns["currency:100"], true, "Preview columns should record currency:100")

-- Test 7: Delete character cleans snapshot but retains directory
local cleanupOwner = registeredOwners[Addon.NAME]
assertTrue(cleanupOwner ~= nil, "Cleanup owner should be registered")
local inspect = cleanupOwner.Inspect({ id = "player-guild-guid-1" })
assertTrue(inspect.hasData, "Char-1 should have data")

cleanupOwner.Delete({ id = "player-guild-guid-1" })
local afterDeleteDir = Addon.Store:GetNativeDirectory()
assertTrue(afterDeleteDir[100] ~= nil, "Directory must retain ID 100 after character deletion")
assertTrue(afterDeleteDir[200] ~= nil, "Directory must retain ID 200 after character deletion")
local char1AfterVal = Addon.Store:GetNativeCurrency("player-guild-guid-1", 100)
assertEqual(char1AfterVal, nil, "Char-1 snapshot should be deleted")

print("ForeverDiscoverySpec passed successfully.")
