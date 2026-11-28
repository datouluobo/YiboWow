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

local function Node(parent)
    local node = { parent = parent, scripts = {}, events = {} }
    function node:SetScript(name, handler) self.scripts[name] = handler end
    function node:GetScript(name) return self.scripts[name] end
    function node:RegisterEvent(event) self.events[event] = true; return true end
    function node:UnregisterEvent(event) self.events[event] = nil end
    function node:GetParent() return self.parent end
    function node:GetEffectiveScale() return 1 end
    function node:GetFrameLevel() return 1 end
    function node:CreateFontString() return Node(self) end
    function node:CreateTexture() return Node(self) end
    function node:SetSize(width, height) self.width, self.height = width, height end
    function node:SetWidth(width) self.width = width end
    function node:SetHeight(height) self.height = height end
    function node:GetWidth() return self.width or 500 end
    function node:GetHeight() return self.height or 400 end
    function node:SetText(value) self.text = value end
    function node:GetStringHeight() return 18 end
    function node:SetEnabled(enabled) self.enabled = enabled end
    function node:GetText() return self.text or "" end
    function node:IsShown() return self.shown == true end
    function node:Show() self.shown = true end
    function node:Hide() self.shown = false end
    function node:SetShown(shown) self.shown = shown end
    return setmetatable(node, { __index = function(_, key)
        if key:match("^Set") or key:match("^Register") or key:match("^Enable")
            or key:match("^Bind") or key:match("^Refresh") or key == "ClearAllPoints" or key == "HookScript" then
            return function() end
        end
    end })
end
_G.CreateFrame = function(_, _, parent) return Node(parent) end
_G.UIParent = Node()
_G.GameTooltip = Node()
_G.STANDARD_TEXT_FONT = "fixture"

-- Mock Core
local currentID = "player-guild-guid-1"
local registeredPages = {}
local registeredOwners = {}
local pageRegistrations = 0
local translations, fieldVisibility, owners, coreMessages = {}, {}, {}, {}
local language = "en"
local goalChanges, coreDB = 0, { settings = {} }
local supportsGoalActions = arg[1] ~= "no-goals"
local mockCore = {
    CheckAPIVersion = function(self, version) return version <= 13 end,
    IsInitialized = function(self) return true end,
    HasCapability = function(_, name) return name ~= "business-item-actions" or supportsGoalActions end,
    RegisterAddon = function(_, name)
        owners[name] = true
        return true
    end,
    Registry = { Get = function(_, name) return owners[name] end },
    Database = { GetDB = function() return coreDB end },
    Print = function(_, text) coreMessages[#coreMessages + 1] = text end,
    CreateItemPicker = function(_, parent, config)
        local picker = Node(parent)
        picker.config = config
        function picker:Layout(width)
            self.layoutContentWidth = width
            return 70
        end
        function picker:SetValue(value) self.value = value end
        return picker
    end,
    ItemConfirmation = { Show = function() end },
    Text = function(self, key) return key end,
    Events = {
        Register = function() end,
        FireIsolated = function(_, event, descriptor)
            if event == "BUSINESS_CONTRACT_CHANGED" and descriptor.name == "action.targets" then
                goalChanges = goalChanges + 1
            end
        end,
    },
    Capabilities = { Register = function() end },
    Client = {
        ReadPhysicalScreenSize = function() return nil, nil, "unavailable" end,
        ReadMouseFocus = function() return nil, "unavailable" end,
    },
    Defaults = {
        Copy = function(self, t)
            if type(t) ~= "table" then return t end
            local copy = {}
            for k, v in pairs(t) do copy[k] = self:Copy(v) end
            return copy
        end
    },
    Locale = {
        Register = function(_, _, locale, entries) translations[locale] = entries end,
        Get = function(_, _, key, ...) return string.format((translations[language] or {})[key] or key, ...) end,
        Bind = function(_, build) return build() end,
    },
    Characters = {
        GetCurrentID = function() return currentID end,
        GetCurrent = function() return { id = currentID, name = "TestChar", realm = "TestRealm" } end,
        FormatName = function(self, char) return char.name or "Unknown" end,
        Get = function(self, id) return { id = id, name = "Char-" .. id } end,
    },
    AccountView = {
        RegisterPage = function(self, name, def)
            pageRegistrations = pageRegistrations + 1
            registeredPages[def.id] = def
            return true
        end,
        GetFieldVisible = function(_, pageID, id)
            if fieldVisibility[id] ~= nil then return fieldVisibility[id] end
            for _, field in ipairs(registeredPages[pageID].GetFieldDefinitions()) do
                if field.id == id then return field.defaultVisible ~= false end
            end
            return true
        end,
        SetFieldVisible = function(_, _, id, visible) fieldVisibility[id] = visible end,
        NotifyPageChanged = function() end,
        Toggle = function() end,
        GetColumnPage = function(_, _, _, characters) return characters, {} end,
        GetColumnPageByWidth = function(_, _, _, columns) return columns, {} end,
        GetScrollSurfaceWidth = function() return 500 end,
        FitRepeatedColumnWidth = function(_, _, _, _, width) return width end,
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
    ItemResolver = {
        GetInfo = function(self, id) return { name = "Item " .. tostring(id), icon = "item-icon" } end,
        Parse = function() return {} end,
        Request = function() end,
    },
}
_G.YiboCore = mockCore
dofile("YiboCore/UI/Theme.lua")
dofile("YiboCore/Runtime/Contracts.lua")
dofile("YiboCore/UI/BusinessItemActions.lua")
local Theme = mockCore.UITheme
Theme.MeasureText = function(_, _, value) return #value * 6 end
Theme.CreateScrollFrame = function(_, parent) return Node(parent) end
Theme.CreateInput = function(_, parent) return Node(parent) end
Theme.CreateDropdown = function(_, parent) return Node(parent) end

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
for line in io.lines("YiboCurrency/YiboCurrency_Forever.toc") do
    local path = line:match("^([^#%s].-%.lua)%s*$")
    if path then dofile("YiboCurrency/" .. path) end
end

local Addon = _G.YiboCurrency

-- Test 1: Initialize
WOW_PROJECT_ID = 19
assertTrue(not Addon:Initialize(), "The Forever manifest must reject a Mists client")
assertEqual(YiboCurrencyForeverDB, nil, "Wrong client stops before writing the store")
WOW_PROJECT_ID = WOW_PROJECT_CAMELOT
local fitColumns = mockCore.AccountView.FitRepeatedColumnWidth
mockCore.AccountView.FitRepeatedColumnWidth = nil
assertTrue(not Addon:Initialize(), "Core without the shared column fit method is rejected")
assertEqual(YiboCurrencyForeverDB, nil, "Incompatible Core stops before writing the store")
mockCore.AccountView.FitRepeatedColumnWidth = fitColumns
assertTrue(Addon:Initialize(), "Bootstrap:Initialize should succeed")
assertTrue(Addon:Initialize(), "Repeated initialization should succeed")
assertEqual(pageRegistrations, 1, "The account page should be registered once")
assertTrue(Addon.initialized, "Addon should be marked initialized")
assertTrue(Addon.Store.nativeStore ~= nil, "nativeStore should be initialized")
assertEqual(Addon.Store.db.schema, 1, "schema should be 1")

local contracts, actions = mockCore.Contracts, mockCore.BusinessItemActions
local providers = contracts:List("action.targets", { major = 1, minMinor = 1 })
if not supportsGoalActions then
    assertEqual(#providers, 0, "Without the optional action capability, no provider is registered")
    assertEqual(Addon.Store.db.goalSourceEpoch, nil, "Disabled goal features do not write goal metadata")
    Addon.Scanner.inWorld = true
    assertTrue(Addon.Scanner:Scan(true), "The base scanner remains usable")
    print("ForeverDiscoverySpec optional goal capability fallback passed.")
    return
end
assertEqual(#providers, 1, "Only one goal provider is registered")
local provider = providers[1]
assertEqual(provider.providerID, "YiboCurrency:targets", "Forever preserves the provider identity")
assertEqual(#contracts:List("action.targets", { major = 2 }), 0, "Incompatible consumers cannot use the provider")
local function Intent(objectID, characterID, quantity)
    return { providerID = provider.providerID, objectID = objectID,
        scope = { characterID = characterID }, conditions = { quantity = quantity, mode = "maintain" } }
end

local function Evaluate(intent)
    local result = assert(contracts:Call(Addon.NAME, provider, "Evaluate", { goals = { { id = "test", intent = intent } } }))
    return result.evaluations.test.task, result
end

-- Test 2: Scan in empty list (Forever 0-line baseline)
Addon.Scanner.inWorld = true
mockCurrencyList = {}
mockCurrencyDetails = {}
local scanned = Addon.Scanner:Scan(true)
assertTrue(scanned, "Scan should succeed on empty currency list")
assertEqual(Addon.Store.db.characters[currentID].moneyCopper, 12345, "money should be saved")
local dir = Addon.Store:GetNativeDirectory()
assertEqual(next(dir), nil, "Directory should initially be empty")
local preset = Addon:GetCatalogEntry("currency:3402")
assertEqual(preset.title, "Merchant's Favor", "The Forever built-in is visible even with an empty native list")
assertEqual(preset.icon, 135725, "The built-in icon is available before native discovery")
language = "zh"
assertEqual(Addon:GetCatalogEntry("currency:3402").title, "商人青睐", "Catalog fallback follows the Core language")
language = "en"
local presetAmount, presetState = Addon.Store:GetNativeCurrency(currentID, 3402)
assertEqual(presetAmount, nil, "Static data cannot establish a balance")
assertEqual(presetState, "unknown", "An unobserved built-in stays unknown")
local goldIntent = Intent("money", currentID, 12345)
local goldGoal, goldResult = Evaluate(goldIntent)
assertEqual(goldGoal.state, "completed", "Gold compares the exact copper balance")
assertTrue(goldResult.sourceEpoch ~= nil and goldResult.revision > 0 and goalChanges > 0, "Successful data updates notify goal consumers")
assertEqual(contracts:Call(Addon.NAME, provider, "Normalize", { intent = Intent("item:100", currentID, 1) }),
    nil, "Item goals belong to the inventory provider")

-- Test 3: Discovered new currencies (e.g. ID 100 with qty 50, ID 200 with qty 0)
mockCurrencyList = {
    { id = 100, name = "Honor Points", isHeader = false, icon = 1001 },
    { id = 200, name = "Conquest Points", isHeader = false, icon = 1002 },
}
mockCurrencyDetails[100] = { name = "Honor Points", quantity = 50, icon = 1001 }
mockCurrencyDetails[200] = { name = "Conquest Points", quantity = 0, icon = 1002 }
mockCurrencyDetails[3402] = { name = "Native Merchant's Favor", quantity = 12, icon = 0 }

_G.GetServerTime = function() return 1050 end
assertTrue(Addon.Scanner:Scan(true), "Scan should collect currencies")

dir = Addon.Store:GetNativeDirectory()
assertTrue(dir[100] ~= nil, "Currency 100 should be in directory")
assertTrue(dir[200] ~= nil, "Currency 200 should be in directory")
assertEqual(dir[100].name, "Honor Points", "Directory should store currency name")
assertEqual(dir[200].name, "Conquest Points", "Directory should store currency name")
assertEqual(Addon.Store:GetNativeCurrency(currentID, 3402), 12, "A known ID is queried even off the native list")
local observed = Addon:GetCatalogEntry("currency:3402")
assertEqual(observed.title, "Native Merchant's Favor", "The native API supplies the observed name")
assertEqual(observed.icon, 135725, "Native discovery retains the built-in icon when the API omits it")

-- Verify Values
local val100, state100 = Addon.Store:GetNativeCurrency(currentID, 100)
assertEqual(val100, 50, "Currency 100 value should be 50")
assertEqual(state100, "known", "Currency 100 state should be known")

local val200, state200 = Addon.Store:GetNativeCurrency(currentID, 200)
assertEqual(val200, 0, "Currency 200 value should be 0 (confirmed zero)")
assertEqual(state200, "known", "Currency 200 state should be known")
local nativeIntent = Intent("currency:100", currentID, 50)
assertEqual(Evaluate(nativeIntent).state, "completed", "Fresh native balance may complete a target")
assertEqual(Evaluate(Intent("currency:200", currentID, 1)).readiness, "actionable", "Confirmed zero is below the threshold")

-- Test 4: Fields & Discovered Catalog
local fields = Addon.AccountPage:Fields(true)
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
assertEqual(Evaluate(nativeIntent).readiness, "unknown", "Previous character is stale before the next scan")
assertEqual(Evaluate(goldIntent).readiness, "unknown", "Previous gold balance cannot establish completion")
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

-- The existing preview choice must feed the shared renderer, including zero and history.
assertTrue(regPage.SetPreviewFieldVisible("currency:200", true), "Should allow preview of confirmed zero")
assertTrue(regPage.SetPreviewFieldVisible("money", false), "Should allow hiding money independently")
local first = { id = "player-guild-guid-1", name = "First" }
local second = { id = currentID, name = "Second" }
local preview = { preview = true, characters = { first, second }, surfaceAvailableWidth = 700 }
local previewPageHost = Node()
regPage.Create(previewPageHost, preview)
local previewMetrics = regPage.GetSurfaceMetrics(preview)
regPage.Refresh(previewPageHost, preview)
local host = previewPageHost.currencyPreview
assertEqual(previewMetrics.scrollContentHeight, 2 * Theme.Table.rowHeight, "Only selected currencies are measured")
assertEqual(host.currencyRows[1].entry.id, "currency:100", "Selected native field is rendered")
assertEqual(host.currencyRows[1].cells[2]:GetText(), "—", "Native currency of unknown scope must not be summed")
assertEqual(host.currencyRows[1].cells[3]:GetText(), "50 (last seen)", "Offline value remains historical")
assertEqual(host.currencyRows[1].cells[4]:GetText(), "15", "Current character uses fresh data")
assertEqual(host.currencyRows[2].cells[3]:GetText(), "0 (last seen)", "Historical zero remains a value")
assertEqual(host.currencyRows[2].cells[4]:GetText(), "Unknown", "Unavailable value is not zero")

Addon.Store.db.settings.customItems = { [100] = "Saved item" }
_G.GetItemCount = function(itemID) if itemID == 100 then return 0 end end
Addon.Store:CommitItems(currentID, { [100] = 0 }, 1100)
local function MainContext()
    local fields = {}
    for _, field in ipairs(regPage.GetFieldDefinitions()) do
        if mockCore.AccountView:GetFieldVisible(Addon.PAGE_ID, field.id) then fields[#fields + 1] = field end
    end
    return { characters = { second }, fields = fields }
end
local main = MainContext()
local mainPageHost = Node()
regPage.Create(mainPageHost, main)
regPage.Refresh(mainPageHost, main)
local mainHost = mainPageHost.currencyMain
assertEqual(mainHost.itemRows[1].count:GetText(), "0", "Main table shows the same confirmed item value")
assertEqual(mainHost.itemRows[1].name:GetText(), "Item 100 · ID 100", "Item and currency may share the same number")
assertTrue(mainHost.balance.shown, "Main money visibility is independent of preview")
local goldBinding = actions.bindings[mainHost.balanceGoal]
assertEqual(goldBinding.GetIntent().objectID, "money", "The gold balance offers the Core target action")
assertEqual(goldBinding.GetIntent().scope.characterID, second.id, "Gold binds the current stable character ID")
local _, unavailable = actions:Invoke(mainHost.balanceGoal)
assertEqual(unavailable, "unavailable", "Missing consumer is handled by Core")
assertTrue(#coreMessages > 0, "Core reports that the action center is unavailable")

mockCore:RegisterAddon("TestConsumer")
local sharedIntent
local consumer = assert(contracts:Register("TestConsumer", { kind = "service", name = "action.demands",
    providerID = "TestConsumer:demands", version = { major = 1, minor = 0 }, methods = {
        Add = function(request) sharedIntent = request.intent; return { id = "test" } end,
    } }))
assertTrue(actions:Invoke(mainHost.balanceGoal), "A late compatible consumer can accept the action")
assertEqual(sharedIntent.objectID, "money", "Core forwards the gold intent")
assertTrue(regPage.SetPreviewFieldVisible("item:100", true), "Item is independently selectable")
local projected = Addon:GetCurrencyProjection({}, { second }, Addon:GetDisplayCatalog(true))
local item, itemState = Addon:ProjectionValue(projected, second, Addon:GetCatalogEntry("item:100"))
assertEqual(item.quantity, 0, "Preview projection sees the same item count")
assertEqual(itemState, "known", "Preview projection sees the same item state")

-- Core creates the instance once, then refreshes it for either surface.
local previewWithGold = { preview = true, characters = { first, second }, surfaceAvailableWidth = 700 }
assertTrue(regPage.SetPreviewFieldVisible("money", true), "Enable the gold row for the transition replay")
regPage.Refresh(previewPageHost, main)
local mainAfterPreview = previewPageHost.currencyMain
assertTrue(mainAfterPreview:IsShown() and mainAfterPreview.balance:IsShown(), "Preview-first instance opens the main balance")
assertTrue(not previewPageHost.currencyPreview:IsShown(), "The preview matrix is hidden under the main window")
assertEqual(mainAfterPreview.balanceTitle:GetText(), "Current character money", "Main balance keeps the single-character label")
assertEqual(mainAfterPreview.itemRows[1].count:GetText(), "0", "Main item counts still render after preview")

regPage.Refresh(previewPageHost, previewWithGold)
assertTrue(previewPageHost.currencyPreview:IsShown() and not mainAfterPreview:IsShown(), "Reopening preview hides the main balance and controls")
assertEqual(previewPageHost.currencyPreview.currencyRows[1].entry.title, "Gold", "The multi-character preview row is named Gold")

local otherPreviewFields = { "currency:100", "currency:200", "item:100" }
for _, id in ipairs(otherPreviewFields) do regPage.SetPreviewFieldVisible(id, false) end
language = "zh"
local chinesePreview = { preview = true, characters = { first, second }, surfaceAvailableWidth = 700 }
regPage.Refresh(previewPageHost, chinesePreview)
assertEqual(host.currencyRows[1].cells[1]:GetText():match("金币$"), "金币", "The Chinese preview renders the full gold label")
local goldLabelWidth = Theme:GetIconTextColumnWidth(16, Theme.Font.body, "金币") - Theme.Table.cellPadding
assertTrue(host.currencyRows[1].cells[1]:GetWidth() >= goldLabelWidth,
    "The hover cell reserves readable width for the gold icon and both Chinese characters")
Addon:GetSettings().hoverTranspose = true
regPage.Refresh(previewPageHost, { preview = true, characters = { first, second }, surfaceAvailableWidth = 700 })
assertEqual(host.currencyHeaders[2].label:GetText():match("金币$"), "金币", "The transposed column uses the same label")
assertTrue(host.currencyHeaders[2]:GetWidth() >= Theme:GetIconTextColumnWidth(16, Theme.Font.body, "金币"),
    "The transposed header has enough width for the gold icon and label")
Addon:GetSettings().hoverTranspose = false
for _, id in ipairs(otherPreviewFields) do regPage.SetPreviewFieldVisible(id, true) end
regPage.Refresh(previewPageHost, { characters = { second }, fields = regPage.GetFieldDefinitions() })
assertEqual(mainAfterPreview.balanceTitle:GetText(), "当前角色金币", "The Chinese main title still names the current character")
language = "en"

regPage.Refresh(mainPageHost, previewWithGold)
assertTrue(mainPageHost.currencyPreview:IsShown() and not mainPageHost.currencyMain:IsShown(), "Main-first instance opens the preview matrix")
assertEqual(mainPageHost.currencyPreview.currencyRows[1].entry.id, "money", "Main-first preview still reads the same gold field")
regPage.Refresh(mainPageHost, main)
assertTrue(mainPageHost.currencyMain:IsShown() and not mainPageHost.currencyPreview:IsShown(), "Returning to main hides the preview")
assertEqual(mainPageHost.currencyMain.balance, mainHost.balance, "Revisiting main reuses its controls")
assertEqual(previewPageHost.currencyPreview.currencyRows, host.currencyRows, "Revisiting preview reuses its matrix")
assertTrue(regPage.SetPreviewFieldVisible("money", false), "Restore the independently hidden money field")

-- Both tabs use the shared panel, with native fields limited to the existing hover surface.
local settingsHost = Node()
local settingsContext = {availableHeight = 460, notifyPageChanged = function() end}
local createSettings = regPage.settings.CreateSettingsPanel
settingsContext.refreshPanel = function() return createSettings(settingsHost, settingsContext) end
assertTrue(not Addon:IsHoverTransposed(), "An old store defaults to the original preview orientation")
settingsContext.refreshPanel()
local panel = settingsHost.ycuSettings
assertTrue(panel.catalogTabs.builtin.shown and panel.catalogTabs.custom.shown, "Both tabs are visible")
assertTrue(panel.transpose.shown and not panel.itemPicker.shown, "The built-in tab exposes transpose but keeps the item picker on the custom tab")
panel.transpose:GetScript("OnClick")(panel.transpose)
assertTrue(Addon:IsHoverTransposed(), "The built-in tab enables actual preview transposition")
panel.transpose:GetScript("OnClick")(panel.transpose)
assertEqual(panel.rows[2].entry.id, "currency:100", "Native discoveries appear under built-ins")
assertTrue(panel.rows[2].main.shown and panel.rows[2].hover.shown, "Native currency has independent checkboxes")
assertTrue(not panel.rows[2].main:GetChecked(), "Existing layouts hide native main rows by default")
assertTrue(panel.rows[2].hover:GetChecked(), "Existing native hover preferences are shown")
panel.rows[2].main:GetScript("OnClick")(panel.rows[2].main)
assertTrue(fieldVisibility["currency:100"] and Addon:IsMonitored(panel.rows[2].entry), "Selecting the main row leaves the hover preference unchanged")
panel.rows[2].hover:GetScript("OnClick")(panel.rows[2].hover)
assertTrue(fieldVisibility["currency:100"] and not Addon:IsMonitored(panel.rows[2].entry), "Changing hover leaves the main preference unchanged")
panel.rows[2].hover:GetScript("OnClick")(panel.rows[2].hover)
assertTrue(Addon:SetCurrencyDisplay("currency:515", "main", true), "Unobserved built-ins can be shown prominently")
assertTrue(not Addon:IsMonitored(Addon:GetCatalogEntry("currency:515")), "Selecting a built-in in the main window does not select it for hover")
regPage.Refresh(mainPageHost, MainContext())
assertEqual(mainHost.itemRows[1].count:GetText(), "15", "Main and hover use the same observed native balance")
assertEqual(mainHost.itemRows[2].count:GetText(), "Unknown", "An unread built-in balance is unknown in the main window")
assertEqual(mainHost.itemRows[3].count:GetText(), "0", "Native main rows preserve the separate item row")
mockCurrencyDetails[100] = nil
assertTrue(Addon.Scanner:Scan(true), "A scan may succeed with unavailable native currency")
regPage.Refresh(mainPageHost, MainContext())
assertEqual(mainHost.itemRows[1].count:GetText(), "Unknown", "An unread current native balance does not show an old amount as current")
mockCurrencyDetails[100] = { name = "Honor Points", quantity = 15, icon = 1001 }
assertTrue(Addon.Scanner:Scan(true), "Restore numeric observations for the remaining preview checks")
panel.rows[2].main:GetScript("OnClick")(panel.rows[2].main)
assertTrue(not fieldVisibility["currency:100"] and Addon:IsMonitored(panel.rows[2].entry), "Hiding the main row leaves hover enabled")
assertTrue(actions:Invoke(panel.rows[2]), "A discovered currency can use the Core target action")
assertEqual(sharedIntent.objectID, "currency:100", "Currency forwards the stable native field ID")
assertEqual(sharedIntent.scope.characterID, second.id, "Native currency targets the current character")
assertTrue(contracts:Unregister("TestConsumer", consumer), "Temporary consumer unregisters")
assertEqual(select(2, actions:Invoke(panel.rows[2])), "unavailable", "Unregistering the consumer disables the operation")

panel.catalogTabs.custom:GetScript("OnClick")()
assertTrue(panel.transpose.shown and panel.itemPicker.shown, "Custom tab contains transpose and the item picker")
assertEqual(panel.itemPicker.config.resolve.allowName, false, "Forever retains ID-only lookup")
panel.rows[1]:GetScript("OnClick")()
assertEqual(panel.itemPicker.value, "100", "Clicking a custom row selects it by item ID")
panel.rows[1].main:GetScript("OnClick")(panel.rows[1].main)
assertEqual(fieldVisibility["item:100"], false, "Shared settings update the Core main field independently")
assertTrue(Addon:GetSettings().previewColumns["item:100"], "Main toggle preserves hover choice")
panel.transpose:GetScript("OnClick")(panel.transpose)
assertTrue(Addon.Store.db.settings.hoverTranspose, "Transpose is stored in the existing Forever settings")
local transposed = { preview = true, characters = { first, second }, surfaceAvailableWidth = 700 }
local transposedMetrics = regPage.GetSurfaceMetrics(transposed)
regPage.Refresh(previewPageHost, transposed)
assertEqual(transposedMetrics.scrollContentHeight, 3 * Theme.Table.rowHeight, "Transpose measures total and character rows")
assertEqual(host.currencyRows[2].entry.character.id, first.id, "First character is now a row")
assertEqual(host.currencyRows[2].cells[2]:GetText(), "50 (last seen)", "Transpose uses the same historical currency value")
assertEqual(host.currencyRows[3].cells[4]:GetText(), "0", "Transpose uses the same confirmed item zero")

local picker = panel.itemPicker.config
assertTrue(not picker.add.Validate({itemID = 100}), "Duplicate custom IDs are rejected")
assertTrue(picker.add.Execute({itemID = 101, name = "Test item"}), "Shared add uses Forever storage")
assertEqual(Addon.Store:Items()[101], "Test item", "Added item keeps the Forever map format")
assertTrue(picker.remove.Confirm({itemID = 101}):find("101", 1, true), "Removal confirmation names the correct item")
assertTrue(picker.remove.Execute({itemID = 101}), "Shared removal uses Forever storage")
assertEqual(Addon.Store:Items()[101], nil, "Confirmed removal drops the custom catalog entry")
assertEqual(YiboCurrencyDB, nil, "Forever settings never write to the Mists database")

panel.transpose:GetScript("OnClick")(panel.transpose)
assertEqual(Addon:GetSettings().hoverTranspose, false, "Turning off transpose restores the original orientation")

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
